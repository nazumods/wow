---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local insert = table.insert

-- Per-character "missing permanent enchants" count column. Only added when
-- ShadowsOfUI-Upgrade is loaded (OptionalDep — it publishes ShadowsOfUI_UpgradeApi
-- and, via Warbandeer's OptionalDeps, loads before this file). Counts equipped
-- enchantable slots that carry no enchant; hover lists them. Only meaningful at
-- max level (you enchant the gear you're keeping), so below-max characters read a
-- muted em-dash (n/a) and a fully-enchanted max-level character a green check.
if not ShadowsOfUI_UpgradeApi then return end

local GetItemTex = (C_Item and C_Item.GetItemIconByID) or _G.GetItemIcon

local getData = function(toon)
  if (toon.basic.level or 0) < ns.wow.maxLevel then return ns.ZeroDashC end

  local list = ShadowsOfUI_UpgradeApi:MissingEnchants(toon.name)
  local n = #list
  if n == 0 then return ns.GreenCheck end

  -- Pre-build hover lines: each leads with the unenchanted item's icon + its link
  -- (the quality-coloured [Item Name]) and the slot it sits in.
  local lines = {}
  for _, e in ipairs(list) do
    local icon = GetItemTex and GetItemTex(e.link)
    local tex = icon and ("|T%d:14:14|t "):format(icon) or ""
    insert(lines, ("%s%s  %s"):format(tex, e.link, e.slot))
  end

  return {
    text = tostring(n),
    color = ns.CappedColor,
    justifyH = ui.justify.Center,
    fontInfo = ns.theme.fonts.number,
    onEnter = function(self)
      ns.AnchorTip(self)
      ui.tip:ClearLines()
      ui.tip:AddLine(("%d slot%s missing an enchant"):format(n, n == 1 and "" or "s"))
      for _, l in ipairs(lines) do ui.tip:AddLine(l) end
      ui.tip:Show()
    end,
    onLeave = function() ui.tip:Hide() end,
    onClick = function() ns:view("detail") end,
  }
end

insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    name = "Ench",
    width = 32,
    justifyH = ui.justify.Center,
    tooltip = "Equipped slots missing a permanent enchant",
    getData = getData,
  }
)
