---@type Warbandeer_Collected
local ns = select(2, ...)
local isCollected = C_TransmogSets.IsBaseSetCollected
local getParts = C_TransmogSets.GetSetPrimaryAppearances

ns:registerCommand("", nil, function(self)
  self:Open()
end, "Open the Collected window")

-- List every set flagged wanted (group — set [tier]), so the target list is
-- readable from chat without opening the window.
ns:registerCommand("wanted", nil, function()
  local race, n = ns:PlayerRace(), 0
  for _, grp in ipairs(ns.Sets) do
    for _, set in ipairs(grp.sets) do
      if set.id and ns:IsWanted(set.id) then
        n = n + 1
        local rank = ns:EffectiveRank(set.id, race)
        ns.Print(("%s — %s%s"):format(grp.name, set.name, rank and (" [" .. rank .. "]") or ""))
      end
    end
  end
  if n == 0 then
    ns.Print("No sets flagged wanted — Shift-click a grid cell, or use the dressing room.")
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

-- Rebuild db.sets/collected/total from the live transmog APIs and refresh the open
-- window. Leaves the rating keys (wanted/rank/raceRank) untouched. Silent so the
-- collection-change event can call it without chat spam; the command prints.
function ns:Scan()
  self.db.collected = 0
  self.db.total = 0
  self.db.sets = {}
  for _, grp in ipairs(ns.Sets) do
    self.db.sets[grp.id] = self.db.sets[grp.id] or {}
    self.db.total = self.db.total + #grp.sets
    for _, set in ipairs(grp.sets) do
      if set.id then
        if isCollected(set.id) then
          self.db.sets[grp.id][set.id] = true
          self.db.collected = self.db.collected + 1
        else
          local parts = getParts(set.id)
          local n = 0
          for _,p in ipairs(parts) do
            if p.collected then n = n + 1 end
          end
          self.db.sets[grp.id][set.id] = {
            collected = n,
            parts = parts,
            total = #parts,
          }
        end
      end
    end
  end
  if ns.window then
    ns.window.counter:Text(self.db.collected .. " / " .. self.db.total)
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
