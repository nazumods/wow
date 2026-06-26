---@class ShadowsOfUI_Upgrade
local ns = select(2, ...)
---@type WarbandeerAPI
local API = ns.api               -- WarbandeerApi (data layer we read)
---@class ShadowsOfUI_UpgradeApi
local Upgrade = ns.UpgradeApi    -- ShadowsOfUI_UpgradeApi (what we publish)
local GetItemInfoInstant = C_Item and C_Item.GetItemInfoInstant
local GetItemInfo = C_Item and C_Item.GetItemInfo
local GetSpellName = C_Spell and C_Spell.GetSpellName

-- Off-hand item types that take a *weapon* enchant.  A shield, frill, or holdable
-- in the off-hand can't be enchanted, so it must never be flagged as "missing one".
local WEAPON_EQUIPLOC = {
  INVTYPE_WEAPON = true, INVTYPE_WEAPONOFFHAND = true, INVTYPE_WEAPONMAINHAND = true,
}

-- Equipped slots checked for a missing permanent enchant, in a stable (top-down) order
-- so the output is deterministic.  Gated per slot by slotTakesEnchant (which consults
-- ns.EnchantableSlots), so a slot listed here that isn't currently enchantable is simply
-- skipped — keep this a superset and let the data file decide.
local ENCHANT_ORDER = {
  "Head", "Shoulder", "Chest", "Legs", "Feet", "Finger1", "Finger2", "MainHand", "OffHand",
}

-- equipLoc of an equipped item, falling back to the link when the data layer didn't
-- store it (alt cached before equipLoc existed).  GetItemInfoInstant is synchronous
-- and works from any link; absent in pure-Lua tests, which always pass equipLoc.
local function itemEquipLoc(item)
  if item.equipLoc and item.equipLoc ~= "" then return item.equipLoc end
  if item.link and GetItemInfoInstant then return (select(4, GetItemInfoInstant(item.link))) end
  return nil
end

-- The permanent enchant id embedded in an item link — field 2 of the itemString
-- (`item:itemID:enchantID:...`); 0 / absent = unenchanted.  A pure string parse, so
-- it reads off any stored alt link without the item being loaded.
---@param link string?
---@return integer
function ns.ItemEnchantID(link)
  if not link then return 0 end
  return tonumber(link:match("item:%d+:(%d*)")) or 0
end

-- Whether an equipped slot should carry a permanent enchant: the always-enchantable
-- slots from ns.EnchantableSlots, plus the off-hand only when it holds a weapon.
local function slotTakesEnchant(slot, item)
  if ns.EnchantableSlots[slot] then return true end
  if slot == "OffHand" then return WEAPON_EQUIPLOC[itemEquipLoc(item)] == true end
  return false
end

-- Whether an equipped item is below the minimum item level any enchant applies to this
-- expansion (ns.EnchantMinIlvl) — too low to enchant at all, so it's neither flagged as
-- missing nor recommended, for every enchantable slot. Only gates when the item's ilvl is
-- known; an unknown ilvl (alt scanned before ilvl was stored) is left ungated, as before.
local function belowEnchantMinIlvl(item)
  return (ns.EnchantMinIlvl and item.ilvl and item.ilvl < ns.EnchantMinIlvl) or false
end

-- A sub-max-level character is still levelling — gear churns constantly, so enchanting or
-- gemming it is wasted. Suppress every enchant/gem surface (missing flags AND recommendations)
-- until they ding max. A nil maxLevel (the pure-Lua tests don't seed ns.wow) or an unknown
-- character level leaves them ungated, matching belowEnchantMinIlvl's unknown-data stance.
---@param charData Character
---@return boolean
local function belowMaxLevel(charData)
  local level = charData and charData.basic and charData.basic.level
  local maxLevel = ns.wow and ns.wow.maxLevel
  return (maxLevel and level and level < maxLevel) or false
end
ns.BelowMaxLevel = belowMaxLevel

---Equipped slots that should carry a permanent enchant but don't, in a stable slot
---order.  Reads only the stored item link (the enchant id is encoded in it), so it
---works warband-wide for every character — not just the one logged in.
---@param charData Character
---@return { slot: string, link: string }[]
function ns.MissingEnchants(charData)
  local slots = charData and charData.equipment and charData.equipment.slots
  if not slots or belowMaxLevel(charData) then return {} end
  local out = {}
  for _, slot in ipairs(ENCHANT_ORDER) do
    local item = slots[slot]
    if item and item.link and slotTakesEnchant(slot, item)
       and not belowEnchantMinIlvl(item) and ns.ItemEnchantID(item.link) == 0 then
      out[#out + 1] = { slot = slot, link = item.link }
    end
  end
  return out
end

-------------------------------------------------------------------------------
-- Recommended enchant (which enchant to apply to a missing slot).
-------------------------------------------------------------------------------

-- An equipped slot → its canonical key in ns.Enchants (the two rings share one ring
-- enchant family, the weapons one weapon enchant). Unlisted slots key by their own name.
local ENCHANT_KEY = {
  Finger1 = "Finger", Finger2 = "Finger",
  MainHand = "Weapon", OffHand = "Weapon",
}

-- Secondary stats in tie-break order: the character's best (lowest-tier) stat that
-- actually has an enchant variant wins; equal tiers resolve by this order.
local STAT_ORDER = { "haste", "crit", "mastery", "versatility" }

-- The stat variant to recommend for a character: their top secondary among those the
-- slot offers a variant for, or nil when none of the offered stats are ranked.
local function pickStat(ranks, byStat)
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
-- and falls back to ns.Enchants on any shape mismatch.

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
local function classCodexEnchant(charData, slot)
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

---@class EnchantSuggestion
---@field kind "item"|"spell"  item = a ClassCodex pick (id is an itemId), spell = a bundled enchanting recipe
---@field id number?           item / recipe-spell id (resolve a name with GetItemInfo / GetSpellName)
---@field name string?         display name when the source already carries it (ClassCodex always does)
---@field stat string?         the stat a bundled variant was picked for (nil for ClassCodex / fixed)

---Recommended enchant for a slot. Prefers ClassCodex's per-spec pick (OptionalDep, read
---live) and falls back to the bundled stat-derived recipe: a `fixed` slot's single recipe,
---or the `byStat` variant for the character's top secondary stat. nil when neither source
---has one (or a stat-variant slot whose character spec/priority is unknown), and nil when
---the equipped item is below the slot enchant's minimum item level (can't be enchanted).
---@param charData Character
---@param slot string
---@return EnchantSuggestion?
function ns.RecommendedEnchant(charData, slot)
  if belowMaxLevel(charData) then return nil end           -- still levelling: don't enchant yet
  local slots = charData and charData.equipment and charData.equipment.slots
  local item = slots and slots[slot]
  if item and belowEnchantMinIlvl(item) then return nil end  -- item too low to enchant

  local ccName, ccItem = classCodexEnchant(charData, slot)
  if ccName or ccItem then return { kind = "item", id = ccItem, name = ccName } end

  local rec = ns.Enchants[ENCHANT_KEY[slot] or slot]
  if not rec then return nil end
  if rec.fixed then return { kind = "spell", id = rec.fixed } end
  if not rec.byStat then return nil end
  local ranks = ns.StatRanks(charData)
  if not ranks then return nil end
  local stat = pickStat(ranks, rec.byStat)
  if not stat then return nil end
  return { kind = "spell", id = rec.byStat[stat], stat = stat }
end

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

-- A recommendation's display name: ClassCodex carries `.name`; a bundled spell resolves
-- via GetSpellName, a bundled item via GetItemInfo. nil when it can't resolve yet (uncached).
local function suggestionName(rec)
  if rec.name and rec.name ~= "" then return rec.name end
  if rec.kind == "spell" then return GetSpellName and GetSpellName(rec.id) end
  if rec.kind == "item" then return GetItemInfo and (GetItemInfo(rec.id)) end
  return nil
end

-- Normalize an enchant name for comparison. The applied name (captured from the item's
-- "Enchanted:" tooltip line) keeps the "Enchant <Slot> - " prefix, but a ClassCodex
-- recommendation is the *bare* enchant name with no prefix — so we strip that prefix from
-- both (the same "^.- %- " drop the Detail display does) before the case/space-insensitive
-- compare, or an identical enchant would read as "wrong". Rank/quality-tier variants share
-- a name (the tier is a separate tooltip icon, stripped at capture), so they are NOT flagged;
-- only a genuinely different enchant is.
local function normEnchant(name)
  return (name:gsub("^.- %- ", ""):lower():gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end

-- A *stat-line* enchant renders its granted stats instead of a name — leg enchants are
-- spellthreads, whose "Enchanted:" tooltip line reads "+41 Intellect & +115 Stamina" rather
-- than "Enchant Legs - <X>". Such a line can't be name-matched to the recommendation (which
-- is the spellthread's *name*), so it's detected by carrying a digit and lacking the
-- "Enchant <Slot> - " naming separator, and compared on stat magnitudes instead.
local function isStatLine(name)
  return name:find("%d") ~= nil and name:find(" %- ") == nil
end

-- The integers embedded in a string ("+41 Intellect & +115 Stamina" → { 41, 115 }).
local function statNumbers(text)
  local nums = {}
  for n in text:gmatch("%d+") do nums[#nums + 1] = tonumber(n) end
  return nums
end

-- Whether a tooltip line contains every number in `want` as a standalone integer (frontier
-- patterns so 41 doesn't match inside 415) — i.e. that one line grants all the applied stats.
local function lineHasAll(line, want)
  for _, n in ipairs(want) do
    if not line:find("%f[%d]" .. n .. "%f[%D]") then return false end
  end
  return true
end

-- The recommended enchant's descriptive tooltip lines: a ClassCodex item's full item
-- tooltip, or a bundled recipe spell's description (one line). Read dynamically off the live
-- globals (so the busted harness can stub them); nil when neither resolves yet.
local function recTooltipLines(rec)
  local TI = _G.C_TooltipInfo
  if rec.kind == "item" and rec.id and TI and TI.GetItemByID then
    local data = TI.GetItemByID(rec.id)
    if data and data.lines then
      local out = {}
      for _, ln in ipairs(data.lines) do out[#out + 1] = ln.leftText or "" end
      return out
    end
  end
  local Spell = _G.C_Spell
  if rec.kind == "spell" and rec.id and Spell and Spell.GetSpellDescription then
    local desc = Spell.GetSpellDescription(rec.id)
    if desc and desc ~= "" then return { desc } end
  end
  return nil
end

-- For a stat-line (spellthread) applied enchant: true = the recommendation grants the same
-- stats (a single tooltip line carries every applied stat number — not a mismatch); false =
-- it genuinely grants different stats; nil = the recommendation has no resolvable tooltip yet,
-- so we can't judge it (caller must NOT flag — never re-introduce a false "wrong enchant").
local function statLineMatches(applied, rec)
  local want = statNumbers(applied)
  if #want == 0 then return nil end
  local lines = recTooltipLines(rec)
  if not lines then return nil end
  for _, line in ipairs(lines) do
    if lineHasAll(line, want) then return true end
  end
  return false
end

---Equipped slots whose APPLIED enchant differs from the recommended one — a *wrong* (not
---missing) enchant — in stable slot order. Skips slots that are bare (those are
---`MissingEnchants`), carry no stored applied-enchant name (an alt not rescanned since the
---name was captured), or have no recommendation to compare against. Each entry carries the
---`itemID` + `enchantID` for a per-item ignore key (both parsed from the link).
---@param charData Character
---@return { slot: string, link: string, itemID: integer?, enchantID: integer, applied: string, recommended: string }[]
function ns.EnchantMismatches(charData)
  local slots = charData and charData.equipment and charData.equipment.slots
  if not slots or belowMaxLevel(charData) then return {} end
  local out = {}
  for _, slot in ipairs(ENCHANT_ORDER) do
    local item = slots[slot]
    local applied = item and item.enchant
    if item and item.link and applied and slotTakesEnchant(slot, item) then
      local rec = ns.RecommendedEnchant(charData, slot)
      local recName = rec and suggestionName(rec)
      -- A spellthread (stat-line) enchant can't be name-matched — compare it on stat
      -- magnitudes; everything else is the case/space-insensitive name compare. Either
      -- path treats an unresolvable recommendation as "can't judge" → not a mismatch.
      local mismatch
      if rec and isStatLine(applied) then
        mismatch = statLineMatches(applied, rec) == false
      elseif recName then
        mismatch = normEnchant(applied) ~= normEnchant(recName)
      end
      if mismatch then
        out[#out + 1] = {
          slot = slot, link = item.link,
          itemID = GetItemInfoInstant and (GetItemInfoInstant(item.link)),
          enchantID = ns.ItemEnchantID(item.link),
          applied = applied, recommended = recName,
        }
      end
    end
  end
  return out
end

-------------------------------------------------------------------------------
-- Empty gem sockets + recommended gem.
-------------------------------------------------------------------------------

-- Equipped slots scanned for empty sockets, in a stable top-down order. Any slot can
-- carry a socket, so this is the full set (vs the enchantable subset).
local GEM_ORDER = {
  "Head", "Neck", "Shoulder", "Back", "Chest", "Wrist", "Hands", "Waist",
  "Legs", "Feet", "Finger1", "Finger2", "Trinket1", "Trinket2", "MainHand", "OffHand",
}

-- ClassCodex's per-spec gems block (its `.gems` table) when installed, or nil.
local function classCodexGems(charData)
  local data = _G.ClassCodexGearData
  if type(data) ~= "table" then return nil end
  local token, specKey = ccClassSpec(charData)
  if not token then return nil end
  local spec = data[token] and data[token][specKey]
  local gems = spec and spec.gems
  return type(gems) == "table" and gems or nil
end

-- An EnchantSuggestion (kind="item") from a ClassCodex gem entry { itemId, name }, or nil.
local function ccGem(g)
  if type(g) == "table" and (g.name or g.itemId) then
    return { kind = "item", id = g.itemId, name = g.name }
  end
  return nil
end

---Recommended gems for a character, as two `EnchantSuggestion`s: the **primary** gem (the
---"diamond" — primary stat, **unique-equipped so you socket exactly one**) and a **secondary**
---stat gem to fill every other socket. ClassCodex supplies both per spec; the bundled
---fallback has only the secondary (the role-specific diamond isn't bundled). Either may be nil.
---@param charData Character
---@return EnchantSuggestion? primary, EnchantSuggestion? secondary
function ns.RecommendedGems(charData)
  if belowMaxLevel(charData) then return nil, nil end       -- still levelling: don't gem yet
  local gems = classCodexGems(charData)
  if gems then
    local list = gems.secondary
    local primary = ccGem(gems.primary)
    local secondary = ccGem(type(list) == "table" and list[1] or nil)
    if primary or secondary then return primary, secondary end
  end
  -- Bundled fallback: a secondary-stat gem by top stat (no unique diamond bundled).
  local byStat = ns.Gems and ns.Gems.byStat
  if byStat then
    local ranks = ns.StatRanks(charData)
    local stat = ranks and pickStat(ranks, byStat)
    if stat then return nil, { kind = "item", id = byStat[stat], stat = stat } end
  end
  return nil, nil
end

---Equipped slots with one or more empty gem sockets, in a stable slot order. Reads the
---data layer's stored `emptySockets` count (captured at scan time when the item is
---loaded), so it works for every scanned character — though a slot socketed since that
---character last logged in won't reflect until its next scan.
---@param charData Character
---@return { slot: string, link: string, sockets: integer }[]
function ns.MissingGems(charData)
  local slots = charData and charData.equipment and charData.equipment.slots
  if not slots or belowMaxLevel(charData) then return {} end
  local out = {}
  for _, slot in ipairs(GEM_ORDER) do
    local item = slots[slot]
    if item and item.link and (item.emptySockets or 0) > 0 then
      out[#out + 1] = { slot = slot, link = item.link, sockets = item.emptySockets }
    end
  end
  return out
end

-------------------------------------------------------------------------------
-- Published API (ShadowsOfUI_UpgradeApi) — consumed by Warbandeer (OptionalDep).
-------------------------------------------------------------------------------

---Equipped slots missing a permanent enchant for a character, in a stable slot
---order.  Empty when the character has no scanned equipment, or every enchantable
---slot is enchanted.
---@param charName string
---@return { slot: string, link: string }[]
function Upgrade:MissingEnchants(charName)
  return ns.MissingEnchants(API:GetCharacterData(charName))
end

---Recommended enchant for a character's slot as an `EnchantSuggestion` (resolve a display
---name from `.name` / `.id`), or nil when no recommendation applies. Prefers ClassCodex's
---per-spec pick when that addon is installed, else the bundled stat-derived recipe.
---@param charName string
---@param slot string
---@return EnchantSuggestion?
function Upgrade:RecommendedEnchant(charName, slot)
  return ns.RecommendedEnchant(API:GetCharacterData(charName), slot)
end

---Equipped slots with empty gem sockets for a character (warband-wide from the stored
---socket count), each `{ slot, link, sockets }`. See ns.MissingGems for the freshness caveat.
---@param charName string
---@return { slot: string, link: string, sockets: integer }[]
function Upgrade:MissingGems(charName)
  return ns.MissingGems(API:GetCharacterData(charName))
end

---Equipped slots whose applied enchant differs from the recommendation (a *wrong*, not
---missing, enchant), each `{ slot, link, itemID, enchantID, applied, recommended }`. Uses
---the applied-enchant name captured at scan time, so it's warband-wide but only as fresh as
---the character's last scan. `itemID`+`enchantID` give a stable per-item ignore key for a
---consumer (the logic addon holds no ignore state). See ns.EnchantMismatches.
---@param charName string
---@return { slot: string, link: string, itemID: integer?, enchantID: integer, applied: string, recommended: string }[]
function Upgrade:EnchantMismatches(charName)
  return ns.EnchantMismatches(API:GetCharacterData(charName))
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

---Recommended gems for a character: a `primary` (unique-equipped "diamond", socket one) and a
---`secondary` (fill the other sockets), each an `EnchantSuggestion` item (resolve a name from
---`.name`/`.id`) or nil. ClassCodex's per-spec pair when installed, else just the bundled secondary.
---@param charName string
---@return EnchantSuggestion? primary, EnchantSuggestion? secondary
function Upgrade:RecommendedGems(charName)
  return ns.RecommendedGems(API:GetCharacterData(charName))
end
