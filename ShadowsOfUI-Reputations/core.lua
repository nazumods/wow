---@class ShadowsOfUI_Reputations: AddOn
local ns = LibNAddOn(...)

local floor = math.floor
local LABEL = NORMAL_FONT_COLOR
local MUTED = GRAY_FONT_COLOR
local DONE = GREEN_FONT_COLOR
local VAL = WHITE_FONT_COLOR
local PARAGON = "|cff66b3ffParagon|r"
local MAX = 12 -- character lines before collapsing into "+N more"
local MIN_NAME = 5 -- ignore very short faction names when matching item tooltips (false-positive guard)

-- Wrap a character name in its class colour (ns.Colors keys are PascalCase, matching classKey).
---@param name string
---@param classKey string?
function ns.ColorName(name, classKey)
  local c = classKey and ns.Colors[classKey]
  if not c or not c[1] then return name end
  return ("|cff%02x%02x%02x%s|r"):format(floor(c[1] * 255 + 0.5), floor(c[2] * 255 + 0.5), floor(c[3] * 255 + 0.5), name)
end

-- Append the "Standing across your warband" block for one faction to a tooltip: one
-- class-coloured line per character (highest standing first), the value green when maxed,
-- a blue "Paragon" marker when earning paragon rewards. Returns false (no block) when no
-- character has any standing with the faction. Shared by the item + reputation-panel hooks.
---@return boolean appended
function ns.AppendStandings(tooltip, factionID)
  local list = ns.api:GetFactionStandings(factionID)
  if not list then return false end
  tooltip:AddLine(LABEL:WrapTextInColorCode("Standing across your warband:"))
  local shown = #list > MAX and MAX - 1 or #list
  for i = 1, shown do
    local e = list[i]
    local val = (e.done and DONE or VAL):WrapTextInColorCode(e.label)
    if e.paragon then val = val .. " " .. PARAGON end
    tooltip:AddDoubleLine("  " .. ns.ColorName(e.name, e.classKey), val)
  end
  if #list > shown then
    tooltip:AddLine(MUTED:WrapTextInColorCode(("  +%d more"):format(#list - shown)))
  end
  return true
end

-- lowercased faction name -> factionID, built from every tracked character's cached
-- reputations (the union of names seen across the account). Rebuilt each login.
local nameIndex

function ns.RebuildFactionIndex()
  nameIndex = {}
  for _, c in ipairs(ns.api:GetAllCharacters()) do
    local reps = ns.api:GetReputations(c.name)
    if reps then
      for fid, f in pairs(reps) do
        if f.name and #f.name >= MIN_NAME then nameIndex[f.name:lower()] = fid end
      end
    end
  end
end

-- The factionID of a tracked faction whose name appears in the given (lowercased) text, or
-- nil. Returns the longest match so "Council of Dornogal" wins over a nested shorter name.
-- Heuristic, but the cached names and the live tooltip share the client's locale.
---@param text string lowercased
---@return integer?
function ns.FactionIDByName(text)
  if not nameIndex then ns.RebuildFactionIndex() end
  local bestId, bestLen
  for name, fid in pairs(nameIndex) do
    if text:find(name, 1, true) and (not bestLen or #name > bestLen) then
      bestId, bestLen = fid, #name
    end
  end
  return bestId
end

-- On login: refresh the name index (alts seen since last build) and make sure the
-- reputation-panel hook is installed (panel.lua may load before the frame mixin exists).
ns.onLogin = function()
  ns.RebuildFactionIndex()
  if ns.InstallPanelHook then ns.InstallPanelHook() end
end
