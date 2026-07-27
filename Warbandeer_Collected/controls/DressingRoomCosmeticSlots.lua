---@type Warbandeer_Collected
local ns = select(2, ...)
local GameTooltip = GameTooltip
local DressingRoom = ns.DressingRoom
local k = DressingRoom._k

-- Shirt + tabard paper-doll slots (#641). They sit in the LEFT armor column
-- (controls/DressingRoomSlots.lua lays them out and this file builds them), but they behave like
-- the bottom-center weapon slots, NOT like their column neighbours: transmog sets never carry a
-- shirt or a tabard, so there is no set piece for UpdateSlots to find and nothing to toggle on and
-- off. They're driven entirely by the composed look — left-click opens the docked picker at this
-- slot, right-click clears it — exactly as controls/DressingRoomWeaponSlots.lua works.
--
-- Which is why the slot itself comes from the shared look-slot layer in DressingRoomLookSlots.lua;
-- all that is cosmetic-specific is the column position it's handed, the tooltip wording and the
-- category lookup that supplies its label and placeholder art.
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
local function slotTooltip(room, f, e)
  GameTooltip:SetOwner(f, e.anchor)
  if e.itemID then
    GameTooltip:SetItemByID(e.itemID)
    GameTooltip:AddLine("Left-click to change, right-click to clear", 0.6, 0.6, 0.6)
  else
    GameTooltip:SetText(e.label)
    GameTooltip:AddLine("Click to choose an appearance", 0.6, 0.6, 0.6)
  end
  GameTooltip:Show()
end

-- Build one cosmetic slot at the column position DressingRoomSlots.lua computed.
---@param spec table  a column entry ({ slotID, label, target = "shirt"|"tabard" })
---@param x number
---@param y number
---@param side string  "left"|"right" — which way the tooltip opens
function DressingRoom:_buildCosmeticSlot(spec, x, y, side)
  local cat = ns.CosmeticCategoryForSlot(spec[1])
  local entry = DressingRoom._buildLookSlot(self, {
    target = spec.target, label = (cat and cat.name) or spec[2], empty = cat and cat.empty,
    position = { TopLeft = {x, y}, Width = k.SLOT, Height = k.SLOT },
    tooltip = slotTooltip,
  })
  -- Cosmetic-only. `slotID` and `cosmetic` are what the armor-only passes walking room._slots key
  -- off; `anchor` is read back by the tooltip above, since a left-column slot opens its tooltip the
  -- other way from a right-column one.
  entry.slotID, entry.cosmetic = spec[1], true
  entry.anchor = side == "left" and "ANCHOR_LEFT" or "ANCHOR_RIGHT"

  self._slots[#self._slots + 1] = entry
  self._cosmeticSlots[#self._cosmeticSlots + 1] = entry
end
