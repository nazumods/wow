---@type Warbandeer_Characters
local ns = select(2, ...)
local GetCritChance, GetHaste = GetCritChance, GetHaste
local GetMasteryEffect = GetMasteryEffect
local GetCombatRating, GetCombatRatingBonus = GetCombatRating, GetCombatRatingBonus
local GetSpecialization, GetSpecializationMasterySpells = GetSpecialization, GetSpecializationMasterySpells
local CR_CRIT, CR_HASTE = CR_CRIT_MELEE, CR_HASTE_MELEE
local CR_MASTERY_, CR_VERS = CR_MASTERY, CR_VERSATILITY_DAMAGE_DONE

-- The active spec's mastery passive spell, so the Detail view can name the mastery
-- ("Mastery: Razor Claws") and describe its spec-specific effect. Captured here (the
-- only place we have the logged-in character's spec context); nil before a spec is chosen.
local function masterySpell()
  local idx = GetSpecialization()
  return idx and GetSpecializationMasterySpells(idx) or nil
end

---@class Character
---@field stats StatsBroker?

---@class StatsBroker
---@field secondary table<string, {pct: number, rating: number, spell: integer?}>  crit/haste/mastery/versatility: effective % + combat rating (mastery also carries its passive `spell` id)

---@class StatsBroker: Broker
local Stats = ns:RegisterBroker("stats")

-- Secondary stats: the effective percent (base + rating + buffs, as the character sheet
-- shows) plus the gear combat rating, for crit/haste/mastery/versatility. These come from
-- live combat-rating APIs (logged-in character only), so they're captured at scan time and
-- on COMBAT_RATING_UPDATE and persisted — letting the Detail view show them warband-wide
-- (a last-seen snapshot, like ilvl). Versatility uses the damage-done bonus, matching the
-- value the paperdoll displays.
Stats.fields = {
  secondary = {
    get = function()
      return {
        crit        = { pct = GetCritChance(),    rating = GetCombatRating(CR_CRIT) },
        haste       = { pct = GetHaste(),         rating = GetCombatRating(CR_HASTE) },
        mastery     = { pct = GetMasteryEffect(), rating = GetCombatRating(CR_MASTERY_), spell = masterySpell() },
        versatility = { pct = GetCombatRatingBonus(CR_VERS), rating = GetCombatRating(CR_VERS) },
      }
    end,
    event = "COMBAT_RATING_UPDATE",
  },
}
