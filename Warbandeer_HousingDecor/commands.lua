---@type Warbandeer_HousingDecor
local ns = select(2, ...)

ns:registerCommand("", nil, function(self)
  self:Open()
end, "Open the Housing Decor window")

ns:registerCommand("scan", "", function(self)
  self:Scan()
  ns.Print(("Scanned %d decor entries."):format(#ns._entries))
end, "Re-scan the housing catalog")

-- List every decor flagged wanted, so the target list is readable from chat without
-- opening the window. Names come from the live snapshot; a wanted id not in the current
-- scan (catalog still loading) is counted but can't be named yet.
ns:registerCommand("wanted", nil, function()
  local total = ns:WantedCount()
  if total == 0 then
    ns.Print("No decor flagged wanted -- Shift-click a row in the /decor window to flag one.")
    return
  end
  local named = 0
  for _, e in ipairs(ns._entries) do
    if ns:IsWanted(e.recordID) then
      named = named + 1
      ns.Print(("%s%s"):format(e.name, e.owned and "" or "  (not owned)"))
    end
  end
  if named < total then
    ns.Print(("%d wanted decor (%d not in the current scan -- open /decor to refresh)."):format(total, total - named))
  else
    ns.Print(total .. " wanted decor.")
  end
end, "List decor flagged as wanted")
