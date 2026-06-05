---@class Warbandeer
local ns = select(2, ...)

-- level
table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    name = "Lvl",
    width = 20,
    getData = function(t) return t.basic.level end,
  }
)
