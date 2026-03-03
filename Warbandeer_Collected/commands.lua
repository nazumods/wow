local _, ns = ...
local isCollected = C_TransmogSets.IsBaseSetCollected
local getParts = C_TransmogSets.GetSetPrimaryAppearances
local Colors = ns.Colors.Strings

ns:registerCommand("scan", "", function()
  ns.db.collected = 0
  ns.db.total = 0
  ns.db.sets = {}
  for g, grp in ipairs(ns.Sets) do
    ns.db.sets[grp.id] = ns.db.sets[grp.id] or {}
    ns.db.total = ns.db.total + #grp.sets
    for s, set in ipairs(grp.sets) do
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
