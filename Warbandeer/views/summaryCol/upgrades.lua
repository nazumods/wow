---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local insert, remove = table.insert, table.remove

-- Per-character "available gear upgrades" count column.  Only added when
-- ShadowsOfUI-Upgrade is loaded (OptionalDep — it publishes ShadowsOfUI_UpgradeApi
-- and, via Warbandeer's OptionalDeps, loads before this file).  Counts slots with
-- an available upgrade (held in the character's own bags/bank, or a better one in
-- the warband bank); hover lists them.
if not ShadowsOfUI_UpgradeApi then return end

local theme = ns.theme
local WARBAND = theme.colors.gold
local GetItemTex = (C_Item and C_Item.GetItemIconByID) or _G.GetItemIcon

-- Building a character's upgrade list scans its bags/bank + the warband bank and
-- evaluates every candidate — far too heavy to run for *every* character while the
-- Summary view renders.  Done synchronously it trips the "script ran too long"
-- watchdog, especially when the window is opened from a secure path (an action
-- button / macro → UseAction), which runs on a tighter budget.  So the column
-- computes lazily off the render frame: a cold cell shows a muted placeholder and
-- enqueues a compute (one character per tick); when the queue drains the view
-- refreshes once with the real counts.  Results are cached per character and reused
-- until the data layer rescans that character (keyed on `lastRefresh`).
local PLACEHOLDER = {
  text = "…", color = theme.colors.muted,
  justifyH = ui.justify.Right, fontInfo = theme.fonts.number,
}

local cache = {}      -- [name] = { refresh = number, payload = cell }
local pending = {}    -- [name] = true while queued / computing
local queue = {}      -- FIFO of character names awaiting a compute
local pumping = false
local refreshQueued = false
local STEP = 30       -- ms between per-character computes (one char per ~2 frames)

-- The expensive part: resolve a character's upgrade list and pre-build its hover
-- lines.  Each line leads with the item's icon + quality-coloured link (what the
-- upgrade *is*), its ilvl, and a trailing "@ <reqLevel>" when it isn't equippable
-- yet:  "[icon] [Amulet of the Naaru]  +95 ilvl  (i720, held, good stats) @ 80".
local function buildPayload(toon)
  local list = ShadowsOfUI_UpgradeApi:CharacterUpgrades(toon.name)
  local n = #list
  -- no upgrades available reads as a muted em-dash (n/a)
  if n == 0 then return ns.ZeroDash end

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

-- Coalesce the post-compute refresh into a single next-frame rebuild of the open
-- Summary view (mirrors init.lua's bank/gear refreshers).
local function scheduleRefresh()
  if refreshQueued then return end
  refreshQueued = true
  ns:after(0, function()
    refreshQueued = false
    local v = ns.MainWindow and ns.MainWindow:ShownView()
    if v and v.name == "summary" then
      v:OnBeforeShow()
      ns.MainWindow:Fit()
    end
  end)
end

-- Compute one queued character per tick, then refresh once the queue drains.
local function pump()
  local name = remove(queue, 1)
  if not name then
    pumping = false
    scheduleRefresh()
    return
  end
  local data = ns.api:GetCharacterData(name)
  if data then cache[name] = { refresh = data.lastRefresh, payload = buildPayload(data) } end
  pending[name] = nil
  ns:after(STEP, pump)
end

local getUpgrades = function(toon)
  local c = cache[toon.name]
  if c and c.refresh == toon.lastRefresh then return c.payload end
  -- Cold (or stale after a rescan): enqueue an off-frame compute and show a
  -- placeholder for now.
  if not pending[toon.name] then
    pending[toon.name] = true
    insert(queue, toon.name)
    if not pumping then pumping = true; ns:after(0, pump) end
  end
  return PLACEHOLDER
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
