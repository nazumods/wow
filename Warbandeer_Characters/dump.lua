local _, ns = ...
local print = print
local GetBuildInfo = GetBuildInfo -- luacheck: globals GetBuildInfo

local TIME_LONG = "%d days %d hours %d minutes"
local TIME_SHORT = "%dd %dh %dm"

local function formatTime(seconds, fmt)
  fmt = fmt or TIME_LONG
  local days = 0
  local hours = math.floor(seconds / 3600)
  local minutes = math.floor((seconds % 3600) / 60)
  if hours > 24 then
    days = math.floor(hours / 24)
    hours = hours % 24
  end
  return string.format(fmt, days, hours, minutes)
end

local function roundTime(seconds)
  return string.format("%.2f days", seconds / 86400)
end

ns:registerCommand("stat", "", function(self)
  local patch = select(1, GetBuildInfo())
  local a, h, p, pp = 0, 0, 0, 0
  local mp, ft = 0, nil
  local pbc = {}
  for _,t in pairs(self.db.characters) do
    if t.isAlliance then a = a + 1 else h = h + 1 end
    if t.playtime then
      p = p + t.playtime.total
      pp = pp + t.playtime.byPatch[patch]
      if t.playtime.total > mp then
        mp = t.playtime.total
        ft = t.name
      end
      pbc[t.className] = (pbc[t.className] or 0) + t.playtime.total
    end
  end
  local cp, cn = 0, nil
  for c,t in pairs(pbc) do
    if t > cp then
      cp = t
      cn = c
    end
  end

  self.Print("Warband Statistics:")
  print(self.db.numCharacters .. " characters, " .. a .. " alliance, " .. h .. " horde. " .. roundTime(p) .. " played, " .. formatTime(pp, TIME_SHORT) .. " this patch.")
  print("Most played: " .. ft .. " (" .. formatTime(mp) .. ")")
  print("Most played class: " .. cn .. " (" .. formatTime(cp) .. ")")
end, "Dump current character data")
