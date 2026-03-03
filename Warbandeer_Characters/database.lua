local _, ns = ...
local gsub = string.gsub
local Player = ns.wow.Player

ns:registerCommand("list", "", function(self)
  ns.Print("Characters:")
  for n,_ in pairs(ns.db.characters) do
    print(n)
  end
  ns.Print("done")
end, "List all characters")

ns:registerCommand("delete", "", function(self, args)
  ns.db.characters[args] = nil
  ns.db.numCharacters = ns.db.numCharacters - 1
  ns.Print(args .. " deleted.")
end, "Delete a character")

---@class Character
---@field name string
---@field classId string
---@field classKey string
---@field race string
---@field raceId string
---@field raceIdx integer
---@field isAlliance boolean
---@field realm string
---@field IsLegionTimerunner boolean

function ns:MigrateDB()
  if ns.db.version == 6 then return end
  local db = ns.db
  if not db.characters then db.characters = {} end
  if not db.numCharacters then
    local n = 0
    for _ in pairs(db.characters) do n = n + 1 end
    db.numCharacters = n
  end
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
  db.version = 6
end

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
  c.IsLegionTimerunner = PlayerIsTimerunning() and C_TimerunningUI.GetActiveTimerunningSeasonID() == 2

  self:InitBrokers()
end
