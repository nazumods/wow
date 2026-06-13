---@type ShadowsOfUI_Upgrade
local ns = select(2, ...)

-- Per-class equip proficiency.  Armour TYPE (cloth/leather/mail/plate) is not
-- repeated here — it's read from ns.wow.Armor.byClass.  This file adds the two
-- things that table doesn't cover: which classes can use a shield, and each
-- class's allowed WEAPON subclasses.  There's no API to query an arbitrary
-- (offline) class's proficiency, so this is a bundled baseline matrix.  It is a
-- best-effort approximation at class granularity (a few spec-only quirks aren't
-- modelled); since upgrades are ilvl-gated, an occasional mis-allow only adds or
-- drops a single suggestion.  Keep in sync with weapon-proficiency changes.

-- Enum.ItemWeaponSubclass IDs (named for clarity; numeric so we don't depend on
-- the enum table being present at load).
local AXE1H, AXE2H = 0, 1
local BOW, GUN = 2, 3
local MACE1H, MACE2H = 4, 5
local POLEARM = 6
local SWORD1H, SWORD2H = 7, 8
local WARGLAIVE, STAFF = 9, 10
local FIST = 13
local DAGGER = 15
local CROSSBOW, WAND = 18, 19

-- Build a membership set {[id]=true} from a list of subclass IDs.
local function weapons(...)
  local set = {}
  for _, id in ipairs({ ... }) do set[id] = true end
  return set
end

---@class ClassGearProfile
---@field shield boolean can equip shields
---@field weapons table<integer, boolean> usable weapon subclasses

---@type table<string, ClassGearProfile>  keyed by PascalCase classKey
ns.ClassGear = {
  Warrior     = { shield = true,  weapons = weapons(AXE1H, AXE2H, MACE1H, MACE2H, SWORD1H, SWORD2H, POLEARM, STAFF, DAGGER, FIST) },
  Paladin     = { shield = true,  weapons = weapons(AXE1H, AXE2H, MACE1H, MACE2H, SWORD1H, SWORD2H, POLEARM) },
  DeathKnight = { shield = false, weapons = weapons(AXE1H, AXE2H, MACE1H, MACE2H, SWORD1H, SWORD2H, POLEARM) },
  Hunter      = { shield = false, weapons = weapons(BOW, GUN, CROSSBOW) },
  Shaman      = { shield = true,  weapons = weapons(AXE1H, AXE2H, MACE1H, MACE2H, DAGGER, FIST, STAFF) },
  Druid       = { shield = false, weapons = weapons(MACE1H, MACE2H, POLEARM, STAFF, DAGGER, FIST) },
  Rogue       = { shield = false, weapons = weapons(AXE1H, MACE1H, SWORD1H, DAGGER, FIST) },
  Mage        = { shield = false, weapons = weapons(STAFF, SWORD1H, DAGGER, WAND) },
  Priest      = { shield = false, weapons = weapons(STAFF, MACE1H, DAGGER, WAND) },
  Warlock     = { shield = false, weapons = weapons(STAFF, SWORD1H, DAGGER, WAND) },
  Monk        = { shield = false, weapons = weapons(AXE1H, MACE1H, SWORD1H, POLEARM, STAFF, FIST) },
  DemonHunter = { shield = false, weapons = weapons(WARGLAIVE, AXE1H, SWORD1H, FIST) },
  Evoker      = { shield = false, weapons = weapons(AXE1H, MACE1H, SWORD1H, DAGGER, FIST, STAFF) },
}
