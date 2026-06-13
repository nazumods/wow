---@type Warbandeer_Characters
local ns = select(2, ...)
local insert = table.insert

---@class WarbandeerAPI
local API = ns.api

---Name of the currently logged-in character.
---@return string
function API:GetCurrentCharacter() return ns.currentPlayer end

---@class WarbandeerAPI
---@field GetCharacterData fun(string?): Character
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
