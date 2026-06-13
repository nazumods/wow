---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Frame, Texture = ui.Frame, ui.Texture
local GetSourcesForSlot = C_TransmogSets.GetSourcesForSlot
local getParts = C_TransmogSets.GetSetPrimaryAppearances
local GetSourceInfo = C_TransmogCollection.GetSourceInfo
local GetItemIcon = C_Item.GetItemIconByID
local RequestItem = C_Item.RequestLoadItemDataByID
local find, any = ns.lua.lists.find, ns.lua.maps.any
local GameTooltip = GameTooltip

-- Reopen the class and borrow the layout primitives DressingRoom.lua shares with
-- us (it loads first; see the explicit exports just after its class definition).
local DressingRoom = ns.DressingRoom
local selBox, IDLE = DressingRoom._selBox, DressingRoom._IDLE
local PAD, MODELH = DressingRoom._PAD, DressingRoom._MODELH

-- slot-status colors + the question-mark fallback icon (used only here)
local GREEN    = {0, 104/255, 55/255, 1}   -- piece collected
local RED      = {165/255, 0, 38/255, 1}   -- piece missing
local QUESTION = 134400                    -- inv_misc_questionmark fileID

-- Equipment-slot columns flanking the model (paper-doll style). Slot ids are
-- inventory slots, also the GetSourcesForSlot key. Four/five per side.
local SLOT     = 44   -- slot button size
local SLOTGAP  = 16   -- vertical gap between slots
local COLINSET = 8    -- column distance from the window edge
local LEFT_SLOTS  = { {1, "Head"},  {3, "Shoulder"}, {15, "Back"}, {5, "Chest"}, {9, "Wrist"} }
local RIGHT_SLOTS = { {10, "Hands"}, {6, "Waist"},   {7, "Legs"},  {8, "Feet"} }

-- How far the model is inset from each window edge to clear a slot column. Read
-- back by the constructor in DressingRoom.lua when anchoring the model.
DressingRoom.MODEL_INSET = COLINSET + SLOT + PAD

-- Build one paper-doll equipment slot: a framed icon that shows the set piece for
-- `slotID` and opens the in-game item tooltip on hover. Registered on room._slots
-- and refreshed per set by UpdateSlots.
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
  local entry = { slotID = slotID, icon = icon, border = border }

  local anchor = side == "left" and "ANCHOR_LEFT" or "ANCHOR_RIGHT"
  box._widget:EnableMouse(true)
  box._widget:SetScript("OnEnter", function(f)
    if not entry.itemID then return end
    GameTooltip:SetOwner(f, anchor)
    GameTooltip:SetItemByID(entry.itemID)
    GameTooltip:Show()
  end)
  box._widget:SetScript("OnLeave", function() GameTooltip:Hide() end)

  room._slots[#room._slots + 1] = entry
end

-- Lay out one vertically-centered column of slots at column x (each column is
-- centered independently, so the two sides can hold a different number of slots).
---@param room DressingRoom
---@param slots table[]  { {slotID, label}, ... }
---@param x number
---@param side string  "left"|"right"
local function layoutColumn(room, slots, x, side)
  local n = #slots
  local colH = n * SLOT + (n - 1) * SLOTGAP
  local startY = -(30 + PAD) - (MODELH - colH) / 2
  for i, s in ipairs(slots) do
    buildSlot(room, s[1], x, startY - (i - 1) * (SLOT + SLOTGAP), side)
  end
end

-- Build both paper-doll slot columns flanking the model. Called once from the
-- constructor; winW is the final window width (right column hugs the right edge).
---@param winW number
function DressingRoom:_buildSlots(winW)
  self._slots = {}
  layoutColumn(self, LEFT_SLOTS, COLINSET, "left")
  layoutColumn(self, RIGHT_SLOTS, winW - COLINSET - SLOT, "right")
end

-- Fill the paper-doll slots with the current set's pieces: icon + status border
-- (green collected / red missing), and the itemID each slot's tooltip shows.
function DressingRoom:UpdateSlots()
  local set = self._set
  if not set then return end
  local parts = getParts(set.id)
  local primary = {}
  for _, p in ipairs(parts) do primary[p.appearanceID] = true end

  local missing = false
  for _, e in ipairs(self._slots) do
    local sources = GetSourcesForSlot(set.id, e.slotID)
    local _, p = find(sources, function(s) return primary[s.sourceID] end)
    if p then
      local info = GetSourceInfo(p.sourceID)
      e.itemID = info and info.itemID
      local tex = e.itemID and GetItemIcon(e.itemID)
      if e.itemID and not tex then RequestItem(e.itemID); missing = true end
      e.icon:Texture(tex or QUESTION)
      e.icon:Show()
      e.border:Color(any(sources, function(s) return s.isCollected end) and GREEN or RED)
    else
      -- No piece for this slot in the set: show the "unresolved" marker.
      e.itemID = nil
      e.icon:Texture(ui.media.unresolved)
      e.icon:Show()
      e.border:Color(IDLE)
    end
  end

  -- Icons aren't always cached on the first pass; re-run shortly (capped) until
  -- they resolve.
  if self._slotTimer then self._slotTimer:Cancel(); self._slotTimer = nil end
  if missing and (self._slotRetries or 0) < 10 then
    self._slotRetries = (self._slotRetries or 0) + 1
    self._slotTimer = C_Timer.NewTimer(0.2, function()
      self._slotTimer = nil
      self:UpdateSlots()
    end)
  end
end
