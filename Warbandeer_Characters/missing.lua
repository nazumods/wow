---@type Warbandeer_Characters
local _, ns = ...
local GetBuildInfo = GetBuildInfo -- luacheck: globals GetBuildInfo

local patch = false

-- True when the stored profession detail shows the character has trained the
-- current expansion's skill line.  Only then is recipe capture expected, so only
-- then does a nil recipes table mean "missing data" rather than "not trained yet".
local function hasCurrentExpSkill(detail)
  if not detail or not detail.expansions then return false end
  for _, exp in ipairs(detail.expansions) do
    if exp.name == ns.CURRENT_RECIPE_EXP and (exp.maxSkillLevel or 0) > 0 then
      return true
    end
  end
  return false
end

function ns.getMissingFields(toon)
  if not patch then patch = select(1, GetBuildInfo()) end
  local missing = {}

  -- gold/total are recorded numbers; 0 is valid data (a broke or freshly-tracked
  -- character), so only a nil means the value was never captured.
  if not toon.currency or toon.currency.gold == nil then
    table.insert(missing, "gold")
  end

  if not toon.playtime or toon.playtime.total == nil then
    table.insert(missing, "playtime")
  elseif not toon.playtime.byPatch or toon.playtime.byPatch[patch] == nil then
    table.insert(missing, "playtime (this patch)")
  end

  if not toon.lastRefresh then table.insert(missing, "lastRefresh") end

  -- LumberAxe is a recorded boolean (has / doesn't have the Find Lumber tracking
  -- spell), so only a nil means the data was never captured. false is real data.
  if not toon.quests or toon.quests.LumberAxe == nil then
    table.insert(missing, "lumber axe")
  end

  if toon.basic and toon.basic.level == ns.wow.maxLevel then
    if toon.equipment and toon.equipment.slots and not toon.equipment.trackScanned then
      table.insert(missing, "upgrade track data")
    end
    if not toon.currency or toon.currency.HeroDawncrest == nil then
      table.insert(missing, "hero dawncrest")
    end
    if not toon.currency or toon.currency.MythDawncrest == nil then
      table.insert(missing, "myth dawncrest")
    end
  end

  if toon.basic and toon.basic.professions then
    local details = toon.professions and toon.professions.details
    local missingProfs, missingRecipes = {}, {}
    for _, prof in ipairs({ toon.basic.professions.primary, toon.basic.professions.secondary,
                              toon.basic.professions.fishing, toon.basic.professions.cooking }) do
      if prof and prof.name and prof.skillID then
        local detail = details and details[prof.skillID]
        if not detail then
          table.insert(missingProfs, prof.name)
        elseif not detail.recipes and hasCurrentExpSkill(detail) then
          -- Trained the current expansion but recipes weren't captured: detail
          -- predates recipe tracking, or the prof window hasn't been reopened since.
          -- (A character that simply hasn't trained the current-expansion skill is
          -- intentionally not reported here — that's expected, not missing data.)
          table.insert(missingRecipes, prof.name)
        end
      end
    end
    if #missingProfs > 0 then
      table.insert(missing, "professions (" .. table.concat(missingProfs, ", ") .. ")")
    end
    if #missingRecipes > 0 then
      table.insert(missing, "recipes (" .. table.concat(missingRecipes, ", ") .. ")")
    end
  end

  return missing
end
local getMissingFields = ns.getMissingFields

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
