---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Frame, Texture = ui.Frame, ui.Texture
local GetSourceInfo = C_TransmogCollection.GetSourceInfo
local GetItemIcon = C_Item.GetItemIconByID
local RequestItem = C_Item.RequestLoadItemDataByID
local DressingRoom = ns.DressingRoom
local k = DressingRoom._k
local selBox, SELECTED, IDLE = k.selBox, k.SELECTED, k.IDLE
local TARGETS = DressingRoom._TARGETS

-- The **look-driven** paper-doll slots (#770 step 15): the main/off-hand pair across the model's
-- bottom centre (controls/DressingRoomWeaponSlots.lua) and the shirt/tabard cells in the left armour
-- column (controls/DressingRoomCosmeticSlots.lua). Despite living at opposite ends of the doll the
-- two are the same control — a framed icon over one composed-look field, left-click opens the docked
-- picker at that field, right-click clears it — and they had been written out twice, so eight
-- features since #641 landed in both files by hand.
--
-- This file owns the shared behaviour; the two companion files keep only what genuinely differs:
-- where the slot sits, how its tooltip reads, and (weapons only) when it's suppressed.
--
-- **Not the armour slots** (controls/DressingRoomSlots.lua). Those are driven by the previewed SET
-- rather than the composed look: no picker target, a three-state worn→hidden→empty left-click, a
-- `_slotHint` tooltip line and no placeholder art. Merging them produces a builder that is mostly
-- `if`, which is why the plan excluded them.
--
-- Reopens the DressingRoom class.

---@class Warbandeer_Collected
---@field slotOK number[]  status border: this appearance is collected
---@field slotMissing number[]  status border: not collected

-- The slot status colours, declared five times across the room before this. **Not** `ns.gridShades`
-- [1]/[10], which happen to be the same two endpoints: those are a completion gradient over a grid
-- cell, they carry different alpha, and tying a slot border to the grid's palette would make either
-- one impossible to retune alone.
ns.slotOK      = {0, 104/255, 55/255, 1}
ns.slotMissing = {165/255, 0, 38/255, 1}

---Build one look-driven slot and return its entry. The caller registers the entry in whichever
---lists it belongs to and adds any kind-specific fields — those differ (`hand`, `slotID`,
---`cosmetic`) and nothing shared reads them.
---@param room DressingRoom
---@param spec table  { target, label, empty, position, level?, tooltip, blocked? }
---@return table entry
function DressingRoom._buildLookSlot(room, spec)
  local box = Frame:new{ parent = room, position = spec.position }
  -- The weapon pair overlays the mouse-enabled ModelScene, so it has to be lifted above it or the
  -- clicks rotate the model instead. The column cells sit on the window and need no lift.
  if spec.level then box:Level(spec.level) end
  local border = selBox(box)
  local icon = Texture:new{
    parent = box, layer = ui.layer.Artwork,
    position = { TopLeft = {2, -2}, BottomRight = {-2, 2} },
  }
  local entry = {
    target = spec.target, label = spec.label, empty = spec.empty,
    look = TARGETS[spec.target].look, blocked = spec.blocked,
    icon = icon, border = border, box = box,
  }

  box._widget:EnableMouse(true)
  box._widget:SetScript("OnEnter", function(f) spec.tooltip(room, f, entry) end)
  box._widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
  box._widget:SetScript("OnMouseUp", function(_, button)
    if entry.blocked and entry.blocked(room) then return end   -- suppressed off-hand (#618)
    if button == "LeftButton" then
      local open = room._picker and room._picker._widget:IsShown()
      if open and room._pickerTarget == entry.target then
        room:TogglePicker(false)               -- already open on this slot → close
      else
        room:TogglePicker(true, entry.target)  -- open / switch to this slot
      end
    elseif button == "RightButton" then
      room:_clearLookSlot(entry.target)
    end
  end)

  return entry
end

---Paint one list of look slots from the composed look.
---@param room DressingRoom
---@param entries table[]
---@return boolean missing  true if any icon is still loading
local function paint(room, entries)
  local open = room._picker and room._picker._widget:IsShown()
  local missing = false
  for _, e in ipairs(entries) do
    -- Read straight off the entry's `look` field. The weapon half used to branch on the hand, under
    -- a standing warning never to fold it into `_lookOH or _lookMH` — an empty off-hand must stay
    -- blank rather than fall through to the main-hand weapon. Indexing can't fall through at all.
    local sourceID = room[e.look]
    local info = sourceID and GetSourceInfo(sourceID)
    local itemID = info and info.itemID
    if itemID then
      e.itemID = itemID
      local tex = GetItemIcon(itemID)
      if not tex then RequestItem(itemID); missing = true end
      e.icon:Texture(tex or e.empty)
    else
      e.itemID = nil
      e.icon:Texture(e.empty)
    end
    -- A suppressed slot and the master Undress both grey the ICON only (0.3, matching a toggled-off
    -- armour slot) — the status border stays, so the slot still reads as collected or not.
    local blocked = e.blocked and e.blocked(room)
    local v = (blocked or room._undressed) and 0.3 or 1
    e.icon:SetVertexColor(v, v, v, 1)
    if blocked then
      e.border:Color(IDLE)                                       -- whatever pick it's keeping
    elseif open and room._pickerTarget == e.target then
      e.border:Color(SELECTED)                                   -- picker open on this slot
    elseif itemID then
      e.border:Color(info.isCollected and ns.slotOK or ns.slotMissing)
    else
      e.border:Color(IDLE)
    end
  end
  return missing
end

---Repaint every look-driven slot — both hands and both cosmetics — from the composed look.
---
---One method where there were two, because every one of the call sites wanted both: all four
---repainted the hands and the cosmetics back to back. That also puts the two under ONE retry budget
---rather than two, which is what they effectively had anyway — the pair was scheduled together, on
---the same cadence, re-checking the same look.
---@param retry boolean?  internal: true on the self-scheduled re-run (skips the budget reset)
function DressingRoom:UpdateLookSlots(retry)
  if not (self._weaponSlots and self._cosmeticSlots) then return end
  if not retry then ns.ResetRetry(self, "lookSlots") end   -- a fresh pass gets a full budget
  -- Both painted every pass: `paint(...) or missing` and not `missing or paint(...)`, so a resolved
  -- first list can't short-circuit the second out of its icon requests.
  local missing = paint(self, self._weaponSlots)
  missing = paint(self, self._cosmeticSlots) or missing
  if missing then
    ns.Retry(self, "lookSlots", { again = function() self:UpdateLookSlots(true) end })
  else
    ns.CancelRetry(self, "lookSlots")
  end
end

---Clear a slot's pick — the right-click gesture, left-click being taken by "open the picker".
---@param target string  "main" | "off" | "shirt" | "tabard"
function DressingRoom:_clearLookSlot(target)
  local field = TARGETS[target].look
  if not self[field] then return end
  self[field] = nil
  -- Emptying the main hand releases the two-hander's off-hand suppression along with it, or the
  -- off-hand would stay dimmed and unclickable with nothing left to justify it.
  if target == "main" then self._lookNoOH = nil end
  self:_applyLook()
  -- The browsed weapon just came off the doll, so the cell chooser has to stop claiming it's still
  -- in this hand (#763). `_cellHand` drives BOTH the gold "this is where it is" border and
  -- `_useCellLook`'s no-op guard, so leaving it set left the selector lit *and* dead.
  --
  -- Guarded on the slot actually cleared, so clearing the main hand while the browsed weapon sits in
  -- the off hand leaves that selection where it belongs. A cosmetic target can never match a hand,
  -- so the guard is simply false on that path.
  if self._cellHand == target then
    self._cellHand = nil
    self:_syncCellActions()
    if self._cellList then self._cellList:Refresh() end
  end
  if self._picker and self._picker._widget:IsShown() then self._pickerList:Refresh() end
end
