---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui

-- xp: current XP as a percent of the level's total. Hidden at max level.
local function getXpPercent(toon)
  if toon.basic.level >= ns.wow.maxLevel then return "" end
  local xp = toon.basic.xp
  if not xp then return "" end
  local pct = math.floor(xp.percent * 100 + 0.5)
  return {
    text = pct.."%",
    justifyH = ui.justify.Right,
    fontInfo = ns.theme.fonts.number,
  }
end

table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    key = "xp", label = "XP",
    name = "XP",
    width = 35,
    justifyH = ui.justify.Right,
    tooltip = {
      "XP",
      "Current experience as a percent of the level's total. Hidden for max-level characters.",
    },
    getData = getXpPercent,
  }
)
