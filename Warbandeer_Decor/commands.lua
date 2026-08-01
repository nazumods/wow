---@type Warbandeer_Decor
local ns = select(2, ...)

ns:registerCommand("", nil, function(self)
  self:Open()
end, "Open the Housing Decor window")

ns:registerCommand("scan", "", function(self)
  self:Scan()
  ns.Print(("Scanned %d decor entries."):format(#ns._entries))
end, "Re-scan the housing catalog")

-- Show every decor flagged wanted in a copyable window, so the target list is portable
-- away from the game (a shopping list you can paste elsewhere) rather than one-name-per-line
-- chat spam. Names + "where to get it" blurbs come from the live snapshot; a wanted id not
-- in the current scan (catalog still loading) is counted in the header but can't be named
-- yet. Re-running toggles the window closed, matching the suite's window convention.
ns:registerCommand("wanted", nil, function()
  local total = ns:WantedCount()
  if total == 0 then
    ns.Print("No decor flagged wanted -- Shift-click a row in the /wbdecor window to flag one.")
    return
  end
  local body = ns.WantedListText(ns._entries, function(id) return ns:IsWanted(id) end, total)
  ns.ui.ToggleCopyWindow("Wanted Decor", body)
end, "Show a copyable list of decor flagged as wanted")
