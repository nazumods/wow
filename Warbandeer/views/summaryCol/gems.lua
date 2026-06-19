---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local insert = table.insert

-- Per-character "empty gem sockets" count column. Only added when ShadowsOfUI-Upgrade
-- is loaded (OptionalDep). Counts empty sockets across equipped gear (from the data
-- layer's stored per-slot count, so it's warband-wide). Only meaningful at max level
-- (you gem the gear you're keeping), so below-max characters read a muted em-dash and a
-- fully-socketed max-level character a green check. Hover lists the slots + the one
-- recommended gem (ClassCodex per-spec, else the bundled top-stat pick).
if not ShadowsOfUI_UpgradeApi or not ShadowsOfUI_UpgradeApi.MissingGems then return end

local GetItemTex = (C_Item and C_Item.GetItemIconByID) or _G.GetItemIcon

local getData = function(toon)
  if (toon.basic.level or 0) < ns.wow.maxLevel then return ns.ZeroDashC end

  local list = ShadowsOfUI_UpgradeApi:MissingGems(toon.name)
  if #list == 0 then return ns.GreenCheck end

  -- Total empty sockets (a slot can have more than one).
  local empty = 0
  local lines = {}
  for _, e in ipairs(list) do
    empty = empty + e.sockets
    local icon = GetItemTex and GetItemTex(e.link)
    local tex = icon and ("|T%d:14:14|t "):format(icon) or ""
    local count = e.sockets > 1 and (" ×%d"):format(e.sockets) or ""
    insert(lines, ("%s%s  %s%s"):format(tex, e.link, e.slot, count))
  end
  -- Recommended gems, shown once under the slot list: the unique diamond (one) + a fill gem.
  local gemPrimary, gemSecondary = ns.RecommendedGems(toon.name)

  return {
    text = tostring(empty),
    color = ns.CappedColor,
    justifyH = ui.justify.Center,
    fontInfo = ns.theme.fonts.number,
    onEnter = function(self)
      ns.AnchorTip(self)
      ui.tip:ClearLines()
      ui.tip:AddLine(("%d empty gem socket%s"):format(empty, empty == 1 and "" or "s"))
      for _, l in ipairs(lines) do ui.tip:AddLine(l) end
      if gemPrimary then
        ui.tip:AddLine(("|cff808080Recommended:|r |cff4fc3f7%s|r ×1, then |cffb0b0b0%s|r"):format(gemPrimary, gemSecondary or "?"))
      elseif gemSecondary then
        ui.tip:AddLine(("|cff808080Recommended:|r |cffb0b0b0%s|r"):format(gemSecondary))
      end
      ui.tip:Show()
    end,
    onLeave = function() ui.tip:Hide() end,
    onClick = function() ns:view("detail") end,
  }
end

insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    key = "gems", label = "Empty Sockets",
    name = "Gem",
    width = 32,
    justifyH = ui.justify.Center,
    tooltip = "Equipped gear with empty gem sockets",
    getData = getData,
  }
)
