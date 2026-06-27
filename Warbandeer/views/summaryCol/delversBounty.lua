---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui

-- Delver's Bounty — the weekly delve treasure (quest 86371). Green check once a
-- character has claimed it this week; a muted em-dash for a max-level character
-- who hasn't yet (below-max stays blank, matching the other weekly-chore columns).
table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    key = "delversBounty", label = "Delver's Bounty",
    iconPath = "Interface\\AddOns\\Warbandeer\\icons\\delversBounty.tga",
    iconColor = ns.theme.colors.muted,
    width = 30,
    justifyH = ui.justify.Center,
    tooltip = {
      "Delver's Bounty",
      "Weekly delve treasure. Green check once claimed this week.",
    },
    getData = function(t)
      if t.weeklies and t.weeklies.delversBounty then return ns.GreenCheck end
      return t.basic.level >= ns.wow.maxLevel and ns.ZeroDashC or ""
    end,
  }
)
