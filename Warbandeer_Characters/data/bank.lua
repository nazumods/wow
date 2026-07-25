---@type Warbandeer_Characters
local ns = select(2, ...)
---@type WarbandeerAPI
local API = ns.api
local insert = table.insert
local C_Item = C_Item
local C_Bank = C_Bank
local C_Container = C_Container
local BankType = Enum.BankType
local GetCurrentItemLevel = C_Item.GetCurrentItemLevel
local GetDetailedItemLevelInfo = C_Item.GetDetailedItemLevelInfo
local GetItemInfo = C_Item.GetItemInfo
local RequestLoadItemData = C_Item.RequestLoadItemData

-- Bank slots whose item data wasn't loaded during the in-progress scan (collected by
-- addEquip; consumed by scanPersonalBanks to request a load + re-scan). nil between scans.
local cold
-- Guild bank (the classic, non-C_Bank API):

-- Account-wide cache of profession gear sitting in banks, so the prof-gear
-- tooltip can tell you where an empty slot could be filled from.  Bank contents
-- are only readable client-side while the relevant frame is open, so each bank
-- is scanned on open / slot-change and cached (last-seen model, consistent with
-- the rest of the addon).  We keep only profession gear, which makes the cache
-- tiny.  Three banks, all under db.bank:
--   * warband (account) bank — shared across the account, stored once
--   * character banks         — per character, keyed by name
--   * guild banks             — shared per guild, keyed by guild (a single
--                               account can see several across its characters)

local GUILD_SLOTS_PER_TAB = MAX_GUILDBANK_SLOTS_PER_TAB or 98

---@class BankGearEntry
---@field itemID integer
---@field skillID integer parent skillLineID the gear is for
---@field equipLoc string INVTYPE_PROFESSION_TOOL | INVTYPE_PROFESSION_GEAR
---@field rarity integer Enum.ItemQuality
---@field count integer total quantity in this bank

---@class BankGearStore
---@field scannedAt integer server time of the last scan
---@field gear BankGearEntry[]
---@field equip GearCandidate[]? equippable gear (warband + personal banks only)
---@field items table<integer, integer>? itemID -> total count of every item in this bank (drives the warband-stock tooltip)

---@class BankData
---@field warband BankGearStore? account-wide warband bank
---@field characters table<string, BankGearStore> per-character personal banks
---@field guilds table<string, BankGearStore> guild banks, keyed by guild name (-realm if cross-realm)

---@class WarbandeerCharactersDB
---@field bank BankData

local function store()
  local db = ns.db
  if not db.bank then db.bank = {characters = {}, guilds = {}} end
  local b = db.bank
  b.characters = b.characters or {}
  b.guilds = b.guilds or {}
  return b
end

-- An item's display name out of its link.  Crafted profession gear carries its
-- quality-tier atlas *inside* the link's brackets ("[Toolbox |A:…Tier3…|a]"), which
-- would become the name's trailing word and break consumers that key a gear line on
-- it — so inline escapes are stripped and the result trimmed.
local function linkName(link)
  local n = link and link:match("%[(.-)%]")
  if not n then return nil end
  n = n:gsub("|A.-|a", ""):gsub("|T.-|t", "")
  n = n:match("^%s*(.-)%s*$")
  return n ~= "" and n or nil
end

-- Accumulate one item into a [itemID] = BankGearEntry map, ignoring anything
-- that isn't profession gear.  count/quality come from the caller's bank API.
local function addItem(gear, itemID, count, quality, link)
  if not itemID then return end
  local skillID, equipLoc = API:ClassifyProfGearItem(itemID)
  if not skillID then return end
  local entry = gear[itemID]
  if not entry then
    entry = {
      itemID   = itemID,
      skillID  = skillID,
      equipLoc = equipLoc,
      rarity   = quality or C_Item.GetItemQualityByID(itemID) or 1,
      count    = 0,
      -- Consumers key a gear line by the name's last word, which can't be recovered
      -- from the id alone offline.  GetItemInfo gives the clean name but needs the
      -- item cache warm; the slot's own link is always present, so it backstops a
      -- cold first scan (via linkName, which strips the crafted-quality atlas).
      name     = C_Item.GetItemInfo(itemID) or linkName(link) or nil,
    }
    gear[itemID] = entry
  end
  entry.count = entry.count + (count or 1)
end

local function toList(gear)
  local list = {}
  for _, entry in pairs(gear) do insert(list, entry) end
  return list
end

-- Accumulate one slot into a full itemID -> count map (everything, not just prof
-- gear), so the warband-stock tooltip can report total copies held in this bank.
local function addCount(counts, itemID, count)
  if not itemID then return end
  counts[itemID] = (counts[itemID] or 0) + (count or 1)
end

-- Accumulate one slot's equippable gear (armour/weapon filling a real slot) into
-- a GearCandidate list, mirroring data/gearbag.lua so the bank's "held"/"better
-- elsewhere" gear shares the candidate shape.  Skips non-gear via the shared
-- classifier.  Bank slots carry the same hyperlink as bags do.
local function addEquip(equip, info, bagID, slot)
  if not info or not info.itemID then return end
  local equipLoc, classID, subClassID = API:ClassifyGearItem(info.itemID)
  if not equipLoc then return end
  local link = info.hyperlink
  -- Effective (context-scaled) ilvl via the bank location, matching how equipped slots
  -- are measured (data/gearbag.lua carries the same note). It needs the item loaded,
  -- though, and a fresh bank-open scan reads many slots cold → nil. A nil ilvl makes the
  -- upgrade finder drop the candidate, so a worse but already-loaded piece gets
  -- recommended first; fall back to the link's unscaled ilvl so it still ranks, and flag
  -- the slot so scanPersonalBanks requests a load + re-scan for the exact scaled value.
  local loc = ItemLocation:CreateFromBagAndSlot(bagID, slot)
  local ilvl = GetCurrentItemLevel(loc)
  if not ilvl then
    ilvl = link and GetDetailedItemLevelInfo(link) or nil
    if cold then cold[#cold + 1] = loc end
  end
  insert(equip, {
    link = link,
    itemID = info.itemID,
    ilvl = ilvl,
    equipLoc = equipLoc,
    classID = classID,
    subClassID = subClassID,
    -- Captured now (item warm in the open bank), so the upgrade finder's artifact gate
    -- fires for this candidate even when later read for an offline alt with the item cold.
    quality = info.quality,
    -- Required level (static per-item), captured warm so a consumer's "can equip now?"
    -- gate doesn't fall back to a cold live lookup when read for an offline alt.
    reqLevel = link and (select(5, GetItemInfo(link))) or nil,
  })
end

-- ─── Warband (account) + character banks ─────────────────────────────────────
-- Both use the modern C_Bank tab model: FetchPurchasedBankTabIDs hands back the
-- container bag IDs, which C_Container reads slot-by-slot while the bank is open.

local function scanBankType(bankType)
  local gear, equip, counts = {}, {}, {}
  if not C_Bank.CanViewBank(bankType) then return toList(gear), equip, counts end
  for _, bagID in ipairs(C_Bank.FetchPurchasedBankTabIDs(bankType) or {}) do
    for slot = 1, (C_Container.GetContainerNumSlots(bagID) or 0) do
      local info = C_Container.GetContainerItemInfo(bagID, slot)
      if info then
        addItem(gear, info.itemID, info.stackCount, info.quality, info.hyperlink)
        addEquip(equip, info, bagID, slot)
        addCount(counts, info.itemID, info.stackCount)
      end
    end
  end
  return toList(gear), equip, counts
end

-- Scan both personal banks; returns true if any slot was still cold (so a re-scan is
-- worthwhile once its data loads). Requests a load for every cold slot before returning.
local function scanPersonalBanks()
  local b = store()
  local now = GetServerTime()
  cold = {}
  local charGear, charEquip, charCounts = scanBankType(BankType.Character)
  local wbGear, wbEquip, wbCounts = scanBankType(BankType.Account)
  b.characters[ns.currentPlayer] = { scannedAt = now, gear = charGear, equip = charEquip, items = charCounts }
  b.warband = { scannedAt = now, gear = wbGear, equip = wbEquip, items = wbCounts }
  local pending = cold
  cold = nil
  for _, loc in ipairs(pending) do RequestLoadItemData(loc) end
  return #pending > 0
end

local bankOpen = false

local BANK_RESCAN_DELAY = 800 -- ms; outlasts a typical item-data load
local MAX_BANK_RESCANS = 5
local bankRescanGen = 0

-- A fresh bank-open scan reads cold (unloaded) slots as nil ilvl; once their data is
-- requested, re-scan a few times until it's all loaded — so the upgrade finder ranks
-- every piece by its real ilvl, not whichever happened to be cached first. Generation-
-- guarded (a newer scan supersedes an in-flight chain), attempt-capped (a never-loading
-- item can't loop forever), gated on the bank still being open. Mirrors data/equipment.lua.
local function scheduleBankRescan()
  bankRescanGen = bankRescanGen + 1
  local gen, attempt = bankRescanGen, 0
  local function tick()
    if gen ~= bankRescanGen or not bankOpen then return end
    attempt = attempt + 1
    if scanPersonalBanks() and attempt < MAX_BANK_RESCANS then ns:after(BANK_RESCAN_DELAY, tick) end
  end
  ns:after(BANK_RESCAN_DELAY, tick)
end

local function refreshBanks()
  if scanPersonalBanks() then scheduleBankRescan() end
end

ns:registerEvent("BANKFRAME_OPENED", function()
  bankOpen = true
  refreshBanks()
end)
ns:registerEvent("BANKFRAME_CLOSED", function()
  if bankOpen then scanPersonalBanks() end -- final capture before it closes
  bankOpen = false
end)
ns:registerEvent("PLAYERBANKSLOTS_CHANGED", function()
  if bankOpen then refreshBanks() end
end)
ns:registerEvent("PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED", function()
  if bankOpen then refreshBanks() end
end)

-- ─── Guild bank ──────────────────────────────────────────────────────────────
-- The guild bank predates C_Bank and keeps its own classic API.  Unlike the
-- personal banks, tab contents aren't available until queried, so each tab is
-- requested on open and folded in as GUILDBANKBAGSLOTS_CHANGED reports it.

-- Stable key for the player's current guild; appends the realm only when it
-- differs from the player's, so same-realm guilds read cleanly.
local function currentGuildKey()
  local name, _, _, realm = GetGuildInfo("player")
  if not name then return nil end
  return realm and (name .. "-" .. realm) or name
end

local function scanGuildBank()
  local key = currentGuildKey()
  if not key then return end
  local gear, counts = {}, {}
  for tab = 1, (GetNumGuildBankTabs() or 0) do
    local _, _, isViewable = GetGuildBankTabInfo(tab)
    if isViewable then
      for slot = 1, GUILD_SLOTS_PER_TAB do
        local link = GetGuildBankItemLink(tab, slot)
        local itemID = link and tonumber(link:match("item:(%d+)"))
        if itemID then
          local _, count, _, _, quality = GetGuildBankItemInfo(tab, slot)
          addItem(gear, itemID, count, quality, link)
          addCount(counts, itemID, count)
        end
      end
    end
  end
  store().guilds[key] = { scannedAt = GetServerTime(), gear = toList(gear), items = counts }
end

-- Request item data for every tab so a subsequent scan sees populated slots.
-- QueryGuildBankTab switches the viewed tab as a side effect, so the player's
-- current tab is restored afterwards to avoid disrupting them.
local function queryAllGuildTabs()
  local numTabs = GetNumGuildBankTabs() or 0
  if numTabs == 0 then return end
  local current = GetCurrentGuildBankTab()
  for tab = 1, numTabs do QueryGuildBankTab(tab) end
  if current and current > 0 then SetCurrentGuildBankTab(current) end
end

local guildBankOpen = false
ns:registerEvent("GUILDBANKFRAME_OPENED", function()
  guildBankOpen = true
  queryAllGuildTabs()
  scanGuildBank()
end)
ns:registerEvent("GUILDBANKFRAME_CLOSED", function() guildBankOpen = false end)
ns:registerEvent("GUILDBANKBAGSLOTS_CHANGED", function()
  if guildBankOpen then scanGuildBank() end
end)

-- ─── Query API ───────────────────────────────────────────────────────────────

---@class ProfGear
---@field itemID integer
---@field equipLoc string
---@field rarity integer
---@field count integer
---@field name string? item name captured at bank-scan time; the slot's link backstops a cold item cache (atlas markup stripped — see `linkName`)
---@field source string
---@field sourceType string

---@class WarbandeerAPI
---@field GetBankProfGear fun(self: WarbandeerAPI, skillID: integer): ProfGear[]
---Profession-gear items for a profession cached across every bank the account
---has opened — warband bank, each character's bank, and each guild bank.  Each
---returned entry is tagged with a human-readable `source` and a `sourceType`
---("warband" | "character" | "guild").  Empty until a bank has been opened.
---@param skillID integer parent skillLineID
---@return ProfGear[]
function API:GetBankProfGear(skillID)
  local out = {}
  local b = ns.db.bank
  if not b then return out end
  local function collect(data, source, sourceType)
    for _, entry in ipairs(data and data.gear or {}) do
      if entry.skillID == skillID then
        insert(out, {
          itemID   = entry.itemID,
          equipLoc = entry.equipLoc,
          rarity   = entry.rarity,
          count    = entry.count,
          name     = entry.name,
          source   = source,
          sourceType = sourceType,
        })
      end
    end
  end
  collect(b.warband, "the warband bank", "warband")
  for name, data in pairs(b.characters or {}) do collect(data, name .. "'s bank", "character") end
  for _, data in pairs(b.guilds or {}) do collect(data, "the guild bank", "guild") end
  return out
end

ns:registerDump("bankgear", "Bank Profession Gear", "Dump cached bank profession gear", function(_, out)
  local b = ns.db.bank
  if not b then out:line("No bank gear scanned yet (open a bank)."); return end
  out:line("Bank profession gear:")
  local function show(label, data)
    if not data or not next(data.gear or {}) then return end
    out:line(label .. " (" .. #data.gear .. " kinds):")
    for _, entry in ipairs(data.gear) do
      local name = C_Item.GetItemInfo(entry.itemID)
      out:line("  " .. (name or entry.itemID) .. " x" .. entry.count
        .. " (skill " .. entry.skillID .. ")")
    end
  end
  show("Warband bank", b.warband)
  for charName, data in pairs(b.characters or {}) do show(charName .. "'s bank", data) end
  for guild, data in pairs(b.guilds or {}) do show(guild .. " guild bank", data) end
end)

-- Missing report: a character's bank is scanned only when it opens one (the store stamps a
-- record even for an empty bank), so no entry under db.bank.characters means "never scanned".
-- Account-wide cache, not a per-character broker field, so it registers here.
ns:RegisterMissing{
  order = 60,
  check = function(toon)
    local banks = ns.db.bank and ns.db.bank.characters
    if not (banks and banks[toon.name]) then return "bank contents" end
  end,
}
