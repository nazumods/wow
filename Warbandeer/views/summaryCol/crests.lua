---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui

local CREST_ICON = "Interface\\AddOns\\Warbandeer\\icons\\"
-- match the muted tan of the other (text) column headers
local CREST_TINT = ns.theme.colors.muted

local function formatCrest(c)
  if not c then return "" end
  -- stale DB entries from before the table migration store a bare number
  if type(c) == "number" then
    return c > 0 and {text = c, justifyH = ui.justify.Right} or ""
  end
  if c.quantity == 0 then return "" end
  -- No cell tooltip: the count + cap color already convey everything the
  -- per-cell breakdown did. Header tooltip still explains the column.
  return {
    text     = c.quantity,
    justifyH = ui.justify.Right,
    color    = c.capped and ns.CappedColor or ns.UncappedColor,
  }
end

-- Hero Dawncrest
table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    iconPath    = CREST_ICON .. "crest_hero.tga",
    iconColor   = CREST_TINT,
    iconOffsetX = 8,
    width = 30,
    justifyH = ui.justify.Center,
    tooltip = {"Hero Dawncrest", "Hero Dawncrest held. Red when weekly cap reached."},
    getData = function(t)
      if not t.currency then return "" end
      return formatCrest(t.currency.HeroDawncrest)
    end,
  }
)

-- Myth Dawncrest
table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    iconPath    = CREST_ICON .. "crest_myth.tga",
    iconColor   = CREST_TINT,
    iconOffsetX = 5,
    width = 30,
    justifyH = ui.justify.Center,
    tooltip = {"Myth Dawncrest", "Myth Dawncrest held. Red when weekly cap reached."},
    getData = function(t)
      if not t.currency then return "" end
      return formatCrest(t.currency.MythDawncrest)
    end,
  }
)
