---@type Warbandeer_Characters
local ns = select(2, ...)
local insert, remove = table.insert, table.remove
local floor = math.floor
local GetServerTime = GetServerTime
local GetInstanceInfo = GetInstanceInfo

-- Personal Mythic+ completion-time tracker.  Structurally mirrors data/delvetimes.lua, but keyed on
-- keystone level instead of delve tier and driven by the clean CHALLENGE_MODE_START → _COMPLETED
-- pair (M+ exposes an authoritative start event, unlike delves' SCENARIO_UPDATE proxy).  Only keyed
-- runs are timed here; normal/heroic dungeons have no start/completion event and are tracked
-- separately (see issue: normal/heroic dungeon run timing).  XP capture rides along via the shared
-- ns.StartRunXP/FinishRunXP helpers (moot at max level, where all M+ is played, so it stays nil in
-- practice — the field is present for structural parity with delve runs).

local KEEP = 10 -- rolling window: only the most recent N durations per dungeon+level are kept

---@class DungeonRuns
---@field name string canonical dungeon name (most recently seen)
---@field tiers table<integer, integer[]> keystone level (0 = unknown) -> recent durations in seconds
---@field xps table<integer, integer[]>? keystone level -> recent XP gains (leveling runs only)

---@class DungeonTimes
---@field active { key: string, name: string, level: integer, start: integer, xp: RunXP? }? in-progress run
---@field runs table<string, DungeonRuns> normalized dungeon key -> recorded runs

---@class Character
---@field dungeonTimes DungeonTimes?

-- (Lazily create and) return the current character's dungeonTimes store.
local function store()
  local toon = ns.currentData
  if not toon then return nil end
  local dt = toon.dungeonTimes
  if not dt then dt = { runs = {} }; toon.dungeonTimes = dt end
  if not dt.runs then dt.runs = {} end
  return dt
end

-- Whether the player is currently inside an active keystone run.
local function inMythicPlus()
  return (C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive()) or false
end

-- The current dungeon's display name.  Uses the instance name (falling back to the player's map
-- name), matching the name a consumer would look up — normalized the same way as delve keys.
local function dungeonName()
  local name = GetInstanceInfo()
  if name and name ~= "" then return name end
  local mapID = C_Map.GetBestMapForUnit("player")
  local info = mapID and C_Map.GetMapInfo(mapID)
  return info and info.name
end

-- Active keystone level (0 = unknown bucket, so the run is still recorded).
local function readLevel()
  local getInfo = C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo
  local level = getInfo and getInfo()
  return level or 0
end

-- CHALLENGE_MODE_START: the authoritative run start, fired when the timer begins (after the
-- countdown).  Always (re)stamp the start here so the countdown isn't counted.  This event does
-- NOT re-fire on a mid-run /reload, so the persisted start (dt.active, in WarbandeerCharDB) is what
-- survives — refreshActive below only resumes/discards, never restarts the clock.
local function beginRun()
  local dt = store()
  if not dt then return end
  local name = dungeonName()
  local key = ns.NormalizeDelveKey(name)
  if not key then return end -- instance data not ready; a later PLAYER_ENTERING_WORLD refreshes it
  dt.active = { key = key, name = name, level = readLevel(), start = GetServerTime(), xp = ns.StartRunXP() }
end

-- PLAYER_ENTERING_WORLD: resume an in-progress run after a /reload (keep its persisted start,
-- refresh a not-yet-known name/level), or discard the timer once we're no longer in a keyed run.
-- A run whose CHALLENGE_MODE_START we never saw (addon enabled mid-run) is intentionally not begun
-- here — timing it from this point would log a partial run at full weight and skew the average.
local function refreshActive()
  local dt = store()
  if not dt then return end
  if inMythicPlus() then
    local a = dt.active
    if not a then return end
    local name = dungeonName()
    if name and name ~= "" then a.name = name; a.key = ns.NormalizeDelveKey(name) or a.key end
    local level = readLevel()
    if level > 0 then a.level = level end
  elseif dt.active then
    dt.active = nil -- left the dungeon without completing it; discard
  end
end

-- Record a finished run on CHALLENGE_MODE_COMPLETED.  Gated on an in-progress timer, so a stray or
-- duplicate completion (no active run) is ignored rather than logged as a bogus 0-duration row.
local function recordCompletion()
  local dt = store()
  local a = dt and dt.active
  if not a then return end
  dt.active = nil
  local seconds = GetServerTime() - a.start
  if seconds <= 0 then return end
  local entry = dt.runs[a.key]
  if not entry then entry = { name = a.name, tiers = {} }; dt.runs[a.key] = entry end
  entry.name = a.name or entry.name
  local level = a.level and a.level ~= 0 and a.level or readLevel()
  local list = entry.tiers[level]
  if not list then list = {}; entry.tiers[level] = list end
  insert(list, seconds)
  while #list > KEEP do remove(list, 1) end
  -- XP gained (leveling runs only): parallel rolling window, independent of durations.
  local xpGain = ns.FinishRunXP(a.xp)
  if xpGain and xpGain > 0 then
    entry.xps = entry.xps or {}
    local xl = entry.xps[level]
    if not xl then xl = {}; entry.xps[level] = xl end
    insert(xl, xpGain)
    while #xl > KEEP do remove(xl, 1) end
  end
end

ns:registerEvent("CHALLENGE_MODE_START", beginRun)
ns:registerEvent("PLAYER_ENTERING_WORLD", refreshActive)
ns:registerEvent("CHALLENGE_MODE_COMPLETED", recordCompletion)

-- /wbc dump dungeons — recorded M+ run-times for the current character (tooltip text can't be copied).
ns:registerCommand("dump", "dungeons", function()
  local dt = ns.currentData and ns.currentData.dungeonTimes
  if not dt or not dt.runs or not next(dt.runs) then ns.Print("No dungeon run-times recorded.") return end
  ns.Print("Dungeon run-times:")
  for _, entry in pairs(dt.runs) do
    for level, list in pairs(entry.tiers) do
      local total = 0
      for _, s in ipairs(list) do total = total + s end
      local xps = entry.xps and entry.xps[level]
      local xpStr = ""
      if xps and #xps > 0 then
        local xt = 0
        for _, x in ipairs(xps) do xt = xt + x end
        xpStr = (" · avg %d XP over %d run(s)"):format(floor(xt / #xps + 0.5), #xps)
      end
      print(("  %s [%s]: avg %ds over %d run(s)%s"):format(entry.name, level > 0 and ("+" .. level) or "?", floor(total / #list + 0.5), #list, xpStr))
    end
  end
  if dt.active then
    ns.Print(("In progress: %s [+%s] for %ds"):format(dt.active.name or "?", dt.active.level or 0, GetServerTime() - dt.active.start))
  end
end, "dump M+ run-times")

-- /wbc clear dungeons — reset the current character's recorded run-times (and any in-progress timer).
ns:registerCommand("clear", "dungeons", function()
  local toon = ns.currentData
  if not toon or not toon.dungeonTimes then ns.Print("No dungeon run-times to clear.") return end
  toon.dungeonTimes = nil
  ns.Print("Dungeon run-times cleared.")
end, "clear M+ run-times")
