---@type Warbandeer
local ns = select(2, ...)
local min = math.min
local ui = ns.ui
local theme = ns.theme
local Class, Frame, Label = ns.lua.Class, ui.Frame, ui.Label
local GameTooltip = GameTooltip

-- Transmog-set collection grid. The grid itself is the sibling Collected addon's
-- own DataView, reused in `embedded` mode via the WarbandeerCollectedApi global
-- (OptionalDep) — one source of truth, maintained in Collected/DataView.lua. This
-- view owns only the surrounding chrome: the filter strip (DataView:BuildFilterStrip),
-- the scroll container, and the header counters. Embedded mode drops the lock column /
-- lockout side-panel — see Collected's own /collected window for those.
--
-- The whole view is only registered (see the bottom of the file) when the Collected
-- addon is loaded, so the grid is always present once a CollectedView is built.

local SCROLLBAR_W  = 20

-- The live view instance, captured so the grid's wanted-toggle hook and the
-- ratings-changed listener can refresh this view's header.
local _view

---@class CollectedView: Frame
---@field grid DataView the shared set-by-class grid (Collected's own DataView, embedded)
---@field filterStrip Frame the shared filter chrome row (DataView:BuildFilterStrip)
---@field scroll ScrollFrame
---@field counter Label
---@field wantedCount Label running "★ N" wanted-set count (mirrors the /collected window)
---@field emptyMsg Label
---@field _top number grid top offset (filter strip + gap) — _fitToGrid re-derives the height from it
local CollectedView = Class(Frame, function(self)
  _view = self
  local STRIP_H, GAP = WarbandeerCollectedApi.DataView.STRIP_H, 6
  local TOP = STRIP_H + GAP   -- the grid sits below the filter strip
  self._top = TOP             -- _fitToGrid re-derives the view + scroll height from it

  self.grid = WarbandeerCollectedApi.DataView:new{
    parent = self,
    position = { TopLeft = {0, -TOP} },
    embedded = true,
    colInfo = WarbandeerCollectedApi.DataView.BuildColInfo(true),  -- no lock column
    -- Anchor the hover InfoTip on the configured side (shared with Overview's set
    -- cells); refresh this view's wanted tally after a Shift-click toggle.
    infoTipAnchor = ns.InfoTipPosition,
    onWantedToggle = function() _view:RefreshWanted() end,
    -- Refit the scroll container to the (filtered) row count so it can't overscroll.
    onResized = function() _view:_fitToGrid() end,
  }

  -- Shared filter strip (PTR / Wanted / Sort toggles + Expansion / Category dropdowns)
  -- along the top; the PTR toggle re-renders this view so its mode counter updates.
  self.filterStrip = self.grid:BuildFilterStrip(self, function() _view:_render() end)
  self.filterStrip:Position({ TopLeft = {0, 0} })

  local headerH = self.grid.headerHeight
  local capH = min(self.grid.MAX_HEIGHT, self.grid.rowArea:Height())
  local gridW = self.grid:Width()

  self.scroll = ui.ScrollFrame:new{
    parent = self,
    position = {
      TopLeft = {0, -(TOP + headerH)},
      Width   = gridW,
      Height  = capH,
    },
  }
  self.scroll:Child(self.grid.rowArea)

  -- Counter rides the grid's header row (over the name column, in line with the class
  -- icons), below the filter strip. Created after the grid so it draws above the header.
  local hdrPad = (headerH - theme.fonts.title[2]) / 2
  self.counter = Label:new{
    parent = self, fontInfo = theme.fonts.title, color = theme.colors.text,
    position = { TopLeft = {2, -(TOP + hdrPad)} },
    text = "",
  }
  self.wantedCount = Label:new{
    parent = self, fontInfo = theme.fonts.title, color = theme.colors.gold,
    position = { Left = {self.counter, ui.edge.Right, 16, 0} },
    text = "",
  }

  -- A FontString can't take mouse events, so overlay a transparent frame on the counter
  -- to host its hover tooltip (anchored to the label, so it tracks the text width).
  local counterHover = Frame:new{
    parent = self,
    position = {
      TopLeft = {self.counter, ui.edge.TopLeft, 0, 0},
      BottomRight = {self.counter, ui.edge.BottomRight, 0, 0},
    },
  }
  counterHover:EnableMouse(true)
  counterHover:SetScript("OnEnter", function(f) self.grid:ShowCountTooltip(f) end)
  counterHover:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- The gold wanted tally toggles WANTED ONLY on click (same as the filter button).
  local wantedHover = Frame:new{
    parent = self,
    position = {
      TopLeft = {self.wantedCount, ui.edge.TopLeft, -2, 0},
      BottomRight = {self.wantedCount, ui.edge.BottomRight, 2, 0},
    },
  }
  wantedHover:EnableMouse(true)
  wantedHover:SetScript("OnMouseUp", function() self.grid:ToggleWanted() end)
  wantedHover:SetScript("OnEnter", function(f) self.grid:ShowWantedTooltip(f) end)
  wantedHover:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- Shown before the first /collected scan has populated any data. Centered below the
  -- header; the grid is hidden while it shows (see _showGrid) so it never overlaps the
  -- static row names.
  self.emptyMsg = Label:new{
    parent = self, fontInfo = theme.fonts.body, color = theme.colors.muted,
    justifyH = ui.justify.Center,
    position = { Top = {0, -(TOP + headerH + 28)}, Width = gridW, Height = 20, Hide = true },
  }

  self:Width(gridW + SCROLLBAR_W)
  self:_fitToGrid()
end, {})
CollectedView.name = "collected"
CollectedView._title = "Collected"

-- Only surface the view (nav icon, minimap menu, and slash command all derive from
-- ns.views) when the sibling Collected addon is loaded — the whole view is its data.
-- OptionalDeps load before us, so the API global is already set here when present.
if WarbandeerCollectedApi and WarbandeerCollectedApi.DataView then
  ns.views.CollectedView = CollectedView
end

-- Live-refresh this view's grid when a rating changes in the shared dressing room
-- (registered once at load; Collected loads first via the OptionalDep order).
if WarbandeerCollectedApi and WarbandeerCollectedApi.OnRatingsChanged then
  WarbandeerCollectedApi:OnRatingsChanged(function()
    local g = _view and _view.grid
    if not g then return end
    if g._wantedOnly then g.data = g:GetData(); g:update() else g:_refreshMarks() end
    _view:RefreshWanted()
  end)
end

-- Refresh counts, grid data, and the empty-state message each time the view shows
-- (so a /collected scan run after the view was built is reflected on next open).
function CollectedView:OnBeforeShow()
  self:_render()
end

-- Cap the visible grid at the shared `DataView.MAX_HEIGHT` and size the scroll container
-- (and the view) to match. Called at construction and again on every filter/PTR change
-- (via the grid's `onResized` hook), so the scroll range tracks the filtered row count and
-- can't overscroll into empty space below the rows.
function CollectedView:_fitToGrid()
  local capH = min(self.grid.MAX_HEIGHT, self.grid.rowArea:Height())
  self.scroll:Height(capH)
  self:Height(self._top + self.grid.headerHeight + capH + 4)
  self.scroll:Refresh()   -- recompute the scroll range for the new child height
end

-- Show/hide the grid (header icons + scrolling rows) as a unit, so the empty-state
-- message can take over a clear area instead of overlapping the static row names.
function CollectedView:_showGrid(shown)
  self.grid:SetShown(shown)
  self.scroll:SetShown(shown)
end

-- Hide the grid and show the centered empty-state message with the given text.
function CollectedView:_showEmpty(text)
  self:_showGrid(false)
  self.emptyMsg:Text(text)
  self.emptyMsg:Show()
end

-- Render the active dataset. PTR PREVIEW shows only the upcoming sets (no scan
-- needed for the upcoming rows); live-only mode shows collected/total and needs a scan.
function CollectedView:_render()
  local api = WarbandeerCollectedApi
  local ptr = self.grid._ptr
  if not ptr and not api:IsScanned() then
    self.counter:Text("")
    self.wantedCount:Text("")
    self:_showEmpty("Run /collected scan to populate")
    return
  end
  self.emptyMsg:Hide()
  self:_showGrid(true)
  if ptr then
    local seen, n = {}, 0
    for _, grp in ipairs(api.PtrSets or {}) do
      for _, set in ipairs(grp.sets) do
        if set.id and not seen[set.id] then seen[set.id] = true; n = n + 1 end
      end
    end
    self.counter:Text(("+%d sets upcoming%s"):format(n, api.PtrBuild and (" · PTR " .. api.PtrBuild.ptr) or ""))
  else
    local sets, cells, green = self.grid:VisibleCounts()   -- tracks the active expansion/category filter
    self.counter:Text(("%d sets · %d appearances · %d collected"):format(sets, cells, green))
  end
  -- The PTR line (with the build) is longer than the live count, so shrink the counter
  -- font in PTR mode so it stays within the name column, clear of the class icons.
  self.counter:Font(ptr and {theme.fonts.title[1], 12} or theme.fonts.title)
  self:RefreshWanted()
  self.grid.data = self.grid:GetData()
  self.grid:update()
end

-- Refresh the running wanted-set count in the header (gold star + N), matching the
-- /collected window. The star is drawn from the shared WantedIcon atlas rather than
-- a literal glyph so it renders in the body font.
function CollectedView:RefreshWanted()
  local api = WarbandeerCollectedApi
  self.wantedCount:Text(("|A:%s:14:14|a %d"):format(api.WantedIcon, api:WantedCount()))
end

