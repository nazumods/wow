---@class Warbandeer
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui

-- Find Lumber tracking spell (1256697)
table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    iconPath = "Interface\\AddOns\\Warbandeer\\icons\\axe.tga",
    iconColor = ns.theme.colors.muted,
    width = 30,
    justifyH = ui.justify.Center,
    tooltip = {
      "Find Lumber",
      "Green check when the character knows Find Lumber.",
    },
    getData = function(t)
      return t.quests and t.quests.LumberAxe and ns.GreenCheck or ""
    end,
  }
)
