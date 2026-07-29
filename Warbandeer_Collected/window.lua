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
---@field wantedCount Label running "★ N" wanted tally — sets in armor mode, weapon looks in weapons mode
---@field filterStrip Frame the shared filter chrome row (DataView:BuildFilterStrip)
---@field weapons WeaponView? the weapon-source grid — nil until the first switch to Weapons builds it
---@field weaponStrip Frame? the weapon grid's filter strip (built with the grid)
---@field weaponScroll ScrollFrame? scroll container for the weapon grid's row area (built with the grid)
---@field _top number grid top offset (filter strip + gap) — _fitToGrid re-derives the height from it
---@field _stripX number filter-strip x offset, clearing the mode toggle; both strips share it
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
    onEnsureVisible = function(_, rowTop, rowH) ns.EnsureRowVisible(self.scroll, rowTop, rowH) end,
  }
  w = max(w, self.data:Width() + 4)

  -- Shared filter strip (PTR / Wanted / Sort toggles + Expansion / Category dropdowns)
  -- below the titlebar; the PTR toggle refreshes this window's mode counter.
  self.filterStrip = self.data:BuildFilterStrip(self, function() self:RefreshCounter() end)
  self.filterStrip:Position({ TopLeft = {self.titlebar, ui.edge.BottomLeft, 2, -2} })
  -- Both dropdowns' option lists walk the whole row source to build themselves, so the strip is a
  -- deferral candidate in its own right rather than a rounding error on the grid (see profile.lua).
  ns.prof:Mark("strip")

  self.scroll = ScrollFrame:new{
    parent = self,
    position = {
      TopLeft = {self.titlebar, ui.edge.BottomLeft, 2, -2 - TOP - self.data.headerHeight},
      BottomRight = {self, ui.edge.BottomRight, -2, 2},
    },
  }
  self.scroll:Child(self.data.rowArea)
  ns.prof:Mark("scroll")

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

  -- The gold wanted tally toggles WANTED ONLY on click (same as the filter button). It follows the
  -- ACTIVE grid: both grids now have a wanted filter of their own, over different units — sets on
  -- one side, individual weapon looks on the other (#689).
  local wantedHover = ui.Frame:new{
    parent = self,
    position = {
      TopLeft = {self.wantedCount, ui.edge.TopLeft, -2, 0},
      BottomRight = {self.wantedCount, ui.edge.BottomRight, 2, 0},
    },
  }
  wantedHover:EnableMouse(true)
  wantedHover:SetScript("OnMouseUp", function() (self.active or self.data):ToggleWanted() end)
  wantedHover:SetScript("OnEnter", function(f) (self.active or self.data):ShowWantedTooltip(f) end)
  wantedHover:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- ── Armor / Weapons mode ──────────────────────────────────────────────────
  -- A second grid (WeaponView) with its own strip + scroll, hidden until toggled. The
  -- persistent Armor/Weapons segmented toggle (far left of the strip row) swaps which trio is
  -- shown via SetMode. Armor is the default and stays fully intact when Weapons is off; the two
  -- grids overlap (same anchors), so only their SetShown state differs.
  self.active, self.activeScroll, self._weaponsMode = self.data, self.scroll, false
  -- The persistent Armor/Weapons segmented toggle (the active segment takes the gold rim).
  --
  -- `ui.SegmentedToggle` since #816. It was this addon's own builder, self-published so the embedded
  -- view could reach it; in LibNUI both hosts simply call it, and neither carries a copy for the
  -- version where the other doesn't have one.
  --
  -- Eager, unlike the grid it reveals: it IS the thing that asks for that grid.
  self._modeToggle = ui.SegmentedToggle:new{
    parent = self, height = STRIP_H, selected = "armor",
    options = { { key = "armor", label = "Armor" }, { key = "weapons", label = "Weapons" } },
    position = { TopLeft = {self.titlebar, ui.edge.BottomLeft, 2, -2} },
    onSelect = function(_, key)
      local weapons = key == "weapons"
      self:SetMode(weapons)
      -- The shared dressing room needs to know which grid is being browsed, for one rule: while a
      -- loaded look is on the doll its ratings row is hidden, a browsed weapon earns the row back,
      -- and switching to Armor without clicking a cell gives it up again (#827). From the handler
      -- rather than from `SetMode`, which early-returns when the click repeats the mode already in
      -- force; the builder used to carry this for both hosts, and can't now that it is a LibNUI
      -- widget with no knowledge of this addon.
      ns.SetGridMode(weapons)
    end,
    -- The toggle can only measure its captions once its fonts are resident and it has been laid
    -- out, so the width read below is a floor rather than the final answer. When it re-measures,
    -- re-place the strips against the real width.
    onResize = function() self:_applyStripX() end,
  }

  self:_applyStripX()
  ns.prof:Mark("chrome")

  -- `VisibleCounts` walks every group and set independently of the cells, so the counter is its own
  -- split — it is paid again on every mode swap, where nothing is being built at all.
  self:RefreshCounter()
  self:RefreshWanted()
  ns.prof:Mark("counter")
  self:_fitToGrid()
  self:Width(w)
  ns.prof:Mark("fit")
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

---Place both filter strips clear of the Armor/Weapons toggle, at the toggle's current width.
---
---Read back rather than declared: the toggle sizes itself to its captions, which is what stopped
---"Weapons" rendering as "Wea…" at a hand-picked 92 (#770 step 12). Re-run from its `onResize`,
---because a caption is only measurable once its font is resident and the window has been laid out —
---so the width available at construction is a floor, not the answer. The weapon strip is nil until
---`_ensureWeapons`, and picks the value up itself when built.
function MainWindow:_applyStripX()
  self._stripX = 2 + self._modeToggle:Width() + 6
  local at = { TopLeft = {self.titlebar, ui.edge.BottomLeft, self._stripX, -2} }
  self.filterStrip:Position(at)
  if self.weaponStrip then self.weaponStrip:Position(at) end
end

---Build the weapon grid + its filter strip and scroll container, once, on the first switch to
---Weapons mode. No-op afterwards.
---
---**Deferred deliberately (#770 step 19).** `ns.WeaponSources` is ~241 rows × 18 columns, so building
---it with the window cost every user roughly 4,300 `Cell` frames on the first `/collected` — on top
---of the armour grid's own ~6,600 — for a grid plenty of people never open. It is the one lazily
---built thing in this window, which is why the handful of "refresh both grids" callers go through
---`Grids()` and the dressed-cell hook nil-guards rather than assuming the trio exists.
function MainWindow:_ensureWeapons()
  if self.weapons then return end
  local TOP = self._top

  self.weapons = ns.WeaponView:new{
    parent = self,
    position = {
      TopLeft = {self.titlebar, ui.edge.BottomLeft, 2, -2 - TOP},
      TopRight = {self.titlebar, ui.edge.BottomRight, -2, -2 - TOP},
    },
    colInfo = ns.WeaponView.BuildColInfo(),
    onResized = function() self:_fitToGrid() end,
    -- Recompute the source/appearance/collected counter when the wanted-only filter flips
    -- (VisibleCounts is filter-scoped), so it tracks the rows actually shown.
    onFilterChanged = function() self:RefreshCounter() end,
    -- Scroll the dressed-weapon row into view (weaponScroll is assigned just below; the
    -- closure only reads it at highlight time, by which point it exists).
    onEnsureVisible = function(_, rowTop, rowH) ns.EnsureRowVisible(self.weaponScroll, rowTop, rowH) end,
  }
  self.weapons:Hide()   -- SetMode shows it; building it hidden keeps the window at the armor width
                        -- until the swap, exactly as the eager build did.

  self.weaponStrip = self.weapons:BuildFilterStrip(self, function() self:RefreshCounter() end)
  ns.prof:Mark("strip")
  self.weaponStrip:Position({ TopLeft = {self.titlebar, ui.edge.BottomLeft, self._stripX, -2} })
  self.weaponStrip:Hide()
  -- Built long after the toggle settled, so `_stripX` above is already final for it. Placed by
  -- `_applyStripX` from here on, which is what a later re-measure would move.

  self.weaponScroll = ScrollFrame:new{
    parent = self,
    position = {
      TopLeft = {self.titlebar, ui.edge.BottomLeft, 2, -2 - TOP - self.weapons.headerHeight},
      BottomRight = {self, ui.edge.BottomRight, -2, 2},
    },
  }
  self.weaponScroll:Child(self.weapons.rowArea)
  self.weaponScroll:Hide()
  ns.prof:Mark("scroll")
end

---Every grid that currently exists, for the callers that refresh "both". The weapon grid is built
---lazily (`_ensureWeapons`), so before the first switch to Weapons there is only one.
---@return table[]
function MainWindow:Grids()
  if self.weapons then return { self.data, self.weapons } end
  return { self.data }
end

---Switch the window between the armor grid and the weapon grid (the Armor/Weapons toggle).
---Swaps which (grid + strip + scroll) trio is shown, re-points the counter + scroll refit at the
---active grid, hides the armor-only wanted tally, recolors the toggle, and resizes to the active
---grid's width. No-op if already in the requested mode.
---@param weapons boolean
function MainWindow:SetMode(weapons)
  if self._weaponsMode == weapons then return end
  -- Timed as its own run so the three swaps read separately: the FIRST switch to Weapons builds a
  -- second grid, every later swap builds nothing. If a swap that builds nothing is still slow, the
  -- cost is the counter + refit below rather than construction — a different fix (see profile.lua).
  ns.prof:Begin(weapons and "weapons" or "armor")
  -- First switch to Weapons builds the trio. Switching back can't reach a nil one: the guard above
  -- means `SetMode(false)` only proceeds when we were already in Weapons mode.
  if weapons then self:_ensureWeapons() end
  self._weaponsMode = weapons
  self.active = weapons and self.weapons or self.data
  self.activeScroll = weapons and self.weaponScroll or self.scroll
  -- Carry the PTR PREVIEW state across the Armor/Weapons swap so it reads as one window-level mode:
  -- the grid being shown adopts the mode of the one being hidden (SetPtr repaints its own toggle).
  local prevGrid = weapons and self.data or self.weapons
  if self.active._ptr ~= prevGrid._ptr then self.active:SetPtr(prevGrid._ptr) end
  self.data:SetShown(not weapons); self.filterStrip:SetShown(not weapons); self.scroll:SetShown(not weapons)
  self.weapons:SetShown(weapons); self.weaponStrip:SetShown(weapons); self.weaponScroll:SetShown(weapons)
  -- `SetShown` routes through Region:Show → OnBeforeShow → _fitNameCol on the grid coming up, so
  -- this split is not the free visibility flip it looks like.
  ns.prof:Mark("show")
  self:RefreshWanted()   -- the tally switches units with the grid: wanted sets ↔ wanted weapon looks
  self._modeToggle:Select(weapons and "weapons" or "armor")
  -- The weapon name column is too narrow to hold the counter over the header, so in weapon mode
  -- the counter rides the strip row (right of the dropdowns); armor keeps it over the header.
  self.counter:Position(weapons and { TopLeft = {self.weaponStrip, ui.edge.TopRight, 12, -3} }
    or { TopLeft = {self.filterStrip, ui.edge.TopRight, 12, -3} })
  self:RefreshCounter()
  ns.prof:Mark("counter")
  self:_fitToGrid()   -- sizes BOTH axes now (#768 L-4), so the mode swap needs no width of its own
  ns.prof:Mark("fit")
  ns.prof:Finish(self.active)
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
  -- Width as well as height (#768 L-4). `ns.FitNameCol` widens the name column and returns true so
  -- "the host should refit", but this only ever adjusted height — so on the login path, where the
  -- deferred second measurement (#718's repair) supplies the real width, the grid grew and the
  -- window didn't, pushing the rightmost column past the edge. Only `SetMode` re-widened, so Armor
  -- mode stayed clipped for the rest of the session unless you toggled to Weapons and back.
  self:Width(max(110, grid:Width() + (self._weaponsMode and 20 or 4)))
  local capH = min(grid.MAX_HEIGHT, grid.rowArea:Height())
  self:Height(self.titlebar:Height() + self._top + grid.headerHeight + capH + 4)
  scroll:Refresh()   -- the scroll frame tracks the window's BottomRight; recompute its range
end

---Refresh the running wanted tally in the header — flagged SETS in armor mode, flagged weapon
---APPEARANCES in weapons mode, since that's what the grid under it is made of and what its own ★
---filter acts on. The star is drawn from the shared WantedIcon atlas (not a literal glyph, which the
---header font can't render).
function MainWindow:RefreshWanted()
  local n = self._weaponsMode and ns:WeaponWantedCount() or ns:WantedCount()
  self.wantedCount:Text(("|A:%s:14:14|a %d"):format(ns.WantedIcon, n))
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
    -- The unique-setId tally is the grid's own now (#770 step 11), as the weapon one already was.
    local n, ptrBuild = self.data:UpcomingCounts()
    self.counter:Text(("+%d sets upcoming%s"):format(n, ptrBuild and (" · PTR " .. ptrBuild) or ""))
  else
    local sets, cells, green = self.data:VisibleCounts()
    self.counter:Text(("%d sets · %d/%d collected"):format(sets, green, cells))
  end
  -- The counter sits in the strip row in every mode, so keep it at the compact strip font.
  local titleFont = collectedTheme().fonts.title
  if titleFont then self.counter:Font({titleFont[1], 12}) end
end

-- Live-refresh this window's grids + wanted counter when a rating changes anywhere (e.g. via the
-- shared dressing room). No-op until the window has been opened.
--
-- BOTH grids, not just the shown one: a weapon flagged while Armor is up would otherwise leave the
-- weapon grid holding a stale wanted-only row set for the next toggle over to it (and vice versa).
--
-- Re-filtering goes through each grid's own `_refilter` (#762), which is what clears a stranded
-- lockout selection — `_selectedRow` indexes DISPLAY rows, so a raw rebuild left an open panel
-- pointing at whatever set inherited that screen row. Polymorphic on purpose: the armor grid clears
-- behind its `embedded` guard, and the weapon grid has no selection to clear (lockouts are
-- armor-only). The refit rides along with it via `onResized`, so it now happens per grid that
-- actually re-filtered rather than once unconditionally — a `_refreshMarks` pass only recolours
-- cells and moves no rows, so it needs none.
ns:OnRatingsChanged(function(setId, visualID)
  local w = ns.window
  if not w then return end
  -- Each grid says what the broadcast means for it (#768 L-8, closed). The two keys are different id
  -- spaces — armour cells by `setId`, weapon cells by the `visualID`s their source drops — so a
  -- change of one kind can't touch the other grid at all, and `affected` is false for it. That is the
  -- bulk of the win: a weapon rank click used to walk the armour grid's ~6,600 cells for nothing.
  for _, grid in ipairs(w:Grids()) do
    local affected, only = grid:_ratingScope(setId, visualID)
    if affected then
      if grid._wantedOnly then
        grid:_refilter()   -- re-filter (row set may change) + clear selection + refit
      else
        grid:_refreshMarks(only)
      end
    end
  end
  w:RefreshWanted()
  w:RefreshCounter()   -- the counter is filter-scoped, so a re-filter moves it
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
  -- Nothing to draw on a grid that was never built (#770 step 19). Reaching this at all takes
  -- browsing a weapon cell, which only the Weapons grid offers — so in practice it exists by then.
  if not (ns.window and ns.window.weapons) then return end
  ns.window.weapons:HighlightWeaponCell(source, weaponType, true)
end)

---@class Warbandeer_Collected
---@field window CollectedWindow? main window (nil until first opened)
ns.window = nil
---Open the main window, creating it on first use.
function ns:Open()
  if not ns.window then
    -- The one measurement that can only be taken once per session (`/collected profile` arms it and
    -- opens in the same step for exactly that reason). Begins here rather than inside the class so
    -- the theme resolution and RememberPosition below are inside the run too.
    ns.prof:Begin("open")
    -- Theme the whole window (titlebar included) to match Warbandeer's collected view;
    -- the explicit opaque `background` (in defaults) overrides the theme's alpha-0
    -- `window` token so the surface stays solid. Resolved here, not in the class
    -- defaults, since the void-dark theme registers only once Warbandeer has loaded.
    ns.window = MainWindow:new{ theme = collectedTheme() }
    ns.window:RememberPosition(ns.db.windowPos)   -- restore + persist the user's dragged position
    ns.prof:Mark("position")
    ns.prof:Finish(ns.window.data)
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
