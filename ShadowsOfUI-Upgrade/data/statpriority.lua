---@class ShadowsOfUI_Upgrade
local ns = select(2, ...)

-- Secondary-stat priority per spec, as tiers (1 = highest priority).  This is all
-- we need: an item's stats are "good" when it carries a tier-1 stat, else "off".
-- Derived offline from current PvE secondary-stat weightings (M+); stats within
-- ~15% of each other share a tier, stored precomputed so there's nothing to rank
-- at runtime.  Each class is an array in GetSpecialization() index order, so a
-- character resolves by (classToken, spec index) — no spec-name lookup table is
-- needed (the trailing comment is just for humans).  Refresh each season.
---@type table<string, table<string, integer>[]>
ns.StatPriority = {}

ns.StatPriority["DEATHKNIGHT"] = {
  { crit = 1, haste = 2, mastery = 1, versatility = 1 },  -- blood
  { crit = 1, haste = 2, mastery = 1, versatility = 3 },  -- frost
  { crit = 1, haste = 2, mastery = 1, versatility = 3 },  -- unholy
}
ns.StatPriority["DEMONHUNTER"] = {
  { crit = 1, haste = 3, mastery = 2, versatility = 4 },  -- havoc
  { crit = 2, haste = 1, mastery = 3, versatility = 3 },  -- vengeance
  { crit = 2, haste = 1, mastery = 1, versatility = 3 },  -- devourer
}
ns.StatPriority["DRUID"] = {
  { crit = 1, haste = 1, mastery = 1, versatility = 2 },  -- balance
  { crit = 3, haste = 2, mastery = 1, versatility = 4 },  -- feral
  { crit = 3, haste = 1, mastery = 3, versatility = 2 },  -- guardian
  { crit = 3, haste = 1, mastery = 1, versatility = 2 },  -- restoration
}
ns.StatPriority["EVOKER"] = {
  { crit = 1, haste = 2, mastery = 3, versatility = 4 },  -- devastation
  { crit = 2, haste = 1, mastery = 1, versatility = 3 },  -- preservation
  { crit = 1, haste = 2, mastery = 3, versatility = 4 },  -- augmentation
}
ns.StatPriority["HUNTER"] = {
  { crit = 1, haste = 2, mastery = 1, versatility = 3 },  -- beast-mastery
  { crit = 1, haste = 3, mastery = 2, versatility = 4 },  -- marksmanship
  { crit = 2, haste = 3, mastery = 1, versatility = 4 },  -- survival
}
ns.StatPriority["MAGE"] = {
  { crit = 1, haste = 2, mastery = 1, versatility = 3 },  -- arcane
  { crit = 3, haste = 1, mastery = 1, versatility = 2 },  -- fire
  { crit = 1, haste = 3, mastery = 2, versatility = 4 },  -- frost
}
ns.StatPriority["MONK"] = {
  { crit = 1, haste = 4, mastery = 3, versatility = 2 },  -- brewmaster
  { crit = 2, haste = 1, mastery = 4, versatility = 3 },  -- mistweaver
  { crit = 1, haste = 1, mastery = 1, versatility = 2 },  -- windwalker
}
ns.StatPriority["PALADIN"] = {
  { crit = 2, haste = 1, mastery = 1, versatility = 3 },  -- holy
  { crit = 1, haste = 1, mastery = 2, versatility = 3 },  -- protection
  { crit = 1, haste = 2, mastery = 1, versatility = 3 },  -- retribution
}
ns.StatPriority["PRIEST"] = {
  { crit = 1, haste = 1, mastery = 2, versatility = 3 },  -- discipline
  { crit = 1, haste = 2, mastery = 4, versatility = 3 },  -- holy
  { crit = 3, haste = 1, mastery = 2, versatility = 4 },  -- shadow
}
ns.StatPriority["ROGUE"] = {
  { crit = 1, haste = 2, mastery = 3, versatility = 4 },  -- assassination
  { crit = 1, haste = 2, mastery = 3, versatility = 4 },  -- outlaw
  { crit = 2, haste = 2, mastery = 1, versatility = 3 },  -- subtlety
}
ns.StatPriority["SHAMAN"] = {
  { crit = 2, haste = 3, mastery = 1, versatility = 4 },  -- elemental
  { crit = 2, haste = 1, mastery = 1, versatility = 3 },  -- enhancement
  { crit = 1, haste = 3, mastery = 4, versatility = 2 },  -- restoration
}
ns.StatPriority["WARLOCK"] = {
  { crit = 1, haste = 1, mastery = 2, versatility = 3 },  -- affliction
  { crit = 1, haste = 2, mastery = 3, versatility = 4 },  -- demonology
  { crit = 1, haste = 1, mastery = 2, versatility = 3 },  -- destruction
}
ns.StatPriority["WARRIOR"] = {
  { crit = 1, haste = 2, mastery = 3, versatility = 4 },  -- arms
  { crit = 2, haste = 1, mastery = 1, versatility = 3 },  -- fury
  { crit = 2, haste = 1, mastery = 3, versatility = 4 },  -- protection
}
