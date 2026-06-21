---@type Warbandeer_Characters
local ns = select(2, ...)
local insert = table.insert
local sort = table.sort
local GetServerTime = GetServerTime

---@class WarbandeerAPI
local API = ns.api

---Name of the currently logged-in character.
---@return string
function API:GetCurrentCharacter() return ns.currentPlayer end

---@param char? string
---@return Character
function API:GetCharacterData(char)
  -- todo: return a copy so it is immutable
  return ns.db.characters[char or ns.currentPlayer]
end

---Total number of tracked characters.
---@return integer
function API:GetNumCharacters() return ns.db.numCharacters end
---Number of tracked characters at the level cap.
---@return integer
function API:GetNumMaxLevel()
  local n = 0
  for _,c in pairs(ns.db.characters) do
    if c.basic.level == ns.wow.maxLevel then n = n + 1 end
  end
  return n
end

---@class WarbandeerAPI
---@field GetAllCharacters fun(): Character[]
function API:GetAllCharacters()
  local list = {}
  for _,c in pairs(ns.db.characters) do insert(list, c) end
  return list
end

---All tracked Alliance characters (unordered).
---@return Character[]
function API:GetAllianceCharacters()
  local c = {}
  for _,t in pairs(ns.db.characters) do
    if t.isAlliance then table.insert(c, t) end
  end
  return c
end

---All tracked Horde characters (unordered).
---@return Character[]
function API:GetHordeCharacters()
  local c = {}
  for _,t in pairs(ns.db.characters) do
    if not t.isAlliance then table.insert(c, t) end
  end
  return c
end

---Warband (account) bank gold, in copper.
---@return integer
function API:GetWarbandBankGold() return (ns.db.warband and ns.db.warband.bankGold) or 0 end

---Total warband wealth (copper): warband bank + last-known gold of every character.
---@return integer
function API:GetWarbandWealth() return ns:GetWarbandWealth() end

---Gold made for the warband so far this week (copper): current wealth minus the
---week's baseline. May be negative if net wealth has dropped.
---@return integer
function API:GetWeeklyGoldMade()
  local w = ns.db.warband
  if not w or not w.week then return 0 end
  return ns:GetWarbandWealth() - w.week.baseline
end

---Closed-week wealth history (oldest first).
---@return WarbandWeekRecord[]
function API:GetWealthHistory() return (ns.db.warband and ns.db.warband.history) or {} end

---Equippable gear a character has loose in its own bags + personal bank.  Bags
---come from the per-character `gearbag` broker; the bank list is the last scan of
---that character's personal bank (empty until they've opened it).  Both lists are
---last-seen caches and may be empty.
---@param charName string?
---@return { bags: GearCandidate[], bank: GearCandidate[] }
function API:GetCharacterGearCandidates(charName)
  local name = charName or ns.currentPlayer
  local c = ns.db.characters[name]
  local bank = ns.db.bank and ns.db.bank.characters and ns.db.bank.characters[name]
  return {
    bags = (c and c.gearbag and c.gearbag.items) or {},
    bank = (bank and bank.equip) or {},
  }
end

---Equippable gear sitting in the warband (account) bank.  Last-seen; empty until
---the warband bank has been opened.
---@return GearCandidate[]
function API:GetWarbandBankGear()
  return (ns.db.bank and ns.db.bank.warband and ns.db.bank.warband.equip) or {}
end

---Active world-quest gear rewards cached for a character that could upgrade an
---equipped slot.  Captured while that character was logged in (world-quest reward
---data isn't readable for alts), last-seen.  Expired quests are dropped here on
---read, since an alt's cache can't be refreshed live.  Each entry is a
---GearCandidate plus `questID`, `title`, `zone`, `endTime`.
---@param charName string?
---@return WorldQuestReward[]
function API:GetWorldQuestRewards(charName)
  local c = ns.db.characters[charName or ns.currentPlayer]
  local list = c and c.worldquests and c.worldquests.rewards
  if not list then return {} end
  local now = GetServerTime()
  local out = {}
  for _, r in ipairs(list) do
    if not r.endTime or r.endTime > now then insert(out, r) end
  end
  return out
end

---@class ItemCountEntry
---@field name string character name
---@field classKey string PascalCase class key (for class colouring)
---@field realm string? the character's realm, set only when it differs from the current character's realm
---@field bags integer copies in the character's bags + reagent bag
---@field bank integer copies in the character's personal bank
---@field total integer bags + bank

---@class GuildItemCount
---@field name string guild key (name, -realm if cross-realm)
---@field count integer copies in that guild bank

---@class ItemCountReport
---@field total integer grand total across every source
---@field warband integer copies in the shared warband (account) bank, counted once
---@field characters ItemCountEntry[] per-character (bags + personal bank), sorted by total desc
---@field guilds GuildItemCount[] per-guild bank, sorted by count desc

---Account-wide counts of an item across every tracked character's bags + personal
---bank, the shared warband bank, and each known guild bank.  Bag counts are live for
---the logged-in character and last-seen for alts (a character's bag map only updates
---while it's logged in); bank/guild counts are last-seen, captured when that bank was
---last opened.  Returns nil when no copies are tracked anywhere.
---@param itemID integer
---@return ItemCountReport?
function API:GetItemCounts(itemID)
  if not itemID then return nil end
  local bankStore = ns.db.bank
  local charBanks = (bankStore and bankStore.characters) or {}
  local myRealm = ns.currentData and ns.currentData.realm
  local chars, total = {}, 0
  for name, c in pairs(ns.db.characters) do
    local bags = (c.inventory and c.inventory.counts and c.inventory.counts[itemID]) or 0
    local bankData = charBanks[name]
    local bank = (bankData and bankData.items and bankData.items[itemID]) or 0
    local sum = bags + bank
    if sum > 0 then
      insert(chars, {
        name = name,
        classKey = c.classKey,
        realm = (c.realm and c.realm ~= myRealm) and c.realm or nil,
        bags = bags, bank = bank, total = sum,
      })
      total = total + sum
    end
  end
  local warband = (bankStore and bankStore.warband and bankStore.warband.items and bankStore.warband.items[itemID]) or 0
  total = total + warband
  local guilds = {}
  for gname, g in pairs((bankStore and bankStore.guilds) or {}) do
    local n = g.items and g.items[itemID]
    if n and n > 0 then
      insert(guilds, { name = gname, count = n })
      total = total + n
    end
  end
  if total == 0 then return nil end
  sort(chars, function(a, b)
    if a.total ~= b.total then return a.total > b.total end
    return a.name < b.name
  end)
  sort(guilds, function(a, b)
    if a.count ~= b.count then return a.count > b.count end
    return a.name < b.name
  end)
  return { total = total, warband = warband, characters = chars, guilds = guilds }
end

---Synchronously re-fetch one broker field for the current character.
---Safe to call at any time; respects the maxLevel guard.
---@param brokerName string
---@param fieldName string
function API:RefreshCurrentCharacterField(brokerName, fieldName)
  local toon = ns.currentData
  if not toon then return end
  local broker = ns.brokers[brokerName]
  if not broker then return end
  local field = broker.fields[fieldName]
  if not field then return end
  if not (field.maxLevel and toon.basic.level < ns.wow.maxLevel) then
    toon[brokerName][fieldName] = field:get(toon, toon[brokerName][fieldName])
  end
end
