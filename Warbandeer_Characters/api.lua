local _, ns = ...
local insert = table.insert

---@class WarbandeerAPI
local API = ns.api

function API:GetCurrentCharacter() return ns.currentPlayer end

---@class WarbandeerAPI
---@field GetCharacterData fun(string?): Character
function API:GetCharacterData(char)
  -- todo: return a copy so it is immutable
  return ns.db.characters[char or ns.currentPlayer]
end

function API:GetNumCharacters() return ns.db.numCharacters end
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

function API:GetAllianceCharacters()
  local c = {}
  for _,t in pairs(ns.db.characters) do
    if t.isAlliance then table.insert(c, t) end
  end
  return c
end

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
