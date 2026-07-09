---@type Warbandeer_Collected
local ns = select(2, ...)
local max = math.max
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
---@field _expansion number|string? release filter — a release index, or "all" (see SetExpansion)
---@field _category string? category filter — a category name, or "all" (see SetCategory)
---@field _playerRace number? cached canonical race id the rank pips resolve against
---@field _selectedRow number? lockout-panel selected row index (window grid only)
---@field _arrow Texture? lockout-selection arrow texture (window grid only, created lazily)
---@field _dressedSetId number? setId currently previewed in the shared dressing room (drives the row highlight; nil = none)
---@field _dressedRow number? row index currently highlighted for the dressed set (shifts on re-sort)
---@field onEnsureVisible fun(self: DataView, rowTop: number, rowH: number)?  host hook to scroll a row into view (see HighlightSet)
---@field _emptyMsg Label? centered empty-state message (created lazily; shown when "wanted only" matches nothing)
---@field embedded boolean? render trimmed for a host view (no lock column / lockout name-click)
---@field infoTipAnchor fun(cell: Cell): table?  host override for the hover InfoTip anchor (defaults to "above the cell")
---@field onWantedToggle fun(self: DataView)?  host callback fired after a Shift-click wanted toggle (refresh the host's header)
---@field onResized fun(self: DataView)?  host callback fired after a filter/PTR change shrinks or grows the row area, so the host can refit its scroll container (see _refilter / SetPtr)
local DataView = Class(TableFrame, function(self)
  -- autoadjust name width (col 1 embedded, col 2 in the window — lock takes col 1)
  local nameCol = self.embedded and 1 or 2
  local w = 0
  for _,r in ipairs(self.cells) do
    if #r > nameCol then
      w = max(w, r[nameCol].label:Width())
    end
  end
  self.cols[nameCol]:Width(w)
  self.rowArea:Width(self.rowArea:Width() + w)
  self:Width(self:Width() + w)
  self:_refreshMarks()   -- the constructor-time update() ran before our override was mixed in
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
  GetData = function(self) return ns.CollectedRows(self) end,
})

-- Refresh overlays after the base table (re)builds its cells. The row count varies
-- (PTR PREVIEW swaps the ~live-raid list for the small upcoming list), so follow the
-- variable-height pattern: grow the row pool for any new rows, pad the data out to the
-- pool with blank-string cells so update() overwrites cells left from a larger previous
-- render (PTR's few rows leave the live rows behind), then ResizeRows to hide the dead
-- space below the active rows.
function DataView:update()
  local real = #self.data
  for _ = #self.rows + 1, real do self:addRow{} end
  if real < #self.rows then
    local blank = {}
    for c = 1, #self.cols do blank[c] = "" end
    for i = real + 1, #self.rows do self.data[i] = blank end
  end
  TableFrame.update(self)
  self:ResizeRows(real)
  self:_setEmpty(self._wantedOnly and real == 0)
  self:_refreshMarks()
  -- Rows were rebuilt/re-sorted, so the dressed-set row moved — re-resolve it (no
  -- scroll: a passive re-sort/filter shouldn't yank the view). Clears if it's now
  -- filtered out.
  self:HighlightSet(self._dressedSetId, false)
end

-- Row-area height reserved for the empty-state message (ResizeRows(0) collapses it).
DataView.EMPTY_H = 48

-- Show or hide a centered empty-state message in the row area. Shown when "wanted
-- only" is active but no set is flagged, so the grid reads as intentionally empty
-- rather than blank/broken. ResizeRows already collapsed the area to 0, so reserve
-- EMPTY_H here; the host's onResized → _fitToGrid then sizes the window to fit it.
---@param on boolean
function DataView:_setEmpty(on)
  if not on then
    if self._emptyMsg then self._emptyMsg:Hide() end
    return
  end
  if not self._emptyMsg then
    self._emptyMsg = ui.Label:new{
      parent = self.rowArea, justifyH = ui.justify.Center,
      color = self:Theme().colors.muted or {0.6, 0.6, 0.62, 1},
      text = "You don't have any Wanted sets.",
      position = { Center = {} },
    }
  end
  self._emptyMsg:Show()
  self.rowArea:Height(DataView.EMPTY_H)
  self:Height(self.offsetY + DataView.EMPTY_H)
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
