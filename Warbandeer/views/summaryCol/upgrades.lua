---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local insert = table.insert

-- Per-character "available gear upgrades" count column.  Only added when
-- ShadowsOfUI-Upgrade is loaded (OptionalDep — it publishes ShadowsOfUI_UpgradeApi
-- and, via Warbandeer's OptionalDeps, loads before this file).  Counts slots with
-- an available upgrade (held in the character's own bags/bank, or a better one in
-- the warband bank); hover lists them.
if not ShadowsOfUI_UpgradeApi then return end

local theme = ns.theme
local WARBAND = theme.colors.gold

local getUpgrades = function(toon)
  local list = ShadowsOfUI_UpgradeApi:CharacterUpgrades(toon.name)
  local n = #list
  -- no upgrades available reads as a muted em-dash (n/a)
  if n == 0 then return ns.ZeroDash end

  -- Pre-build hover lines, best gains first.  Each names the actual upgrade item
  -- (its link renders as the quality-coloured [Item Name]) and its ilvl, so the
  -- hover says *what* the upgrade is, not just which slot:
  --   "Neck:  [Amulet of the Naaru]  +95 ilvl  (i720, held, good stats)"
  local lines = {}
  for _, r in ipairs(list) do
    local where = r.betterElsewhere and "warband (better)"
      or (r.where == "warband" and "warband" or "held")
    local tag = r.statTag == "good" and ", good stats"
      or (r.statTag == "off" and ", off-stats" or "")
    local swap = r.pairSwap and ", weapon swap" or ""
    insert(lines, ("%s:  %s  +%d ilvl  (i%d, %s%s%s)"):format(
      r.slot, r.link, r.ilvlGain, r.ilvl, where, tag, swap))
  end

  return {
    text = tostring(n),
    color = WARBAND,
    justifyH = ui.justify.Right,
    fontInfo = theme.fonts.number,
    onEnter = function(self)
      ns.AnchorTip(self)
      ui.tip:ClearLines()
      ui.tip:AddLine(("%d gear upgrade%s available"):format(n, n == 1 and "" or "s"))
      for _, l in ipairs(lines) do ui.tip:AddLine(l) end
      ui.tip:Show()
    end,
    onLeave = function() ui.tip:Hide() end,
    onClick = function() ns:view("gear") end,
  }
end

insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    name = "Up",
    width = 26,
    justifyH = ui.justify.Right,
    tooltip = "Gear upgrades available (in bags/bank or warband bank)",
    getData = getUpgrades,
  }
)
