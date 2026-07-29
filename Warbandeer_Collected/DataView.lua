---@type Warbandeer_Collected
local ns = select(2, ...)
local Class = ns.lua.Class
local ui = ns.ui
local TableFrame = ui.TableFrame

---Main grid: one row per set group (lock icon + name), one column per class,
---cells show missing-piece counts color-shaded by completion.
---
---Shared by both the standalone /collected window and Warbandeer's embedded
---collected view (single source of truth). `embedded` trims the chrome the host
---window owns: the lock column is dropped (so the name column is col 1, not col 2)
---and the lockout-panel name-click is removed (Warbandeer keeps lockouts in
---/collected's own window). Each host passes its `colInfo` via `BuildColInfo`.
---
---The class is assembled across four files, all hanging off this one shared table:
---`DataView.lua` (constructor + lifecycle), `DataViewData.lua` (`ns.CollectedRows`
---row builder + `VisibleCounts`), `DataViewFilters.lua` (filter/sort toggles, the
---filter strip, dropdown options, `BuildColInfo`) and `DataViewMarks.lua` (per-cell
---wanted/rank overlays + lockout selection).
---@class DataView: TableFrame
---@field _reverse boolean? sort by expansion newest-first (release 12→1; defaults true; see ToggleOrder)
---@field _wantedOnly boolean? show only rows holding a wanted set (non-wanted cells within a shown row still blank; empty → _setEmpty message) — see ToggleWantedOnly
---@field _ptr boolean? show the PTR-only "upcoming" sets (ns.PtrSets) instead of live (see SetPtr)
---@field _repaintPtr fun(on: boolean)? repaints the PTR toggle border on a programmatic SetPtr (mode swap)
---@field _expansion number|string? release filter — a release index, or "all" (see SetExpansion)
---@field _category string? category filter — a category name, or "all" (see SetCategory)
---@field _playerRace number? cached canonical race id the rank pips resolve against
---@field _nameColW number? name-column width already applied, so a re-fit adds only the delta (see ns.FitNameCol)
---@field _selectedRow number? lockout-panel selected row index (window grid only)
---@field _arrow Texture? lockout-selection arrow texture (window grid only, created lazily)
---@field _dressedSetId number? setId currently previewed in the shared dressing room (drives the cell cursor; nil = none)
---@field _dressedClassIndex number? class column of the previewed set (with setId, pins the exact cell; PvP sets share a setId across classes)
---@field _dressedBox Frame? the white 4-edge cursor box re-anchored over the dressed set's cell (created lazily)
---@field onEnsureVisible fun(self: DataView, rowTop: number, rowH: number)?  host hook to scroll a row into view (see HighlightSet)
---@field _emptyMsg Label? centered empty-state message (created lazily; shown when "wanted only" matches nothing)
---@field embedded boolean? render trimmed for a host view (no lock column / lockout name-click)
---@field infoTipAnchor fun(cell: Cell): table?  host override for the hover InfoTip anchor (defaults to "above the cell")
---@field onWantedToggle fun(self: DataView)?  host callback fired after a Shift-click wanted toggle (refresh the host's header)
---@field onResized fun(self: DataView)?  host callback fired after a filter/PTR change shrinks or grows the row area, so the host can refit its scroll container (see _refilter / SetPtr)
---@field onFilterChanged fun(self: DataView)?  host callback fired after the wanted-only filter flips, so the host can recompute its filter-scoped counter (see ToggleWantedOnly)
local DataView = Class(TableFrame, function(self)
  -- Reaching this body means the base TableFrame has finished: columns built, GetData run, and
  -- `update()` done creating every cell frame. That is the profiler's `cells` split — the base
  -- class can't mark it itself without a LibNUI change, and this is the first addon-owned code to
  -- run after it (see profile.lua).
  ns.prof:Mark("cells")
  -- Autosize the name column. Called raw (not through _fitNameCol) because the host hasn't
  -- assigned its own grid field yet — firing onResized here would refit against a nil grid.
  -- Always col 2: the lock column at col 1 is emitted in both hosts and merely zero-width when the
  -- host owns lockouts (#864), so this index no longer depends on who is rendering.
  ns.FitNameCol(self, 2)
  ns.prof:Mark("fitname")
  -- A label only measures true once WoW has laid the grid out, so measure again on the next
  -- frame, when it definitely has — this is the repair for a short first pass (#718).
  C_Timer.After(0, function() self:_fitNameCol() end)
  self:_refreshMarks()   -- the constructor-time update() ran before our override was mixed in
  ns.prof:Mark("marks")
end, {
  headerHeight = 28,
  _reverse = true,   -- default to newest expansion first (release 12→1)
  _wantedOnly = false,
  _ptr = false,
  _expansion = "all",
  _category = "all",
  embedded = false,
  -- The row builder lives in DataViewData.lua (too large to inline here); base
  -- TableFrame construction calls this through onLoad, by which point it's defined.
  --
  -- The two profiler marks bracket the row build, which also dates the column build before it:
  -- `onLoad` calls this first thing, so everything since the run began was TableFrame's own
  -- constructor (see profile.lua).
  GetData = function(self)
    ns.prof:Mark("cols")
    local rows = ns.CollectedRows(self)
    ns.prof:Mark("data")
    return rows
  end,
})

-- Fit the name column to its widest set name (col 1 embedded, col 2 in the window — the lock takes
-- col 1) and let the host refit when it grew. Re-runnable (see ns.FitNameCol), so it doubles as the
-- repair for a first measurement taken before WoW had laid the grid out.
function DataView:_fitNameCol()
  if ns.FitNameCol(self, 2) and self.onResized then self:onResized() end
end

-- Re-fit on show. The window's Armor/Weapons swap shows this grid via SetShown, which routes
-- through Region:Show — so a grid whose name column measured short while its window was still
-- being built gets a second chance every time it comes back on screen (#718).
function DataView:OnBeforeShow() self:_fitNameCol() end

-- Re-derive the rating overlays and the dressed-set cursor after virtualisation re-points the resident
-- cells at a new window (`TableFrame.onRebind`, #843). Neither is cell data, so `Cell:update` leaves
-- both attached to whichever row the slot held before. Defined even when `virtual` is off, where it
-- simply never fires.
function DataView:onRebind() ns.OnGridRebind(self) end

-- Refresh overlays after the base table (re)builds its cells. The row count varies
-- (PTR PREVIEW swaps the ~live-raid list for the small upcoming list), so follow the
-- variable-height pattern: grow the row pool for any new rows, pad the data out to the
-- pool with blank-string cells so update() overwrites cells left from a larger previous
-- render (PTR's few rows leave the live rows behind), then ResizeRows to hide the dead
-- space below the active rows.
function DataView:update()
  local real = #self.data
  -- Both halves of the variable-height dance are STATIC-mode only (#843). Under virtualisation the
  -- resident pool is sized from the viewport by `_virtualUpdate`, so growing it to the row count here
  -- would build a frame per data row and defeat the whole thing — and padding `data` out to the pool
  -- is worse than useless: `#data` is what gives the scroll range its extent, so appending blank rows
  -- would add empty scrollable space below the real ones.
  if not self.virtual then
    for _ = #self.rows + 1, real do self:addRow{} end
    if real < #self.rows then
      local blank = {}
      for c = 1, #self.cols do blank[c] = "" end
      for i = real + 1, #self.rows do self.data[i] = blank end
    end
  end
  TableFrame.update(self)
  self:ResizeRows(real)
  self:_setEmpty(real == 0)   -- any empty result, not just the ★ filter (#768 L-5)
  self:_refreshMarks()
  -- Rows were rebuilt/re-sorted, so the dressed-set cell moved — re-resolve it (no
  -- scroll: a passive re-sort/filter shouldn't yank the view). Clears if it's now
  -- filtered out.
  self:HighlightSet(self._dressedSetId, self._dressedClassIndex, false)
end

-- Show or hide a centered empty-state message in the row area, so an empty grid reads as
-- intentionally empty rather than blank/broken. Both the mechanics and the phrasing are shared with
-- the weapons grid (ns.GridEmptyMessage); only the noun is ours.
--
-- Shown for ANY empty result since #768 L-5, not just the ★ filter: an expansion × category
-- combination that matches nothing used to collapse the grid to its bare header with no message
-- and no reserved height, which reads as the addon having broken rather than the filter being
-- narrow.
---@param on boolean
function DataView:_setEmpty(on) ns.GridEmptyMessage(self, on, "sets") end

-- Scroll `scroll` so a row is fully in view — the shared clamp, exposed as a METHOD purely so the
-- embedded host can reach it: Warbandeer's collected view is a different addon with its own `ns`, so
-- `ns.EnsureRowVisible` is invisible to it, but the grid instance it already holds is not (#770
-- step 11). This addon's own window calls the shared function directly.
---@param scroll table  a LibNUI ScrollFrame
---@param rowTop number
---@param rowH number
function DataView:EnsureRowVisible(scroll, rowTop, rowH) ns.EnsureRowVisible(scroll, rowTop, rowH) end

-- PTR PREVIEW counter data for the host's "+N upcoming" tally: how many distinct upcoming sets
-- there are across ns.PtrSets, plus the PTR build string.
--
-- **Counted by unique setId**, because a set that exists for several classes appears once per class
-- column in `grp.sets` and the tally means "sets you don't have yet", not cells.
--
-- Exposed as a method so BOTH hosts — this addon's window and Warbandeer's embedded view, a
-- different `ns` — share one tally (#770 step 11). Both hand-rolled this loop; the weapon grid has
-- had `WeaponView:UpcomingCounts` since it gained PTR preview, so this is the armour half catching
-- up. The embedded view reaches it on the grid instance it already holds, so no cross-addon
-- publishing is involved.
---@return number count, string? ptrBuild
function DataView:UpcomingCounts()
  local seen, n = {}, 0
  for _, grp in ipairs(ns.PtrSets) do
    for _, set in ipairs(grp.sets) do
      if set.id and not seen[set.id] then seen[set.id] = true; n = n + 1 end
    end
  end
  return n, ns.PtrBuild and ns.PtrBuild.ptr or nil
end

-- Max scrollable row-area height (px) before the grid scrolls — shared so the embedded
-- view and the standalone window cap the grid to the same height (same window size).
DataView.MAX_HEIGHT = 460

-- Height (px) of the filter strip (BuildFilterStrip) — hosts offset the grid by it.
DataView.STRIP_H = 20

---@class Warbandeer_Collected
---@field DataView DataView
ns.DataView = DataView

-- Share the grid class with sibling addons (Warbandeer's embedded collected view)
-- via the API global, so the grid is maintained in this one place. api.lua loads
-- first, so the table already exists; consumers build it with `embedded = true`.
_G.WarbandeerCollectedApi.DataView = DataView
