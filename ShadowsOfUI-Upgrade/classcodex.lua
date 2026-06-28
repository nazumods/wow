---@class ShadowsOfUI_Upgrade
local ns = select(2, ...)
---@type WarbandeerAPI
local API = ns.api               -- WarbandeerApi (data layer we read)
---@class ShadowsOfUI_UpgradeApi
local Upgrade = ns.UpgradeApi    -- ShadowsOfUI_UpgradeApi (what we publish)

-- Shared foundation for the enchant + gem surfaces: the levelling/ilvl gates, the
-- secondary-stat picker, and the ClassCodex resolution layer (an OptionalDep read
-- live). enchants.lua and gems.lua consume these off `ns`; ItemUpgrades-style logic
-- doesn't touch any of it.

-- An equipped item below the minimum item level any enchant applies to this expansion
-- (ns.EnchantMinIlvl) — too low to enchant at all, so it's neither flagged as missing nor
-- recommended, for every enchantable slot. Only gates when the item's ilvl is known; an
-- unknown ilvl (alt scanned before ilvl was stored) is left ungated, as before.
---@param item table
---@return boolean
function ns.BelowEnchantMinIlvl(item)
  return (ns.EnchantMinIlvl and item.ilvl and item.ilvl < ns.EnchantMinIlvl) or false
end

-- A sub-max-level character is still levelling — gear churns constantly, so enchanting or
-- gemming it is wasted. Suppress every enchant/gem surface (missing flags AND recommendations)
-- until they ding max. A nil maxLevel (the pure-Lua tests don't seed ns.wow) or an unknown
-- character level leaves them ungated, matching BelowEnchantMinIlvl's unknown-data stance.
---@param charData Character
---@return boolean
function ns.BelowMaxLevel(charData)
  local level = charData and charData.basic and charData.basic.level
  local maxLevel = ns.wow and ns.wow.maxLevel
  return (maxLevel and level and level < maxLevel) or false
end

-- Secondary stats in tie-break order: the character's best (lowest-tier) stat that
-- actually has an enchant variant wins; equal tiers resolve by this order.
local STAT_ORDER = { "haste", "crit", "mastery", "versatility" }

-- The stat variant to recommend for a character: their top secondary among those the
-- slot offers a variant for, or nil when none of the offered stats are ranked.
---@param ranks table<string, integer>
---@param byStat table<string, any>
---@return string?
function ns.PickStat(ranks, byStat)
  local best, bestTier
  for _, s in ipairs(STAT_ORDER) do
    local tier = byStat[s] and ranks[s]
    if tier and (not bestTier or tier < bestTier) then best, bestTier = s, tier end
  end
  return best
end

-- ClassCodex (OptionalDep) publishes per-spec gearing recommendations as the global
-- ClassCodexGearData[CLASSTOKEN][specKey].enchants = { { slot, best = { itemId, name } } },
-- scraped from Wowhead. When present it's authoritative — per spec, every slot, and kept
-- current by that addon's own updates — so we prefer it over our bundled stat heuristic.
-- It's an undocumented internal global of a young (v0.x) addon, so every read is defensive
-- and falls back to ns.Enchants / ns.Gems on any shape mismatch.

-- our slot name → normalized ClassCodex slot token. CC's slot strings are inconsistent
-- ("Ring" vs "Rings", "Boots" for feet), so we compare against a lowercased, trailing-'s'-
-- stripped form (ccNormalize) — "Ring"/"Rings"/"Shoulders"/"Boots"/"Legs" all collapse.
local CC_SLOT = {
  Head = "head", Shoulder = "shoulder", Chest = "chest", Legs = "leg",
  Feet = "boot", Finger1 = "ring", Finger2 = "ring", MainHand = "weapon", OffHand = "weapon",
}
-- CC also varies by *synonym*, not just plural: the head slot is labelled "Helm" in its
-- data (Wowhead's term) even though the equipment slot is "Head". Fold such synonyms onto
-- our canonical token after the lower/de-plural pass, so "Helm" matches CC_SLOT.Head.
local CC_ALIAS = { helm = "head" }
local function ccNormalize(s)
  if type(s) ~= "string" then return nil end
  local n = s:lower():gsub("s$", "")
  return CC_ALIAS[n] or n
end

-- (classToken, specKey) for a stored character, matching ClassCodex's English data keys:
-- classKey upper-cased (Mage → MAGE) and the spec name lower-cased with spaces → hyphens
-- (Beast Mastery → beast-mastery). The spec name comes from the persisted numeric id when
-- present, else the stored spec-name string — an alt not logged in since the id was added
-- (v13) carries only `primary`/`active` names, but those are exactly what we key on, so the
-- recommendation still resolves. specKey is the *localized* name, so a non-enUS client
-- simply misses and falls back to the bundled recipe.
local function ccClassSpec(charData)
  local spec = charData and charData.basic and charData.basic.specialization
  local token = charData and charData.classKey and charData.classKey:upper()
  if not (spec and token) then return nil end
  local name
  if spec.id then
    local getInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfoByID)
      or _G.GetSpecializationInfoByID
    name = getInfo and select(2, getInfo(spec.id))
  end
  name = name or spec.active or spec.primary   -- prefer the played spec; `primary` is the loot spec
  if not name then return nil end
  return token, (name:lower():gsub("%s+", "-"))
end

-- ClassCodex's per-spec best enchant for a slot → name, itemId (or nil).
---@param charData Character
---@param slot string
---@return string? name, number? itemId
function ns.ClassCodexEnchant(charData, slot)
  local data = _G.ClassCodexGearData
  local ccSlot = CC_SLOT[slot]
  if type(data) ~= "table" or not ccSlot then return nil end
  local token, specKey = ccClassSpec(charData)
  if not token then return nil end
  local spec = data[token] and data[token][specKey]
  local list = spec and spec.enchants
  if type(list) ~= "table" then return nil end
  for _, e in ipairs(list) do
    if type(e) == "table" and ccNormalize(e.slot) == ccSlot and type(e.best) == "table" then
      if e.best.name or e.best.itemId then return e.best.name, e.best.itemId end
    end
  end
  return nil
end

-- ClassCodex's per-spec gems block (its `.gems` table) when installed, or nil.
---@param charData Character
---@return table?
function ns.ClassCodexGems(charData)
  local data = _G.ClassCodexGearData
  if type(data) ~= "table" then return nil end
  local token, specKey = ccClassSpec(charData)
  if not token then return nil end
  local spec = data[token] and data[token][specKey]
  local gems = spec and spec.gems
  return type(gems) == "table" and gems or nil
end

---@class EnchantSuggestion
---@field kind "item"|"spell"  item = a ClassCodex pick (id is an itemId), spell = a bundled enchanting recipe
---@field id number?           item / recipe-spell id (resolve a name with GetItemInfo / GetSpellName)
---@field name string?         display name when the source already carries it (ClassCodex always does)
---@field stat string?         the stat a bundled variant was picked for (nil for ClassCodex / fixed)

-- Dev dump: why a character does / doesn't get a recommendation for each missing-enchant
-- slot. Reuses the real CC helpers above (ccClassSpec/ccNormalize/CC_SLOT) so it reflects
-- exactly what `RecommendedEnchant` resolves — showing the raw ClassCodex slot strings
-- (and their normalized form) so a slot present in CC under an unmatched name is obvious.
-- Returned as a text block for a copyable window (see /supgrade enchants).
---@param charData Character
---@return string
function ns.DumpEnchants(charData)
  local out = {}
  local token, specKey = ccClassSpec(charData)
  out[#out + 1] = ("%s — class=%s spec=%s"):format(charData.name or "?", tostring(token), tostring(specKey))

  local cc = _G.ClassCodexGearData
  out[#out + 1] = "ClassCodex global: " .. (type(cc) == "table" and "present" or "ABSENT (using bundled fallback)")
  local spec = type(cc) == "table" and token and cc[token] and cc[token][specKey]
  if type(spec) == "table" and type(spec.enchants) == "table" then
    out[#out + 1] = "CC enchant entries (raw slot → normalized → pick):"
    for _, e in ipairs(spec.enchants) do
      if type(e) == "table" then
        out[#out + 1] = ("  %q → %s → %s"):format(
          tostring(e.slot), tostring(ccNormalize(e.slot)),
          tostring(e.best and (e.best.name or e.best.itemId) or "?"))
      end
    end
  elseif type(cc) == "table" then
    out[#out + 1] = ("CC has no enchants list for %s/%s"):format(tostring(token), tostring(specKey))
  end

  out[#out + 1] = "Missing-enchant slots → recommendation (CC slot key in []):"
  for _, m in ipairs(ns.MissingEnchants(charData)) do
    local rec = ns.RecommendedEnchant(charData, m.slot)
    local got = rec and (rec.name or ("%s id %s"):format(rec.kind, tostring(rec.id))) or "NONE"
    out[#out + 1] = ("  %s [%s] → %s"):format(m.slot, tostring(CC_SLOT[m.slot]), got)
  end
  return table.concat(out, "\n")
end

-- ClassCodex's Archon stat-rating *targets* for a character's spec + context, as
-- `{ crit, haste, mastery, versatility }` ratings, or nil. Default context is Mythic+,
-- falling back to Raid. Read defensively from the `ClassCodexArchonStats` global (OptionalDep).
local STAT_TARGET_CONTEXTS = { "Mythic+", "Raid" }
function ns.StatTargets(charData, context)
  local data = _G.ClassCodexArchonStats
  if type(data) ~= "table" then return nil end
  local token, specKey = ccClassSpec(charData)
  if not token then return nil end
  local spec = data[token] and data[token][specKey]
  if type(spec) ~= "table" then return nil end
  local ctx = context and spec[context]
  if not ctx then
    for _, c in ipairs(STAT_TARGET_CONTEXTS) do ctx = ctx or spec[c] end
  end
  local targets = ctx and ctx.targets
  return type(targets) == "table" and targets or nil
end

---Archon stat-rating targets for a character's spec (`{ crit, haste, mastery, versatility }`
---ratings), or nil. `context` is "Mythic+" (default) or "Raid". From ClassCodex (OptionalDep);
---compare against the stored combat rating to show how a character stacks up to the meta.
---@param charName string
---@param context string?
---@return table<string, integer>?
function Upgrade:StatTargets(charName, context)
  return ns.StatTargets(API:GetCharacterData(charName), context)
end

---Secondary-stat priority for a character's spec as a `{ stat = tier }` map (tier 1 = top),
---or nil when the spec/priority isn't known. Lets a consumer highlight the character's most-
---valued secondary (e.g. Warbandeer's Detail stat grid).
---@param charName string
---@return table<string, integer>?
function Upgrade:StatRanks(charName)
  return ns.StatRanks(API:GetCharacterData(charName))
end
