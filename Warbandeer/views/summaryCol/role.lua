---@type Warbandeer
local ns = select(2, ...)
local Icons = ns.icons

-- role
table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    padLeft = 2,
    getData = function(toon)
      local role = toon.basic.specialization and Icons[toon.basic.specialization.role]
      return role and ns.SummaryIconCell(role) or ""
    end,
  }
)
