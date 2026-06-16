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

---Recommended enchant for a slot: the enchanting recipe spellID to apply (its name
---resolves live via GetSpellInfo at the surface), plus the stat it was picked for on a
---variant slot. nil when the slot has no bundled recommendation, or a stat-variant
---slot whose character spec/priority is unknown (so we can't choose a variant). A
---`fixed` slot always returns its single recipe regardless of spec.
---@param charData Character
---@param slot string
---@return number? enchantID, string? stat
function ns.RecommendedEnchant(charData, slot)
  local rec = ns.Enchants[ENCHANT_KEY[slot] or slot]
  if not rec then return nil end
  if rec.fixed then return rec.fixed end
  if not rec.byStat then return nil end
  local ranks = ns.StatRanks(charData)
  if not ranks then return nil end
  local stat = pickStat(ranks, rec.byStat)
  if not stat then return nil end
  return rec.byStat[stat], stat
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

---Recommended enchant for a character's slot: the enchanting recipe spellID to apply
---(resolve its name with GetSpellInfo) and the stat it suits, or nil when no
---recommendation applies. Stat-variant slots are chosen from the character's spec
---priority, so this is character-specific; fixed slots return their single recipe.
---@param charName string
---@param slot string
---@return number? enchantID, string? stat
function Upgrade:RecommendedEnchant(charName, slot)
  return ns.RecommendedEnchant(API:GetCharacterData(charName), slot)
end
