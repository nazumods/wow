---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Frame, Texture = ui.Frame, ui.Texture
local GetSourceInfo = C_TransmogCollection.GetSourceInfo
local GetItemIcon = C_Item.GetItemIconByID
local RequestItem = C_Item.RequestLoadItemDataByID
local GameTooltip, C_Timer = GameTooltip, C_Timer
local DressingRoom = ns.DressingRoom
local k = DressingRoom._k
local selBox, SELECTED, IDLE = k.selBox, k.SELECTED, k.IDLE
local TARGETS = DressingRoom._TARGETS
local GREEN = {0, 104/255, 55/255, 1}   -- appearance collected (matches the armor-slot status green)
local RED   = {165/255, 0, 38/255, 1}   -- appearance not collected

-- Shirt + tabard paper-doll slots (#641). They sit in the LEFT armor column
-- (controls/DressingRoomSlots.lua lays them out and this file builds them), but they behave like
-- the bottom-center weapon slots, NOT like their column neighbours: transmog sets never carry a
-- shirt or a tabard, so there is no set piece for UpdateSlots to find and nothing to toggle on and
-- off. They're driven entirely by the composed look — left-click opens the docked picker at this
-- slot, right-click clears it — exactly as controls/DressingRoomWeaponSlots.lua works.
-- Reopens the DressingRoom class.
--
-- Their entries live in room._slots alongside the armor ones (so they show/hide with the columns
-- and the outfit path can walk one list), flagged `cosmetic` so the armor-only passes — UpdateSlots,
-- the undress toggles, ClearOutfitArmor — skip them. room._cosmeticSlots indexes the same entry
-- tables for this file's own refresh loop.

-- Show the picked appearance's item tooltip (+ change/clear hint), or a prompt for an empty slot.
---@param room DressingRoom
---@param f table  the slot's backing widget
---@param e table  the cosmetic-slot entry
---@param anchor string  which way the tooltip opens
local function slotTooltip(room, f, e, anchor)
  GameTooltip:SetOwner(f, anchor)
  if e.itemID then
    GameTooltip:SetItemByID(e.itemID)
    GameTooltip:AddLine("Left-click to change, right-click to clear", 0.6, 0.6, 0.6)
  else
    GameTooltip:SetText(e.label)
    GameTooltip:AddLine("Click to choose an appearance", 0.6, 0.6, 0.6)
  end
  GameTooltip:Show()
end

-- Build one cosmetic slot at the column position DressingRoomSlots.lua computed: a framed icon
-- showing the composed look's pick for this slot, with Blizzard's paper-doll placeholder art when
-- empty. Left-click opens/switches the picker to this slot (or closes it if already open here);
-- right-click clears the slot.
---@param spec table  a column entry ({ slotID, label, target = "shirt"|"tabard" })
---@param x number
---@param y number
---@param side string  "left"|"right" — which way the tooltip opens
function DressingRoom:_buildCosmeticSlot(spec, x, y, side)
  local cat = ns.CosmeticCategoryForSlot(spec[1])
  local box = Frame:new{
    parent = self,
    position = { TopLeft = {x, y}, Width = k.SLOT, Height = k.SLOT },
  }
  local border = selBox(box)
  local icon = Texture:new{
    parent = box, layer = ui.layer.Artwork,
    position = { TopLeft = {2, -2}, BottomRight = {-2, 2} },
  }
  local entry = {
    slotID = spec[1], label = (cat and cat.name) or spec[2], target = spec.target,
    look = TARGETS[spec.target].look, empty = cat and cat.empty,
    cosmetic = true, icon = icon, border = border, box = box,
  }

  local anchor = side == "left" and "ANCHOR_LEFT" or "ANCHOR_RIGHT"
  box._widget:EnableMouse(true)
  box._widget:SetScript("OnEnter", function(f) slotTooltip(self, f, entry, anchor) end)
  box._widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
  box._widget:SetScript("OnMouseUp", function(_, button)
    if button == "LeftButton" then
      local open = self._picker and self._picker._widget:IsShown()
      if open and self._pickerTarget == entry.target then
        self:TogglePicker(false)            -- already open on this slot → close
      else
        self:TogglePicker(true, entry.target)  -- open / switch to this slot
      end
    elseif button == "RightButton" then
      self:_clearCosmeticSlot(entry.target)
    end
  end)

  self._slots[#self._slots + 1] = entry
  self._cosmeticSlots[#self._cosmeticSlots + 1] = entry
end

-- Fill each cosmetic slot from the composed look (_lookShirt / _lookTabard): the picked
-- appearance's icon, with a status border — gold while the picker targets this slot, else green
-- (collected) and IDLE when empty (the placeholder art shows). Icons load async, so retry shortly
-- (capped) until they resolve, like UpdateSlots and UpdateWeaponSlots.
---@param retry boolean?  internal: true on the self-scheduled re-run (skips the retry-count reset)
function DressingRoom:UpdateCosmeticSlots(retry)
  if not self._cosmeticSlots then return end
  if not retry then self._cosmeticSlotRetries = 0 end
  local open = self._picker and self._picker._widget:IsShown()
  local missing = false
  for _, e in ipairs(self._cosmeticSlots) do
    local sourceID = self[e.look]
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
    -- The master Undress bares the composed look off the model, so grey these with the armor
    -- rather than leave them reading as worn. Icon only — the status border stays.
    local v = self._undressed and 0.3 or 1
    e.icon:SetVertexColor(v, v, v, 1)
    if open and self._pickerTarget == e.target then
      e.border:Color(SELECTED)                                   -- picker open on this slot
    elseif itemID then
      e.border:Color(info.isCollected and GREEN or RED)
    else
      e.border:Color(IDLE)
    end
  end

  if self._cosmeticSlotTimer then self._cosmeticSlotTimer:Cancel(); self._cosmeticSlotTimer = nil end
  if missing and (self._cosmeticSlotRetries or 0) < 10 then
    self._cosmeticSlotRetries = (self._cosmeticSlotRetries or 0) + 1
    self._cosmeticSlotTimer = C_Timer.NewTimer(0.2, function()
      self._cosmeticSlotTimer = nil
      self:UpdateCosmeticSlots(true)
    end)
  end
end

-- Clear a cosmetic slot's pick (the right-click gesture — left-click is taken by "open the
-- picker"). Re-applies the look (which repaints the slots) and re-colors the picker's selection
-- borders if it's open.
---@param target string  "shirt" | "tabard"
function DressingRoom:_clearCosmeticSlot(target)
  local field = TARGETS[target].look
  if not self[field] then return end
  self[field] = nil
  self:_applyLook()
  if self._picker and self._picker._widget:IsShown() then self._pickerList:Refresh() end
end
