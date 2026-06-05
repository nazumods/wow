---@class Warbandeer
local ns = select(2, ...)
---@class LibNUI
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
      ui.ShowCharacterTooltip(toon, self, {
        TopLeft = {self, ui.edge.Bottom, 20, -10},
      })
    end,
    onLeave = function(self) ui.HideCharacterTooltip() end,
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
  return {
    text = text,
    justifyH = Left,
    color = {1, 1, 1, 0.6},
    onEnter = function(self)
      ui.tip:AnchorTo(self, "ANCHOR_BOTTOMRIGHT", -10, 10)
      ui.tip:ClearLines()
      ui.tip:AddLine(maxN.." at max level")
      ui.tip:AddLine(lvlN.." levelling")
      ui.tip:Show()
    end,
    onLeave = function(self) ui.tip:Hide() end,
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
