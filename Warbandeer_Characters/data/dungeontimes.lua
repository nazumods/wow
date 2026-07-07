---@type Warbandeer_Characters
local ns = select(2, ...)
local insert, remove = table.insert, table.remove
local floor = math.floor
local GetServerTime = GetServerTime
local GetInstanceInfo = GetInstanceInfo

-- Personal dungeon completion-time tracker.  Structurally mirrors data/delvetimes.lua, covering two
-- run types keyed on different axes, both recorded into the per-character `dungeonTimes` store:
--   * Keyed Mythic+ — the clean CHALLENGE_MODE_START → _COMPLETED pair, bucketed by keystone level
--     (`runs.*.tiers` / `.xps`).
--   * Non-keyed dungeons (normal/heroic/etc.) — no start/completion event pair exists, so the run is
--     timed from instance entry (PLAYER_ENTERING_WORLD into a party instance) and recorded on
--     LFG_COMPLETION_REWARD, bucketed by difficultyID (`runs.*.diffs` / `.diffXps`).  This only fires
--     for **Dungeon-Finder (queued)** runs — walk-in / manually-formed premade runs have no reward
--     event and are intentionally not recorded (deferred; see issue #378).  XP capture rides along
--     via the shared ns.StartRunXP/FinishRunXP helpers (leveling runs only).

local KEEP = 10 -- rolling window: only the most recent N durations per dungeon+bucket are kept

-- Non-keyed dungeon difficulty labels (locale-independent — keyed M+ is difficulty 8, tracked
-- separately by keystone level).  The fallback keeps an unmapped difficulty visible, not hidden.
local DIFF_LABEL = { [1] = "Normal", [2] = "Heroic", [23] = "Mythic", [24] = "Timewalking" }

---@class Warbandeer_Characters
---@field DungeonDifficultyLabel fun(difficultyID: integer): string
function ns.DungeonDifficultyLabel(difficultyID)
  return DIFF_LABEL[difficultyID] or ("difficulty " .. tostring(difficultyID))
end

---@class DungeonRuns
---@field name string canonical dungeon name (most recently seen)
---@field tiers table<integer, integer[]> keystone level (0 = unknown) -> recent keyed-run durations (seconds)
---@field xps table<integer, integer[]>? keystone level -> recent XP gains (leveling runs only)
---@field diffs table<integer, integer[]>? difficultyID -> recent non-keyed (finder) run durations (seconds)
---@field diffXps table<integer, integer[]>? difficultyID -> recent XP gains (leveling runs only)

---@class DungeonTimes
---@field active { kind: string, key: string, name: string, start: integer, xp: RunXP?, level: integer?, diffID: integer? }? in-progress run
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

-- The current dungeon's display name (falling back to the player's map name), normalized the same
-- way as delve keys so a consumer's lookup converges on the same key.
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

-- Name + difficultyID when standing in a non-keyed dungeon, else nil.  Excludes Mythic+ (difficulty
-- 8 / an active keystone), which the CHALLENGE_MODE path owns.
local function currentDungeon()
  local _, instanceType, difficultyID = GetInstanceInfo()
  if instanceType ~= "party" then return nil end
  if difficultyID == 8 or inMythicPlus() then return nil end
  return dungeonName(), difficultyID
end

-- Append a duration (and any XP gain) to a run entry's rolling windows for one bucket.
local function pushRun(entry, timeField, xpField, bucket, seconds, xpGain)
  entry[timeField] = entry[timeField] or {}
  local list = entry[timeField][bucket]
  if not list then list = {}; entry[timeField][bucket] = list end
  insert(list, seconds)
  while #list > KEEP do remove(list, 1) end
  if xpGain and xpGain > 0 then
    entry[xpField] = entry[xpField] or {}
    local xl = entry[xpField][bucket]
    if not xl then xl = {}; entry[xpField][bucket] = xl end
    insert(xl, xpGain)
    while #xl > KEEP do remove(xl, 1) end
  end
end

-- (Lazily create and) return the runs entry for the active run's dungeon.
local function getEntry(dt, a)
  local entry = dt.runs[a.key]
  if not entry then entry = { name = a.name, tiers = {} }; dt.runs[a.key] = entry end
  entry.name = a.name or entry.name
  return entry
end

-- CHALLENGE_MODE_START: the authoritative M+ run start, fired when the timer begins (after the
-- countdown).  Always (re)stamp here so the countdown isn't counted; this event does NOT re-fire on
-- a mid-run /reload, so the persisted start (dt.active) is what survives.
local function beginRun()
  local dt = store()
  if not dt then return end
  local name = dungeonName()
  local key = ns.NormalizeDelveKey(name)
  if not key then return end -- instance data not ready; a later PLAYER_ENTERING_WORLD refreshes it
  dt.active = { kind = "mplus", key = key, name = name, level = readLevel(), start = GetServerTime(), xp = ns.StartRunXP() }
end

-- PLAYER_ENTERING_WORLD: for keyed runs, resume the persisted timer / refresh a not-yet-known level.
-- For non-keyed dungeons, begin timing on entry (there is no start event), resume it across a
-- /reload, and discard it once we've left without a completion.  A keyed run whose START we never
-- saw is not begun here — timing a partial at full weight would skew the average.
local function refreshActive()
  local dt = store()
  if not dt then return end
  local a = dt.active
  if inMythicPlus() then
    if not a or a.kind ~= "mplus" then return end
    local name = dungeonName()
    if name and name ~= "" then a.name = name; a.key = ns.NormalizeDelveKey(name) or a.key end
    local level = readLevel()
    if level > 0 then a.level = level end
    return
  end
  local name, diffID = currentDungeon()
  if name then
    local key = ns.NormalizeDelveKey(name)
    if not key then return end -- instance data not ready; a later PLAYER_ENTERING_WORLD retries
    if a and a.kind == "dungeon" and a.key == key then
      a.name = name; a.diffID = diffID -- resume: keep the persisted start
    else
      dt.active = { kind = "dungeon", key = key, name = name, diffID = diffID, start = GetServerTime(), xp = ns.StartRunXP() }
    end
  elseif a then
    dt.active = nil -- left the tracked instance without a completion signal; discard
  end
end

-- CHALLENGE_MODE_COMPLETED: record a finished keyed run.  Gated on an in-progress keyed timer, so a
-- stray/duplicate completion (no active run) is ignored rather than logged as a 0-duration row.
local function recordCompletion()
  local dt = store()
  local a = dt and dt.active
  if not a or a.kind ~= "mplus" then return end
  dt.active = nil
  local seconds = GetServerTime() - a.start
  if seconds <= 0 then return end
  local level = a.level and a.level ~= 0 and a.level or readLevel()
  pushRun(getEntry(dt, a), "tiers", "xps", level, seconds, ns.FinishRunXP(a.xp))
end

-- LFG_COMPLETION_REWARD: record a finished non-keyed (Dungeon-Finder) run.  Gated on an in-progress
-- dungeon timer, so the event only counts when it fires for the run we're timing.
local function recordDungeon()
  local dt = store()
  local a = dt and dt.active
  if not a or a.kind ~= "dungeon" then return end
  dt.active = nil
  local seconds = GetServerTime() - a.start
  if seconds <= 0 then return end
  pushRun(getEntry(dt, a), "diffs", "diffXps", a.diffID or 0, seconds, ns.FinishRunXP(a.xp))
end

ns:registerEvent("CHALLENGE_MODE_START", beginRun)
ns:registerEvent("CHALLENGE_MODE_COMPLETED", recordCompletion)
ns:registerEvent("LFG_COMPLETION_REWARD", recordDungeon)
ns:registerEvent("PLAYER_ENTERING_WORLD", refreshActive)

-- /wbc dump dungeons — recorded run-times for the current character (tooltip text can't be copied).
ns:registerCommand("dump", "dungeons", function()
  local dt = ns.currentData and ns.currentData.dungeonTimes
  if not dt or not dt.runs or not next(dt.runs) then ns.Print("No dungeon run-times recorded.") return end
  ns.Print("Dungeon run-times:")
  local function avgOf(list)
    local t = 0
    for _, s in ipairs(list) do t = t + s end
    return floor(t / #list + 0.5)
  end
  local function printBuckets(entry, timeField, xpField, labelFn)
    local buckets = entry[timeField]
    if not buckets then return end
    for bucket, list in pairs(buckets) do
      local xps = entry[xpField] and entry[xpField][bucket]
      local xpStr = (xps and #xps > 0) and (" · avg %d XP over %d run(s)"):format(avgOf(xps), #xps) or ""
      print(("  %s [%s]: avg %ds over %d run(s)%s"):format(entry.name, labelFn(bucket), avgOf(list), #list, xpStr))
    end
  end
  for _, entry in pairs(dt.runs) do
    printBuckets(entry, "tiers", "xps", function(l) return l > 0 and ("+" .. l) or "?" end)
    printBuckets(entry, "diffs", "diffXps", ns.DungeonDifficultyLabel)
  end
  if dt.active then
    local a = dt.active
    local tag = a.kind == "mplus" and ("+" .. (a.level or 0)) or ns.DungeonDifficultyLabel(a.diffID or 0)
    ns.Print(("In progress: %s [%s] for %ds"):format(a.name or "?", tag, GetServerTime() - a.start))
  end
end, "dump M+ / dungeon run-times")

-- /wbc clear dungeons — reset the current character's recorded run-times (and any in-progress timer).
ns:registerCommand("clear", "dungeons", function()
  local toon = ns.currentData
  if not toon or not toon.dungeonTimes then ns.Print("No dungeon run-times to clear.") return end
  toon.dungeonTimes = nil
  ns.Print("Dungeon run-times cleared.")
end, "clear M+ / dungeon run-times")
