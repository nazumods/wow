---@class ShadowsOfUI_Upgrade
local ns = select(2, ...)
---@type WarbandeerAPI
local API = ns.api               -- WarbandeerApi (data layer we read)
---@class ShadowsOfUI_UpgradeApi
local Upgrade = ns.UpgradeApi    -- ShadowsOfUI_UpgradeApi (what we publish)
local GetItemInfoInstant = C_Item and C_Item.GetItemInfoInstant

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

---Equipped slots that should carry a permanent enchant but don't, in a stable slot
---order.  Reads only the stored item link (the enchant id is encoded in it), so it
---works warband-wide for every character — not just the one logged in.
---@param charData Character
---@return { slot: string, link: string }[]
function ns.MissingEnchants(charData)
  local slots = charData and charData.equipment and charData.equipment.slots
  if not slots then return {} end
  local out = {}
  for _, slot in ipairs(ENCHANT_ORDER) do
    local item = slots[slot]
    if item and item.link and slotTakesEnchant(slot, item) and ns.ItemEnchantID(item.link) == 0 then
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
local function ccNormalize(s)
  return type(s) == "string" and (s:lower():gsub("s$", "")) or nil
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
  name = name or spec.primary or spec.active   -- primary mirrors what `id` would resolve to
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
---has one (or a stat-variant slot whose character spec/priority is unknown).
---@param charData Character
---@param slot string
---@return EnchantSuggestion?
function ns.RecommendedEnchant(charData, slot)
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

-------------------------------------------------------------------------------
-- Empty gem sockets + recommended gem.
-------------------------------------------------------------------------------

-- Equipped slots scanned for empty sockets, in a stable top-down order. Any slot can
-- carry a socket, so this is the full set (vs the enchantable subset).
local GEM_ORDER = {
  "Head", "Neck", "Shoulder", "Back", "Chest", "Wrist", "Hands", "Waist",
  "Legs", "Feet", "Finger1", "Finger2", "Trinket1", "Trinket2", "MainHand", "OffHand",
}

-- ClassCodex's per-spec primary gem (name, itemId) when installed, or nil.
local function classCodexGem(charData)
  local data = _G.ClassCodexGearData
  if type(data) ~= "table" then return nil end
  local token, specKey = ccClassSpec(charData)
  if not token then return nil end
  local spec = data[token] and data[token][specKey]
  local primary = spec and spec.gems and spec.gems.primary
  if type(primary) == "table" and (primary.name or primary.itemId) then
    return primary.name, primary.itemId
  end
  return nil
end

---Recommended gem for a character (sockets take any gem, so it's not per-slot): prefers
---ClassCodex's per-spec primary gem, else the bundled secondary-stat gem for the top stat.
---Both are items (resolve a name via GetItemInfo). nil when neither source applies.
---@param charData Character
---@return EnchantSuggestion?
function ns.RecommendedGem(charData)
  local ccName, ccItem = classCodexGem(charData)
  if ccName or ccItem then return { kind = "item", id = ccItem, name = ccName } end
  local byStat = ns.Gems and ns.Gems.byStat
  if not byStat then return nil end
  local ranks = ns.StatRanks(charData)
  if not ranks then return nil end
  local stat = pickStat(ranks, byStat)
  if not stat then return nil end
  return { kind = "item", id = byStat[stat], stat = stat }
end

---Equipped slots with one or more empty gem sockets, in a stable slot order. Reads the
---data layer's stored `emptySockets` count (captured at scan time when the item is
---loaded), so it works for every scanned character — though a slot socketed since that
---character last logged in won't reflect until its next scan.
---@param charData Character
---@return { slot: string, link: string, sockets: integer }[]
function ns.MissingGems(charData)
  local slots = charData and charData.equipment and charData.equipment.slots
  if not slots then return {} end
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

---Recommended gem for a character as an `EnchantSuggestion` (an item — resolve a name from
---`.name`/`.id`), or nil. ClassCodex's per-spec gem when installed, else the bundled pick.
---@param charName string
---@return EnchantSuggestion?
function Upgrade:RecommendedGem(charName)
  return ns.RecommendedGem(API:GetCharacterData(charName))
end
