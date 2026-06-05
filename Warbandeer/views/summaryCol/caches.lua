---@class Warbandeer
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui
local Icons = ns.icons

-- caches
table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    icon = Icons.Treasure,
    tooltip = {
      "Weekly cache quests completed",
      "Count of weekly activities completed that reward a cache.",
    },
    getData = function(t) return t.weeklies and t.weeklies.caches and t.weeklies.caches > 0 and {text = t.weeklies.caches, justifyH = ui.justify.Center} or "" end,
  }
)
