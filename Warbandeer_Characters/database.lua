---@type Warbandeer_Characters
local ns = select(2, ...)
local gsub = string.gsub
local Player = ns.wow.Player

---@class WarbandeerCharactersDB
---@field version integer
---@field characters table<string, Character> Character data indexed by character name
---@field numCharacters integer total number of characters
---@field warband WarbandData account-wide warband bank gold + weekly wealth tracking

---@class Warbandeer_Characters
---@field db WarbandeerCharactersDB

local function countCharacters(db)
  local n = 0
  for _ in pairs(db.characters) do n = n + 1 end
  return n
end

ns:registerCommand("list", "", function(self)
  ns.Print("Characters:")
  for n,_ in pairs(ns.db.characters) do
    print(n)
  end
  ns.Print("done")
end, "List all characters")

ns:registerCommand("delete", "", function(self, args)
  if not ns.db.characters[args] then
    ns.Print(args .. " not found. Use /wbc list for exact names (case-sensitive).")
    return
  end
  ns.db.characters[args] = nil
  ns.db.numCharacters = ns.db.numCharacters - 1
  ns.Print(args .. " deleted.")
end, "Delete a character")

-- Explicit, user-invoked repair of stored data (per the DB-compat convention,
-- cleanup never runs automatically). Currently: recount numCharacters, which
-- pre-#47 deletes could skew by decrementing on names that didn't exist.
ns:registerCommand("cleanup", "", function(self)
  local fixed = 0
  local n = countCharacters(ns.db)
  if ns.db.numCharacters ~= n then
    ns.Print("numCharacters corrected: " .. tostring(ns.db.numCharacters) .. " -> " .. n)
    ns.db.numCharacters = n
    fixed = fixed + 1
  end
  if fixed == 0 then ns.Print("Nothing to clean.") end
end, "Repair stored data (recount characters)")

---@class Character
---@field name string
---@field classId string
---@field classKey string
---@field race string
---@field raceId string
---@field raceIdx integer
---@field isAlliance boolean
---@field realm string

---@class Warbandeer_Characters
---@field MigrateDB fun(self) Migrate database to latest version
function ns:MigrateDB()
  local db = ns.db
  if db.version == 8 then return end
  if not db.characters then db.characters = {} end
  if not db.numCharacters then
    db.numCharacters = countCharacters(db)
  end
  if (db.version or 0) < 7 then
  for _,c in pairs(db.characters) do
    if not c.basic then
      c.basic = {
        level = c.level,
        specialization = {
          primary = c.specialization,
          active = c.specializationActive,
          role = c.role,
        },
        professions = {
          primary = c.prof1,
          secondary = c.prof2,
          fishing = c.fishing,
          cooking = c.cooking,
        },
      }
    end
    if not c.basic.level then c.basic.level = 1 end
    if not c.instances then
      c.instances = { locks = c.locks or {} }
    end
    c.level = nil
    c.locks = nil
    c.specialization = nil
    c.specializationActive = nil
    c.role = nil
    c.prof1 = nil
    c.prof2 = nil
    c.fishing = nil
    c.cooking = nil
  end
  db.version = 7
  end

  -- v8: account-wide warband bank gold + weekly wealth tracking (non-destructive)
  if not db.warband then db.warband = { bankGold = 0, history = {} } end
  db.version = 8
end

---@class Warbandeer_Characters
---@field currentPlayer string Name of currently active character
---@field currentData Character Data for currently active character

---@class Warbandeer_Characters
---@field initialize fun(self) Initialize character data for the current player and set up brokers
function ns:initialize()
  self.currentPlayer = Player:GetName()
  local c = self.db.characters[self.currentPlayer]
  if not c then
    -- initialize new character
    c = {}
    self.db.characters[self.currentPlayer] = c
    self.db.numCharacters = self.db.numCharacters + 1
    c.name = self.currentPlayer
    c.classId = Player:GetClassId()
    c.className = Player:GetClassName()
    c.classKey = gsub(c.className, " ", "")
    local raceFile, raceId = Player:GetRace()
    c.race = raceFile
    c.raceId = raceId
    local raceIndex, isAlliance = ns.NormalizeRaceId(raceId)
    c.raceIdx = raceIndex
    c.isAlliance = isAlliance
    c.realm = GetRealmName()
  end
  self.currentData = c

  self:InitBrokers()
  self:InitWarband()
end
