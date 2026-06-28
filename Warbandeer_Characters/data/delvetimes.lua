---@type Warbandeer_Characters
local ns = select(2, ...)
local insert, remove = table.insert, table.remove
local floor = math.floor
local GetServerTime = GetServerTime
local GetInstanceInfo = GetInstanceInfo

-- Personal delve completion-time tracker.  WoW exposes no completion-time API, so we time each
-- run ourselves: capture the start when a delve scenario begins and, on SCENARIO_COMPLETED,
-- record the elapsed seconds under that delve + tier.  Modeled on data/mail.lua (imperative
-- event handlers writing straight to ns.currentData) rather than a scannable `fields` broker —
-- run-times accumulate over time and can't be re-derived from a single live scan.

local KEEP = 10 -- rolling window: only the most recent N durations per delve+tier are kept

---@class DelveRuns
---@field name string canonical delve name (most recently seen)
---@field tiers table<integer, integer[]> tier (1-11, 0 = unknown) -> recent durations in seconds

---@class DelveTimes
---@field active { key: string, name: string, tier: integer, start: integer }? in-progress run
---@field runs table<string, DelveRuns> normalized delve key -> recorded runs

---@class Character
---@field delveTimes DelveTimes?

-- Normalized delve key, shared by the writer here and api.lua's GetDelveStats reader so a map
-- pin's POI name and the in-delve scenario name converge (e.g. "The Earthcrawl Mines" and
-- "Earthcrawl Mines").  Lower-cased, leading article stripped, trimmed.
---@class Warbandeer_Characters
---@field NormalizeDelveKey fun(name: string?): string?
function ns.NormalizeDelveKey(name)
  if not name then return nil end
  local key = strtrim(name):lower():gsub("^the ", "")
  return key ~= "" and key or nil
end

-- (Lazily create and) return the current character's delveTimes store.
local function store()
  local toon = ns.currentData
  if not toon then return nil end
  local dt = toon.delveTimes
  if not dt then dt = { runs = {} }; toon.delveTimes = dt end
  if not dt.runs then dt.runs = {} end
  return dt
end

-- Whether the player is currently inside a delve.
local function inDelve()
  if C_DelvesUI and C_DelvesUI.HasActiveDelve and C_DelvesUI.HasActiveDelve() then return true end
  if C_PartyInfo and C_PartyInfo.IsDelveInProgress and C_PartyInfo.IsDelveInProgress() then return true end
  return false
end

-- The current delve's specific display name, e.g. "Earthcrawl Mines".  GetScenarioInfo().name is
-- the generic "Delves" for every delve, so read the instance name (falling back to the player's
-- map name) — both match the delve's map entrance-pin name that the tooltip looks up.
local function delveName()
  local name = GetInstanceInfo()
  if name and name ~= "" then return name end
  local mapID = C_Map.GetBestMapForUnit("player")
  local info = mapID and C_Map.GetMapInfo(mapID)
  return info and info.name
end

-- Best-effort current delve tier (1-11).  The tier is surfaced by the scenario's delves-header
-- widget as `tierText` (a localized string, e.g. "Tier 11" — there is no numeric `tier` field), so
-- pull the first run of digits out of it.  Returns 0 (unknown bucket) when it can't be read, so the
-- run is still recorded and counted in the all-tiers aggregate.
local function readTier()
  local step = C_ScenarioInfo and C_ScenarioInfo.GetScenarioStepInfo and C_ScenarioInfo.GetScenarioStepInfo()
  local setID = step and step.widgetSetID
  local getWidgets = C_UIWidgetManager and C_UIWidgetManager.GetAllWidgetsBySetID
  local getDelves = C_UIWidgetManager and C_UIWidgetManager.GetScenarioHeaderDelvesWidgetVisualizationInfo
  if setID and getWidgets and getDelves then
    for _, w in ipairs(getWidgets(setID)) do
      local viz = getDelves(w.widgetID)
      local tier = viz and viz.tierText and tonumber(viz.tierText:match("%d+"))
      if tier then return tier end
    end
  end
  return 0
end

-- Start (or resume) timing the current delve.  Keeps an existing same-delve timer's start so a
-- mid-run /reload doesn't reset it; re-reads tier/name in case they weren't ready at entry.
local function refreshActive()
  local dt = store()
  if not dt then return end
  if inDelve() then
    local name = delveName()
    local key = ns.NormalizeDelveKey(name)
    if not key then return end -- scenario data not ready yet; a later SCENARIO_UPDATE retries
    local a = dt.active
    if a and a.key == key then
      -- Refresh now that the scenario is fully set up, but never clobber a known tier with the
      -- unknown bucket: SCENARIO_UPDATE also fires before the header widget is populated and again
      -- as it tears down at completion, where readTier() reads 0.
      a.name = name
      local tier = readTier()
      if tier ~= 0 then a.tier = tier end
    else
      dt.active = { key = key, name = name, tier = readTier(), start = GetServerTime() }
    end
  elseif dt.active then
    dt.active = nil -- left the delve without completing it; discard
  end
end

-- Record a finished run on SCENARIO_COMPLETED.  Gated on an in-progress delve timer, so non-delve
-- scenario completions (which never set `active`) are ignored.
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
  -- Last-ditch read in case no in-run SCENARIO_UPDATE ever caught a populated header widget.
  local tier = a.tier and a.tier ~= 0 and a.tier or readTier()
  local list = entry.tiers[tier]
  if not list then list = {}; entry.tiers[tier] = list end
  insert(list, seconds)
  while #list > KEEP do remove(list, 1) end
end

ns:registerEvent("PLAYER_ENTERING_WORLD", refreshActive)
ns:registerEvent("SCENARIO_UPDATE", refreshActive)
ns:registerEvent("SCENARIO_COMPLETED", recordCompletion)

-- /wbc dump delves — recorded run-times for the current character (tooltip text can't be copied).
ns:registerCommand("dump", "delves", function(self)
  local dt = ns.currentData and ns.currentData.delveTimes
  if not dt or not dt.runs or not next(dt.runs) then ns.Print("No delve run-times recorded.") return end
  ns.Print("Delve run-times:")
  for _, entry in pairs(dt.runs) do
    for tier, list in pairs(entry.tiers) do
      local total = 0
      for _, s in ipairs(list) do total = total + s end
      print(("  %s [%s]: avg %ds over %d run(s)"):format(entry.name, tier > 0 and ("T" .. tier) or "T?", floor(total / #list + 0.5), #list))
    end
  end
  if dt.active then
    ns.Print(("In progress: %s [T%s] for %ds"):format(dt.active.name or "?", dt.active.tier or 0, GetServerTime() - dt.active.start))
  end
end, "dump delve run-times")

-- /wbc clear delves — reset the current character's recorded run-times (and any in-progress timer).
ns:registerCommand("clear", "delves", function(self)
  local toon = ns.currentData
  if not toon or not toon.delveTimes then ns.Print("No delve run-times to clear.") return end
  toon.delveTimes = nil
  ns.Print("Delve run-times cleared.")
end, "clear delve run-times")
