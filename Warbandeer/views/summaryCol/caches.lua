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
      local n = t.weeklies and t.weeklies.caches or 0
      -- known 0 at max level reads as a muted em-dash; below-max stays empty
      if n == 0 then return t.basic.level >= ns.wow.maxLevel and ns.ZeroDash or "" end
      return {text = n, justifyH = ui.justify.Center}
    end,
  }
)
