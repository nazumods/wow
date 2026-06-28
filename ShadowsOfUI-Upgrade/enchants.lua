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

---Equipped slots that should carry a permanent enchant but don't, in a stable slot
---order.  Reads only the stored item link (the enchant id is encoded in it), so it
---works warband-wide for every character — not just the one logged in.
---@param charData Character
---@return { slot: string, link: string }[]
function ns.MissingEnchants(charData)
  local slots = charData and charData.equipment and charData.equipment.slots
  if not slots or ns.BelowMaxLevel(charData) then return {} end
  local out = {}
  for _, slot in ipairs(ENCHANT_ORDER) do
    local item = slots[slot]
    if item and item.link and slotTakesEnchant(slot, item)
       and not ns.BelowEnchantMinIlvl(item) and ns.ItemEnchantID(item.link) == 0 then
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

---Recommended enchant for a slot. Prefers ClassCodex's per-spec pick (OptionalDep, read
---live) and falls back to the bundled stat-derived recipe: a `fixed` slot's single recipe,
---or the `byStat` variant for the character's top secondary stat. nil when neither source
---has one (or a stat-variant slot whose character spec/priority is unknown), and nil when
---the equipped item is below the slot enchant's minimum item level (can't be enchanted).
---@param charData Character
---@param slot string
---@return EnchantSuggestion?
function ns.RecommendedEnchant(charData, slot)
  if ns.BelowMaxLevel(charData) then return nil end        -- still levelling: don't enchant yet
  local slots = charData and charData.equipment and charData.equipment.slots
  local item = slots and slots[slot]
  if item and ns.BelowEnchantMinIlvl(item) then return nil end  -- item too low to enchant

  local ccName, ccItem = ns.ClassCodexEnchant(charData, slot)
  if ccName or ccItem then return { kind = "item", id = ccItem, name = ccName } end

  local rec = ns.Enchants[ENCHANT_KEY[slot] or slot]
  if not rec then return nil end
  if rec.fixed then return { kind = "spell", id = rec.fixed } end
  if not rec.byStat then return nil end
  local ranks = ns.StatRanks(charData)
  if not ranks then return nil end
  local stat = ns.PickStat(ranks, rec.byStat)
  if not stat then return nil end
  return { kind = "spell", id = rec.byStat[stat], stat = stat }
end

-------------------------------------------------------------------------------
-- Wrong (not missing) enchant detection.
-------------------------------------------------------------------------------

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
    -- The scroll's stat ("Use:") line only appears in the tooltip once the item is cached;
    -- before that GetItemByID returns just its name/quality, which `statLineMatches` would
    -- read as a stat mismatch and wrongly flag a *correct* spellthread (#236). Treat an
    -- uncached item as "can't judge" (return nil) and kick off a load so the next render
    -- resolves it — matching the observed "refresh twice and it clears" behaviour.
    local Item = _G.C_Item
    if Item and Item.IsItemDataCachedByID and not Item.IsItemDataCachedByID(rec.id) then
      if Item.RequestLoadItemDataByID then Item.RequestLoadItemDataByID(rec.id) end
      return nil
    end
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
  if not slots or ns.BelowMaxLevel(charData) then return {} end
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
