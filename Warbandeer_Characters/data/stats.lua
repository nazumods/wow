---@type Warbandeer_Characters
local ns = select(2, ...)
local GetCritChance, GetHaste = GetCritChance, GetHaste
local GetMasteryEffect = GetMasteryEffect
local GetCombatRating, GetCombatRatingBonus = GetCombatRating, GetCombatRatingBonus
local GetSpecialization, GetSpecializationMasterySpells = GetSpecialization, GetSpecializationMasterySpells
local CR_CRIT, CR_HASTE = CR_CRIT_MELEE, CR_HASTE_MELEE
local CR_MASTERY_, CR_VERS = CR_MASTERY, CR_VERSATILITY_DAMAGE_DONE
local canaccessvalue = canaccessvalue

-- Combat-rating / stat APIs can return "secret" numbers that tainted addon code can't do
-- arithmetic on. The Detail view computes deltas vs Archon targets and feeds the radar, so
-- store nil instead of a value it can't use (and that can't be safely serialized).
-- canaccessvalue is retail-only — on classic builds (no secret values) every value passes.
local function safe(v)
  if canaccessvalue and not canaccessvalue(v) then return nil end
  return v
end

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
---@field secondary table<string, {pct: number?, rating: number?, spell: integer?}>  crit/haste/mastery/versatility: effective % + combat rating (nil when the API returns a secret value; mastery also carries its passive `spell` id)

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
    missing = { label = "secondary stats", maxLevel = true, order = 260 },
    get = function()
      return {
        crit        = { pct = safe(GetCritChance()),    rating = safe(GetCombatRating(CR_CRIT)) },
        haste       = { pct = safe(GetHaste()),         rating = safe(GetCombatRating(CR_HASTE)) },
        mastery     = { pct = safe(GetMasteryEffect()), rating = safe(GetCombatRating(CR_MASTERY_)), spell = masterySpell() },
        versatility = { pct = safe(GetCombatRatingBonus(CR_VERS)), rating = safe(GetCombatRating(CR_VERS)) },
      }
    end,
    event = "COMBAT_RATING_UPDATE",
    -- Fires constantly in combat (every proc/buff/gear rating tick). Debounce so a
    -- burst rebuilds this snapshot once it settles instead of on every event — it's a
    -- last-seen snapshot, so coalescing loses nothing.
    eventDelay = 1000,
  },
}
