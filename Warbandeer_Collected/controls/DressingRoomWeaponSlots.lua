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
-- is the entry point to the docked picker (WeaponPicker.lua), replacing the old floating
-- "Weapons" button. Reopens the DressingRoom class.
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
  if e.hand == "off" and room._lookMH2H then
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
    if entry.hand == "off" and room._lookMH2H then return end   -- 2H main-hand: off-hand unavailable (#618)
    if button == "LeftButton" then
      local open = room._picker and room._picker._widget:IsShown()
      if open and room._pickerHand == entry.hand then
        room:ToggleWeaponPicker(false)          -- already open on this hand → close
      else
        room:ToggleWeaponPicker(true, entry.hand)  -- open / switch to this hand
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
  self._pickerHand = "main"
  self._weaponSlots = {}
  for _, spec in ipairs(HANDS) do buildWeaponSlot(self, spec) end
end

-- Show or hide the weapon-slot pair. Hidden in weapon-cosmetic preview (its own held-weapon
-- render has no look-builder slots), shown for armor sets — mirroring _showSlots for the armor
-- columns.
---@param show boolean
function DressingRoom:_showWeaponSlots(show)
  for _, e in ipairs(self._weaponSlots) do
    if show then e.box:Show() else e.box:Hide() end
  end
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
    -- A two-handed main-hand disables the off-hand: dim its icon (0.3, matching the armor slots'
    -- toggled-off dim) and hold the border idle, whatever pick it's keeping. Otherwise full color +
    -- the normal status / selection border. #618.
    local disabled = e.hand == "off" and self._lookMH2H
    local v = disabled and 0.3 or 1
    e.icon:SetVertexColor(v, v, v, 1)
    if disabled then
      e.border:Color(IDLE)
    elseif open and self._pickerHand == e.hand then
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
    self._lookMH, self._lookMH2H = nil, nil
  end
  self:_applyLook()
  if self._picker and self._picker._widget:IsShown() then self._pickerList:Refresh() end
end
