---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui

-- caches
table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    iconPath = "Interface\\AddOns\\Warbandeer\\icons\\chest.tga",
    iconColor = ns.theme.colors.muted,
    width = 30,
    justifyH = ui.justify.Center,
    tooltip = {
      "Weekly cache quests completed",
      "Count of weekly activities completed that reward a cache.",
    },
    getData = function(t)
      return t.weeklies and t.weeklies.caches and t.weeklies.caches > 0
        and {text = t.weeklies.caches, justifyH = ui.justify.Center} or ""
    end,
  }
)
