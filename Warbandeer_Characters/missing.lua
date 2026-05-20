local _, ns = ...
local GetBuildInfo = GetBuildInfo -- luacheck: globals GetBuildInfo

ns:registerCommand("missing", "", function(self)
  local patch = select(1, GetBuildInfo())
  local missing = {}
  for name, toon in pairs(self.db.characters) do
    local issues = {}

    if not toon.playtime or not toon.playtime.total then
      table.insert(issues, "playtime")
    elseif not toon.playtime.byPatch or not toon.playtime.byPatch[patch] then
      table.insert(issues, "playtime (this patch)")
    end

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
        table.insert(issues, "professions (" .. table.concat(missingProfs, ", ") .. ")")
      end
    end

    if #issues > 0 then
      table.insert(missing, name .. " - missing " .. table.concat(issues, ", "))
    end
  end

  if #missing == 0 then
    ns.Print("All characters have complete data.")
    return
  end

  table.sort(missing)
  ns.Print(#missing .. " characters missing data:")
  for _, line in ipairs(missing) do
    print(line)
  end
end, "List characters missing data")

ns:registerCommand("missing", "me", function(self)
  local patch = select(1, GetBuildInfo())
  local toon = self.currentData
  local missing = {}

  if not toon.playtime or not toon.playtime.total then
    table.insert(missing, "playtime")
  elseif not toon.playtime.byPatch or not toon.playtime.byPatch[patch] then
    table.insert(missing, "playtime (this patch)")
  end

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

  if #missing > 0 then
    ns.Print("Missing: " .. table.concat(missing, ", "))
  else
    ns.Print("No missing data.")
  end
end, "List the current character's missing data")
