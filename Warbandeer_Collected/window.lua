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
  self.counter = Label:new{
    parent = self, fontInfo = titleFont, color = theme.colors.text,
    -- The counter rides the filter-strip row (right of the dropdowns) in both modes — matching the
    -- weapon view — so the grid header row is just the class icons.
    position = { TopLeft = {self.filterStrip, ui.edge.TopRight, 12, -3} },
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
  counterHover:SetScript("OnEnter", function(f) (self.active or self.data):ShowCountTooltip(f) end)
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

  -- ── Armor / Weapons mode ──────────────────────────────────────────────────
  -- A second grid (WeaponView) with its own strip + scroll, hidden until toggled. The
  -- persistent Armor/Weapons segmented toggle (far left of the strip row) swaps which trio is
  -- shown via SetMode. Armor is the default and stays fully intact when Weapons is off; the two
  -- grids overlap (same anchors), so only their SetShown state differs.
  self.active, self.activeScroll, self._weaponsMode = self.data, self.scroll, false
  local TOGGLE_W, TGAP = 92, 6

  self.weapons = ns.WeaponView:new{
    parent = self,
    position = {
      TopLeft = {self.titlebar, ui.edge.BottomLeft, 2, -2 - TOP},
      TopRight = {self.titlebar, ui.edge.BottomRight, -2, -2 - TOP},
    },
    colInfo = ns.WeaponView.BuildColInfo(),
    onResized = function() self:_fitToGrid() end,
    -- Scroll the dressed-weapon row into view (weaponScroll is assigned just below; the
    -- closure only reads it at highlight time, by which point it exists).
    onEnsureVisible = function(_, rowTop, rowH)
      local s = self.weaponScroll
      local cur, view = s:VerticalScroll(), s:Height()
      if rowTop < cur then s:VerticalScroll(rowTop)
      elseif rowTop + rowH > cur + view then s:VerticalScroll(rowTop + rowH - view) end
    end,
  }
  self.weapons:Hide()   -- SetMode resizes the window to the active grid's width, so the window
                        -- starts at the armor width and widens on the toggle to Weapons.

  self.weaponStrip = self.weapons:BuildFilterStrip(self, function() self:RefreshCounter() end)
  self.weaponStrip:Position({ TopLeft = {self.titlebar, ui.edge.BottomLeft, 2 + TOGGLE_W + TGAP, -2} })
  self.weaponStrip:Hide()

  self.weaponScroll = ScrollFrame:new{
    parent = self,
    position = {
      TopLeft = {self.titlebar, ui.edge.BottomLeft, 2, -2 - TOP - self.weapons.headerHeight},
      BottomRight = {self, ui.edge.BottomRight, -2, 2},
    },
  }
  self.weaponScroll:Child(self.weapons.rowArea)
  self.weaponScroll:Hide()

  -- Shift the armor strip right to clear the persistent toggle at the far left.
  self.filterStrip:Position({ TopLeft = {self.titlebar, ui.edge.BottomLeft, 2 + TOGGLE_W + TGAP, -2} })

  -- The persistent Armor/Weapons segmented toggle (two halves; the active half gets the gold
  -- border). Built through the shared `ns.ModeToggle` because the dressing room carries the same
  -- control (#653) and two hand-rolled copies of one toggle would drift.
  self._modeToggle = ns.ModeToggle{
    parent = self, theme = theme, width = TOGGLE_W, height = STRIP_H, weapons = false,
    position = { TopLeft = {self.titlebar, ui.edge.BottomLeft, 2, -2} },
    onClick = function(weapons) self:SetMode(weapons) end,
  }

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

---Switch the window between the armor grid and the weapon grid (the Armor/Weapons toggle).
---Swaps which (grid + strip + scroll) trio is shown, re-points the counter + scroll refit at the
---active grid, hides the armor-only wanted tally, recolors the toggle, and resizes to the active
---grid's width. No-op if already in the requested mode.
---@param weapons boolean
function MainWindow:SetMode(weapons)
  if self._weaponsMode == weapons then return end
  self._weaponsMode = weapons
  self.active = weapons and self.weapons or self.data
  self.activeScroll = weapons and self.weaponScroll or self.scroll
  -- Carry the PTR PREVIEW state across the Armor/Weapons swap so it reads as one window-level mode:
  -- the grid being shown adopts the mode of the one being hidden (SetPtr repaints its own toggle).
  local prevGrid = weapons and self.data or self.weapons
  if self.active._ptr ~= prevGrid._ptr then self.active:SetPtr(prevGrid._ptr) end
  self.data:SetShown(not weapons); self.filterStrip:SetShown(not weapons); self.scroll:SetShown(not weapons)
  self.weapons:SetShown(weapons); self.weaponStrip:SetShown(weapons); self.weaponScroll:SetShown(weapons)
  self.wantedCount:SetShown(not weapons)   -- the wanted tally is armor-only
  self._modeToggle:Select(weapons)
  -- The weapon name column is too narrow to hold the counter over the header, so in weapon mode
  -- the counter rides the strip row (right of the dropdowns); armor keeps it over the header.
  self.counter:Position(weapons and { TopLeft = {self.weaponStrip, ui.edge.TopRight, 12, -3} }
    or { TopLeft = {self.filterStrip, ui.edge.TopRight, 12, -3} })
  self:Width(max(110, self.active:Width() + (weapons and 20 or 4)))   -- +scrollbar room in weapon mode
  self:RefreshCounter()
  self:_fitToGrid()
  -- The preview window is deliberately NOT touched here (#673). It used to be: with two dolls, one
  -- per view, the toggle had to swap which was on screen or toggling back to Armor left a weapon on
  -- the model (#656). There is one doll now — the armour set and the browsed weapon are on it
  -- together — so there is nothing to swap, and this is back to what it says it is: which grid is
  -- shown, and nothing else. Every other action is on the one model viewer.
end

---Cap the visible grid at the shared `DataView.MAX_HEIGHT` and size the window with the
---same header + cap + margin math as the embedded view, plus the filter strip. Called at
---construction and again on every filter/PTR change (via the grid's `onResized` hook), so
---the window shrinks to the filtered row count and the scroll range refits — no overscroll.
function MainWindow:_fitToGrid()
  local grid, scroll = self.active or self.data, self.activeScroll or self.scroll
  local capH = min(grid.MAX_HEIGHT, grid.rowArea:Height())
  self:Height(self.titlebar:Height() + self._top + grid.headerHeight + capH + 4)
  scroll:Refresh()   -- the scroll frame tracks the window's BottomRight; recompute its range
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
  if self._weaponsMode then
    if self.weapons._ptr then
      -- PTR PREVIEW: the weapon grid is only the upcoming (not-yet-live) appearances, so the counter
      -- becomes a "+N appearances upcoming" tally rather than a collected count.
      local n, ptrBuild = self.weapons:UpcomingCounts()
      self.counter:Text(("+%d appearances upcoming%s"):format(n, ptrBuild and (" · PTR " .. ptrBuild) or ""))
    else
      local sources, apps, coll = self.weapons:VisibleCounts()
      self.counter:Text(("%d sources · %d/%d collected"):format(sources, coll, apps))
    end
    local tf = collectedTheme().fonts.title
    if tf then self.counter:Font({tf[1], 12}) end
    return
  end
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
    self.counter:Text(("%d sets · %d/%d collected"):format(sets, green, cells))
  end
  -- The counter sits in the strip row in every mode, so keep it at the compact strip font.
  local titleFont = collectedTheme().fonts.title
  if titleFont then self.counter:Font({titleFont[1], 12}) end
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

-- Same for the Weapons grid: box the (source, type) cell of the weapon currently in the
-- dressing room, following ←/→ type-stepping (nil clears on close / when an armor set is shown).
ns:OnDressedWeaponCellChanged(function(source, weaponType)
  if not ns.window then return end
  ns.window.weapons:HighlightWeaponCell(source, weaponType, true)
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
