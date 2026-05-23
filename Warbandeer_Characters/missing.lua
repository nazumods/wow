---@type Warbandeer_Characters
local _, ns = ...
local GetBuildInfo = GetBuildInfo -- luacheck: globals GetBuildInfo

local patch = false

local function getMissingFields(toon)
  if not patch then patch = select(1, GetBuildInfo()) end
  local missing = {}

  if not toon.playtime or not toon.playtime.total then
    table.insert(missing, "playtime")
  elseif not toon.playtime.byPatch or not toon.playtime.byPatch[patch] then
    table.insert(missing, "playtime (this patch)")
  end

  if not toon.lastRefresh then table.insert(missing, "lastRefresh") end

  if toon.basic and toon.basic.professions then
    local details = toon.professions and toon.professions.details
    local missingProfs = {}
    for _, prof in ipairs({ toon.basic.professions.primary, toon.basic.professions.secondary,
                              toon.basic.professions.fishing, toon.basic.professions.cooking }) do
      if prof and prof.name and prof.skillID and (not details or not details[prof.skillID]) then
        table.insert(missingProfs, prof.name)
      end
    end
    if #missingProfs > 0 then
      table.insert(missing, "professions (" .. table.concat(missingProfs, ", ") .. ")")
    end
  end

  return missing
end

---@class Warbandeer_Characters
---@field getMissingReport fun(self): string[] Report of missing character data
function ns:getMissingReport()
  local missing = {}
  for name, toon in pairs(self.db.characters) do
    local issues = getMissingFields(toon)
    if #issues > 0 then
      table.insert(missing, name .. " - missing " .. table.concat(issues, ", "))
    end
  end
  table.sort(missing)
  return missing
end

ns:registerCommand("missing", "", function(self)
  local missing = self:getMissingReport()

  if #missing == 0 then
    ns.Print("All characters have complete data.")
    return
  end

  ns.Print(#missing .. " characters missing data:")
  for _, line in ipairs(missing) do
    print(line)
  end
end, "List characters missing data")

ns:registerCommand("missing", "me", function(self)
  local toon = self.currentData
  local missing = getMissingFields(toon)

  if #missing > 0 then
    ns.Print("Missing: " .. table.concat(missing, ", "))
  else
    ns.Print("No missing data.")
  end
end, "List the current character's missing data")
