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
--     matching the character's top secondary stat (via `ns.StatRanks`). Use for the
--     slots whose enchant comes in Crit/Haste/Mastery/Versatility variants.
--   * `fixed` — a single recipe id. Use for slots whose enchant isn't a stat variant
--     (weapon proc/utility enchants; a primary-stat leg armour kit; etc.).
-- `id` is the **enchanting recipe spellID** — its name resolves live (`GetSpellInfo`),
-- so nothing here is hardcoded text or locale-bound. A slot absent from this table (or
-- a stat-variant slot whose character spec is unknown) simply yields no recommendation.
---@class EnchantRec
---@field byStat table<string, number>?  secondary-stat token → recipe spellID
---@field fixed number?                  single recipe spellID (non-variant slots)

---@type table<string, EnchantRec>
ns.Enchants = {
  -- TODO(12.0.5): populate with verified recipe ids harvested in-game.
  -- Example shape (ids are placeholders — do not ship):
  --   Finger = { byStat = { haste = 0, crit = 0, mastery = 0, versatility = 0 } },
  --   Back   = { byStat = { ... } },
  --   Chest  = { byStat = { ... } },
  --   Wrist  = { byStat = { ... } },
  --   Legs   = { fixed = 0 },
  --   Feet   = { byStat = { ... } },
  --   Weapon = { fixed = 0 },
}
