---@type Warbandeer_Characters
local ns = select(2, ...)
---@type WarbandeerAPI
local API = ns.api
local insert = table.insert
local C_Item = C_Item
local C_Bank = C_Bank
local C_Container = C_Container
local BankType = Enum.BankType
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

-- Accumulate one item into a [itemID] = BankGearEntry map, ignoring anything
-- that isn't profession gear.  count/quality come from the caller's bank API.
local function addItem(gear, itemID, count, quality)
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

-- Accumulate one slot's equippable gear (armour/weapon filling a real slot) into
-- a GearCandidate list, mirroring data/gearbag.lua so the bank's "held"/"better
-- elsewhere" gear shares the candidate shape.  Skips non-gear via the shared
-- classifier.  Bank slots carry the same hyperlink as bags do.
local function addEquip(equip, info, bagID, slot)
  if not info or not info.itemID then return end
  local equipLoc, classID, subClassID = API:ClassifyGearItem(info.itemID)
  if not equipLoc then return end
  local link = info.hyperlink
  insert(equip, {
    link = link,
    itemID = info.itemID,
    -- Effective (context-scaled) ilvl via the bank location, matching how
    -- equipped slots are measured (data/gearbag.lua carries the same note); the
    -- link's unscaled GetDetailedItemLevelInfo would over-report a downscaled item.
    ilvl = C_Item.GetCurrentItemLevel(ItemLocation:CreateFromBagAndSlot(bagID, slot)),
    equipLoc = equipLoc,
    classID = classID,
    subClassID = subClassID,
  })
end

-- ─── Warband (account) + character banks ─────────────────────────────────────
-- Both use the modern C_Bank tab model: FetchPurchasedBankTabIDs hands back the
-- container bag IDs, which C_Container reads slot-by-slot while the bank is open.

local function scanBankType(bankType)
  local gear, equip = {}, {}
  if not C_Bank.CanViewBank(bankType) then return toList(gear), equip end
  for _, bagID in ipairs(C_Bank.FetchPurchasedBankTabIDs(bankType) or {}) do
    for slot = 1, (C_Container.GetContainerNumSlots(bagID) or 0) do
      local info = C_Container.GetContainerItemInfo(bagID, slot)
      if info then
        addItem(gear, info.itemID, info.stackCount, info.quality)
        addEquip(equip, info, bagID, slot)
      end
    end
  end
  return toList(gear), equip
end

local function scanPersonalBanks()
  local b = store()
  local now = GetServerTime()
  local charGear, charEquip = scanBankType(BankType.Character)
  local wbGear, wbEquip = scanBankType(BankType.Account)
  b.characters[ns.currentPlayer] = { scannedAt = now, gear = charGear, equip = charEquip }
  b.warband = { scannedAt = now, gear = wbGear, equip = wbEquip }
end

local bankOpen = false
ns:registerEvent("BANKFRAME_OPENED", function()
  bankOpen = true
  scanPersonalBanks()
end)
ns:registerEvent("BANKFRAME_CLOSED", function()
  if bankOpen then scanPersonalBanks() end -- final capture before it closes
  bankOpen = false
end)
ns:registerEvent("PLAYERBANKSLOTS_CHANGED", function()
  if bankOpen then scanPersonalBanks() end
end)
ns:registerEvent("PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED", function()
  if bankOpen then scanPersonalBanks() end
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
  local gear = {}
  for tab = 1, (GetNumGuildBankTabs() or 0) do
    local _, _, isViewable = GetGuildBankTabInfo(tab)
    if isViewable then
      for slot = 1, GUILD_SLOTS_PER_TAB do
        local link = GetGuildBankItemLink(tab, slot)
        local itemID = link and tonumber(link:match("item:(%d+)"))
        if itemID then
          local _, count, _, _, quality = GetGuildBankItemInfo(tab, slot)
          addItem(gear, itemID, count, quality)
        end
      end
    end
  end
  store().guilds[key] = { scannedAt = GetServerTime(), gear = toList(gear) }
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

ns:registerCommand("dump", "bankgear", function(self)
  local b = ns.db.bank
  if not b then ns.Print("No bank gear scanned yet (open a bank)."); return end
  ns.Print("Bank profession gear:")
  local function show(label, data)
    if not data or not next(data.gear or {}) then return end
    print(label .. " (" .. #data.gear .. " kinds):")
    for _, entry in ipairs(data.gear) do
      local name = C_Item.GetItemInfo(entry.itemID)
      print("  " .. (name or entry.itemID) .. " x" .. entry.count
        .. " (skill " .. entry.skillID .. ")")
    end
  end
  show("Warband bank", b.warband)
  for charName, data in pairs(b.characters or {}) do show(charName .. "'s bank", data) end
  for guild, data in pairs(b.guilds or {}) do show(guild .. " guild bank", data) end
end, "Dump cached bank profession gear")
