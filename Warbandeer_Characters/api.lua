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
