---@class Warbandeer
local ns = select(2, ...)

-- level
table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    name = "Lvl",
    width = 25,
    justifyH = ns.ui.justify.Right,
    getData = function(t) return { text = t.basic.level, justifyH = ns.ui.justify.Right } end,
  }
)
