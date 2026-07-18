---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui

-- M+ keystone level
table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    key = "keystone", label = "Mythic+",
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
      -- The narrow cell only fits "+level"; the dungeon lives in a per-cell tooltip. Resolve its
      -- name from the stored challenge-map id at render time (client-global). Older data (or an
      -- alt not seen since v41) lacks the map — fall back to a level-only tooltip.
      local map = t.weeklies.keystoneMap
      local name = map and C_ChallengeMode.GetMapUIInfo(map)
      return {
        text = "+"..k,
        justifyH = ui.justify.Right,
        onEnter = function(self)
          ns.AnchorTip(self)
          ui.tip:ClearLines()
          ui.tip:AddLine("Mythic+ Keystone")
          if name then ui.tip:AddLine(name, 1, 1, 1) end
          ui.tip:AddLine(("Keystone: |cffffffff+%d|r"):format(k))
          ui.tip:Show()
        end,
        onLeave = function() ui.tip:Hide() end,
      }
    end,
  }
)
