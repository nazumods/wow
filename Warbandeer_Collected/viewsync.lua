---@type Warbandeer_Collected
local ns = select(2, ...)
local Enum = Enum

-- The pure half of making the Armor and Weapons views compose: **which hand a weapon goes into,
-- and what staging it there does to the composed look**. No WoW API calls and no frames, so it's
-- unit-tested (spec/viewsync_spec.lua); the chooser that drives it is controls/WeaponCellPicker.lua
-- and the look-builder picker that shares its eligibility rules is controls/WeaponPicker.lua.
--
-- Browsing a weapon in the Weapons view puts it on the SAME paper doll armour is built on (#673) —
-- there is one model viewer, and a browsed weapon is a live pick in the composed look rather than a
-- second bare-body render. So the hand rules below aren't just what the chooser is allowed to
-- offer; they decide what the model is wearing the moment a cell is clicked.
--
-- This file used to carry a second half — `PreviewToRestore`, the decision table for which
-- remembered preview the grid's Armor|Weapons toggle should swap onto the model (#656). With one
-- doll there is nothing to swap: the armour set and the browsed weapon are on it together, and the
-- toggle is back to swapping grids and nothing else. Removed rather than left as API with no
-- callers, along with the per-view memory it read (controls/DressingRoomViews.lua).

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
---@field WeaponHands fun(category: number?): boolean, boolean
---@field SuppressesOffHand fun(category: number?): boolean
---@field DefaultWeaponHand fun(category: number?): string?
---@field StageCellWeapon fun(category: number?, hand: string?, sourceID: number, current: table): table

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

---Which hand a browsed weapon lands in when nothing has said otherwise — **the main hand whenever
---the type can hold one**, the off hand for the two types that can't (a shield, a holdable), and
---nil for anything that isn't a stageable weapon.
---
---Main-hand-first rather than "nothing until a hand is clicked" (#673): the browsed weapon is a
---LIVE pick on the one doll, so a default of nothing would mean clicking a weapon cell renders
---exactly what it rendered before — which is the chat-message stand-in the issue is removing, in
---another form. A hand that turns out to be wrong is one click away on the chooser's selector.
---@param category number?  Enum.TransmogCollectionType
---@return string?  "main" | "off" | nil
function ns.DefaultWeaponHand(category)
  local main, off = ns.WeaponHands(category)
  if main then return "main" end
  if off then return "off" end
  return nil
end

---Put a browsed cell look into a hand of the composed look, and answer what the look's weapon
---fields become. The whole of what clicking a weapon cell, stepping its looks, and picking a hand
---do to the model — kept pure so the rules below are testable without a client.
---
---`current.hand` is **where this same cell's look currently sits**, and it is what separates the
---two gestures that reach here:
---
---| gesture | `current.hand` | effect |
---|---|---|---|
---| a new cell clicked, or ↑/↓ to another of its looks | nil / the same hand | replace that hand only |
---| the chooser's other hand button | the hand being left | **vacate it**, then stage |
---
---So browsing a sword and then a shield builds a pair (each lands in its own default hand and
---neither disturbs the other), while moving one weapon between hands doesn't leave a copy behind.
---A hand the type can't occupy falls back to the default, so an off-hand-only shield can never be
---forced into the main hand by the button.
---
---`noOffHand` is derived from the MAIN-hand pick alone (see `SuppressesOffHand`), so it's rewritten
---only when the main hand changes and cleared when the main hand is vacated.
---@param category number?  Enum.TransmogCollectionType — the cell's weapon type
---@param hand string?  the hand asked for ("main"|"off"), nil for the type's default
---@param sourceID number  the browsed look's appearance sourceID
---@param current table  { mainHand: number?, offHand: number?, noOffHand: boolean?, hand: string? }
---@return table  the same shape, with `hand` = where the look actually landed (nil = not staged)
function ns.StageCellWeapon(category, hand, sourceID, current)
  local main, off = ns.WeaponHands(category)
  -- An ineligible request falls back to the default rather than being refused: the chooser greys
  -- the button, but nothing else may depend on the caller having honoured that.
  if not ((hand == "main" and main) or (hand == "off" and off)) then
    hand = ns.DefaultWeaponHand(category)
  end
  local out = { mainHand = current.mainHand, offHand = current.offHand,
                noOffHand = current.noOffHand, hand = hand }
  if not hand then return out end
  -- Leaving a hand this cell's look was occupying: take it back off before staging, or the move
  -- would read as a second weapon appearing rather than the same one changing hands.
  if current.hand and current.hand ~= hand then
    if current.hand == "main" then out.mainHand, out.noOffHand = nil, nil else out.offHand = nil end
  end
  if hand == "main" then
    out.mainHand = sourceID
    out.noOffHand = ns.SuppressesOffHand(category) or nil
  else
    out.offHand = sourceID
  end
  return out
end

-- `ns.TitansGripWeapon` and `ns.OffHandOnlyWeapon` used to live here, as the two halves of the
-- picker's off-hand dropdown filter (`offHandOnly or canOffHand or titansGrip`). `ns.WeaponHands`
-- answers all of it in one call now that the picker no longer consults `canOffHand`, so both were
-- removed rather than left as API with no callers. `titansGrip` survives as a local because
-- `SuppressesOffHand` still needs it.
