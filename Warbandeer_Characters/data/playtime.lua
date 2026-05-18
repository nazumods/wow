local _, ns = ...
local GetBuildInfo = GetBuildInfo -- luacheck: globals GetBuildInfo
local RequestTimePlayed = RequestTimePlayed -- luacheck: globals RequestTimePlayed

---@class Character
---@field playtime PlaytimeBroker

---@class PlaytimeBroker
---@field total integer total /played in seconds
---@field byPatch table<string, integer> /played total at first login per WoW patch version

ns.Playtime = ns:RegisterBroker("playtime")

-- TIME_PLAYED_MSG is async; bypass the field system and handle it directly.
local parentInit = ns.Playtime.Init
function ns.Playtime:Init(toon)
  parentInit(self, toon) -- creates toon.playtime = {} and self.fieldOrder = {}

  local patch = select(1, GetBuildInfo())

  ns:registerEvent("TIME_PLAYED_MSG", function(_, totalTime)
    toon.playtime.total = totalTime
    if not toon.playtime.byPatch then toon.playtime.byPatch = {} end
    if not toon.playtime.byPatch[patch] then
      toon.playtime.byPatch[patch] = totalTime
    end
  end)

  RequestTimePlayed()
end
