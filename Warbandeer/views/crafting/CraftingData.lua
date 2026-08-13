---@type Warbandeer
local ns = select(2, ...)

-- Shared expansion metadata for the Crafting view, split out of CraftingView.lua (loaded
-- first) so the view shell and its spec read the same table. Each entry:
--   key       selected-expansion state + recipe bucket key (matches the short keys in
--             RECIPE_EXP_KEYS, Warbandeer_Characters/data/professions.lua)
--   label     display name for the expansion toggle and the skill/recipe tooltips
--   skillName the profession child's `expansionName` (a bare continent name) that the
--             scanner stores in `exp.name`; used to match the per-expansion skill. It
--             differs from `label` wherever the continent name isn't the marketing name
--             (Dragonflight -> Dragon Isles, The War Within -> Khaz Algar), and every value
--             is a key in ProfsData's EXP_ABBR. Matching skill on `label` instead silently
--             never matches the stored name (the same class of bug as Horde BFA, #910).
--   enabled   whether the column is wired (DF/TWW await recipe/concentration capture)
---@type { key:string, label:string, skillName:string, enabled:boolean }[]
local EXPANSIONS = {
  { key = "df",       label = "Dragonflight",   skillName = "Dragon Isles", enabled = false },
  { key = "tww",      label = "The War Within", skillName = "Khaz Algar",   enabled = false },
  { key = "midnight", label = "Midnight",       skillName = "Midnight",     enabled = true  },
}

-- Derived per-key lookups: `EXP_LABEL` for display (toggle + tooltips), `EXP_SKILL_NAME`
-- for the skill match against `exp.name`. Keeping them separate is the fix (see skillName).
local EXP_LABEL, EXP_SKILL_NAME = {}, {}
for _, e in ipairs(EXPANSIONS) do
  EXP_LABEL[e.key]      = e.label
  EXP_SKILL_NAME[e.key] = e.skillName
end

---@class Warbandeer
---@field crafting table  shared expansion metadata for the Crafting view (see views/crafting/CraftingData.lua)
ns.crafting = {
  EXPANSIONS = EXPANSIONS,
  EXP_LABEL = EXP_LABEL,
  EXP_SKILL_NAME = EXP_SKILL_NAME,
}
