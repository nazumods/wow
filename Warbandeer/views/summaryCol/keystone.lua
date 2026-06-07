---@class Warbandeer
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui

-- M+ keystone level
table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    name = "M+",
    width = 28,
    justifyH = ui.justify.Right,
    tooltip = {
      "Mythic+ Keystone",
      "Current keystone level held by this character.",
    },
    getData = function(t)
      local k = t.weeklies and t.weeklies.keystone
      if not k then return "" end
      return {text = "+"..k, justifyH = ui.justify.Right}
    end,
  }
)
