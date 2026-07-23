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

-- Four explicit sets rather than `GetCategoryInfo`'s capability flags, because the flags cannot
-- answer either question we need. Measured on a Warrior via `/collected weapons` (#661):
--
--   15  One-Handed Maces    M--        19  Held In Off-hand    -O-
--   16  Daggers             M--        23  Staves              M--
--
-- **`canOffHand` is not a dual-wield test.** It is true only for things that live in the off-hand
-- SLOT — a holdable, a shield — and false for every dual-wield one-hander, on a class that dual
-- wields. So it answers the same question `OFF_HAND_ONLY` does and adds nothing, while reading as
-- though it meant "can pair in the off hand". The picker's off-hand dropdown was built on it and
-- consequently offered NO one-handers to anyone, which is how ordinary dual-wield came to be
-- unofferable there (#661). `canMainHand` is no better at the other end: a Shield and a TwoHSword
-- report identical flags, so only naming the categories separates them.
--
-- Both surfaces therefore share these sets through `ns.WeaponHands`, and neither consults a class.
-- The weapon GRID cannot (a weapon cell has no class column, and `_classIndex` is nil for a
-- weapon-cell preview); the picker is already scoped by `_pickerCats` to the previewed class's own
-- category list, which is as much class-awareness as the flags ever really gave it.

-- Held in both hands — except the Titan's Grip three below, which are two-handed AND dual-wieldable.
local TWO_HANDED = {
  Enum.TransmogCollectionType.TwoHAxe, Enum.TransmogCollectionType.TwoHSword,
  Enum.TransmogCollectionType.TwoHMace, Enum.TransmogCollectionType.Polearm,
  Enum.TransmogCollectionType.Staff, Enum.TransmogCollectionType.Bow,
  Enum.TransmogCollectionType.Crossbow, Enum.TransmogCollectionType.Gun,
}
-- Titan's Grip (Fury Warrior) dual-wields two-handed axes, maces and swords, so these three are
-- off-hand eligible in spite of being two-handed (#661). Polearms, staves and the ranged weapons
-- are NOT: nothing pairs with those, for any class or spec, which is what #618 was really
-- protecting and what still holds below.
--
-- Deliberately NOT gated on the previewed class, though a class is genuinely in play — only a
-- Warrior gets the talent. Three reasons, in ascending order of force:
--
--   * The room previews a set's CLASS, never a spec, and Arms and Protection Warriors don't get
--     Titan's Grip either — so a class gate would already be imprecise about its own rule.
--   * The room is a preview. `SlotTransmog` renders any appearance on anyone, and #642 settled
--     that this addon stores looks a character can't wear, validating at the transmogrifier.
--   * Decisively: the weapon grid stages into the same composed look with NO class at all —
--     `_classIndex` is nil for a weapon-cell preview (controls/DressingRoomActions.lua) — so a
--     class-gated rule is not computable at one of the three call sites, and a gate the picker
--     applied alone would be bypassable by staging the same weapon from the grid.
--
-- The cost is that a Paladin previewing a 2H mace is now offered an off-hand it couldn't equip.
-- That is the same latitude every other slot already has here, and the transmogrifier is where it
-- gets checked.
local TITANS_GRIP = {
  Enum.TransmogCollectionType.TwoHAxe, Enum.TransmogCollectionType.TwoHSword,
  Enum.TransmogCollectionType.TwoHMace,
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

local twoHanded, titansGrip, hands = {}, {}, {}
for _, c in ipairs(TWO_HANDED) do twoHanded[c] = true; hands[c] = { main = true, off = false } end
-- After TWO_HANDED, which seeded the entries this reopens: a Titan's Grip type stays two-handed
-- (it still fills both hands when worn alone) and gains an off hand on top.
for _, c in ipairs(TITANS_GRIP) do titansGrip[c] = true; hands[c].off = true end
for _, c in ipairs(ONE_HANDED) do hands[c] = { main = true, off = true } end
for _, c in ipairs(OFF_HAND_ONLY) do hands[c] = { main = false, off = true } end
-- A wand is neither: one-handed, but main-hand only since Legion — so it is main-hand-eligible
-- without being two-handed, which is the one case the two sets above can't express between them.
hands[Enum.TransmogCollectionType.Wand] = { main = true, off = false }

---@class Warbandeer_Collected
---@field PreviewToRestore fun(current: string?, wanted: string, memory: table?): table?
---@field WeaponHands fun(category: number?): boolean, boolean
---@field SuppressesOffHand fun(category: number?): boolean

---Which hands a weapon category can be staged into — **the single hand-eligibility answer**, used
---by the look-builder picker's dropdown split and by the weapon grid's staging buttons alike, so
---the two surfaces cannot offer different hands for the same weapon type.
---
---Both false for anything that isn't a weapon type this client offers, so an unknown category
---simply offers nothing rather than guessing.
---@param category number?  Enum.TransmogCollectionType
---@return boolean mainHand, boolean offHand
function ns.WeaponHands(category)
  local h = category and hands[category]
  if not h then return false, false end
  return h.main, h.off
end

---Whether a weapon category leaves no room for an off-hand at all — the test that decides
---`_lookNoOH`, and so whether the off-hand slot greys out behind a main-hand pick.
---
---Two-handed AND not dual-wieldable: a polearm, a staff, or a ranged weapon. A two-handed axe,
---mace or sword is equally two-handed but pairs under Titan's Grip, so it does NOT suppress —
---which is the whole of #661. #618 named the same idea when the two were not yet distinguished.
---@param category number?
---@return boolean
function ns.SuppressesOffHand(category)
  return (category and twoHanded[category] and not titansGrip[category]) or false
end

-- `ns.TitansGripWeapon` and `ns.OffHandOnlyWeapon` used to live here, as the two halves of the
-- picker's off-hand dropdown filter (`offHandOnly or canOffHand or titansGrip`). `ns.WeaponHands`
-- answers all of it in one call now that the picker no longer consults `canOffHand`, so both were
-- removed rather than left as API with no callers. `titansGrip` survives as a local because
-- `SuppressesOffHand` still needs it.
