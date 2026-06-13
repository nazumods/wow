---@type Warbandeer_Characters
local ns = select(2, ...)
local gsub = string.gsub
local Player = ns.wow.Player
-- luacheck: globals UnitClassBase GetClassInfo
local UnitClassBase = UnitClassBase

---@class WarbandeerCharactersDB
---@field version integer
---@field characters table<string, Character> Character data indexed by character name
---@field numCharacters integer total number of characters
---@field warband WarbandData account-wide warband bank gold + weekly wealth tracking
---@field ui table account-wide UI preferences (e.g. wmissingFontSize)

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
  -- Cached bank gear lives in the account-wide store keyed by name, so prune it
  -- here too or it would orphan (it isn't part of the per-character struct).
  if ns.db.bank and ns.db.bank.characters then ns.db.bank.characters[args] = nil end
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
  -- Drop cached bank gear for characters no longer tracked (the account-wide
  -- bank store is keyed by name and isn't pruned when a character vanishes by
  -- means other than /wbc delete, e.g. a rename or a stale pre-existing entry).
  local banks = ns.db.bank and ns.db.bank.characters
  if banks then
    local orphans = 0
    for name in pairs(banks) do
      if not ns.db.characters[name] then banks[name] = nil; orphans = orphans + 1 end
    end
    if orphans > 0 then
      ns.Print("Removed bank gear for " .. orphans .. " untracked character(s).")
      fixed = fixed + 1
    end
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
  if db.version == 12 then return end
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
  if (db.version or 0) < 8 then
    if not db.warband then db.warband = { bankGold = 0, history = {} } end
    db.version = 8
  end

  -- v9: re-derive classKey from the locale-independent class token so that
  -- characters stored on non-English clients get the correct PascalCase key.
  -- Non-destructive: keeps the existing value if classId is absent or unknown.
  if (db.version or 0) < 9 then
    for _, c in pairs(db.characters) do
      if c.classId then
        local _, _, classFile = GetClassInfo(c.classId)
        if classFile then
          c.classKey = ns.wow.ClassKeyByToken[classFile] or c.classKey
        end
      end
    end
    db.version = 9
  end

  -- v10: account-wide recipe → profession-gear cache (non-destructive).  The
  -- build stamp is left empty so data/recipegear.lua re-stamps and fills it
  -- lazily against the live client build.
  if (db.version or 0) < 10 then
    if not db.recipeGear then db.recipeGear = { build = "", recipes = {} } end
    db.version = 10
  end

  -- v11: account-wide bank profession-gear cache (non-destructive), filled
  -- lazily by data/bank.lua whenever a warband/character/guild bank is opened.
  if (db.version or 0) < 11 then
    if not db.bank then db.bank = { characters = {}, guilds = {} } end
    db.version = 11
  end

  -- v12: account-wide UI preferences table (non-destructive), filled lazily by
  -- the views that own a preference (currently the /wbc wmissing font size).
  if (db.version or 0) < 12 then
    if not db.ui then db.ui = {} end
    db.version = 12
  end
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
    local _, classToken = UnitClassBase("player")
    c.classKey = ns.wow.ClassKeyByToken[classToken] or gsub(c.className, " ", "")
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
