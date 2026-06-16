---@class ShadowsOfUI_Upgrade
local ns = select(2, ...)

-- Recommended permanent enchant per equippable slot for the current season.
-- **REGENERATE EACH SEASON** — the enchant families change every expansion/patch.
-- Harvest the live enchanting-recipe ids + names in-game (see CONTEXT.md → Gotchas →
-- "Refreshing ns.Enchants") and re-bake the rows below.
--
-- Keyed by a canonical enchant slot (the two rings share `Finger`, the weapons share
-- `Weapon`); `resolve`/`enhance` map an equipped slot name onto it. Two shapes:
--   * `byStat` — a secondary-stat → recipe-id map. The resolver picks the variant
--     matching the character's top secondary stat (via `ns.StatRanks`); if that stat
--     has no variant here, it falls to their next-best stat that does.
--   * `fixed` — a single recipe id, for a slot whose best enchant isn't a stat variant.
-- `id` is the **enchanting recipe spellID** — its name resolves live (`GetSpellInfo`),
-- so nothing here is hardcoded text or locale-bound. A slot absent from this table (or
-- a stat-variant slot whose character spec is unknown) simply yields no recommendation.
---@class EnchantRec
---@field byStat table<string, number>?  secondary-stat token → recipe spellID
---@field fixed number?                  single recipe spellID (non-variant slots)

-- Season note (Midnight, 12.0.x): ring enchants come in Crit/Haste/Mastery/Versatility,
-- each at a weaker (+22) and stronger (+27) rank across three themes — we take the +27.
-- Chest's best is Mark of the Worldsoul (+36 to *Primary*, class-agnostic), so it's a
-- single pick. Weapon enchants are procs, not stat variants; the three that proc a
-- secondary stat are mapped by stat (no Haste proc exists — Haste specs fall through),
-- while the damage / absorb / primary procs aren't modelled. Head / Shoulder / Boots
-- carry only utility effects (Leech / Speed / Avoidance) — a player preference, not a
-- stat pick — so they're intentionally omitted (flagged as missing, no suggestion).
---@type table<string, EnchantRec>
ns.Enchants = {
  Finger = { byStat = {
    haste       = 1236088,  -- Enchant Ring - Silvermoon's Alacrity (+27)
    crit        = 1236074,  -- Enchant Ring - Nature's Fury (+27)
    mastery     = 1236060,  -- Enchant Ring - Zul'jin's Mastery (+27)
    versatility = 1236089,  -- Enchant Ring - Silvermoon's Tenacity (+27)
  } },
  Chest = { fixed = 1236069 },  -- Enchant Chest - Mark of the Worldsoul (+36 Primary)
  Weapon = { byStat = {
    crit        = 1236066,  -- Enchant Weapon - Jan'alai's Precision (Crit proc)
    mastery     = 1236097,  -- Enchant Weapon - Arcane Mastery (Mastery proc)
    versatility = 1236081,  -- Enchant Weapon - Worldsoul Tenacity (Versatility proc)
  } },
}
