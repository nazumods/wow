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

-- Resolve an enchant illusion's sourceID by matching a name substring against the live
-- illusion collection. Only HITS are cached (illusions never change) — a miss is retried
-- next call, so an early scan before the illusion collection has streamed in doesn't
-- permanently poison the cache for a substring that will resolve once data loads.
ns._illusionMatch = {}
function ns._resolveIllusion(match)
  if not match then return nil end
  local hit = ns._illusionMatch[match]
  if hit then return hit end
  for _, ill in ipairs(C_TransmogCollection.GetIllusions()) do
    local nm = C_TransmogCollection.GetIllusionStrings(ill.sourceID)
    if nm and nm:find(match, 1, true) then ns._illusionMatch[match] = ill.sourceID; return ill.sourceID end
  end
  return nil
end

-- Owned count for one weapon-cosmetic cell (data/weapons.lua). Illusions live on
-- C_TransmogCollection, not C_TransmogSets: an illusion is owned iff
-- GetIllusionInfo(sid).isCollected; an arsenal weapon iff PlayerHasTransmog(itemID).
-- Writes db.sets in the SAME shape as the armor path (true = fully owned, else
-- {collected,total} so the grid shades a partial bundle like a partial set) and bumps
-- the running totals. A cell with nothing resolvable yet (e.g. an arsenal whose pieces
-- list is still empty) records nothing and renders blank.
function ns:_scanWeaponSet(grp, set)
  local n, total = 0, 0
  if grp.kind == "illusion" then
    for _, piece in ipairs(set.illusions) do
      total = total + 1
      local sid = piece.sourceID or ns._resolveIllusion(piece.match)
      local info = sid and C_TransmogCollection.GetIllusionInfo(sid)
      if info and info.isCollected then n = n + 1 end
    end
  else   -- "arsenal"
    for _, itemID in ipairs(set.pieces) do
      total = total + 1
      if C_TransmogCollection.PlayerHasTransmog(itemID) then n = n + 1 end
    end
  end
  if total == 0 then return end
  self.db.total = self.db.total + 1
  if n >= total then
    self.db.collected = self.db.collected + 1
    self.db.sets[grp.id][set.id] = true
  else
    self.db.sets[grp.id][set.id] = { collected = n, total = total }
  end
end

-- Rebuild db.sets/collected/total from the live transmog APIs and refresh the open
-- window. Leaves the rating keys (wanted/rank/raceRank) untouched. Silent so the
-- collection-change event can call it without chat spam; the command prints.
function ns:Scan()
  self.db.collected = 0
  self.db.total = 0
  self.db.sets = {}
  for _, grp in ipairs(ns.Sets) do
    -- Difficulty rows of one raid share a grp.id, each contributing its own
    -- set ids to the shared table — so merge, don't reset, per group.
    self.db.sets[grp.id] = self.db.sets[grp.id] or {}
    for _, set in ipairs(grp.sets) do
      if set.id then
        if grp.kind then
          -- Weapon-cosmetic group (illusions / arsenals) — different API surface.
          self:_scanWeaponSet(grp, set)
        elseif isCollected(set.id) then
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
    ns.window.data.data = ns.window.data:GetData()
    ns.window.data:update()
  end
  -- Notify consumers (Warbandeer's collected view) now the DB is fresh, so both
  -- grids stay in sync (see api.lua OnScanned).
  if ns._scanned then
    for _, fn in ipairs(ns._scanned) do fn() end
  end
end

ns:registerCommand("scan", "", function(self)
  self:Scan()
  ns.Print("Scanned sets, collected sets updated.")
end, "Scan all sets for collected status")

-- Learning a new appearance changes the per-set collected counts, so re-scan when
-- the collection updates. This event fires in bursts (e.g. login), so debounce
-- through ns.delay; only rescan once the user has scanned at least once.
ns:registerEvent("TRANSMOG_COLLECTION_UPDATED", function(self)
  if self.db.total == 0 then return end
  self:delay(500, function() self:Scan() end)
end)
