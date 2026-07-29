---@type Warbandeer_Collected
local ns = select(2, ...)
local ui = ns.ui
local isCollected = C_TransmogSets.IsBaseSetCollected
local getParts = C_TransmogSets.GetSetPrimaryAppearances

ns:registerCommand("", nil, function(self)
  self:Open()
end, "Open the Collected window")

-- List every set flagged wanted (group — set [tier]), so the target list is
-- readable from chat without opening the window.
ns:registerCommand("wanted", nil, function()
  local race, n, seen = ns:PlayerRace(), 0, {}
  -- Walk both sources: live sets AND the PTR-only "upcoming" sets, since a set can
  -- be flagged wanted while the grid is in PTR PREVIEW mode (its id lives in
  -- ns.PtrSets, not ns.Sets yet). Dedupe by setId so a set present in both prints once.
  local function list(groups, tag)
    for _, grp in ipairs(groups) do
      for _, set in ipairs(grp.sets) do
        if set.id and not seen[set.id] and ns:IsWanted(set.id) then
          seen[set.id] = true
          n = n + 1
          local rank = ns:EffectiveRank(set.id, race)
          ns.Print(("%s — %s%s%s"):format(grp.name, set.name,
            rank and (" [" .. rank .. "]") or "", tag))
        end
      end
    end
  end
  list(ns.Sets, "")
  list(ns.PtrSets, " (upcoming)")
  if n == 0 then
    ns.Print("No sets flagged wanted — Shift-click an appearance in the grid, or use the dressing room.")
  else
    ns.Print(n .. " wanted set(s).")
  end
end, "List sets flagged as wanted")

-- Groups this version no longer renders, whose account-DB entries an upgrade leaves behind. Only
-- #653's two so far: the Illusions and Arsenals rows that used to sit in the ARMOR grid.
--
-- **The set ids are spelled out rather than read back from `db.sets`.** `ns:Scan` wipes that table
-- and rebuilds it from `ns.Sets`, which no longer has these groups — so after the first scan (which
-- the collection-change event fires on its own) there is nothing left to enumerate, while the
-- rating keys, which scans deliberately never touch, are still there keyed by set id with no way
-- back to them. Deriving would have quietly cleaned nothing.
local RETIRED = {
  { group = 9000001, name = "Illusions", sets = { 9000104, 9000106, 9000107 } },
  { group = 9000002, name = "Arsenals",  sets = { 9000202, 9000206, 9000212 } },
}

-- Drop those entries. Deliberately a COMMAND, never automatic: a DB upgrade has to be
-- non-destructive and rollback-safe within a patch cycle (see CONTRIBUTING), so stale keys only go
-- once the user has decided the upgrade is stable. Reports what it removed, and says so plainly
-- when there was nothing to do.
ns:registerCommand("cleanup", nil, function(self)
  local db = self.db
  local groups, ratings = 0, 0
  for _, retired in ipairs(RETIRED) do
    if db.sets and db.sets[retired.group] then db.sets[retired.group] = nil; groups = groups + 1 end
    for _, setId in ipairs(retired.sets) do
      for _, store in ipairs({ db.wanted, db.rank, db.raceRank }) do
        if store and store[setId] ~= nil then store[setId] = nil; ratings = ratings + 1 end
      end
    end
  end
  if groups == 0 and ratings == 0 then
    ns.Print("Nothing to clean up — no retired collection data in this account's saved variables.")
  else
    ns.Print(("Cleaned up %d retired group(s) and %d leftover rating(s)."):format(groups, ratings))
    ns.Print("The Illusions and Arsenals rows moved: illusions to the dressing room's look builder, arsenals to the Weapons view.")
  end
end, "Remove saved data for collection groups this version no longer shows")

-- dev: force a raw creature display id into the open preview, to vet candidate
-- ns.RaceModels ids in-game (open a set's Preview model first).
ns:registerCommand("model", nil, function(_, args)
  local idStr, flag = string.match(args or "", "(%d+)%s*(%d*)")
  local id = tonumber(idStr)
  if not id then
    ns.Print("Usage: /collected model <creatureDisplayID> [1]  (open a set's Preview model first;")
    ns.Print("       append 1 to overlay your own customizations — default off)")
    return
  end
  local useCust = flag == "1"
  ns.PreviewModelID(id, useCust)
  ns.Print(("Preview display %d (customizations %s)"):format(id, useCust and "on" or "off"))
end, "dev: preview a raw creature display id; append 1 to overlay player customizations")

-- dev: vet a freshly curated batch — list the rows that render NOTHING in the grid.
-- Scans first, then checks each row against db.sets (the exact signal the grid cells
-- use), so it catches sets that resolve via GetAllSourceIDs yet have no renderable
-- pieces on this client (their cells/tooltips show blank). Default dumps just the
-- empties to a copy window; `coverage all` dumps every row tagged OK/EMPTY. Always
-- prints a count summary.
ns:registerCommand("coverage", nil, function(_, args)
  local showAll = (args or ""):lower():find("all") ~= nil
  ns:Scan()   -- refresh db.sets so the check matches exactly what the grid renders
  local ok, empty = {}, {}
  for _, grp in ipairs(ns.Sets) do
    local gsets = ns.db.sets[grp.id]
    local rendered = false
    for _, set in ipairs(grp.sets) do
      if set.id and gsets and gsets[set.id] then rendered = true; break end
    end
    local bucket = rendered and ok or empty
    bucket[#bucket + 1] = ("%d  %s"):format(grp.id, grp.name)
  end
  local summary = ("%d rows: %d render, %d empty."):format(#ns.Sets, #ok, #empty)
  local body, title
  if showAll then
    local lines = { summary, "" }
    if #empty > 0 then lines[#lines + 1] = "-- EMPTY --"; for _, l in ipairs(empty) do lines[#lines + 1] = l end; lines[#lines + 1] = "" end
    lines[#lines + 1] = "-- OK --"
    for _, l in ipairs(ok) do lines[#lines + 1] = l end
    body, title = table.concat(lines, "\n"), "Collected coverage — all groups"
  else
    body = #empty > 0 and table.concat(empty, "\n") or summary
    title = ("Collected coverage — %d empty"):format(#empty)
  end
  ui.ShowCopyWindow(title, body)
  ns.Print(summary)
end, "dev: list grid rows that render nothing (copy window); `all` lists every row, else empties only")

-- dev: live-tune the open preview model's user scale multiplier (on top of the
-- automatic normalization), or dump the scale state with no arg.
ns:registerCommand("scale", nil, function(_, args)
  local n = tonumber(args)
  if not n then
    ns.DebugDressScale()   -- no arg → dump current scale state
    return
  end
  ns.PreviewModelScale(n)
  ns.Print("Preview scale " .. n)
end, "dev: set the open preview model's user scale multiplier (no arg dumps scale state)")

-- dev: live-tune the open preview model's bounding-box normalization strength (0..1),
-- to find a race's `normalize` override value.
ns:registerCommand("normalize", nil, function(_, args)
  local n = tonumber(args)
  if not n then ns.Print("Usage: /collected normalize <0..1>  (open a set's Preview model first)"); return end
  ns.PreviewNormalize(n)
  ns.Print(("Preview normalization %.2f"):format(n))
end, "dev: set the open preview model's normalization strength 0..1 (find a race's override)")

-- dev: force an expansion badge into the open preview by release index, to vet each
-- icon texture in-game (open any set's Preview model first).
ns:registerCommand("release", nil, function(_, args)
  local n = tonumber(args)
  if not n or not ns.Releases[n] then
    ns.Print("Usage: /collected release <1..12>  (1=Vanilla .. 12=Midnight; open a set's Preview model first)")
    return
  end
  ns.PreviewRelease(n)
  ns.Print(("Preview release %d (%s)"):format(n, ns.Releases[n]))
end, "dev: preview an expansion badge by release index 1..12 (eyeball each icon)")

-- dev: exercise the #596 weapon-browser data layer with no UI — vet the category enumeration
-- and per-appearance source resolution against the live transmog API. No arg lists every weapon
-- category with its owned/total counts + capability flags; an arg (category-name substring) samples
-- that category's appearances, each with its resolved "where from" line. Copy window (see wdump).
ns:registerCommand("weapons", nil, function(_, args)
  local cats = ns.WeaponCategories()
  local filter = (args or ""):lower():match("^%s*(.-)%s*$")
  if filter == "" then
    local lines = {}
    for _, c in ipairs(cats) do
      local apps, owned = ns.WeaponAppearances(c.category), 0
      for _, a in ipairs(apps) do if a.isCollected then owned = owned + 1 end end
      lines[#lines + 1] = ("%2d  %-22s  %4d/%4d  %s%s%s"):format(c.category, c.name, owned, #apps,
        c.canMainHand and "M" or "-", c.canOffHand and "O" or "-", c.canHaveIllusions and "i" or "-")
    end
    ui.ShowCopyWindow("Weapon browser — categories", table.concat(lines, "\n"))
    ns.Print(("%d weapon categories (owned/total; M=mainhand O=offhand i=illusions)"):format(#cats))
    return
  end
  local match
  for _, c in ipairs(cats) do if c.name:lower():find(filter, 1, true) then match = c; break end end
  if not match then ns.Print("No weapon category matching '" .. filter .. "'"); return end
  local apps, lines = ns.WeaponAppearances(match.category), {}
  for i = 1, math.min(#apps, 40) do
    local a = apps[i]
    local src = ns.WeaponSource(a.visualID)
    lines[#lines + 1] = ("%s  visual %-6d  src %-8s  %s"):format(a.isCollected and "[x]" or "[ ]",
      a.visualID, src and tostring(src.sourceID) or "-", src and (src.text or src.name or "?") or "(none)")
  end
  ui.ShowCopyWindow(("Weapon browser — %s (%d of %d)"):format(match.name, #lines, #apps),
    table.concat(lines, "\n"))
  ns.Print(("%s: %d appearances"):format(match.name, #apps))
end, "dev: verify the #596 weapon-browser data layer (no arg = categories; <name> samples sources)")

-- Rebuild db.sets/collected/total from the live transmog APIs and refresh the open
-- window. Leaves the rating keys (wanted/rank/raceRank) untouched. Silent so the
-- collection-change event can call it without chat spam; the command prints.
function ns:Scan()
  local scanStart = GetTimePreciseSec()
  self.db.collected = 0
  self.db.total = 0
  self.db.sets = {}
  for _, grp in ipairs(ns.Sets) do
    -- Difficulty rows of one raid share a grp.id, each contributing its own
    -- set ids to the shared table — so merge, don't reset, per group.
    self.db.sets[grp.id] = self.db.sets[grp.id] or {}
    for _, set in ipairs(grp.sets) do
      if set.id then
        if isCollected(set.id) then
          self.db.total = self.db.total + 1
          self.db.sets[grp.id][set.id] = true
          self.db.collected = self.db.collected + 1
        else
          local parts = getParts(set.id)
          if parts and #parts > 0 then
            self.db.total = self.db.total + 1
            local n = 0
            for _,p in ipairs(parts) do
              if p.collected then n = n + 1 end
            end
            self.db.sets[grp.id][set.id] = {
              collected = n,
              parts = parts,
              total = #parts,
            }
          else
            -- No primary appearances: a raid-tier concept that non-raid sets (PvP
            -- seasons, recolors, world/event sets) lack. Fall back to the appearance
            -- sources — the same path the InfoTip and dressing room use — so the cell
            -- still renders a collected count. A set whose sources don't resolve to
            -- items on this client (truly absent) yields no pieces and stays blank.
            local pieces = ns.SetSlotPieces(set.id)
            local total, n = 0, 0
            for _, p in pairs(pieces) do
              total = total + 1
              if p.isCollected then n = n + 1 end
            end
            if total > 0 then
              self.db.total = self.db.total + 1
              self.db.sets[grp.id][set.id] = { collected = n, total = total }
            end
          end
        end
      end
    end
  end
  if ns.window then
    ns.window:RefreshCounter()   -- respects live/PTR mode (leaves the upcoming count alone in PTR)
    -- **BOTH grids, and unconditionally (#761).** This rebuilt only the armor grid, so collecting a
    -- weapon appearance with the Weapons grid open left three surfaces disagreeing at once: the
    -- header counter ticked up (`VisibleCounts` recomputes live from `ns.WeaponSources` and the
    -- collected map, so it never reads this row set), the cell still showed the old count with no
    -- check, and the cell's own tooltip called it collected. Nothing healed it short of a
    -- filter/sort/PTR change or a `/reload` — a ratings edit only re-marks, and `ns:Open` reuses the
    -- frame with a plain `Show()`.
    --
    -- Unconditional is the point: `OnRatingsChanged` (window.lua) rebuilds only when `_wantedOnly`
    -- and otherwise just re-marks, which is right for a rating change and a no-op for this one —
    -- a scan changes the collected counts every cell is drawn from, not which rows pass a filter.
    -- `Grids()` and not a literal pair: the weapons grid is built lazily on the first switch to it
    -- (#770 step 19), and a grid that doesn't exist yet has no stale counts to refresh — it reads
    -- them when it's built.
    for _, grid in ipairs(ns.window:Grids()) do
      grid.data = grid:GetData()
      grid:update()
    end
  end
  -- Notify consumers (Warbandeer's collected view) now the DB is fresh, so both
  -- grids stay in sync (see api.lua OnScanned).
  if ns._scanned then
    for _, fn in ipairs(ns._scanned) do fn() end
  end
  -- The login burst of TRANSMOG_COLLECTION_UPDATED schedules a scan 500ms out, and a scan walks
  -- every set through the transmog API *and* rebuilds both grids. Landing one next to a window open
  -- is the difference between a slow build and a build that also paid for a rescan, so the profiler
  -- records it whether or not a run is in flight (see profile.lua).
  ns.prof:Scan((GetTimePreciseSec() - scanStart) * 1000)
end

ns:registerCommand("scan", "", function(self)
  self:Scan()
  ns.Print("Scanned sets, collected sets updated.")
end, "Scan all sets for collected status")

-- Rebuild the open window's grids from the CURRENT db — the display half of `scan`, without the
-- transmog-API walk that wipes and refills `db.sets`. Touches no collection or rating data.
--
-- Exists as a workaround for #718: the grid intermittently comes up after a login with its text
-- missing while the cells underneath are intact. `Cell:update` re-applies each cell's text and
-- re-shows its label, so a rebuild restores the display. `scan` already did this as a side effect,
-- but rescanning every set to fix a drawing fault is a sledgehammer.
--
-- It doubles as a probe: if this fixes a blank grid, the cells were built correctly and something
-- hid them or stopped them drawing — which is a different bug from the row builder never producing
-- the text, and narrows #718 accordingly.
ns:registerCommand("refresh", nil, function()
  if not ns.window then
    ns.Print("The Collected window isn't open — /collected opens it.")
    return
  end
  for _, grid in ipairs(ns.window:Grids()) do
    grid.data = grid:GetData()
    grid:update()
    if grid.onResized then grid:onResized() end
  end
  ns.window:RefreshCounter()
  ns.window:RefreshWanted()
  ns.Print("Rebuilt the Collected grids from the current data.")
end, "Rebuild the open window's grids without rescanning (fixes a blank grid — see #718)")

-- Learning a new appearance changes the per-set collected counts, so re-scan when
-- the collection updates. This event fires in bursts (e.g. login), so debounce
-- through ns.delay; only rescan once the user has scanned at least once.
ns:registerEvent("TRANSMOG_COLLECTION_UPDATED", function(self)
  if self.db.total == 0 then return end
  self:delay(500, function() self:Scan() end)
end)
