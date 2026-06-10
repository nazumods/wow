---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui

-- restored coffer keys (+ shards as fractional, 100 shards = 1 key)
table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    iconPath = "Interface\\AddOns\\Warbandeer\\icons\\key.tga",
    iconColor = ns.theme.colors.muted,
    width = 40,
    justifyH = ui.justify.Center,
    tooltip = {
      "Restored Coffer Keys",
      "Keys + shards/100 as a fractional total. Red when shards are capped.",
    },
    getData = function(t)
      if not t.currency then return "" end
      local keys = t.currency.RestoredCofferKey or 0
      local shards = t.currency.CofferKeyShard
      local shardQty = shards and shards.quantity or 0
      if keys == 0 and shardQty == 0 then return "" end
      return {
        text = ("%.2f"):format(keys + shardQty / 100),
        justifyH = ui.justify.Right,
        fontInfo = ns.theme.fonts.number,
        color = shards and shards.capped and ns.CappedColor or ns.UncappedColor,
      }
    end,
  }
)
