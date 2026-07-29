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

-- Scroll a grid row into view. Collected owns the clamp (`ns.EnsureRowVisible`, nazumods/wow#770
-- step 11) and exposes it as a grid method, which is the only way it can reach us: that addon's `ns`
-- is invisible from here, but the grid instance isn't.
--
-- **Guarded, with the clamp kept as a fallback.** This is a cross-addon call and users do run
-- mismatched versions, so a Collected predating the method must not silently lose scroll-into-view.
---@param grid table  the DataView / WeaponView the hook fired for
---@param scroll table?
---@param rowTop number
---@param rowH number
local function ensureRowVisible(grid, scroll, rowTop, rowH)
  if not scroll then return end
  if grid.EnsureRowVisible then return grid:EnsureRowVisible(scroll, rowTop, rowH) end
  local cur, view = scroll:VerticalScroll(), scroll:Height()
  if rowTop < cur then scroll:VerticalScroll(rowTop)
  elseif rowTop + rowH > cur + view then scroll:VerticalScroll(rowTop + rowH - view) end
end

-- No-op stand-in for the sibling addon's build profiler, so the call sites below need no guards.
local NOOP = { Begin = function() end, Mark = function() end, Finish = function() end }

---Collected's build profiler (nazumods/wow#718), which owns the grid the marks fire from and so
---owns the run they belong to. This view builds the SAME grid as the `/collected` window through
---different chrome, and the point of instrumenting both is that a slow one beside a fast one is
---itself the finding.
---
---Resolved per call rather than cached at file scope: Collected is an OptionalDep on its own
---release cadence, so a published version exists without it — and this file's load can precede the
---API global being populated.
---@return table
local function prof()
  return (WarbandeerCollectedApi and WarbandeerCollectedApi.prof) or NOOP
end

---@class CollectedView: Frame
---@field grid DataView the shared set-by-class grid (Collected's own DataView, embedded)
---@field filterStrip Frame the shared filter chrome row (DataView:BuildFilterStrip)
---@field scroll ScrollFrame
---@field counter Label
---@field wantedCount Label running "★ N" wanted tally — sets in armor mode, weapon looks in weapons mode (mirrors the /collected window)
---@field emptyMsg Label
---@field _top number grid top offset (filter strip + gap) — _fitToGrid re-derives the height from it
---@field weaponGrid WeaponView? the weapon-source grid (Armor/Weapons toggle); nil until the first switch to Weapons builds it, and always nil if the sibling addon predates it
---@field weaponStrip Frame? the weapon grid's filter strip (built with the grid)
---@field weaponScroll ScrollFrame? scroll container for the weapon grid's row area (built with the grid)
---@field _weaponsAvailable boolean? the sibling addon exposes WeaponView — what SetMode gates on, since the grid itself may not be built yet
---@field _weaponGeom table? layout measured at construction, replayed when the weapon trio is built
---@field active DataView|WeaponView the currently-shown grid (armor default, or weapon)
---@field activeScroll ScrollFrame the currently-shown scroll container
---@field _weaponsMode boolean? true when the weapon grid is shown (the Armor/Weapons toggle)
local CollectedView = Class(Frame, function(self)
  _view = self
  -- Views are built lazily (MainWindow:getView), so reaching this constructor IS the first click on
  -- Collected in `/wb` — the wait the user actually feels. Later clicks only re-render (`OnBeforeShow`).
  prof():Begin("wb-build")
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
    -- Recompute the set/appearance/collected counter when the wanted-only filter flips
    -- (VisibleCounts is filter-scoped), so it tracks the rows actually shown.
    onFilterChanged = function() _view:_render() end,
    -- Refit the scroll container to the (filtered) row count so it can't overscroll.
    onResized = function() _view:_fitToGrid() end,
    -- Scroll the dressed-set row into view (VerticalScroll clamps out-of-range targets).
    onEnsureVisible = function(grid, rowTop, rowH)
      ensureRowVisible(grid, _view and _view.scroll, rowTop, rowH)
    end,
  }

  -- Shared filter strip (PTR / Wanted / Sort toggles + Expansion / Category dropdowns)
  -- along the top; the PTR toggle re-renders this view so its mode counter updates.
  self.filterStrip = self.grid:BuildFilterStrip(self, function() _view:_render() end)
  self.filterStrip:Position({ TopLeft = {0, 0} })
  prof():Mark("strip")

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
  prof():Mark("scroll")

  -- Counter rides the grid's header row (over the name column, in line with the class
  -- icons), below the filter strip. Created after the grid so it draws above the header.
  self.counter = Label:new{
    parent = self, fontInfo = theme.fonts.title, color = theme.colors.text,
    -- The counter rides the filter-strip row (right of the dropdowns) in both modes — matching the
    -- weapon view — so the grid header row is just the class icons.
    position = { TopLeft = {self.filterStrip, ui.edge.TopRight, 12, -3} },
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
  counterHover:SetScript("OnEnter", function(f) (self.active or self.grid):ShowCountTooltip(f) end)
  counterHover:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- The gold wanted tally toggles WANTED ONLY on click (same as the filter button). It follows the
  -- ACTIVE grid: both grids now have a wanted filter of their own, over different units — sets on
  -- one side, individual weapon looks on the other (#689).
  local wantedHover = Frame:new{
    parent = self,
    position = {
      TopLeft = {self.wantedCount, ui.edge.TopLeft, -2, 0},
      BottomRight = {self.wantedCount, ui.edge.BottomRight, 2, 0},
    },
  }
  wantedHover:EnableMouse(true)
  wantedHover:SetScript("OnMouseUp", function() (self.active or self.grid):ToggleWanted() end)
  wantedHover:SetScript("OnEnter", function(f) (self.active or self.grid):ShowWantedTooltip(f) end)
  wantedHover:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- Shown before the first /collected scan has populated any data. Centered below the
  -- header; the grid is hidden while it shows (see _showGrid) so it never overlaps the
  -- static row names.
  self.emptyMsg = Label:new{
    parent = self, fontInfo = theme.fonts.body, color = theme.colors.muted,
    justifyH = ui.justify.Center,
    position = { Top = {0, -(TOP + headerH + 28)}, Width = gridW, Height = 20, Hide = true },
  }

  -- ── Armor / Weapons mode ──────────────────────────────────────────────────
  -- A second grid (Collected's WeaponView, via the API global) with its own strip + scroll,
  -- hidden until toggled; the persistent Armor/Weapons toggle (far left of the strip row) swaps
  -- trios via SetMode. Built only when the sibling addon exposes WeaponView (same OptionalDep gate
  -- as the grid). The armor grid is the default and stays intact when Weapons is off.
  self.active, self.activeScroll, self._weaponsMode = self.grid, self.scroll, false
  if WarbandeerCollectedApi.WeaponView then
    -- The weapon trio is built on the first switch to Weapons, not here (nazumods/wow#770 step 19):
    -- it is ~241 rows × 18 columns of Cells that plenty of people never look at. `_weaponsAvailable`
    -- records that the sibling addon CAN supply it, which is what `SetMode` gates on now — gating on
    -- `self.weaponGrid` would mean the toggle could never build the thing it toggles to.
    self._weaponsAvailable = true

    -- The persistent Armor/Weapons segmented toggle (the active segment takes the gold rim).
    --
    -- `ui.SegmentedToggle` since nazumods/wow#816. This used to be Collected's builder, reached
    -- through the API global behind a version guard, with a hand-rolled copy of the same control for
    -- the releases that didn't publish it — three pieces of machinery that existed only because the
    -- widget lived in an addon. LibNUI is a hard dependency of this one, so a version where it isn't
    -- there can't load us at all, and all three are gone.
    self._modeToggle = ui.SegmentedToggle:new{
      parent = self, height = STRIP_H, selected = "armor",
      options = { { key = "armor", label = "Armor" }, { key = "weapons", label = "Weapons" } },
      position = { TopLeft = {0, 0} },
      onSelect = function(_, key)
        local weapons = key == "weapons"
        _view:SetMode(weapons)
        -- Tell the shared dressing room which grid is being browsed, so its ratings row is rated
        -- against the right one (nazumods/wow#827). Guarded on its own, not folded into the
        -- `WeaponView` gate above: Collected is an OptionalDep on its own release cadence, and a
        -- published window exists that has the grid but not this call.
        if WarbandeerCollectedApi.SetGridMode then WarbandeerCollectedApi:SetGridMode(weapons) end
      end,
      -- The toggle can only measure its captions once its fonts are resident and it has been laid
      -- out, so the width read in `_applyStripX` is a floor rather than the final answer. When it
      -- re-measures, re-place the strips against the real width.
      onResize = function() self:_applyStripX() end,
    }

    self._weaponGeom = { top = TOP, headerH = headerH, capH = capH, stripX = 0 }
    self:_applyStripX()
  end
  prof():Mark("chrome")

  self:Width(gridW + SCROLLBAR_W)
  self:_fitToGrid()   -- emits the fit:* splits itself
  -- The base TableFrame has just built every cell from this same data, and the show that reveals a
  -- freshly-built view fires `OnBeforeShow` → `_render` in this same frame — so that first render's
  -- `GetData()` + `update()` walk all ~6,600 cells to reproduce what is already on them. Measured at
  -- 104ms of a 120ms `wb-show`, immediately after a 1357ms build. One-shot: `_render` clears it, so
  -- only the render that cannot possibly have new data skips, and every later show rebuilds as
  -- before — by then a scan, rating or filter change genuinely may have landed.
  self._gridFresh = true
  prof():Finish(self.grid)
end, {})
CollectedView.name = "collected"
CollectedView._title = "Collected"

-- Only surface the view (nav icon, minimap menu, and slash command all derive from
-- ns.views) when the sibling Collected addon is loaded — the whole view is its data.
-- OptionalDeps load before us, so the API global is already set here when present.
if WarbandeerCollectedApi and WarbandeerCollectedApi.DataView then
  ns.views.CollectedView = CollectedView
end

-- Live-refresh this view's grids when a rating changes in the shared dressing room (registered once
-- at load; Collected loads first via the OptionalDep order). BOTH grids, not just the shown one: a
-- weapon flagged while Armor is up would otherwise leave the weapon grid holding a stale wanted-only
-- row set for the next toggle over to it (and vice versa).
if WarbandeerCollectedApi and WarbandeerCollectedApi.OnRatingsChanged then
  WarbandeerCollectedApi:OnRatingsChanged(function(setId, visualID)
    if not (_view and _view.grid) then return end
    -- The SHOWN grid, its counter and the tally all refresh through _render; the hidden one needs
    -- its own pass so it isn't holding a stale wanted-only row set when it's toggled back to.
    local hidden = _view._weaponsMode and _view.grid or _view.weaponGrid
    if hidden then
      -- Ask the grid what the broadcast means for it (nazumods/wow#768 L-8): an armour rating can't
      -- have altered a weapon cell or the reverse, so the hidden grid is usually skipped outright.
      -- Guarded because Collected is an OptionalDep on its own release cadence — a released version
      -- exists without `_ratingScope`, and there the old unscoped full pass is still correct.
      local affected, only = true, nil
      if hidden._ratingScope then affected, only = hidden:_ratingScope(setId, visualID) end
      if affected then
        if hidden._wantedOnly then hidden.data = hidden:GetData(); hidden:update()
        else hidden:_refreshMarks(only) end
      end
    end
    _view:_render()
    _view:_fitToGrid()   -- the shown grid's row count may have changed
  end)
end

-- Draw the cell cursor on the set shown in the shared dressing room, following the
-- user's arrow navigation (nil clears on close). Registered once at load.
if WarbandeerCollectedApi and WarbandeerCollectedApi.OnDressedSetChanged then
  WarbandeerCollectedApi:OnDressedSetChanged(function(setId, classIndex)
    local g = _view and _view.grid
    if g then g:HighlightSet(setId, classIndex, true) end
  end)
end

-- Same for the Weapons grid: box the (source, type) cell of the weapon shown in the dressing
-- room, following ←/→ type-stepping (nil clears on close / when an armor set is shown).
if WarbandeerCollectedApi and WarbandeerCollectedApi.OnDressedWeaponCellChanged then
  WarbandeerCollectedApi:OnDressedWeaponCellChanged(function(source, weaponType)
    local g = _view and _view.weaponGrid
    if g then g:HighlightWeaponCell(source, weaponType, true) end
  end)
end

-- Refresh counts, grid data, and the empty-state message each time the view shows
-- (so a /collected scan run after the view was built is reflected on next open).
function CollectedView:OnBeforeShow()
  -- Every click on Collected after the first lands here rather than in the constructor, so this is
  -- the run that says whether re-entering the view is cheap. `_render` refreshes counts and grid
  -- data, which is not nothing on a 473-row grid.
  prof():Begin("wb-show")
  self:_render()
  prof():Mark("render")
  prof():Finish(self.active or self.grid)
end

---Place both filter strips clear of the Armor/Weapons toggle, at the toggle's current width.
---
---Read back rather than declared: the toggle sizes itself to its captions, which is what stopped
---"Weapons" rendering as "Wea…". Re-run from its `onResize`, because a caption is only measurable
---once its font is resident and the view has been laid out — so the width available at construction
---is a floor, not the answer. `_weaponGeom.stripX` is kept in step for the weapon strip built later.
function CollectedView:_applyStripX()
  local stripX = self._modeToggle:Width() + 6
  self._weaponGeom.stripX = stripX
  self.filterStrip:Position({ TopLeft = {stripX, 0} })
  if self.weaponStrip then self.weaponStrip:Position({ TopLeft = {stripX, 0} }) end
end

---Build the weapon grid + its filter strip and scroll container, once, on the first switch to
---Weapons mode. No-op afterwards, and never called when the sibling addon has no `WeaponView`.
---
---Deferred for the reason given where `_weaponGeom` is stamped: it is a large grid many users never
---open. The geometry it needs was measured at construction, so this reproduces the same layout
---rather than re-deriving it from a view that has since been resized.
function CollectedView:_ensureWeapons()
  if self.weaponGrid then return end
  local g = self._weaponGeom

  self.weaponGrid = WarbandeerCollectedApi.WeaponView:new{
    parent = self,
    position = { TopLeft = {0, -g.top} },
    colInfo = WarbandeerCollectedApi.WeaponView.BuildColInfo(),
    onResized = function() _view:_fitToGrid() end,
    -- Recompute the source/appearance/collected counter when the wanted-only filter flips
    -- (VisibleCounts is filter-scoped), so it tracks the rows actually shown.
    onFilterChanged = function() _view:_render() end,
    -- Scroll the dressed-weapon row into view (weaponScroll is assigned just below;
    -- the closure only reads it at highlight time).
    onEnsureVisible = function(grid, rowTop, rowH)
      ensureRowVisible(grid, _view and _view.weaponScroll, rowTop, rowH)
    end,
  }
  self.weaponGrid:Hide()

  self.weaponStrip = self.weaponGrid:BuildFilterStrip(self, function() _view:_render() end)
  self.weaponStrip:Position({ TopLeft = {g.stripX, 0} })
  self.weaponStrip:Hide()
  prof():Mark("strip")

  self.weaponScroll = ui.ScrollFrame:new{
    parent = self,
    position = { TopLeft = {0, -(g.top + g.headerH)}, Width = self.weaponGrid:Width(), Height = g.capH },
  }
  self.weaponScroll:Child(self.weaponGrid.rowArea)
  self.weaponScroll:Hide()
  prof():Mark("scroll")
end

---Switch the embedded view between the armor grid and the weapon grid (the Armor/Weapons toggle).
---Swaps which (grid + strip + scroll) trio is shown, re-points the counter + refit at the active
---grid, hides the armor-only wanted tally, recolors the toggle, resizes to the active grid, and asks
---the Warbandeer window to re-fit. No-op if the weapon grid is unavailable or already in that mode.
---@param weapons boolean
function CollectedView:SetMode(weapons)
  if not self._weaponsAvailable or self._weaponsMode == weapons then return end
  -- Timed separately from the `/collected` window's swap, so the same toggle can be compared across
  -- the two hosts. The first `wb-weapons` run builds a second grid; every later swap builds nothing.
  prof():Begin(weapons and "wb-weapons" or "wb-armor")
  -- First switch to Weapons builds the trio. Switching back can't reach a nil one: the guard above
  -- means `SetMode(false)` only proceeds when we were already in Weapons mode.
  if weapons then self:_ensureWeapons() end
  self._weaponsMode = weapons
  self.active = weapons and self.weaponGrid or self.grid
  self.activeScroll = weapons and self.weaponScroll or self.scroll
  -- Carry the PTR PREVIEW state across the Armor/Weapons swap (one window-level mode): the grid being
  -- shown adopts the mode of the one being hidden (SetPtr repaints its own toggle).
  local prevGrid = weapons and self.grid or self.weaponGrid
  if self.active._ptr ~= prevGrid._ptr then self.active:SetPtr(prevGrid._ptr) end
  self.grid:SetShown(not weapons); self.filterStrip:SetShown(not weapons); self.scroll:SetShown(not weapons)
  self.weaponGrid:SetShown(weapons); self.weaponStrip:SetShown(weapons); self.weaponScroll:SetShown(weapons)
  -- Not the free visibility flip it looks like: SetShown routes through Region:Show → OnBeforeShow
  -- → _fitNameCol on the grid coming up.
  prof():Mark("show")
  -- Unguarded: the toggle is built in the same block that sets `_weaponsAvailable`, which the
  -- early return above already required.
  self._modeToggle:Select(weapons and "weapons" or "armor")
  -- Weapon mode: the narrow name column can't hold the counter over the header, so ride the strip
  -- row (right of the dropdowns); armor restores it over the header.
  self.counter:Position(weapons and { TopLeft = {self.weaponStrip, ui.edge.TopRight, 12, -3} }
    or { TopLeft = {self.filterStrip, ui.edge.TopRight, 12, -3} })
  self:_render()
  prof():Mark("render")
  self:_fitToGrid()   -- sizes both axes and refits the main window (#768 L-4); emits the fit:* splits
  prof():Finish(self.active)
end

-- Cap the visible grid at the shared `DataView.MAX_HEIGHT` and size the scroll container
-- (and the view) to match. Called at construction and again on every filter/PTR change
-- (via the grid's `onResized` hook), so the scroll range tracks the filtered row count and
-- can't overscroll into empty space below the rows.
function CollectedView:_fitToGrid()
  local grid, scroll = self.active or self.grid, self.activeScroll or self.scroll
  -- Width as well as height (#768 L-4). `ns.FitNameCol` widens the name column and returns true so
  -- "the host should refit", but this only ever adjusted height — so the deferred login-path
  -- measurement (#718's repair) grew the grid while the view stayed narrow and clipped its
  -- rightmost column. Only `SetMode` re-widened.
  self:Width(grid:Width() + SCROLLBAR_W)
  local capH = min(grid.MAX_HEIGHT, grid.rowArea:Height())
  scroll:Height(capH)
  self:Height(self._top + grid.headerHeight + capH + 4)
  -- Split three ways because the phase measured 185ms on a build — far more than a resize should
  -- cost — and which of the three owns it decides whether there's anything cheap to do about it.
  prof():Mark("fit:size")
  scroll:Refresh()   -- recompute the scroll range for the new child height
  prof():Mark("fit:scroll")
  -- The main window sizes itself to this view, so a resize here has to carry through — otherwise a
  -- widened view is just clipped one frame further out.
  if ns.MainWindow then ns.MainWindow:Fit() end
  prof():Mark("fit:window")
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
  -- Consumed on whatever path this render takes, including the early returns below, so the flag can
  -- never survive into a later show where the data really could have moved on (see the constructor).
  local fresh = self._gridFresh
  self._gridFresh = nil
  -- Weapon mode: no scan gate (WeaponView computes collected state live via ns:WeaponCollectedMap);
  -- the source/appearance/collected counts, its own wanted tally, and a data refresh.
  if self._weaponsMode then
    self.emptyMsg:Hide()
    self:RefreshWanted()
    if self.weaponGrid._ptr then
      -- PTR PREVIEW: only the upcoming (not-yet-live) appearances — a "+N upcoming" tally.
      local n, ptrBuild = self.weaponGrid:UpcomingCounts()
      self.counter:Text(("+%d appearances upcoming%s"):format(n, ptrBuild and (" · PTR " .. ptrBuild) or ""))
    else
      local sources, apps, coll = self.weaponGrid:VisibleCounts()
      self.counter:Text(("%d sources · %d/%d collected"):format(sources, coll, apps))
    end
    self.counter:Font({theme.fonts.title[1], 12})
    self.weaponGrid.data = self.weaponGrid:GetData(); self.weaponGrid:update()
    return
  end
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
    -- Collected's own tally (nazumods/wow#770 step 11) — both hosts hand-rolled the same unique-setId
    -- loop while the weapon grid had a method for it. Guarded like every other cross-addon reach:
    -- an older Collected keeps the loop.
    local n, ptrBuild
    if self.grid.UpcomingCounts then
      n, ptrBuild = self.grid:UpcomingCounts()
    else
      local seen = {}
      n = 0
      for _, grp in ipairs(api.PtrSets or {}) do
        for _, set in ipairs(grp.sets) do
          if set.id and not seen[set.id] then seen[set.id] = true; n = n + 1 end
        end
      end
      ptrBuild = api.PtrBuild and api.PtrBuild.ptr or nil
    end
    self.counter:Text(("+%d sets upcoming%s"):format(n, ptrBuild and (" · PTR " .. ptrBuild) or ""))
  else
    local sets, cells, green = self.grid:VisibleCounts()   -- tracks the active expansion/category filter
    self.counter:Text(("%d sets · %d/%d collected"):format(sets, green, cells))
  end
  -- The counter sits in the strip row in every mode, so keep it at the compact strip font.
  self.counter:Font({theme.fonts.title[1], 12})
  self:RefreshWanted()
  -- Skipped only for the render that immediately follows construction, where the cells already hold
  -- exactly this. The counter and tally above still run — those the constructor never did.
  if not fresh then
    self.grid.data = self.grid:GetData()
    self.grid:update()
  end
end

-- Refresh the running wanted tally in the header (gold star + N), matching the /collected window:
-- flagged SETS in armor mode, flagged weapon APPEARANCES in weapons mode, since that's what the grid
-- under it is made of and what its own ★ filter acts on. The star is drawn from the shared WantedIcon
-- atlas rather than a literal glyph so it renders in the body font.
function CollectedView:RefreshWanted()
  local api = WarbandeerCollectedApi
  -- Guarded like every other reach across the API boundary in this file: a Collected older than
  -- #689 exposes no weapon tally, and the view still has to render.
  local n = (self._weaponsMode and api.WeaponWantedCount) and api:WeaponWantedCount() or api:WantedCount()
  self.wantedCount:Text(("|A:%s:14:14|a %d"):format(api.WantedIcon, n))
end

