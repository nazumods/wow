---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Left = ui.justify.Left

local function getNameString(toon)
  local current = ns.api.GetCurrentCharacter()
  local s = toon.name
  if s == current then
    s = s.." |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:14:14|t"
  end
  return {
    text = s,
    color = ns.Colors[toon.classKey or toon.className],
    onEnter = function(self)
      ns.ShowCharacterTooltip(toon, self)
    end,
    onLeave = function(self) ns.HideCharacterTooltip() end,
  }
end

-- footer: tally of max-level vs still-levelling characters
local getLevelFooter = function(toons)
  local maxN, lvlN = 0, 0
  for _,t in ipairs(toons) do
    if t.basic.level == ns.wow.maxLevel then maxN = maxN + 1 else lvlN = lvlN + 1 end
  end
  local text = maxN.." max"
  if lvlN > 0 then text = text..", "..lvlN.." lvl" end
  -- No footer tooltip: the "N max, M lvl" text already says it all.
  return {
    text = text,
    justifyH = Left,
    color = {1, 1, 1, 0.6},
  }
end

table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    padLeft = 2,
    name = "Character",
    width = 105,
    getData = getNameString,
    getFooter = getLevelFooter,
  }
)
