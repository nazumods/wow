---@class ShadowsOfUI_Upgrade
local ns = select(2, ...)
---@type WarbandeerAPI
local API = ns.api               -- WarbandeerApi (data layer we read)
---@class ShadowsOfUI_UpgradeApi
local Upgrade = ns.UpgradeApi    -- ShadowsOfUI_UpgradeApi (what we publish)

-------------------------------------------------------------------------------
-- Empty gem sockets + recommended gem.
-------------------------------------------------------------------------------

-- Equipped slots scanned for empty sockets, in a stable top-down order. Any slot can
-- carry a socket, so this is the full set (vs the enchantable subset).
local GEM_ORDER = {
  "Head", "Neck", "Shoulder", "Back", "Chest", "Wrist", "Hands", "Waist",
  "Legs", "Feet", "Finger1", "Finger2", "Trinket1", "Trinket2", "MainHand", "OffHand",
}

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
  if ns.BelowMaxLevel(charData) then return nil, nil end     -- still levelling: don't gem yet
  local gems = ns.ClassCodexGems(charData)
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
    local stat = ranks and ns.PickStat(ranks, byStat)
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
  if not slots or ns.BelowMaxLevel(charData) then return {} end
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

---Equipped slots with empty gem sockets for a character (warband-wide from the stored
---socket count), each `{ slot, link, sockets }`. See ns.MissingGems for the freshness caveat.
---@param charName string
---@return { slot: string, link: string, sockets: integer }[]
function Upgrade:MissingGems(charName)
  return ns.MissingGems(API:GetCharacterData(charName))
end

---Recommended gems for a character: a `primary` (unique-equipped "diamond", socket one) and a
---`secondary` (fill the other sockets), each an `EnchantSuggestion` item (resolve a name from
---`.name`/`.id`) or nil. ClassCodex's per-spec pair when installed, else just the bundled secondary.
---@param charName string
---@return EnchantSuggestion? primary, EnchantSuggestion? secondary
function Upgrade:RecommendedGems(charName)
  return ns.RecommendedGems(API:GetCharacterData(charName))
end
