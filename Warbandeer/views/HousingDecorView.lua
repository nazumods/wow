---@type Warbandeer
local ns = select(2, ...)
local ui = ns.ui
local theme = ns.theme
local Class, Frame, Label = ns.lua.Class, ui.Frame, ui.Label

-- Housing decor collection grid. The grid itself is the sibling Warbandeer_Decor
-- addon's own list, reused in `embedded` mode via the WarbandeerHousingDecorApi global
-- (OptionalDep) — one source of truth, maintained in Warbandeer_Decor/list.lua.
-- This view owns only the surrounding chrome: the filter strip and the header counter.
--
-- The whole view is registered (see the bottom of the file) only when the Housing Decor
-- addon is loaded, so the grid is always present once a HousingDecorView is built.

-- The live view instance, captured so the scan/ratings listeners refresh this view.
local _view

local CONTENT_W = 470   -- view content width
local LIST_H = 470      -- list viewport height (the windowed list scrolls internally)

---@class HousingDecorView: Frame
---@field grid HousingDecorList  the shared decor list (the sibling addon's own list, embedded)
---@field filterStrip Frame      the shared filter chrome row
---@field counter Label          "N / N collected" counter (filter-scoped)
---@field wantedCount Label      running "star N" wanted tally
---@field emptyMsg Label         shown before the catalog has been scanned
local HousingDecorView = Class(Frame, function(self)
  _view = self
  local api = WarbandeerHousingDecorApi
  local STRIP_H, GAP, HEADER_H = api.List.STRIP_H, 6, 20
  local TOP = STRIP_H + GAP + HEADER_H

  self.grid = api.List:new{
    parent = self,
    position = { TopLeft = { 0, -TOP }, Width = CONTENT_W, Height = LIST_H },
    embedded = true,
    -- Recompute the counter after any filter change (VisibleCounts is filter-scoped).
    onFilterChanged = function() _view:RefreshCounter() end,
  }

  self.filterStrip = self.grid:BuildFilterStrip(self)
  self.filterStrip:Position({ TopLeft = { 0, 0 } })

  -- Counter band between the filter strip and the list.
  local hdrPad = (HEADER_H - theme.fonts.title[2]) / 2
  self.counter = Label:new{
    parent = self, fontInfo = theme.fonts.title, color = theme.colors.text, text = "",
    position = { TopLeft = { self.filterStrip, ui.edge.BottomLeft, 2, -(GAP + hdrPad) } },
  }
  self.wantedCount = Label:new{
    parent = self, fontInfo = theme.fonts.title, color = theme.colors.gold, text = "",
    position = { Left = { self.counter, ui.edge.Right, 16, 0 } },
  }
  -- The gold wanted tally toggles WANTED ONLY on click.
  local wantedHover = Frame:new{
    parent = self,
    position = {
      TopLeft = { self.wantedCount, ui.edge.TopLeft, -2, 2 },
      BottomRight = { self.wantedCount, ui.edge.BottomRight, 2, -2 },
    },
  }
  wantedHover:EnableMouse(true)
  wantedHover:SetScript("OnMouseUp", function() self.grid:ToggleWantedOnly() end)

  self.emptyMsg = Label:new{
    parent = self, fontInfo = theme.fonts.body, color = theme.colors.muted, justifyH = ui.justify.Center,
    wordWrap = true,
    position = { Top = { 0, -(TOP + 28) }, Width = CONTENT_W, Height = 40, Hide = true },
    text = "Loading the housing catalog...",
  }

  self:RefreshCounter()
  self:RefreshWanted()
  self:Width(CONTENT_W + 6)
  self:Height(TOP + LIST_H + 4)
end, {
  name = "decor",
  background = theme.colors.window,
})
HousingDecorView.name = "decor"
HousingDecorView._title = "Housing Decor"

-- Only surface the view (nav icon, minimap menu, and slash command all derive from
-- ns.views) when the sibling Housing Decor addon is loaded — the whole view is its data.
-- OptionalDeps load before us, so the API global is already set here when present.
if WarbandeerHousingDecorApi and WarbandeerHousingDecorApi.List then
  ns.views.HousingDecorView = HousingDecorView
end

-- Live-refresh the view when a scan rebuilds the snapshot, or a wanted flag changes
-- anywhere (this grid or the standalone /decor window). Registered once at load.
if WarbandeerHousingDecorApi and WarbandeerHousingDecorApi.OnScanned then
  WarbandeerHousingDecorApi:OnScanned(function()
    if _view then _view.grid:Render(); _view:RefreshWanted() end
  end)
end
if WarbandeerHousingDecorApi and WarbandeerHousingDecorApi.OnRatingsChanged then
  WarbandeerHousingDecorApi:OnRatingsChanged(function()
    if _view then _view.grid:Render(); _view:RefreshWanted() end
  end)
end

-- Refresh counts + grid each time the view shows (so a scan run while it was hidden is
-- reflected on next open).
function HousingDecorView:OnBeforeShow()
  self.grid:Render()
  self:RefreshWanted()
end

-- Refresh the "N / N collected" counter (owned / shown for the current filter), or hide
-- the grid behind the empty-state message until the first scan populates the snapshot.
-- Guarded so the grid's construction-time Render is a no-op until this Label exists.
function HousingDecorView:RefreshCounter()
  if not self.counter then return end
  local api = WarbandeerHousingDecorApi
  if not api:IsScanned() then
    self.counter:Text("")
    self.grid:SetShown(false)
    self.emptyMsg:Show()
    return
  end
  self.emptyMsg:Hide()
  self.grid:SetShown(true)
  local shown, collected = self.grid:VisibleCounts()
  self.counter:Text(("%d / %d collected"):format(collected, shown))
end

-- Refresh the running wanted tally (gold star + N), matching the /decor window.
function HousingDecorView:RefreshWanted()
  local api = WarbandeerHousingDecorApi
  self.wantedCount:Text(("|A:%s:14:14|a %d"):format(api.WantedIcon, api:WantedCount()))
end
