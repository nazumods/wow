---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Frame, Texture = ui.Frame, ui.Texture
local GetSourcesForSlot = C_TransmogSets.GetSourcesForSlot
local GetAllSourceIDs = C_TransmogSets.GetAllSourceIDs
local getParts = C_TransmogSets.GetSetPrimaryAppearances
local GetSourceInfo = C_TransmogCollection.GetSourceInfo
local GetItemInfoInstant = C_Item.GetItemInfoInstant
local find, any = ns.lua.lists.find, ns.lua.maps.any
local GameTooltip = GameTooltip

-- Equip-location string → paper-doll slot id, for bucketing a set's pieces by item
-- when the per-slot source API yields nothing (see ns.SetSlotPieces). Cloak folds
-- into the Back slot; robes into Chest.
local EQUIP_SLOT = {
  INVTYPE_HEAD = 1, INVTYPE_SHOULDER = 3, INVTYPE_CLOAK = 15,
  INVTYPE_CHEST = 5, INVTYPE_ROBE = 5, INVTYPE_WAIST = 6,
  INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10,
}

-- Bucket a set's appearance sources into paper-doll slots by each piece's equip
-- location, with collected status + itemID from GetSourceInfo. A fallback for sets
-- (e.g. Trading Post recolors) where C_TransmogSets.GetSourcesForSlot returns
-- nothing per slot even though GetAllSourceIDs still has all the pieces (and the
-- model wears them). Shared by the dressing-room slots and the hover InfoTip.
---@param setID number
---@return table<number, { itemID: number, isCollected: boolean }>  keyed by slot id
function ns.SetSlotPieces(setID)
  local out = {}
  for _, sourceID in ipairs(GetAllSourceIDs(setID)) do
    local info = GetSourceInfo(sourceID)
    local itemID = info and info.itemID
    local loc = itemID and select(4, GetItemInfoInstant(itemID))
    local slot = loc and EQUIP_SLOT[loc]
    if slot then out[slot] = { itemID = itemID, isCollected = info.isCollected } end
  end
  return out
end

-- Resolve a single appearance source to its paper-doll slot id (nil if it maps to
-- no shown slot — e.g. a weapon). Lets Dress drop the sources of slots the user has
-- toggled off. Same equip-location mapping as ns.SetSlotPieces, one source at a time.
---@param sourceID number
---@return number?
function ns.SourceSlot(sourceID)
  local info = GetSourceInfo(sourceID)
  local itemID = info and info.itemID
  local loc = itemID and select(4, GetItemInfoInstant(itemID))
  return loc and EQUIP_SLOT[loc]
end

-- Reopen the class and borrow the layout primitives DressingRoom.lua shares with
-- us (it loads first; see the explicit exports just after its class definition).
-- What each slot LOOKS like — and the worn/hidden/empty state it looks that way for — is the
-- companion DressingRoomSlotStates.lua's business, reached here through `:_paintSlot`.
local DressingRoom = ns.DressingRoom
local selBox = DressingRoom._selBox
local PAD, MODELH = DressingRoom._PAD, DressingRoom._MODELH

-- Equipment-slot columns flanking the model (paper-doll style), in Blizzard's own paper-doll
-- order. Slot ids are inventory slots, also the GetSourcesForSlot key. Six left / five right.
--
-- The two `target`-bearing entries are the COSMETIC slots (#641): shirt and tabard are never set
-- pieces, so they're built and refreshed by controls/DressingRoomCosmeticSlots.lua off the composed
-- look instead of by UpdateSlots off the previewed set. `target` is the picker target a click on
-- them opens. Six slots is 6*44 + 5*16 = 344px, well inside MODELH, and layoutColumn centres each
-- column independently — so the uneven split needs no other geometry change.
local SLOT     = 44   -- slot button size
local SLOTGAP  = 16   -- vertical gap between slots
local COLINSET = 8    -- column distance from the window edge
local LEFT_SLOTS  = {
  {1, "Head"}, {3, "Shoulder"}, {15, "Back"}, {5, "Chest"},
  {INVSLOT_BODY, "Shirt", target = "shirt"}, {INVSLOT_TABARD, "Tabard", target = "tabard"},
}
local RIGHT_SLOTS = { {9, "Wrist"}, {10, "Hands"}, {6, "Waist"}, {7, "Legs"}, {8, "Feet"} }

-- How far the model is inset from each window edge to clear a slot column. Read
-- back by the constructor in DressingRoom.lua when anchoring the model.
DressingRoom.MODEL_INSET = COLINSET + SLOT + PAD

-- The column's slot metric, published for the cosmetic slots — they're built by a companion file
-- but have to size themselves identically to their column neighbours.
DressingRoom._k.SLOT = SLOT

-- Build one paper-doll equipment slot: a framed icon that shows the set piece for
-- `slotID`, opens the in-game item tooltip on hover, and left-click cycles the
-- piece through worn / hidden / no transmog. Registered on room._slots and refreshed
-- per set by UpdateSlots.
---@param room DressingRoom
---@param slotID number  inventory slot id
---@param x number
---@param y number
---@param side string  "left"|"right" — which way the tooltip opens
local function buildSlot(room, slotID, x, y, side)
  local box = Frame:new{
    parent = room,
    position = { TopLeft = {x, y}, Width = SLOT, Height = SLOT },
  }
  local border = selBox(box)
  local icon = Texture:new{
    parent = box, layer = ui.layer.Artwork,
    position = { TopLeft = {2, -2}, BottomRight = {-2, 2}, Hide = true },
  }
  local entry = { slotID = slotID, icon = icon, border = border, box = box }

  local anchor = side == "left" and "ANCHOR_LEFT" or "ANCHOR_RIGHT"
  box._widget:EnableMouse(true)
  box._widget:SetScript("OnEnter", function(f)
    if not entry.itemID then return end
    GameTooltip:SetOwner(f, anchor)
    GameTooltip:SetItemByID(entry.itemID)
    -- The tooltip is where the three states are named: the icon says which one a slot is in, this
    -- says what it means and what the next click does.
    local hint = room:_slotHint(entry.slotID)
    if hint then GameTooltip:AddLine(hint, 0.6, 0.6, 0.6) end
    GameTooltip:Show()
  end)
  box._widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
  -- Left-click steps this piece round the state cycle; empty/unresolved slots stay inert.
  box._widget:SetScript("OnMouseUp", function(_, button)
    if button == "LeftButton" and entry.itemID then room:ToggleSlot(entry) end
  end)

  room._slots[#room._slots + 1] = entry
end

-- Lay out one vertically-centered column of slots at column x (each column is
-- centered independently, so the two sides can hold a different number of slots).
-- A `target`-bearing entry is a cosmetic slot, built by its own companion file.
---@param room DressingRoom
---@param slots table[]  { {slotID, label, target?}, ... }
---@param x number
---@param side string  "left"|"right"
local function layoutColumn(room, slots, x, side)
  local n = #slots
  local colH = n * SLOT + (n - 1) * SLOTGAP
  local startY = -(30 + PAD) - (MODELH - colH) / 2
  for i, s in ipairs(slots) do
    local y = startY - (i - 1) * (SLOT + SLOTGAP)
    if s.target then room:_buildCosmeticSlot(s, x, y, side) else buildSlot(room, s[1], x, y, side) end
  end
end

-- Build both paper-doll slot columns flanking the model. Called once from the
-- constructor; winW is the final window width (right column hugs the right edge).
---@param winW number
function DressingRoom:_buildSlots(winW)
  self._slots = {}
  self._cosmeticSlots = {}   -- the shirt/tabard subset of _slots (DressingRoomCosmeticSlots.lua)
  self._hiddenSlots = {}   -- inventory slot ids that aren't being worn, by state (reset per set in _load)
  layoutColumn(self, LEFT_SLOTS, COLINSET, "left")
  layoutColumn(self, RIGHT_SLOTS, winW - COLINSET - SLOT, "right")
end

-- `_showSlots(show)` used to live here, and its weapon-slot twin in DressingRoomWeaponSlots.lua:
-- the columns came down for a weapon-cell preview (a bare body has no armour slots) and went back
-- up for a set. #673 removed the second doll, so nothing hides them any more — the columns are up
-- from construction, and browsing a weapon happens on the same paper doll with them still there.

-- Resolve the current set's piece for each paper-doll slot into the slot entry (its itemID and
-- collected status), then hand the painting to _paintSlot — what a slot looks like belongs to the
-- state it's in, so this file finds the piece and DressingRoomSlotStates.lua renders it.
function DressingRoom:UpdateSlots()
  local set = self._set
  -- No set previewed — a weapon browsed straight from a fresh open (#673). Blank the columns rather
  -- than returning: the doll is a bare body, and leaving the last set's icons up would claim it was
  -- wearing pieces it isn't. Cosmetic slots are the picker's, as ever.
  if not set then
    for _, e in ipairs(self._slots) do
      if not e.cosmetic then e.itemID, e.collected = nil, nil; self:_paintSlot(e) end
    end
    return
  end
  -- GetSetPrimaryAppearances returns nil for a set with none (e.g. a PvP set — primary
  -- appearances are a raid-tier concept), so coalesce: ipairs(nil) would error here and
  -- abort _load before Dress(), leaving the model un-skinned. Empty primary → every slot
  -- falls through to the GetAllSourceIDs bucket below, which has the pieces.
  local parts = getParts(set.id) or {}
  local primary = {}
  for _, p in ipairs(parts) do primary[p.appearanceID] = true end

  -- Built lazily, only if a slot's per-slot source lookup comes up empty.
  local fallback

  local missing = false
  for _, e in ipairs(self._slots) do
    -- Cosmetic slots (shirt/tabard) are picker-driven, not set pieces — a set never carries one,
    -- so there is nothing to look up here. UpdateLookSlots owns them. #641.
    if not e.cosmetic then
      local sources = GetSourcesForSlot(set.id, e.slotID)
      local _, p = find(sources, function(s) return primary[s.sourceID] end)
      local itemID, collected
      if p then
        local info = GetSourceInfo(p.sourceID)
        itemID = info and info.itemID
        collected = any(sources, function(s) return s.isCollected end)
      else
        -- Per-slot API gave nothing (Trading Post / variant set): bucket the set's
        -- pieces by equip location instead.
        fallback = fallback or ns.SetSlotPieces(set.id)
        local fb = fallback[e.slotID]
        if fb then itemID, collected = fb.itemID, fb.isCollected end
      end
      e.itemID, e.collected = itemID, collected
      if self:_paintSlot(e) then missing = true end
    end
  end

  -- Icons aren't always cached on the first pass; re-run shortly (capped) until
  -- they resolve.
  -- The shared capped retry (#770 step 14). Its budget is reset in `DressingRoom:_load`, not here —
  -- it belongs to the room's whole open rather than to one `UpdateSlots` call.
  if missing then
    ns.Retry(self, "slots", { again = function() self:UpdateSlots() end })
  else
    ns.CancelRetry(self, "slots")
  end
end
