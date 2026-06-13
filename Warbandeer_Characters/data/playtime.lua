---@type Warbandeer_Characters
local ns = select(2, ...)
local GetBuildInfo = GetBuildInfo
local RequestTimePlayed = RequestTimePlayed

---@class Character
---@field playtime PlaytimeBroker

---@class PlaytimeBroker
---@field total integer total /played in seconds
---@field byPatch table<string, integer> /played total at first login per WoW patch version

ns.Playtime = ns:RegisterBroker("playtime")

-- Suppress the CHAT_MSG_SYSTEM that fires alongside the automatic login query.
local suppressTimePlayed = false
ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(_, _, _)
  if suppressTimePlayed then suppressTimePlayed = false; return true end
end)

-- TIME_PLAYED_MSG is async; bypass the field system and handle it directly.
local parentInit = ns.Playtime.Init
---@param toon Character
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

  suppressTimePlayed = true
  RequestTimePlayed()
end
