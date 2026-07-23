---@type Warbandeer_Collected
local ns = select(2, ...)
local Enum = Enum

-- The two pure halves of making the Armor and Weapons views compose (#656). No WoW API calls and
-- no frames, so both are unit-tested (spec/viewsync_spec.lua); the room-coupled memory that drives
-- the first is controls/DressingRoomViews.lua, and the chooser buttons that drive the second are
-- controls/WeaponCellPicker.lua.
--
--   1. **Which preview a view toggle should restore.** The grids and the dressing room were
--      independent surfaces: `MainWindow:SetMode` swapped which grid was shown and never touched
--      the room, so toggling back to Armor left a weapon on the model. The room now remembers one
--      preview per view and the toggle restores it — `PreviewToRestore` is the decision.
--
--   2. **Which hand a browsed weapon can be staged into.** A weapon found in the Weapons view had
--      no route into the composed look at all; the cell chooser now offers the hands its type can
--      actually occupy.

-- ── Which preview a view toggle restores ───────────────────────────────────────--

---What the room should switch to when the grid toggles to `wanted`, or nil to leave it alone.
---
---Three of the four cases are deliberately "leave it alone", and each for its own reason:
---
---| room is showing | toggling to | result |
---|---|---|---|
---| the other view's preview, and that view has one remembered | either | **restore it** |
---| the other view's preview, that view has nothing remembered | either | leave alone |
---| this view's preview already | same | leave alone (no needless re-skin) |
---| a loaded library look (`current` nil — outfit mode) | either | leave alone |
---
---**Leaving alone, never closing.** Closing the preview because a grid was toggled is destructive
---and there is nothing to switch to instead. Outfit mode is `nil` rather than a view because a
---loaded look belongs to neither grid — both cursors clear when one loads — so a grid toggle has
---no business disturbing it.
---@param current string?  the view the room is previewing ("armor"|"weapons"), nil for neither
---@param wanted string  the view being switched to
---@param memory table?  { armor = <preview>?, weapons = <preview>? }
---@return table?  the remembered preview to restore, or nil to leave the room as it is
function ns.PreviewToRestore(current, wanted, memory)
  if current == nil or current == wanted then return nil end
  return memory and memory[wanted] or nil
end

-- ── Which hand a weapon type can occupy ────────────────────────────────────────--

-- Three explicit sets rather than `GetCategoryInfo`'s capability flags, for the reason
-- controls/WeaponPicker.lua discovered and this file inherits: a Shield and a TwoHSword report
-- IDENTICAL isWeapon/canMainHand/canOffHand (both canOffHand = false, since that flag means "can be
-- a dual-wield off-hand WEAPON", which neither is), so no flag test can tell the two apart. Naming
-- the categories is the only thing that works.
--
-- `canOffHand` IS still the right signal in the picker, which is scoped to a class and must not
-- offer a paladin a dual-wielded off-hand sword. The weapon GRID is class-agnostic by design (a
-- weapon cell has no class column and no ratings row, and the model renders any appearance on
-- anyone through SlotTransmog), so staging from there uses these sets and offers both hands for a
-- one-hander whoever is logged in.

-- Occupies BOTH hands, so a main-hand pick here suppresses the off-hand (#618).
local TWO_HANDED = {
  Enum.TransmogCollectionType.TwoHAxe, Enum.TransmogCollectionType.TwoHSword,
  Enum.TransmogCollectionType.TwoHMace, Enum.TransmogCollectionType.Polearm,
  Enum.TransmogCollectionType.Staff, Enum.TransmogCollectionType.Bow,
  Enum.TransmogCollectionType.Crossbow, Enum.TransmogCollectionType.Gun,
}
-- Sits in either hand (the dual-wield one-handers).
local ONE_HANDED = {
  Enum.TransmogCollectionType.OneHAxe, Enum.TransmogCollectionType.OneHSword,
  Enum.TransmogCollectionType.OneHMace, Enum.TransmogCollectionType.Dagger,
  Enum.TransmogCollectionType.Fist, Enum.TransmogCollectionType.Warglaives,
}
-- Off-hand SLOT rather than an off-hand weapon: shields and the off-hand frills.
local OFF_HAND_ONLY = {
  Enum.TransmogCollectionType.Shield, Enum.TransmogCollectionType.Holdable,
}

local twoHanded, offHandOnly, hands = {}, {}, {}
for _, c in ipairs(TWO_HANDED) do twoHanded[c] = true; hands[c] = { main = true, off = false } end
for _, c in ipairs(ONE_HANDED) do hands[c] = { main = true, off = true } end
for _, c in ipairs(OFF_HAND_ONLY) do offHandOnly[c] = true; hands[c] = { main = false, off = true } end
-- A wand is neither: one-handed, but main-hand only since Legion — so it is main-hand-eligible
-- without being two-handed, which is the one case the two sets above can't express between them.
hands[Enum.TransmogCollectionType.Wand] = { main = true, off = false }

---@class Warbandeer_Collected
---@field PreviewToRestore fun(current: string?, wanted: string, memory: table?): table?
---@field WeaponHands fun(category: number?): boolean, boolean
---@field TwoHandedWeapon fun(category: number?): boolean
---@field OffHandOnlyWeapon fun(category: number?): boolean

---Which hands a weapon category can be staged into. Both false for anything that isn't a weapon
---type this client offers, so an unknown category simply offers nothing rather than guessing.
---@param category number?  Enum.TransmogCollectionType
---@return boolean mainHand, boolean offHand
function ns.WeaponHands(category)
  local h = category and hands[category]
  if not h then return false, false end
  return h.main, h.off
end

---Whether a weapon category occupies both hands — the test that decides `_lookMH2H`, and so
---whether the off-hand slot greys out behind a main-hand pick.
---@param category number?
---@return boolean
function ns.TwoHandedWeapon(category)
  return (category and twoHanded[category]) or false
end

---Whether a category can ONLY go in the off-hand slot (a shield or a holdable). The picker's
---dropdown split reads this; see the note above for why it can't be a flag test.
---@param category number?
---@return boolean
function ns.OffHandOnlyWeapon(category)
  return (category and offHandOnly[category]) or false
end
