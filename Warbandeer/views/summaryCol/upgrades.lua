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
local GetItemTex = (C_Item and C_Item.GetItemIconByID) or _G.GetItemIcon

local getUpgrades = function(toon)
  local list = ShadowsOfUI_UpgradeApi:CharacterUpgrades(toon.name)
  local n = #list
  -- no upgrades available reads as a muted em-dash (n/a)
  if n == 0 then return ns.ZeroDash end

  -- Pre-build hover lines, best gains first.  Each leads with the item's icon and
  -- its link (the quality-coloured [Item Name]) — not the slot — so the hover says
  -- *what* the upgrade is, plus its ilvl.  An item whose required level is above
  -- this character's gets a trailing "@ <reqLevel>" so it's clear it isn't
  -- equippable yet:
  --   "[icon] [Amulet of the Naaru]  +95 ilvl  (i720, held, good stats) @ 80"
  local level = toon.basic.level or 0
  local lines = {}
  -- Track whether any listed upgrade is equippable *right now* — at or below the
  -- character's level (location doesn't matter: a warband-bank copy can be
  -- withdrawn and equipped) — so the count can read green ("act on this now")
  -- rather than the default gold (every upgrade still gated above their level).
  local readyNow = false
  for _, r in ipairs(list) do
    local where = r.betterElsewhere and "warband (better)"
      or (r.where == "warband" and "warband" or "held")
    local tag = r.statTag == "good" and ", good stats"
      or (r.statTag == "off" and ", off-stats" or "")
    local swap = r.pairSwap and ", weapon swap" or ""
    local icon = GetItemTex and GetItemTex(r.link)
    local tex = icon and ("|T%d:14:14|t "):format(icon) or ""
    -- Required level comes from the data layer's scan-time capture (reliable for
    -- cold/offline alts + right after a reload); fall back to the live lookup only
    -- for candidates cached before that field existed.
    local reqLevel = r.reqLevel or select(5, C_Item.GetItemInfo(r.link))
    local belowReq = reqLevel and reqLevel > level
    local req = belowReq and (" @ %d"):format(reqLevel) or ""
    if not belowReq then readyNow = true end
    insert(lines, ("%s%s  +%d ilvl  (i%d, %s%s%s)%s"):format(
      tex, r.link, r.ilvlGain, r.ilvl, where, tag, swap, req))
  end

  return {
    text = tostring(n),
    color = readyNow and theme.colors.green or WARBAND,
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
    key = "upgrades", label = "Upgrades",
    name = "Up",
    width = 26,
    justifyH = ui.justify.Right,
    tooltip = "Gear upgrades available (in bags/bank or warband bank)",
    getData = getUpgrades,
  }
)
