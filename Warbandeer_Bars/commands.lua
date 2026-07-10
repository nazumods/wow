---@type Warbandeer_Bars
local ns = select(2, ...)

-- Headless data layer: these commands are for inspection/testing only.
-- The UI lives in a separate addon that consumes WarbandeerBarsApi.

ns:registerCommand("", nil, function()
  ns.Print("Warbandeer Bars (headless profile tracker). Commands: snapshot | list | restore <char> [specID] | forget <char> [specID]")
end, "Show status")

ns:registerCommand("snapshot", nil, function()
  local p = ns.Snapshot()
  if p then
    ns.Print(("Captured |cffffd100%s|r — %s (spec %d): %d slots, %d macros")
      :format(p.char, p.spec or "?", p.specID, #(p.slots or {}), #(p.macros or {})))
  else
    ns.Print("Snapshot skipped (in combat, mid-drag, or no active spec).")
  end
end, "Capture the current character now")

ns:registerCommand("list", nil, function()
  local n = 0
  for char, byChar in pairs(ns.db.profiles) do
    for specID, p in pairs(byChar) do
      n = n + 1
      ns.Print(("|cffffd100%s|r [%d] %s — %d slots (captured %s)")
        :format(char, specID, p.spec or "?", #(p.slots or {}),
                p.captured and date("%Y-%m-%d %H:%M", p.captured) or "?"))
    end
  end
  if n == 0 then ns.Print("No profiles stored yet.") end
end, "List stored profiles")

ns:registerCommand("restore", nil, function(_, args)
  local char, specStr = args:match("^(%S+)%s*(%S*)$")
  if not char or char == "" then
    ns.Print("Usage: /wbb restore <char> [specID]"); return
  end
  local specID = tonumber(specStr) or ns.api:GetCurrentSpecID()
  if not ns.api:RestoreProfile(char, specID) then
    ns.Print(("No profile for %s spec %d. Try /wbb list."):format(char, specID))
  end
end, "Restore a stored profile to the current character")

ns:registerCommand("forget", nil, function(_, args)
  local char, specStr = args:match("^(%S+)%s*(%S*)$")
  if not char or char == "" then
    ns.Print("Usage: /wbb forget <char> [specID]"); return
  end
  local specID = tonumber(specStr)
  if specID then
    ns.api:DeleteProfile(char, specID)
    ns.Print(("Forgot %s spec %d."):format(char, specID))
  elseif ns.api:DeleteCharacter(char) then -- resolves casing; false if nothing to forget
    ns.Print(("Forgot all profiles for %s."):format(char))
  else
    ns.Print(("No stored profiles for %s. Try /wbb list."):format(char))
  end
end, "Delete stored profile(s)")
