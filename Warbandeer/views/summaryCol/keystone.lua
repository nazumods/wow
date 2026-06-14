---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
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
      -- no key at max level reads as a muted em-dash; below-max stays empty
      if not k then return t.basic.level >= ns.wow.maxLevel and ns.ZeroDash or "" end
      return {text = "+"..k, justifyH = ui.justify.Right}
    end,
  }
)
