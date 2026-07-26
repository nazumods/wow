---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Frame, Texture = ui.Frame, ui.Texture
local GetSourceInfo = C_TransmogCollection.GetSourceInfo
local GetItemIcon = C_Item.GetItemIconByID
local RequestItem = C_Item.RequestLoadItemDataByID
local GameTooltip, C_Timer = GameTooltip, C_Timer

-- Character-sheet weapon slots (#615): a main-hand + off-hand pair across the model's
-- bottom center, mirroring Blizzard's paper doll (armor down the sides, weapons across
-- the bottom). Unlike the armor columns (DressingRoomSlots.lua) these aren't C_TransmogSets
-- slots — they're the look-builder's composed weapons (_lookMH / _lookOH), and clicking one
-- is the entry point to the docked picker (AppearancePicker.lua), replacing the old floating
-- "Weapons" button. The shirt/tabard slots (DressingRoomCosmeticSlots.lua) work the same way.
-- Reopens the DressingRoom class.
local DressingRoom = ns.DressingRoom
local k = DressingRoom._k
local selBox, SELECTED, IDLE = k.selBox, k.SELECTED, k.IDLE
local GREEN = {0, 104/255, 55/255, 1}   -- weapon collected (matches the armor-slot status green)
local RED   = {165/255, 0, 38/255, 1}   -- weapon not collected

local SLOT   = 44   -- slot button size (matches the armor slots)
local GAP    = 8    -- gap between the two slots
local BOTTOM = 10   -- lift above the model's bottom edge

-- The two hands, laid out symmetrically about the model's bottom center. `empty` is the
-- Blizzard paper-doll placeholder shown when nothing's picked; `dx` offsets the slot left/
-- right of center so the pair straddles the midline.
local HANDS = {
  { hand = "main", slot = INVSLOT_MAINHAND, label = "Main Hand",
    empty = [[Interface\PaperDoll\UI-PaperDoll-Slot-MainHand]],      dx = -(SLOT + GAP) / 2 },
  { hand = "off",  slot = INVSLOT_OFFHAND,  label = "Off Hand",
    empty = [[Interface\PaperDoll\UI-PaperDoll-Slot-SecondaryHand]], dx =  (SLOT + GAP) / 2 },
}

-- Show the picked weapon's item tooltip (+ change/clear hint), or a "pick a weapon" prompt
-- for an empty slot.
---@param room DressingRoom
---@param f table  the slot's backing widget
---@param e table  the weapon-slot entry
local function slotTooltip(room, f, e)
  GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
  if e.hand == "off" and room._lookNoOH then
    GameTooltip:SetText(e.label)
    GameTooltip:AddLine("Two-handed weapon equipped — no off-hand", 0.6, 0.6, 0.6)
  elseif e.itemID then
    GameTooltip:SetItemByID(e.itemID)
    GameTooltip:AddLine("Left-click to change, right-click to clear", 0.6, 0.6, 0.6)
  else
    GameTooltip:SetText(e.label)
    GameTooltip:AddLine("Click to choose a weapon", 0.6, 0.6, 0.6)
  end
  GameTooltip:Show()
end

-- Build one weapon slot: a framed icon anchored to the model's bottom center, LIFTED above
-- the mouse-enabled ModelScene (Level +10) so clicks land here instead of rotating the model
-- (same lift the on-model overlays use). Left-click opens/switches the picker to this hand
-- (or closes it if already open here); right-click clears the slot.
---@param room DressingRoom
---@param spec table  a HANDS entry
local function buildWeaponSlot(room, spec)
  local box = Frame:new{
    parent = room,
    position = { Bottom = {room._model, ui.edge.Bottom, spec.dx, BOTTOM}, Width = SLOT, Height = SLOT },
  }
  box:Level(room._model:Level() + 10)
  local border = selBox(box)
  local icon = Texture:new{
    parent = box, layer = ui.layer.Artwork,
    position = { TopLeft = {2, -2}, BottomRight = {-2, 2} },
  }
  local entry = { hand = spec.hand, label = spec.label, empty = spec.empty, icon = icon, border = border, box = box }

  box._widget:EnableMouse(true)
  box._widget:SetScript("OnEnter", function(f) slotTooltip(room, f, entry) end)
  box._widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
  box._widget:SetScript("OnMouseUp", function(_, button)
    if entry.hand == "off" and room._lookNoOH then return end   -- staff/polearm/ranged: no off-hand (#618)
    if button == "LeftButton" then
      local open = room._picker and room._picker._widget:IsShown()
      if open and room._pickerTarget == entry.hand then
        room:TogglePicker(false)             -- already open on this hand → close
      else
        room:TogglePicker(true, entry.hand)  -- open / switch to this hand
      end
    elseif button == "RightButton" then
      room:_clearWeaponSlot(entry.hand)
    end
  end)

  room._weaponSlots[#room._weaponSlots + 1] = entry
end

-- Build the bottom-center weapon-slot pair. Called once from the constructor (after the
-- model exists — the slots anchor to it).
function DressingRoom:_buildWeaponSlots()
  self._pickerTarget = "main"   -- the picker opens on the main hand until a slot re-points it
  self._weaponSlots = {}
  for _, spec in ipairs(HANDS) do buildWeaponSlot(self, spec) end
end

-- Fill each weapon slot from the composed look (_lookMH / _lookOH): the picked weapon's icon,
-- with a status border — gold while the picker targets this hand, else green (collected) and
-- IDLE when empty (the placeholder art shows). Weapon icons load async, so retry shortly
-- (capped) until they resolve, like UpdateSlots.
---@param retry boolean?  internal: true on the self-scheduled re-run (skips the retry-count reset)
function DressingRoom:UpdateWeaponSlots(retry)
  if not self._weaponSlots then return end
  if not retry then self._weaponSlotRetries = 0 end
  local open = self._picker and self._picker._widget:IsShown()
  local missing = false
  for _, e in ipairs(self._weaponSlots) do
    -- Each slot shows ONLY its own hand's pick (an if/else, not an `and/or` — an empty off-hand
    -- must stay blank, not fall through to the main-hand weapon).
    local sourceID
    if e.hand == "off" then sourceID = self._lookOH else sourceID = self._lookMH end
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
    -- A main-hand with no room for an off-hand disables it: dim its icon (0.3, matching the armor
    -- slots' toggled-off dim) and hold the border idle, whatever pick it's keeping. Otherwise full
    -- color + the normal status / selection border. A Titan's Grip two-hander leaves the off-hand
    -- live, so this no longer fires for every two-hander. #618, #661.
    --
    -- The master Undress dims BOTH slots too — it bares the composed look off the model along with
    -- the armor, so leaving these reading as worn would contradict the doll. Only the icon greys;
    -- the status border stays, exactly as a toggled-off armor slot keeps its green/red.
    local disabled = e.hand == "off" and self._lookNoOH
    local v = (disabled or self._undressed) and 0.3 or 1
    e.icon:SetVertexColor(v, v, v, 1)
    if disabled then
      e.border:Color(IDLE)
    elseif open and self._pickerTarget == e.hand then
      e.border:Color(SELECTED)                                   -- picker open on this hand
    elseif itemID then
      e.border:Color(info.isCollected and GREEN or RED)
    else
      e.border:Color(IDLE)
    end
  end

  if self._weaponSlotTimer then self._weaponSlotTimer:Cancel(); self._weaponSlotTimer = nil end
  if missing and (self._weaponSlotRetries or 0) < 10 then
    self._weaponSlotRetries = (self._weaponSlotRetries or 0) + 1
    self._weaponSlotTimer = C_Timer.NewTimer(0.2, function()
      self._weaponSlotTimer = nil
      self:UpdateWeaponSlots(true)
    end)
  end
end

-- Clear a hand's picked weapon (the right-click gesture — left-click is taken by "open the
-- picker"). Re-applies the look (which repaints the slots) and re-colors the picker's
-- selection borders if it's open.
---@param hand string  "main" | "off"
function DressingRoom:_clearWeaponSlot(hand)
  if hand == "off" then
    if not self._lookOH then return end
    self._lookOH = nil
  else
    if not self._lookMH then return end
    self._lookMH, self._lookNoOH = nil, nil
  end
  self:_applyLook()
  -- The browsed weapon just came off the doll, so the cell chooser has to stop claiming it's still
  -- in this hand (#763). `_cellHand` drives BOTH the gold "this is where it is" border and
  -- `_useCellLook`'s no-op guard, so leaving it set left the selector lit *and* dead: clicking the
  -- lit hand short-circuited on `hand == self._cellHand`, and the only way back was clicking the
  -- other hand or re-clicking the list row.
  --
  -- Guarded on the hand actually cleared, so clearing the main hand while the browsed weapon sits
  -- in the off hand leaves that selection where it belongs.
  if self._cellHand == hand then
    self._cellHand = nil
    self:_syncCellActions()
    if self._cellList then self._cellList:Refresh() end
  end
  if self._picker and self._picker._widget:IsShown() then self._pickerList:Refresh() end
end
