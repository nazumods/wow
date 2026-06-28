---@type Warbandeer
local ns = select(2, ...)
local insert, fmt = table.insert, string.format

-- Warband craft-hint machinery for the Professions summary column (the column itself
-- + its scoring live in summaryCol/profs.lua, loaded after this). Builds the
-- account-wide "who can craft / upgrade this prof-gear piece" index on first hover and
-- renders the per-item / empty-slot hint lines. Exposed on `ns.profsCol`.

-- Mirrors the scoring constants in summaryCol/profs.lua (crafted tiers are a fixed
-- 5-star game mechanic; rare is the 100%-goal baseline rarity).
local BASE_RARITY = 3 -- rare (blue)
local MAX_TIER    = 5

local RECIPE_EXP_KEY = "midnight" -- recipe bucket to scan (matches CraftingView)

-- A profession has two *distinct* accessory lines (e.g. Blacksmithing's apron is
-- made by a leatherworker; its toolbox by a blacksmith), so "any higher-rarity
-- accessory" is NOT an upgrade — only a higher tier of the SAME line is.  We key
-- a line by the item name's last word (Apron / Toolbox / Hammer), which stays
-- consistent within a line across locales (translations keep the family noun).
-- FAMILY_OVERRIDE pins any item whose suffix the heuristic would get wrong.
local FAMILY_OVERRIDE = {} ---@type table<integer, string>
local function familyKey(itemID)
  if not itemID then return nil end
  if FAMILY_OVERRIDE[itemID] then return FAMILY_OVERRIDE[itemID] end
  local name = C_Item.GetItemInfo(itemID)
  return name and name:match("(%S+)%s*$")
end

-- ─── Warband craft hints ─────────────────────────────────────────────────────
-- "X can upgrade this." / "X can craft a better version." lines under each
-- tooltip item.  Recipe → prof-gear resolution comes from the account-wide
-- cache behind ns.api:ResolveRecipeOutput; the crafters half (who knows it,
-- skill, intent flag) is volatile, so it's rebuilt per session on first hover.

local craftable       -- [itemID] = { itemID, rarity, equipLoc, crafters = {{name, skill, isMain, quality, qualityConc}} }
local craftableByProf -- [skillLineID the gear is for] = entry[]
local craftableDirty  -- some output items weren't in the item cache; rebuild next hover

-- Skill-line IDs of the professions a character CURRENTLY has, from the live
-- basic.professions summary.  professions.details is merge-preserving and keyed
-- by skillLineID, so a dropped-and-replaced profession leaves its stale learned
-- recipes behind — crediting a crafter with recipes they no longer know.  Gating
-- on the current set fixes that (e.g. a blacksmith who used to be a leatherworker
-- is no longer credited with the leatherworking-crafted gear).
local function activeProfessions(toon)
  local active = {}
  local profs = toon.basic and toon.basic.professions
  for _, p in pairs(profs or {}) do
    if type(p) == "table" and p.skillID then active[p.skillID] = true end
  end
  return active
end

local function buildCraftable()
  craftable, craftableByProf, craftableDirty = {}, {}, false
  for _, toon in ipairs(ns.api:GetAllCharacters()) do
    local details = toon.professions and toon.professions.details
    local active = activeProfessions(toon)
    for craftSkillID, det in pairs(details or {}) do
      local bucket = active[craftSkillID] and det.recipes and det.recipes[RECIPE_EXP_KEY]
      for _, recipe in ipairs(bucket and bucket.learned or {}) do
        local out = ns.api:ResolveRecipeOutput(recipe.id)
        if out == nil then craftableDirty = true end
        if out then
          local entry = craftable[out.itemID]
          if not entry then
            entry = { itemID = out.itemID, rarity = out.rarity, equipLoc = out.equipLoc, crafters = {} }
            craftable[out.itemID] = entry
            craftableByProf[out.skillID] = craftableByProf[out.skillID] or {}
            insert(craftableByProf[out.skillID], entry)
          end
          local known = false
          for _, c in ipairs(entry.crafters) do
            if c.name == toon.name then known = true break end
          end
          if not known then
            local prof = ns.data.FindProf(toon, craftSkillID)
            insert(entry.crafters, {
              name    = toon.name,
              skill   = prof and prof.skillLevel or 0,
              isMain  = ns.data.GetProfIntent(toon.name, craftSkillID) == "main",
              -- Crafting quality tier this toon reaches for THIS recipe, captured
              -- at scan time, with/without concentration (nil until re-scanned).
              quality     = recipe.quality,
              qualityConc = recipe.qualityConc,
            })
          end
        end
      end
    end
  end
end

-- The toon flagged "main" for the crafting profession, else the highest skill.
local function bestCrafter(entry)
  local best
  for _, c in ipairs(entry.crafters) do
    if not best
      or (c.isMain and not best.isMain)
      or (c.isMain == best.isMain and c.skill > best.skill) then
      best = c
    end
  end
  return best
end

-- Best crafter who can actually reach a quality tier ABOVE minTier for an entry,
-- and the tier + whether it needs concentration.  Preference: no concentration
-- first, then higher tier, then the profession's main, then raw skill.  Also
-- reports whether ANY crafter carried quality data (nil quality = the recipe
-- hasn't been re-scanned since quality capture shipped), so callers can fall
-- back to a plain (un-tiered) suggestion instead of going silent.
---@return table? crafter, integer? tier, boolean? needsConcentration, boolean hasData
local function bestQualityCrafter(entry, minTier)
  local best, bestTier, bestConc, hasData
  for _, c in ipairs(entry.crafters) do
    if c.quality or c.qualityConc then hasData = true end
    local tier, conc
    if c.quality and c.quality > minTier then tier, conc = c.quality, false
    elseif c.qualityConc and c.qualityConc > minTier then tier, conc = c.qualityConc, true end
    if tier and (not best
      or (bestConc and not conc)
      or (bestConc == conc and tier > bestTier)
      or (bestConc == conc and tier == bestTier and c.isMain and not best.isMain)
      or (bestConc == conc and tier == bestTier and c.isMain == best.isMain and c.skill > best.skill)) then
      best, bestTier, bestConc = c, tier, conc
    end
  end
  return best, bestTier, bestConc, hasData or false
end

-- " (R3 T4)" / " (R3 T4, concentration)" suffix for a crafter clause — rarity
-- AND crafted tier, matching the worn-item lines' R# T# notation so a rarity
-- upgrade at a low tier (e.g. R2 T3 → R3 T1) doesn't read as a downgrade.
local function qualityTag(rarity, tier, conc)
  return fmt(" (R%d T%d%s)", rarity or 0, tier, conc and ", concentration" or "")
end

-- Upgrade hint lines for a worn item (a possibly-empty list).  Both kinds of
-- upgrade are scoped to the worn item's gear LINE (so a different accessory is
-- never offered) and are quality-aware — an alt is only named if they can reach
-- a higher tier (knowing the recipe ≠ having the skill).  Lines, in order:
--   • a higher-RARITY piece of the same line — "can craft a better version (R3 T1)"
--   • the SAME piece recrafted to a higher tier — "can upgrade this (R2 T4)",
--     often the cheaper win, so it's surfaced alongside the rarity jump.
-- The line is keyed by the item-name's last word (Apron/Toolbox/Hammer), which
-- works for any worn item — even one no alt can craft, or an old-expansion piece —
-- unlike an itemID/recipe lookup.  Rarity suggestions stop at the rare baseline
-- (epic isn't part of the 100% goal).  With no quality data yet (recipes not
-- re-scanned since capture shipped) it falls back to a plain, un-tiered line.
local function craftHint(skillID, item, isCurrentExpac)
  if not craftable or craftableDirty then buildCraftable() end
  local itemID = item.link and tonumber(item.link:match("item:(%d+)"))
  if not itemID then return {} end
  local equipLoc = select(4, C_Item.GetItemInfoInstant(itemID))
  local wornFamily = familyKey(itemID)
  local wornRarity = isCurrentExpac and (item.rarity or 0) or 0
  local wornTier = item.tier or 0
  local lines = {}
  if not wornFamily then return lines end

  -- Within the worn line: its own recipe (matching rarity) for tier upgrades,
  -- and the best higher-rarity recipe for a bigger jump.
  local own, better
  for _, entry in ipairs(craftableByProf[skillID] or {}) do
    if entry.equipLoc == equipLoc and familyKey(entry.itemID) == wornFamily then
      if entry.rarity == wornRarity then
        own = entry
      elseif entry.rarity > wornRarity and entry.rarity <= BASE_RARITY
        and (not better or entry.rarity > better.rarity) then
        better = entry
      end
    end
  end

  if better then
    local c, tier, conc, hasData = bestQualityCrafter(better, 0)
    if c then
      insert(lines, fmt("    |cffaaaaaa%s can craft a better version%s.|r", c.name, qualityTag(better.rarity, tier, conc)))
    elseif not hasData then
      local fc = bestCrafter(better)
      if fc then insert(lines, fmt("    |cffaaaaaa%s can craft a better version.|r", fc.name)) end
    end
  end

  if own and wornTier < MAX_TIER then
    local c, tier, conc, hasData = bestQualityCrafter(own, wornTier)
    if c then
      insert(lines, fmt("    |cffaaaaaa%s can upgrade this%s.|r", c.name, qualityTag(own.rarity, tier, conc)))
    elseif not hasData then
      local fc = bestCrafter(own)
      if fc then insert(lines, fmt("    |cffaaaaaa%s can upgrade this.|r", fc.name)) end
    end
  end

  return lines
end

-- Hints for an empty profession slot of a given type (tool vs accessory): who
-- across the warband could craft a piece for THIS slot, and where any spare for
-- it is sitting (warband bank, an alt's bank, the guild bank).  Suggestions are
-- filtered to the slot's equipLoc, and — for accessories — to gear lines NOT
-- already worn in the other accessory slot (wornFamilies), so a character wearing
-- an apron is pointed at the toolbox line rather than a second apron.
-- Returns a (possibly empty) list of tooltip lines.
local function emptyHints(skillID, equipLoc, wornFamilies)
  if not craftable or craftableDirty then buildCraftable() end
  local function wanted(itemID)
    return not (wornFamilies and wornFamilies[familyKey(itemID)])
  end
  local lines = {}
  -- Best crafter (and the tier they'd reach) across this profession's recipes
  -- for this slot type, preferring no concentration then higher tier.  Falls
  -- back to a plain suggestion only when no recipe has quality data yet.
  local best, bestTier, bestConc, bestRarity, anyData, fallback
  for _, entry in ipairs(craftableByProf[skillID] or {}) do
    if entry.equipLoc == equipLoc and wanted(entry.itemID) then
      local c, tier, conc, hasData = bestQualityCrafter(entry, 0)
      if hasData then anyData = true end
      if c and (not best
        or (bestConc and not conc)
        or (bestConc == conc and tier > bestTier)) then
        best, bestTier, bestConc, bestRarity = c, tier, conc, entry.rarity
      end
      fallback = fallback or bestCrafter(entry)
    end
  end
  if best then
    insert(lines, fmt("    |cffaaaaaa%s can craft one%s.|r", best.name, qualityTag(bestRarity, bestTier, bestConc)))
  elseif not anyData and fallback then
    insert(lines, fmt("    |cffaaaaaa%s can craft one.|r", fallback.name))
  end
  -- Spares of this slot type in any scanned bank (same family filter), summed per
  -- source (warband first, then alts, then guild) as GetBankProfGear returns them.
  local order, total = {}, {}
  for _, e in ipairs(ns.api:GetBankProfGear(skillID)) do
    if e.equipLoc == equipLoc and wanted(e.itemID) then
      if not total[e.source] then insert(order, e.source); total[e.source] = 0 end
      total[e.source] = total[e.source] + (e.count or 1)
    end
  end
  for _, source in ipairs(order) do
    insert(lines, fmt("    |cffaaaaaa%d in %s.|r", total[source], source))
  end
  return lines
end

---@class Warbandeer
---@field profsCol table  craft-hint helpers for the Professions summary column (see views/summaryCol/profsCraft.lua)
ns.profsCol = {
  familyKey = familyKey,
  craftHint = craftHint,
  emptyHints = emptyHints,
}
