---@type Warbandeer
local ns = select(2, ...)
local ui = ns.ui
local Class, Frame, Label, Texture = ns.lua.Class, ui.Frame, ui.Label, ui.Texture
local StatCard = ns.StatCard
local theme = ns.theme
local BreakUpLargeNumbers = BreakUpLargeNumbers
local GetBuildInfo = GetBuildInfo

-- Sub-widgets live in views/overview/ (loaded first) and register on ns.overview:
-- FactionBars (reputation bars), TopAlts (top-character gear table + its marks), and
-- Achievements (per-expansion checklist). RAIDS is the raid-picker config (owned by
-- TopAlts, used here by BuildFilter).
local FactionBars = ns.overview.FactionBars
local Achievements = ns.overview.Achievements
local TopAlts = ns.overview.TopAlts

local P, GAP, STRIP_H, HEAD_H = 12, 8, 64, 16
local TREND_ICON = "Interface\\AddOns\\Warbandeer\\icons\\"

-- caps label used for section headers ("REPUTATIONS", "TOP CHARACTERS", ...)
local function capsHeader(parent, text, position)
  return Label:new{
    parent = parent,
    fontInfo = theme.fonts.caps,
    color = theme.colors.muted,
    text = text:upper(),
    position = position,
  }
end

-- Build one expansion's content into `panel`: a Reputations box (left) and an
-- Achievements box (right), each under its own caps header. The two sit a box-gap
-- (GAP*2) apart so each can carry its own module background. Returns the reps and
-- achievements section sizes (width, height) for the caller to size those boxes.
local function buildTab(panel, expansionLevel, extraFactionIDs, achievementIds)
  capsHeader(panel, "Reputations", { TopLeft = {0, 0} })
  local bars = FactionBars:new{
    parent = panel,
    expansionLevel = expansionLevel,
    extraFactionIDs = extraFactionIDs,
    position = { TopLeft = {0, -HEAD_H} },
  }
  -- Achievements is moved into its own equal-thirds column by the caller once the
  -- shared column width is known; the X here is a placeholder.
  local achHead = capsHeader(panel, "Achievements", { TopLeft = {0, 0} })
  local ach = Achievements:new{
    parent = panel,
    achievementIds = achievementIds,
    position = { TopLeft = {0, -HEAD_H} },
  }
  panel._ach = ach -- reachable for the cold-session font heal (ns.HealCellFonts)
  return bars:Width(), bars:Height(), ach:Width(), ach:Height(), achHead
end

-- Expansions selectable via the titlebar dropdown. Each builds its own
-- Reputations + Achievements panel; only the selected one is shown.
local EXPANSIONS = {
  { key = "midnight", label = "Midnight",       expansionLevel = 11, extraFactionIDs = {}, achievementIds = ns.overview.midnightAchievementIds },
  { key = "wwi",      label = "The War Within", expansionLevel = 10, extraFactionIDs = {}, achievementIds = ns.overview.wwiAchievementIds },
}

-- Overview
---@class Overview: Frame
---@field topAlts TopAlts
---@field _panels table<string, Frame>   expansion key -> reps+achievements panel
---@field _repsH table<string, number>   expansion key -> reputations section height
---@field _achH table<string, number>    expansion key -> achievements section height
---@field _altH number                   Top Characters section height
---@field _contentW number               total content width (excl. outer padding)
---@field _contentTop number             Y offset where the panels start
---@field _modReps Texture               reputations module background
---@field _modAch Texture                achievements module background
---@field _expansion string?             currently selected expansion key
---@field _filter FilterDropdown?        titlebar expansion picker
-- The live view instance, captured so the ratings-changed listener (registered once,
-- below) refreshes whichever Top Characters table currently exists.
local _view
local Overview = Class(Frame, function(self)
  _view = self
  local c = theme.colors
  local BLEED = 6                        -- module/strip outer bleed (matches module bg padding)
  local contentTop = P + STRIP_H + GAP
  self._contentTop = contentTop

  -- Reputations + Achievements, one panel per expansion. Each panel holds a reps
  -- box (left) and an achievements box (right); panels share the same anchor and
  -- only the selected one is shown. The two module backgrounds are siblings of the
  -- panels and resize to the active expansion's section heights.
  self._panels, self._repsH, self._achH = {}, {}, {}
  local repsW, achW = 0, 0
  local achHeads = {}                    -- expansion key -> achievements caps header
  for _, e in ipairs(EXPANSIONS) do
    local panel = Frame:new{
      parent = self,
      position = { TopLeft = {P, -contentTop}, Hide = true },
    }
    local bw, bh, aw, ah, achHead = buildTab(panel, e.expansionLevel, e.extraFactionIDs, e.achievementIds)
    panel:Height(HEAD_H + math.max(bh, ah))
    self._panels[e.key] = panel
    self._repsH[e.key] = HEAD_H + bh
    self._achH[e.key]  = HEAD_H + ah
    repsW = math.max(repsW, bw)
    achW  = math.max(achW, aw)
    achHeads[e.key] = achHead
  end

  -- Top Characters header + table — built at a placeholder X, moved to its column below.
  local topHead = capsHeader(self, "Top Characters", { TopLeft = {P, -contentTop} })
  self.topAlts = TopAlts:new{
    parent = self,
    position = { TopLeft = {P, -(contentTop + HEAD_H)} },
  }
  self._altH = HEAD_H + self.topAlts:Height()

  -- Equal thirds: every section gets the same box width — the widest natural column —
  -- laid out left→right with a box-gap between, so the three sections line up as a clean
  -- grid (each content frame left-aligned in its column) instead of staggering to its
  -- own content width.
  local colW = math.max(repsW, achW, self.topAlts:Width())
  local col0, col1, col2 = P, P + colW + GAP * 2, P + 2 * (colW + GAP * 2)

  -- shift each expansion's achievements box into column 1 (local X relative to the
  -- panel, which is anchored at col0); the panel spans columns 0–1 (reps + ach).
  for key, panel in pairs(self._panels) do
    local achHead = achHeads[key]
    achHead:ClearAllPoints();    achHead:TopLeft(col1 - P, 0)
    panel._ach:ClearAllPoints(); panel._ach:TopLeft(col1 - P, -HEAD_H)
    panel:Width(2 * colW + GAP * 2)
  end

  -- move Top Characters into column 2.
  topHead:ClearAllPoints();      topHead:TopLeft(col2, -contentTop)
  self.topAlts:ClearAllPoints(); self.topAlts:TopLeft(col2, -(contentTop + HEAD_H))

  self._contentW = (col2 - P) + colW

  -- module backgrounds (parent textures render behind the child content frames); each
  -- section gets an equal-width box. Reps + ach are resized per selection (height only).
  self._modReps = Texture:new{
    parent = self, layer = ui.layer.Artwork, color = c.module,
    position = { TopLeft = {col0 - 6, -(contentTop - 6)}, Width = colW + 12, Height = 12 },
  }
  self._modAch = Texture:new{
    parent = self, layer = ui.layer.Artwork, color = c.module,
    position = { TopLeft = {col1 - 6, -(contentTop - 6)}, Width = colW + 12, Height = 12 },
  }
  Texture:new{
    parent = self, layer = ui.layer.Artwork, color = c.module,
    position = { TopLeft = {col2 - 6, -(contentTop - 6)}, Width = colW + 12, Height = self._altH + 12 },
  }

  -- Stat strip — one card per content column, each overlaying its column's box.
  local cardX = {col0, col1, col2}

  -- this-patch played time = each char's total minus its /played snapshot taken at
  -- first login on the current patch (PlaytimeBroker.byPatch); chars that never logged
  -- in this patch have no snapshot and contribute nothing.
  local patch = GetBuildInfo()
  local playSecs, patchSecs, topIlvl, count = 0, 0, 0, 0
  for _, toon in ipairs(ns.api.GetAllCharacters()) do
    count = count + 1
    local pt = toon.playtime
    if pt and pt.total then
      playSecs = playSecs + pt.total
      local snap = pt.byPatch and pt.byPatch[patch]
      if snap then patchSecs = patchSecs + (pt.total - snap) end
    end
    if toon.equipment and toon.equipment.ilvl and toon.equipment.ilvl > topIlvl then
      topIlvl = toon.equipment.ilvl
    end
  end

  local function card(i, caption, amount, amountColor, sub, subIcon, subColor)
    return StatCard:new{
      parent = self,
      caption = caption,
      amount = amount,
      amountColor = amountColor,
      sub = sub,
      subIcon = subIcon,
      subColor = subColor,
      subIconColor = subColor,
      position = { TopLeft = {cardX[i] - BLEED, -BLEED}, Width = colW + BLEED * 2, Height = STRIP_H },
    }
  end
  -- wealth includes the warband (account) bank, not just per-character gold
  local wealth = ns.api.GetWarbandWealth()
  local madeCopper = ns.api.GetWeeklyGoldMade()
  local madeGold = math.floor(madeCopper / 10000)
  local madeSub, trendIcon, trendColor
  if madeGold ~= 0 then
    madeSub = (madeGold > 0 and "+" or "") .. ns.wow.GoldString(madeCopper) .. "g this week"
    trendIcon = TREND_ICON .. (madeGold > 0 and "trending_up.tga" or "trending_down.tga")
    trendColor = madeGold > 0 and c.green or c.red
  end
  card(1, "Total Warband Wealth", ns.wow.GoldString(wealth) .. "g", c.gold,
       madeSub, trendIcon, trendColor)
  card(2, "Total Playtime", BreakUpLargeNumbers(math.floor(playSecs / 3600)) .. " hrs", c.text,
       BreakUpLargeNumbers(math.floor(patchSecs / 3600)) .. " hrs this patch · " .. count .. " chars")
  card(3, "Top Item Level", tostring(topIlvl), ns.IlvlColorObj(topIlvl))

  self:selectExpansion(EXPANSIONS[1].key)

  -- Cold-session render glitch: cell FontStrings in the two TableFrames above can
  -- rasterize blank on the first UI load of a client session, even though text,
  -- size, visibility, and font all report correct (and the rest of the view
  -- renders fine). A *real* font change forces the client to re-rasterize them —
  -- a same-params SetFont is a no-op — so one tick after construction every cell
  -- label's font is swapped away and back. Invisible and idempotent.
  ns:after(50, function()
    ns.HealCellFonts(self.topAlts)
    for _, panel in pairs(self._panels) do ns.HealCellFonts(panel._ach) end
  end)
end, {
  name = "overview",
  background = theme.colors.window,
})
Overview.name = "overview"
Overview._title = "Overview"
ns.views.Overview = Overview

-- Live-refresh the Top Characters rating overlays when a rating changes in the shared
-- dressing room (registered once at load; Collected loads first via the OptionalDep
-- order). Mirrors CollectedView's own ratings-changed refresher. The Overview has no
-- wanted-only filter, so a mark re-apply is always enough.
if WarbandeerCollectedApi and WarbandeerCollectedApi.OnRatingsChanged then
  WarbandeerCollectedApi:OnRatingsChanged(function()
    local t = _view and _view.topAlts
    if t then t:_refreshMarks() end
  end)
end

-- Show the panel for `key`, size the reps + achievements boxes and the view to it,
-- and refit the window so the shorter expansion doesn't leave dead space below.
---@param key string
function Overview:selectExpansion(key)
  for k, panel in pairs(self._panels) do
    panel:SetShown(k == key)
  end
  self._expansion = key
  local repsH, achH = self._repsH[key], self._achH[key]
  self._modReps:Height(repsH + 12)
  self._modAch:Height(achH + 12)
  self:Width(P + self._contentW + P)
  self:Height(self._contentTop + math.max(repsH, achH, self._altH) + P)
  if self.parent and self.parent.Fit then self.parent:Fit() end
end

-- Refresh the Top Characters gear columns each time the view shows, so a
-- /collected scan run after the view was built is reflected on next open.
function Overview:OnBeforeShow()
  if self.topAlts then self.topAlts:Refresh() end
  -- Recolour achievement checklists so a mid-session earn shows without a /reload.
  for _, panel in pairs(self._panels) do
    if panel._ach then panel._ach:Refresh() end
  end
end

-- Titlebar pickers (shown only while the Overview is active): a raid picker for the
-- Top Characters gear columns (left) and the reps/achievements expansion picker
-- (right). Both sit in one container anchored by its right edge to the close button.
---@param parent Frame
---@return Frame
function Overview:BuildFilter(parent)
  local box = Frame:new{ parent = parent, position = { Height = 20 } }

  local raid = ui.FilterDropdown:new{
    parent    = box,
    bordered  = true,
    options   = ns.overview.RAIDS,
    selected  = self.topAlts._raidId,
    width     = 110,
    menuWidth = 120,
    onSelect  = function(_, key) self.topAlts:SetRaid(key) end,
    position  = { TopLeft = {0, 0} },
  }
  local exp = ui.FilterDropdown:new{
    parent    = box,
    bordered  = true,
    options   = EXPANSIONS,
    selected  = self._expansion,
    width     = 112,
    menuWidth = 130,
    onSelect  = function(_, key) self:selectExpansion(key) end,
    position  = { TopLeft = {raid, ui.edge.TopRight, GAP, 0} },
  }

  box:Width(raid:Width() + GAP + exp:Width())
  self._filter = box
  return box
end
