---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local min, max = math.min, math.max
local Class, TitleFrame, ScrollFrame, Label = ns.lua.Class, ui.TitleFrame, ui.ScrollFrame, ui.Label
local DataView = ns.DataView
local GameTooltip = GameTooltip

-- This window must match Warbandeer's embedded collected view 1:1 (size + coloring),
-- so it renders the same shared DataView grid and counter/toggle chrome in the same
-- void-dark theme. That theme lives in the main Warbandeer addon and is published on
-- LibNUI's shared `ui.themes` registry; when it isn't loaded (Collected running on
-- its own) we fall back to the LibNUI default and the chrome degrades gracefully.
local function collectedTheme()
  return ui.themes["void-dark"] or ui.themes.dark
end

---Top-level Collected window: titled frame holding the DataView grid and a sets counter.
---@class CollectedWindow: TitleFrame
---@field data DataView the sets-by-class grid
---@field scroll ScrollFrame scroll container for the grid's row area
---@field counter Label "N sets · N appearances · N collected" counter (shrunk in PTR mode)
---@field wantedCount Label running "★ N" wanted-set count
---@field filterStrip Frame the shared filter chrome row (DataView:BuildFilterStrip)
---@field _top number grid top offset (filter strip + gap) — _fitToGrid re-derives the height from it
local MainWindow = Class(TitleFrame, function(self)
  -- The window is themed in `ns:Open` (so the titlebar inherits it too); read it back
  -- here for the counter chrome.
  local theme = self:Theme()
  local gold = theme.colors.gold or theme.colors.header
  local titleFont = theme.fonts.title
  local STRIP_H, GAP = DataView.STRIP_H, 6
  local TOP = STRIP_H + GAP   -- the grid sits below the filter strip
  self._top = TOP             -- _fitToGrid re-derives the window height from it
  local w = 110

  self.data = DataView:new{
    parent = self,                           -- inherits the window's theme
    position = {
      TopLeft = {self.titlebar, ui.edge.BottomLeft, 2, -2 - TOP},
      TopRight = {self.titlebar, ui.edge.BottomRight, -2, -2 - TOP},
    },
    colInfo = DataView.BuildColInfo(false),  -- windowed: includes the lock column
    -- Refresh this window's wanted tally after a Shift-click toggle in the grid.
    onWantedToggle = function() self:RefreshWanted() end,
    -- Recompute the set/appearance/collected counter when the wanted-only filter flips
    -- (VisibleCounts is filter-scoped), so it tracks the rows actually shown.
    onFilterChanged = function() self:RefreshCounter() end,
    -- Refit the window to the (filtered) row count so the scroll range can't overscroll.
    onResized = function() self:_fitToGrid() end,
    -- Scroll the dressed-set row into view (VerticalScroll clamps out-of-range targets).
    onEnsureVisible = function(_, rowTop, rowH)
      local s = self.scroll
      local cur, view = s:VerticalScroll(), s:Height()
      if rowTop < cur then s:VerticalScroll(rowTop)
      elseif rowTop + rowH > cur + view then s:VerticalScroll(rowTop + rowH - view) end
    end,
  }
  w = max(w, self.data:Width() + 4)

  -- Shared filter strip (PTR / Wanted / Sort toggles + Expansion / Category dropdowns)
  -- below the titlebar; the PTR toggle refreshes this window's mode counter.
  self.filterStrip = self.data:BuildFilterStrip(self, function() self:RefreshCounter() end)
  self.filterStrip:Position({ TopLeft = {self.titlebar, ui.edge.BottomLeft, 2, -2} })

  self.scroll = ScrollFrame:new{
    parent = self,
    position = {
      TopLeft = {self.titlebar, ui.edge.BottomLeft, 2, -2 - TOP - self.data.headerHeight},
      BottomRight = {self, ui.edge.BottomRight, -2, 2},
    },
  }
  self.scroll:Child(self.data.rowArea)

  -- Counter rides the grid's header row, over the group-name column and in line with
  -- the class icons (matches the embedded view); gold wanted tally to its right.
  local hdrPad = (self.data.headerHeight - (titleFont and titleFont[2] or 14)) / 2
  self.counter = Label:new{
    parent = self, fontInfo = titleFont, color = theme.colors.text,
    position = { TopLeft = {self.data, ui.edge.TopLeft, 2, -hdrPad} },
    text = "",
  }
  self.wantedCount = Label:new{
    parent = self, fontInfo = titleFont, color = gold,
    position = { Left = {self.counter, ui.edge.Right, 16, 0} },
    text = "",
  }

  -- A FontString can't take mouse events, so overlay a transparent frame on the counter
  -- to host its hover tooltip (anchored to the label, so it tracks the text width).
  local counterHover = ui.Frame:new{
    parent = self,
    position = {
      TopLeft = {self.counter, ui.edge.TopLeft, 0, 0},
      BottomRight = {self.counter, ui.edge.BottomRight, 0, 0},
    },
  }
  counterHover:EnableMouse(true)
  counterHover:SetScript("OnEnter", function(f) self.data:ShowCountTooltip(f) end)
  counterHover:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- The gold wanted tally toggles WANTED ONLY on click (same as the filter button).
  local wantedHover = ui.Frame:new{
    parent = self,
    position = {
      TopLeft = {self.wantedCount, ui.edge.TopLeft, -2, 0},
      BottomRight = {self.wantedCount, ui.edge.BottomRight, 2, 0},
    },
  }
  wantedHover:EnableMouse(true)
  wantedHover:SetScript("OnMouseUp", function() self.data:ToggleWanted() end)
  wantedHover:SetScript("OnEnter", function(f) self.data:ShowWantedTooltip(f) end)
  wantedHover:SetScript("OnLeave", function() GameTooltip:Hide() end)

  self:RefreshCounter()
  self:RefreshWanted()
  self:_fitToGrid()
  self:Width(w)
end, {
  name = ns._NAME,
  title = ns._TITLE,
  -- Match Warbandeer's main window surface (≈ the LibNUI dark window, slightly translucent).
  background = {0.11372549019, 0.14117647058, 0.16470588235, 0.92},
  position = {
    Center = {},
  },
  special = true,
  level = 580,
})

---Cap the visible grid at the shared `DataView.MAX_HEIGHT` and size the window with the
---same header + cap + margin math as the embedded view, plus the filter strip. Called at
---construction and again on every filter/PTR change (via the grid's `onResized` hook), so
---the window shrinks to the filtered row count and the scroll range refits — no overscroll.
function MainWindow:_fitToGrid()
  local capH = min(self.data.MAX_HEIGHT, self.data.rowArea:Height())
  self:Height(self.titlebar:Height() + self._top + self.data.headerHeight + capH + 4)
  self.scroll:Refresh()   -- the scroll frame tracks the window's BottomRight; recompute its range
end

---Refresh the running wanted-set count in the header. The star is drawn from the
---shared WantedIcon atlas (not a literal glyph, which the header font can't render).
function MainWindow:RefreshWanted()
  self.wantedCount:Text(("|A:%s:14:14|a %d"):format(ns.WantedIcon, ns:WantedCount()))
end

---Refresh the counter: "N sets · N appearances · N collected" in live mode (rows shown / grid
---cells with a set / green-check cells, tracking the active filter via VisibleCounts); in
---PTR PREVIEW mode the grid is only the upcoming sets, so it becomes a "+N upcoming" tally.
function MainWindow:RefreshCounter()
  if self.data._ptr then
    local seen, n = {}, 0
    for _, grp in ipairs(ns.PtrSets) do
      for _, set in ipairs(grp.sets) do
        if set.id and not seen[set.id] then seen[set.id] = true; n = n + 1 end
      end
    end
    self.counter:Text(("+%d sets upcoming%s"):format(n, ns.PtrBuild and (" · PTR " .. ns.PtrBuild.ptr) or ""))
  else
    local sets, cells, green = self.data:VisibleCounts()
    self.counter:Text(("%d sets · %d appearances · %d collected"):format(sets, cells, green))
  end
  -- The PTR line (with the build) is longer than the live count, so shrink the counter
  -- font in PTR mode to keep it clear of the class icons (matches the embedded view).
  local titleFont = collectedTheme().fonts.title
  if titleFont then
    self.counter:Font(self.data._ptr and {titleFont[1], 12} or titleFont)
  end
end

-- Live-refresh this window's grid + wanted counter when a rating changes anywhere
-- (e.g. via the shared dressing room). No-op until the window has been opened.
ns:OnRatingsChanged(function()
  if not ns.window then return end
  local grid = ns.window.data
  if grid._wantedOnly then
    grid.data = grid:GetData(); grid:update()             -- re-filter (row set may change)
    if grid.onResized then grid:onResized() end           -- refit the window to the new count
  else grid:_refreshMarks() end
  ns.window:RefreshWanted()
end)

-- Draw the cell cursor on the set currently shown in the shared dressing room, and
-- follow it as the user arrow-navigates (nil clears on close). No-op until opened.
ns:OnDressedSetChanged(function(setId, classIndex)
  if not ns.window then return end
  ns.window.data:HighlightSet(setId, classIndex, true)
end)

---@class Warbandeer_Collected
---@field window CollectedWindow? main window (nil until first opened)
ns.window = nil
---Open the main window, creating it on first use.
function ns:Open()
  if not ns.window then
    -- Theme the whole window (titlebar included) to match Warbandeer's collected view;
    -- the explicit opaque `background` (in defaults) overrides the theme's alpha-0
    -- `window` token so the surface stays solid. Resolved here, not in the class
    -- defaults, since the void-dark theme registers only once Warbandeer has loaded.
    ns.window = MainWindow:new{ theme = collectedTheme() }
    ns.window:RememberPosition(ns.db.windowPos)   -- restore + persist the user's dragged position
  else
    ns.window:Show()
  end
end

---Addon-compartment click handler: right-click rescans, anything else opens the window.
---@param btn string "LeftButton"|"RightButton"|"MiddleButton"
function ns:CompartmentClick(btn) -- buttonName = (LeftButton | RightButton | MiddleButton)
  if btn == "RightButton" then
    ns:Scan()
  else
    self:Open()
  end
end
