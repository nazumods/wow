---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local GameTooltip = GameTooltip

-- Character-sheet weapon slots (#615): a main-hand + off-hand pair across the model's
-- bottom center, mirroring Blizzard's paper doll (armor down the sides, weapons across
-- the bottom). Unlike the armor columns (DressingRoomSlots.lua) these aren't C_TransmogSets
-- slots — they're the look-builder's composed weapons (_lookMH / _lookOH), and clicking one
-- is the entry point to the docked picker (AppearancePicker.lua), replacing the old floating
-- "Weapons" button.
--
-- Only the parts that are weapon-specific live here: where the pair sits, how the tooltip reads,
-- and the off-hand suppression. The slot itself — its frame, its click handling, its painting and
-- its clear gesture — is the shared look-slot layer in DressingRoomLookSlots.lua, which the
-- shirt/tabard slots (DressingRoomCosmeticSlots.lua) build on identically.
-- Reopens the DressingRoom class.
local DressingRoom = ns.DressingRoom

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

-- A staff/polearm/ranged main-hand leaves no room for an off-hand (#618) — that slot stops taking
-- clicks, dims and holds its border idle whatever pick it's keeping. A Titan's Grip two-hander does
-- NOT suppress it, so this no longer fires for every two-hander (#661). The cosmetic slots have no
-- equivalent and pass no predicate at all.
---@param room DressingRoom
---@return boolean
local function offHandSuppressed(room)
  return not not room._lookNoOH
end

-- Show the picked weapon's item tooltip (+ change/clear hint), or a "pick a weapon" prompt
-- for an empty slot.
---@param room DressingRoom
---@param f table  the slot's backing widget
---@param e table  the weapon-slot entry
local function slotTooltip(room, f, e)
  GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
  if e.target == "off" and room._lookNoOH then
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

-- Build the bottom-center weapon-slot pair. Called once from the constructor (after the
-- model exists — the slots anchor to it).
function DressingRoom:_buildWeaponSlots()
  self._pickerTarget = "main"   -- the picker opens on the main hand until a slot re-points it
  self._weaponSlots = {}
  for _, spec in ipairs(HANDS) do
    -- A hand IS its own picker target, so the target map in AppearancePicker.lua covers these and
    -- the cosmetics alike and neither file has to branch on which kind it is.
    local entry = DressingRoom._buildLookSlot(self, {
      target = spec.hand, label = spec.label, empty = spec.empty,
      position = { Bottom = {self._model, ui.edge.Bottom, spec.dx, BOTTOM}, Width = SLOT, Height = SLOT },
      level = self._model:Level() + 10,
      tooltip = slotTooltip,
      blocked = spec.hand == "off" and offHandSuppressed or nil,
    })
    entry.hand = spec.hand   -- weapon-only; the off-hand layout and the cell chooser read it
    self._weaponSlots[#self._weaponSlots + 1] = entry
  end
end
