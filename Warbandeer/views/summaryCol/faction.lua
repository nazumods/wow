---@type Warbandeer
local ns = select(2, ...)

-- faction
table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    getData = function(toon) return ns.SummaryIconCell(ns.factionIcon[toon.isAlliance]) end,
  }
)
