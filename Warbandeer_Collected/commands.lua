---@type Warbandeer_Collected
local ns = select(2, ...)
local isCollected = C_TransmogSets.IsBaseSetCollected
local getParts = C_TransmogSets.GetSetPrimaryAppearances

ns:registerCommand("", nil, function(self)
  self:Open()
end, "Open the Collected window")

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

ns:registerCommand("scan", "", function()
  ns.db.collected = 0
  ns.db.total = 0
  ns.db.sets = {}
  for _, grp in ipairs(ns.Sets) do
    ns.db.sets[grp.id] = ns.db.sets[grp.id] or {}
    ns.db.total = ns.db.total + #grp.sets
    for _, set in ipairs(grp.sets) do
      if set.id then
        if isCollected(set.id) then
          ns.db.sets[grp.id][set.id] = true
          ns.db.collected = ns.db.collected + 1
        else
          local parts = getParts(set.id)
          local n = 0
          for _,p in ipairs(parts) do
            if p.collected then n = n + 1 end
          end
          ns.db.sets[grp.id][set.id] = {
            collected = n,
            parts = parts,
            total = #parts,
          }
        end
      end
    end
  end
  if ns.window then
    ns.window.counter:Text(ns.db.collected .. " / " .. ns.db.total)
    ns.window.data.data = ns.window.data:GetData()
    ns.window.data:update()
  end
  ns.Print("Scanned sets, collected sets updated.")
end, "Scan all sets for collected status")
