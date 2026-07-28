---@type Warbandeer_Collected
local ns = select(2, ...)
local ui = ns.ui
local floor = math.floor
local GetTimePreciseSec = GetTimePreciseSec

-- Build-time profiler for the Collected window (`/collected profile`), off by default.
--
-- It exists to answer ONE question, because the two possible answers want opposite fixes: is the
-- wait Lua work, or is it the engine laying out the frames that work created? A grid build is
-- ~6,600 `Cell` frames, and the layout cost of those lands AFTER the constructor returns — so a
-- Lua-only timer reports a fast build for a window that visibly isn't. Hence two clocks per run:
-- `lua` (the synchronous call) and `paint1..3` (the frames that follow it).
--
-- If `lua` dominates → chunk the build across frames and the window appears immediately.
-- If `paint` dominates → chunking buys nothing and the answer is FEWER frames (virtualise rows to
-- the viewport). Reading only the first number is how you end up building the wrong thing.
--
-- `GetTimePreciseSec` rather than `debugprofilestop`: the latter is zeroed by anyone calling
-- `debugprofilestart()`, which would silently corrupt a span mid-run.
--
-- Samples persist to `db.profile` because the first open happens once per session — a single
-- reading is noise, and #718 has already burned two PRs on exactly that mistake.

-- Samples kept per kind (bounds the SavedVariables), and frames timed after each build.
local MAX_SAMPLES, PAINT_FRAMES = 20, 3

---@class CollectedProfiler
---@field armed boolean    instrumentation on — the `/collected profile` toggle
---@field _run table?      the run being timed (nil = not inside one, so every Mark no-ops)
---@field _ticker Frame?   reusable OnUpdate frame that times the frames after a build
---@field _lastScan table? `{ at, ms }` of the most recent ns:Scan, for the overlap note
local Prof = { armed = false }

---@class Warbandeer_Collected
---@field prof CollectedProfiler
ns.prof = Prof

---Start timing a run. No-op unless armed, and a run already in flight is left alone so a nested
---span can't restart the clock on the one that encloses it.
---@param kind string  "open" | "weapons" | "armor"
function Prof:Begin(kind)
  if not self.armed or self._run then return end
  local now = GetTimePreciseSec()
  self._run = { kind = kind, t0 = now, last = now, phases = {} }
end

---Record a split since the previous mark. No-op outside a run, which is what keeps the call sites
---in the window and grid constructors free when profiling is off.
---@param name string
function Prof:Mark(name)
  local run = self._run
  if not run then return end
  local now = GetTimePreciseSec()
  run.phases[#run.phases + 1] = { name = name, ms = (now - run.last) * 1000 }
  run.last = now
end

---Note a completed `ns:Scan`. Recorded whether or not a run is in flight: the login burst of
---TRANSMOG_COLLECTION_UPDATED schedules a scan 500ms out, and a scan rebuilds BOTH grids — so a
---scan landing next to an open is the difference between a slow build and a build that also paid
---for a full rescan. Without this the open timings look unreproducible.
---@param ms number
function Prof:Scan(ms)
  self._lastScan = { at = GetTimePreciseSec(), ms = ms }
end

---Rows and live cells in the grid this run built or swapped to — the count that decides between
---"chunk the Lua" and "create fewer frames", which time alone can't separate.
---@return number rows, number cells
function Prof:_gridStats()
  local w = ns.window
  if not w then return 0, 0 end
  local grid = w.active or w.data
  local cells = 0
  for r = 1, #grid.cells do
    local row = grid.cells[r]
    for c = 1, #grid.cols do if row[c] then cells = cells + 1 end end
  end
  return #grid.rows, cells
end

---Close the run: stamp the Lua total, then time the next few frames before recording it.
function Prof:Finish()
  local run = self._run
  if not run then return end
  self._run = nil
  run.lua = (GetTimePreciseSec() - run.t0) * 1000
  run.rows, run.cells = self:_gridStats()
  if self._lastScan then
    run.scanGap, run.scanMs = run.t0 - self._lastScan.at, self._lastScan.ms
  end
  self:_timePaint(run)
end

---Time the frames following the build. The engine lays out freshly created frames after the Lua
---call returns, so that cost is invisible to `run.lua`. There is no present/paint callback in the
---client, so "how long did the next three frames take" is the closest available proxy — a build
---whose frames run long is one the user is still waiting on.
---@param run table
function Prof:_timePaint(run)
  self._ticker = self._ticker or ui.Frame:new{ parent = UIParent }
  local n = 0
  self._ticker:SetScript("OnUpdate", function()
    n = n + 1
    run["paint" .. n] = (GetTimePreciseSec() - run.t0) * 1000
    if n < PAINT_FRAMES then return end
    self._ticker:RemoveScript("OnUpdate")
    self:_record(run)
  end)
end

---Persist the finished run and print it. `db.profile` is seeded here rather than in `MigrateDB`:
---it's purely additive and filled lazily, so per the DB rule it earns no version bump.
---@param run table
function Prof:_record(run)
  run.t0, run.last = nil, nil   -- clock state, not results; don't persist it
  local store = ns.db.profile or {}
  ns.db.profile = store
  local samples = store[run.kind] or {}
  store[run.kind] = samples
  samples[#samples + 1] = run
  while #samples > MAX_SAMPLES do table.remove(samples, 1) end
  self:_print(run, #samples)
end

---@param ms number?
---@return string
local function fmt(ms) return ("%.0f"):format(ms or 0) end

---@param run table
---@param n number  how many samples of this kind are now stored
function Prof:_print(run, n)
  local parts = {}
  for _, p in ipairs(run.phases) do parts[#parts + 1] = ("%s %s"):format(p.name, fmt(p.ms)) end
  ns.Print(("%s — lua %sms · paint +%s/+%s/+%sms · %d rows, %d cells  (sample %d)"):format(
    run.kind, fmt(run.lua), fmt(run.paint1), fmt(run.paint2), fmt(run.paint3),
    run.rows, run.cells, n))
  ns.Print("  " .. table.concat(parts, "  "))
  -- Only worth saying when the scan is close enough to have shared the frame budget.
  local gap = run.scanGap
  if gap and gap > -5 and gap < 5 then
    ns.Print(gap < 0
      and ("  |cffff8800a scan (%sms) ran DURING this run — it rebuilds both grids|r"):format(fmt(run.scanMs))
      or  ("  |cffff8800a scan (%sms) ran %.1fs before this run|r"):format(fmt(run.scanMs), gap))
  end
end

---Min / median / max of a list of numbers (sorted copy — the caller's order is the sample order).
---@param list number[]
---@return number, number, number
local function spread(list)
  if #list == 0 then return 0, 0, 0 end
  local s = {}
  for i, v in ipairs(list) do s[i] = v end
  table.sort(s)
  return s[1], s[floor((#s + 1) / 2)], s[#s]
end

---Aggregate every stored sample to a copy window. The point of aggregating is that one login tells
---you nothing: the phase that matters is the one whose MEDIAN is large, not the one that spiked
---while a scan happened to be running.
function Prof:Report()
  local store = ns.db.profile
  if not store then ns.Print("No samples yet — /collected profile arms it."); return end
  local lines = {}
  for _, kind in ipairs({ "open", "weapons", "armor" }) do
    local samples = store[kind]
    if samples and #samples > 0 then
      lines[#lines + 1] = ("== %s (%d samples) =="):format(kind, #samples)
      -- Collect each metric across samples, then report its spread. Phase names come off the first
      -- sample: every run of a kind walks the same call path, so the set is stable.
      local cols = { { "lua", function(r) return r.lua end } }
      for i = 1, PAINT_FRAMES do
        cols[#cols + 1] = { "paint+" .. i, function(r) return r["paint" .. i] end }
      end
      for i, p in ipairs(samples[1].phases) do
        cols[#cols + 1] = { "  " .. p.name, function(r) return r.phases[i] and r.phases[i].ms end }
      end
      for _, col in ipairs(cols) do
        local vals = {}
        for _, r in ipairs(samples) do
          local v = col[2](r)
          if v then vals[#vals + 1] = v end
        end
        local lo, mid, hi = spread(vals)
        lines[#lines + 1] = ("%-14s  min %6.1f   median %6.1f   max %6.1f  (ms)"):format(col[1], lo, mid, hi)
      end
      local last = samples[#samples]
      lines[#lines + 1] = ("%-14s  %d rows, %d cells"):format("grid", last.rows, last.cells)
      lines[#lines + 1] = ""
    end
  end
  if #lines == 0 then ns.Print("No samples yet — /collected profile arms it."); return end
  ui.ShowCopyWindow("Collected build profile", table.concat(lines, "\n"))
end

-- dev: time the window build and the Armor/Weapons swaps. A bare call toggles instrumentation and,
-- when the window doesn't exist yet, opens it — the first open is the measurement that can only be
-- taken once per session, so arming and opening have to be one step. Every run prints as it
-- completes; `report` aggregates the stored samples across reloads.
ns:registerCommand("profile", nil, function(self, args)
  local arg = (args or ""):lower():match("^%s*(.-)%s*$")
  if arg == "report" then Prof:Report(); return end
  if arg == "clear" then
    ns.db.profile = nil
    ns.Print("Cleared the stored build-profile samples.")
    return
  end
  Prof.armed = not Prof.armed
  if not Prof.armed then ns.Print("Build profiling off."); return end
  if ns.window then
    ns.Print("Build profiling on. The first open already happened this session — /reload, then")
    ns.Print("  /collected profile  to time it. Armor/Weapons swaps are timed from now.")
    return
  end
  ns.Print("Build profiling on — opening the window.")
  self:Open()
end, "dev: time the window build + Armor/Weapons swaps (`report` aggregates samples, `clear` wipes)")
