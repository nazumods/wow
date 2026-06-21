---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local ITEM_STANDARD_COLOR = ITEM_STANDARD_COLOR

local getILvlString = function(toon)
  local lines = ns.IlvlTooltipLines(toon)
  return {
    text = (toon.basic.level or 0) < ns.wow.maxLevel and ITEM_STANDARD_COLOR:WrapTextInColorCode(ns.ilvlOf(toon)) or ns.IlvlColor(ns.ilvlOf(toon)),
    justifyH = ui.justify.Right,
    fontInfo = ns.theme.fonts.number,
    onEnter = function(self)
      ns.AnchorTip(self)
      ui.tip:ClearLines()
      for _,l in ipairs(lines) do ui.tip:AddLine(l) end
      ui.tip:Show()
    end,
    onLeave = function(self) ui.tip:Hide() end,
    onClick = function() ns:view("gear") end,
  }
end

table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    name = "iLvl",
    width = 30,
    justifyH = ui.justify.Right,
    getData = getILvlString,
  }
)
