---@class ShadowsOfUI_Upgrade
local ns = select(2, ...)

-- Primary stat per spec ("str" | "agi" | "int").  Used to reject an item whose
-- explicit primary stat doesn't match the spec — e.g. an Intellect dagger for a
-- Rogue, or an Agility leather chest for a Balance druid.  Weapon/armour *type*
-- proficiency (ns.CanEquip) lets those through; the primary stat is the missing
-- gate.  Each class is an array in GetSpecialization() index order, mirroring
-- ns.StatPriority, so a character resolves by (classToken, spec index).
-- Stable per spec (only Druid/Monk/Paladin/Shaman vary across their specs).
---@type table<string, string[]>
ns.ClassPrimary = {}

ns.ClassPrimary["DEATHKNIGHT"] = { "str", "str", "str" }                  -- blood / frost / unholy
ns.ClassPrimary["DEMONHUNTER"] = { "agi", "agi", "agi" }                  -- havoc / vengeance / devourer
ns.ClassPrimary["DRUID"]       = { "int", "agi", "agi", "int" }           -- balance / feral / guardian / restoration
ns.ClassPrimary["EVOKER"]      = { "int", "int", "int" }                  -- devastation / preservation / augmentation
ns.ClassPrimary["HUNTER"]      = { "agi", "agi", "agi" }                  -- beast-mastery / marksmanship / survival
ns.ClassPrimary["MAGE"]        = { "int", "int", "int" }                  -- arcane / fire / frost
ns.ClassPrimary["MONK"]        = { "agi", "int", "agi" }                  -- brewmaster / mistweaver / windwalker
ns.ClassPrimary["PALADIN"]     = { "int", "str", "str" }                  -- holy / protection / retribution
ns.ClassPrimary["PRIEST"]      = { "int", "int", "int" }                  -- discipline / holy / shadow
ns.ClassPrimary["ROGUE"]       = { "agi", "agi", "agi" }                  -- assassination / outlaw / subtlety
ns.ClassPrimary["SHAMAN"]      = { "int", "agi", "int" }                  -- elemental / enhancement / restoration
ns.ClassPrimary["WARLOCK"]     = { "int", "int", "int" }                  -- affliction / demonology / destruction
ns.ClassPrimary["WARRIOR"]     = { "str", "str", "str" }                  -- arms / fury / protection
