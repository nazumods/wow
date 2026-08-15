---@type Warbandeer_Characters
local ns = select(2, ...)
local GetBuildInfo = GetBuildInfo
local RequestTimePlayed = RequestTimePlayed
local GetServerTime = GetServerTime
local date = date
local time = time

---@class Character
---@field playtime PlaytimeBroker?

---@class PlaytimeBroker
---@field total integer total /played in seconds
---@field byPatch table<string, integer> /played total at first login per WoW patch version
---@field byDay table<string, integer>? logged-in seconds per local calendar day ("YYYY-MM-DD")

---@class PlaytimeBroker: Broker
local Playtime = ns:RegisterBroker("playtime")

-- How often the live session's elapsed time is folded into the per-day buckets.
-- Bounds both crash-loss and midnight-split error to a single interval.
local ACCRUE_INTERVAL = 60 -- seconds

-- Suppress the CHAT_MSG_SYSTEM that fires alongside the automatic login query.
local suppressTimePlayed = false
ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(_, _, _)
  if suppressTimePlayed then suppressTimePlayed = false; return true end
end)

-- Split the interval [from, now] (server-epoch seconds) across LOCAL midnight
-- boundaries, adding each day's share to `byDay`. Keyed by local date so the
-- buckets line up with how a human reads "per day" (an evening session stays on
-- one day instead of splitting at UTC midnight). date() with no '!' is local.
---@param byDay table<string, integer>
---@param from integer
---@param now integer
local function accrue(byDay, from, now)
  while from < now do
    local lt = date("*t", from)
    local dayKey = date("%Y-%m-%d", from)
    -- Derive the next local midnight from the calendar, not a fixed +86400: on the two
    -- DST-transition days a year the local day is 23h/25h long, so a hard 86400 lands an
    -- hour off. Clear `isdst` (date() reports `from`'s DST state, which is wrong for the
    -- next day across a transition) so time() re-derives it for the target day and
    -- normalizes the day+1 overflow into the next month.
    lt.hour, lt.min, lt.sec, lt.day, lt.isdst = 0, 0, 0, lt.day + 1, nil
    local nextMidnight = time(lt)
    local chunkEnd = now < nextMidnight and now or nextMidnight
    byDay[dayKey] = (byDay[dayKey] or 0) + (chunkEnd - from)
    from = chunkEnd
  end
end

-- TIME_PLAYED_MSG is async; bypass the field system and handle it directly.
local parentInit = Playtime.Init
---@param toon Character
function Playtime:Init(toon)
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

  -- Per-day session accounting (wall-clock, which equals logged-in time — exactly
  -- what /played measures). The live session's elapsed time is folded into local-day
  -- buckets on a ticker, on logout, and at the next login, so a long or
  -- midnight-crossing session is attributed to the right day(s). Offline time is never
  -- counted: `anchor` resets to login-time here, so the gap since the previous
  -- session's final flush is simply dropped. The ticker bounds crash-loss (a hard
  -- crash skips PLAYER_LOGOUT) and keeps today's bucket fresh for a live view.
  if not toon.playtime.byDay then toon.playtime.byDay = {} end
  local anchor = GetServerTime()
  local function flush()
    local now = GetServerTime()
    if now > anchor then
      accrue(toon.playtime.byDay, anchor, now)
      anchor = now
    end
  end

  C_Timer.NewTicker(ACCRUE_INTERVAL, flush)
  ns:registerEvent("PLAYER_LOGOUT", flush)
end

-- Missing report: no total played captured (never queried since tracking) → "playtime";
-- captured but not stamped for the current client patch → "playtime (this patch)". Not a
-- broker field (playtime is filled via the async TIME_PLAYED_MSG), so it registers here.
local patch = select(1, GetBuildInfo())
ns:RegisterMissing{
  order = 20,
  name = "playtime",
  check = function(toon)
    if not toon.playtime or toon.playtime.total == nil then return "playtime" end
    if not toon.playtime.byPatch or toon.playtime.byPatch[patch] == nil then
      return "playtime (this patch)"
    end
  end,
}
