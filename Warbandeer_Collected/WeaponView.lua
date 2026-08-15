---@type Warbandeer_Collected
local ns = select(2, ...)
local Class = ns.lua.Class
local TableFrame = ns.ui.TableFrame
local GameTooltip = GameTooltip

---The Weapons grid (the Armor/Weapons toggle's weapon view): one row per weapon SOURCE, one column
---per weapon TYPE, each cell the uncollected-appearance count shaded by completion (green check when
---complete) — the identical cell renderer as the armor DataView. A standalone TableFrame subclass
---(NOT a DataView subclass), so the battle-tested armor grid is untouched.
---
---Assembled across four files, mirroring the armor grid's split: `WeaponView.lua` (constructor +
---lifecycle + counts), `WeaponViewData.lua` (the `ns.WeaponRows` row builder, the hover tooltip and
---the drill-in), `WeaponViewFilters.lua` (filter/sort toggles, the filter strip, dropdown options,
---`BuildColInfo`) and `WeaponViewMarks.lua` (per-cell wanted/rank overlays). The collected lookup is
---ns:WeaponCollectedMap.
---@class WeaponView: TableFrame
---@field _reverse boolean? sort by expansion newest-first (release 12→1; defaults true)
---@field _expansion number|string? release filter — a release index, or "all"
---@field _category string? category filter — a category name, or "all"
---@field _wantedOnly boolean? show only rows holding a wanted look (cells holding none still blank; empty → _setEmpty message) — see ToggleWantedOnly
---@field _syncWantedBtn fun()? repaints the ★ toggle's border when other chrome drives the filter (registered by BuildFilterStrip)
---@field _ptr boolean? PTR PREVIEW — show the upcoming (ns.WeaponPtrSources) weapons instead of live
---@field _repaintPtr fun(on: boolean)? repaints the PTR toggle border on a programmatic SetPtr (mode swap)
---@field _emptyMsg Label? centered empty-state message (created lazily; shown when "wanted only" matches nothing)
---@field _nameColW number? name-column width already applied, so a re-fit adds only the delta (see ns.FitNameCol)
---@field infoTipAnchor fun(cell: Cell): table?  host override for the hover InfoTip anchor (defaults to "above the cell"), matching DataView's
---@field onResized fun(self: WeaponView)? host hook fired after a filter/sort change resizes the row area
---@field onFilterChanged fun(self: WeaponView)? host hook fired after the wanted-only filter flips, so the host can recompute its filter-scoped counter
---@field onEnsureVisible fun(self: WeaponView, rowTop: number, rowH: number)? host hook to scroll a row into view (see HighlightWeaponCell)
---@field _dressedBox Frame? the white 4-edge cursor box re-anchored over the dressed weapon cell (created lazily)
---@field _dressedSource table? source group currently previewed in the shared dressing room (drives the cell cursor; nil = none)
---@field _dressedType number? weapon type currently previewed (with _dressedSource, pins the exact cell)
local WeaponView = Class(TableFrame, function(self)
  -- Base TableFrame is done here: columns, GetData, and every cell frame from `update()`. Mirrors
  -- the armour grid's marks so the two builds are directly comparable (see profile.lua).
  ns.prof:Mark("cells")
  -- Autosize the name column (col 1) to the widest source name (+ its expansion badge). Called raw
  -- (not through _fitNameCol) because the host hasn't assigned its own grid field yet — firing
  -- onResized here would refit against a nil grid.
  ns.FitNameCol(self, 1)
  ns.prof:Mark("fitname")
  -- A label only measures true once WoW has laid the grid out, so measure again on the next frame,
  -- when it definitely has — this is the repair for a short first pass (#718).
  C_Timer.After(0, function() self:_fitNameCol() end)
  self:_refreshMarks()   -- the constructor-time update() ran before our override was mixed in
  ns.prof:Mark("marks")
end, {
  headerHeight = 28,
  _reverse = true,
  _expansion = "all",
  _category = "all",
  _wantedOnly = false,
  _ptr = false,
  -- Row builder lives in WeaponViewData.lua; the base TableFrame calls it via GetData in onLoad.
  -- Bracketed for the profiler exactly as the armour grid's is (see profile.lua).
  GetData = function(self)
    ns.prof:Mark("cols")
    local rows = ns.WeaponRows(self)
    ns.prof:Mark("data")
    return rows
  end,
})

-- Fit the name column (col 1) to its widest source name and let the host refit when it grew.
-- Re-runnable (see ns.FitNameCol), so it doubles as the repair for a first measurement taken
-- before WoW had laid the grid out.
function WeaponView:_fitNameCol()
  if ns.FitNameCol(self, 1) and self.onResized then self:onResized() end
end

-- Re-fit on show. This grid is built hidden and revealed by the Armor/Weapons swap's SetShown,
-- which routes through Region:Show — so it gets a fresh measurement every time it comes back on
-- screen, rather than living with whatever it measured while the window was still being built (#718).
function WeaponView:OnBeforeShow() self:_fitNameCol() end

-- Re-derive the rating overlays and the dressed-weapon cursor after virtualisation re-points the
-- resident cells at a new window (`TableFrame.onRebind`, #843) — the armour grid's twin, for the same
-- reason: neither is cell data, so `Cell:update` leaves both on whichever row the slot held before.
-- Forward the resident range like the armour grid (#921): `ns.OnGridRebind` records it for
-- `ns.ResidentCell` / `ns.ResidentRow` (the weapons grid has no lockout selection, but keeps the
-- contract identical rather than silently leaving `_residentFirst` nil).
function WeaponView:onRebind(first, last) ns.OnGridRebind(self, first, last) end

-- Variable-height rebuild (the visible row count changes with the filter): grow the pool for new
-- rows, pad shrinking data with blank-string cells so stale rows blank, base update, then hide the
-- dead rows below the active count. Mirrors DataView:update.
function WeaponView:update()
  local real = #self.data
  -- Static-mode only, exactly as in `DataView:update` (#843): virtual mode sizes its pool from the
  -- viewport, so growing it per data row defeats virtualisation, and padding `data` to the pool would
  -- extend the scroll range with blank rows.
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
  -- Cells are reassigned by the rebuild, so re-resolve the dressed-weapon cursor onto the
  -- cell that still matches (source, type) — the weapon analogue of DataView re-resolving
  -- HighlightSet after a re-sort. No scroll: a passive rebuild shouldn't yank the view.
  self:HighlightWeaponCell(self._dressedSource, self._dressedType, false)
end

WeaponView.MAX_HEIGHT = 460
WeaponView.STRIP_H = 20

-- Box the exact cell of the weapon currently previewed in the shared dressing room, following it as
-- ←/→ steps across weapon-type columns (same source row). Keyed by (source, type) — the identity
-- stamped on each cell's data in WeaponRows. Broadcast from the room via ns:OnDressedWeaponCellChanged;
-- nil (close / an armour set shown) hides it. `scroll` brings the cell's row into view (via the host's
-- onEnsureVisible hook). The cursor box + cell scan are shared with the armor grid — see
-- ns.HighlightGridCell / ns.EnsureDressedCursor (the weapon analogue of DataView:HighlightSet).
---@param source table?  the previewed source group, or nil to clear the cursor
---@param weaponType number?  the previewed weapon type (pins the column)
---@param scroll boolean?  scroll the matched cell's row into view
function WeaponView:HighlightWeaponCell(source, weaponType, scroll)
  self._dressedSource = source
  self._dressedType = weaponType
  ns.HighlightGridCell(self, source and function(data)
    return data._source == source and data._type == weaponType
  end or nil, scroll)
end

---@return number, number, number
function WeaponView:VisibleCounts() return ns.WeaponVisibleCounts(self) end

-- The shared scroll-into-view clamp as a method, for the same reason the armour grid exposes one:
-- the embedded host is a different addon and can't see `ns.EnsureRowVisible`, but it holds this
-- instance (#770 step 11).
---@param scroll table  a LibNUI ScrollFrame
---@param rowTop number
---@param rowH number
function WeaponView:EnsureRowVisible(scroll, rowTop, rowH) ns.EnsureRowVisible(scroll, rowTop, rowH) end

-- PTR PREVIEW counter data for the host's "+N upcoming" tally: the number of upcoming (not-yet-live)
-- weapon appearances across ns.WeaponPtrSources, plus the PTR build string. Exposed as a method so
-- BOTH hosts — this addon's window and Warbandeer's embedded view (a different ns) — share one tally.
---@return number count, string? ptrBuild
function WeaponView:UpcomingCounts()
  local n = 0
  for _, grp in ipairs(ns.WeaponPtrSources) do
    for _, list in pairs(grp.types) do n = n + #list end
  end
  return n, ns.WeaponPtrBuild and ns.WeaponPtrBuild.ptr or nil
end

-- Tooltip for the header counter (shared wording; the host wires its own hover frame over the label).
---@param owner table  the WoW frame the tooltip anchors to
function WeaponView:ShowCountTooltip(owner)
  GameTooltip:SetOwner(owner, "ANCHOR_BOTTOMRIGHT")
  GameTooltip:SetText("Collected weapon totals")
  GameTooltip:AddLine("|cffffffffsources|r — weapon-source rows shown for the current filter.", 0.8, 0.8, 0.8, true)
  GameTooltip:AddLine("|cffffffffappearances|r — individual weapon looks across those sources.", 0.8, 0.8, 0.8, true)
  GameTooltip:AddLine("|cffffffffcollected|r — looks you've collected.", 0.8, 0.8, 0.8, true)
  GameTooltip:Show()
end

---@class Warbandeer_Collected
---@field WeaponView WeaponView
ns.WeaponView = WeaponView

-- Share the weapon grid with sibling addons (Warbandeer's embedded collected view) via the API
-- global, so both hosts build it from this one place. api.lua loads first, so the table exists.
-- The companion files reopen this same table, so their methods land on the shared class too.
_G.WarbandeerCollectedApi.WeaponView = WeaponView
