---@class Warbandeer
local ns = select(2, ...)
local Icons = ns.icons

-- faction
table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    getData = function(toon) return toon.isAlliance and Icons.AllianceLight or Icons.HordeLight end,
  }
)
