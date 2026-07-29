---@type Warbandeer_Collected
local ns = select(2, ...)
local floor, max = math.floor, math.max
local ui = ns.ui
local Frame, Texture, Label, Button = ui.Frame, ui.Texture, ui.Label, ui.Button
local GameTooltip = GameTooltip

-- Shared grid primitives used by BOTH the armor grid (DataView*) and the weapon grid (WeaponView*):
-- the red→green completion cell + gradient, the expansion row-sort, and the dressed-cell cursor.
-- The two grids are parallel TableFrame subclasses whose row BUILDERS and per-cell marks genuinely
-- differ, but these primitives were byte-for-byte identical copies — extracted here so there's one
-- implementation and the two can't drift. Everything hangs on `ns`; the grids call these at
-- row-build / highlight time (runtime), so load order relative to the data files doesn't matter.

---@class Warbandeer_Collected
---@field gridCellWidth number  width of one data column, shared by both grids
---@field gridShades number[][]  10-shade red→green completion gradient (shared cell coloring)
---@field CompletionCell fun(collected: number, total: number, cell: table?): table
---@field ApplyCellMarks fun(cell: table, wanted: boolean?, rank: string?)  wanted star + tier pip overlays
---@field GridNameCell fun(grp: table): table  a row's leading badge + name cell, with its expansion tooltip
---@field GRID_EMPTY_H number  row-area height reserved for a grid's empty-state message
---@field GridEmptyMessage fun(grid: table, on: boolean, noun: string)
---@field baseName fun(name: string): string
---@field sortByExpansion fun(order: number[], source: table[], reverse: boolean?)
---@field FitNameCol fun(grid: table, nameCol: number): boolean
---@field PadNameCol fun(grid: table, nameCol: number, extra: number)
---@field WantedOnlyActive fun(view: table): boolean  is the ★ filter in force (never under PTR preview)
---@field GridMatches fun(view: table, grp: table): boolean
---@field CategoryOptions fun(source: table[], order: string[]): table[]
---@field BuildGridStrip fun(grid: table, parent: table, onModeChanged: fun()?, words: string): table
---@field RefreshGridMarks fun(grid: table, resolve: fun(data: table): any, only: (fun(data: table): boolean?)?)
---@field EnsureRowVisible fun(scroll: table, rowTop: number, rowH: number)
---@field GridRowOrder fun(view: table, source: table[], wantedFn: fun(grp: table): boolean): number[]
---@field EnsureDressedCursor fun(grid: table)
---@field HighlightGridCell fun(grid: table, match: (fun(data: table): boolean)?, scroll: boolean?)
---@field expansionBadgeOptions fun(source: table[]): table[]
---@field filterToggle fun(strip: table, theme: table, spec: table): table, table

-- ─── Scrolling a row into view ───────────────────────────────────────────────

---Scroll `scroll` the minimum distance that brings a row fully into view: nothing if it already is,
---up to its top edge if it sits above, down to its bottom edge if below.
---
---This seven-line clamp was byte-identical **four times across two addons** (#770 step 11) — both
---hosts of both grids. `VerticalScroll` clamps an out-of-range target itself, so no bounds maths.
---
---It lives here rather than on LibNUI's `ScrollFrame` deliberately: a LibNUI change is a dependency
---bump plus README/CONTEXT rows in the same commit, and nothing outside these grids wants it yet.
---Promote it if a second suite addon ever does.
---@param scroll table  a LibNUI ScrollFrame
---@param rowTop number  the row's offset from the top of the scrolled content
---@param rowH number  the row's height
function ns.EnsureRowVisible(scroll, rowTop, rowH)
  local cur, view = scroll:VerticalScroll(), scroll:Height()
  if rowTop < cur then
    scroll:VerticalScroll(rowTop)
  elseif rowTop + rowH > cur + view then
    scroll:VerticalScroll(rowTop + rowH - view)
  end
end

-- ─── Cell marks ──────────────────────────────────────────────────────────────

---Walk every cell and re-apply its rating overlays from live DB state.
---
---The walk, the `type(data) == "table"` guard and the single `_applyCellMarks` call were identical
---in both grids (#770 step 10); only the line deriving a cell's mark key differed, which is now the
---`resolve` argument.
---
---**A cell whose data isn't a table still gets refreshed with nil** on an unscoped pass — that is
---what CLEARS the overlays on blank and name cells, so it must not be optimised into a skip.
---
---`only` narrows the pass to the cells it matches, which is what keeps a single Shift-click from
---repainting the whole grid. It takes the cell's data rather than a bare id because the two grids
---key on different things — a setId for armour, weapon-type identity for weapons — which is the
---enabling half of #768's L-8.
---@param grid table  a DataView / WeaponView instance
---@param resolve fun(data: table): any  the cell's mark key, from its data
---@param only fun(data: table): boolean|nil  optional filter; non-table cells never match it
function ns.RefreshGridMarks(grid, resolve, only)
  for r = 1, #grid.cells do
    local row = grid.cells[r]
    for c = 1, #grid.cols do
      local cell = row[c]
      if cell then
        local data = type(cell.data) == "table" and cell.data or nil
        if not only then
          grid:_applyCellMarks(cell, data and resolve(data) or nil)
        elseif data and only(data) then
          grid:_applyCellMarks(cell, resolve(data))
        end
      end
    end
  end
end

-- ─── The filter strip ────────────────────────────────────────────────────────

---Build the filter chrome both grids sit under: PTR pill → Wanted ★ → sort → Expansion dropdown →
---Category dropdown, in that order, themed from the grid's own theme.
---
---This was ~50 executable lines written out twice (#770 step 9) — same locals, same control order,
---same `_repaintPtr`/`_syncWantedBtn` closures, same closing width. Each class keeps a three-line
---`BuildFilterStrip` supplying only `words`, the noun its tooltips read in.
---
---**The sort handler fires `onResized` for both grids now**, where only the weapon strip did. The
---two were split on it and the plan decided in favour of calling it: `onResized` is `_fitToGrid` in
---both hosts — idempotent, no data effect — so the armour grid gains a harmless refit and the two
---call sites become identical, which is what makes the extraction clean rather than conditional.
---@param grid table  a DataView / WeaponView instance
---@param parent table  frame to parent the strip to
---@param onModeChanged fun()?  fired after the PTR toggle or either dropdown changes the shown rows
---@param words string  plural noun for the ★ tooltips ("sets" / "weapons")
---@return table strip
function ns.BuildGridStrip(grid, parent, onModeChanged, words)
  local theme = grid:Theme()
  -- Dark's `header` token is the same gold, so the toggles read on/off without void-dark.
  local gold, divider = theme.colors.gold or theme.colors.header, theme.colors.divider
  -- Expansion names get long ("Wrath of the Lich King"), so that dropdown is wider.
  local BW, BH, GAP, DW, DW_EXP = 48, grid.STRIP_H, 6, 110, 190
  local IB = BH
  local TEX = [[Interface\AddOns\Warbandeer_Collected\textures\]]
  local NEWEST_ICON, OLDEST_ICON = TEX .. "sort-newest", TEX .. "sort-oldest"
  local strip = ui.Frame:new{ parent = parent, position = { Height = BH } }

  -- Each toggle is the shared filter-strip button primitive (border + icon pill / caption + Button);
  -- it reads the strip's height + the grid theme, so the call just supplies x / face / handlers.
  local function toggle(spec) return ns.filterToggle(strip, theme, spec) end

  -- Running x cursor, since the icon toggles are narrower than the text pill.
  local x = 0
  local ptrBorder, wantedBorder, sortIcon
  ptrBorder = toggle{ x = x, text = "PTR", active = false, onClick = function()
    grid:SetPtr(not grid._ptr)   -- repaints the border via _repaintPtr below
    if onModeChanged then onModeChanged() end
  end }
  -- Lets SetPtr repaint the border when the state is set programmatically (the Armor/Weapons swap
  -- carries the PTR mode across, so both grids' toggles stay in sync — see the host's SetMode).
  grid._repaintPtr = function(on) ptrBorder:Color(on and gold or divider) end
  x = x + BW + GAP

  wantedBorder = toggle{ x = x, atlas = ns.WantedIcon, tint = false, active = false,
    tip = function()
      return grid._wantedOnly and ("Wanted only — click to show all %s"):format(words)
                              or  ("Show only %s you've flagged wanted"):format(words)
    end,
    onClick = function() grid:ToggleWanted() end }
  -- Let other chrome (the wanted-count counter) drive the same toggle and keep the button's border
  -- in sync (the star keeps its natural gold).
  grid._syncWantedBtn = function() wantedBorder:Color(grid._wantedOnly and gold or divider) end
  x = x + IB + GAP

  -- Neutral border (always-on control, no active-highlight glow); the gold calendar glyph carries
  -- the direction. Only the icon face is captured (swapped on toggle).
  sortIcon = select(2, toggle{ x = x, tex = NEWEST_ICON, tint = gold,
    tip = function() return grid._reverse and "Newest first — click for oldest first"
                                           or "Oldest first — click for newest first" end,
    onClick = function()
      local rev = grid:ToggleOrder()
      sortIcon:Texture(rev and NEWEST_ICON or OLDEST_ICON)
      if grid.onResized then grid:onResized() end
    end })
  x = x + IB + GAP

  local dx = x
  ui.FilterDropdown:new{
    parent = strip, position = { TopLeft = {dx, 0} }, width = DW_EXP, menuWidth = 200,
    bordered = true, selected = "all", options = grid:ExpansionOptions(),
    onSelect = function(_, key) grid:SetExpansion(key); if onModeChanged then onModeChanged() end end,
  }
  ui.FilterDropdown:new{
    parent = strip, position = { TopLeft = {dx + DW_EXP + GAP, 0} }, width = DW, menuWidth = 120,
    bordered = true, selected = "all", options = grid:CategoryOptions(),
    onSelect = function(_, key) grid:SetCategory(key); if onModeChanged then onModeChanged() end end,
  }
  strip:Width(dx + DW_EXP + GAP + DW)
  return strip
end

-- ─── Shared filtering ────────────────────────────────────────────────────────
-- Both grids filter rows the same way and build their category dropdown the same way; these were
-- byte-identical copies in the two data/filter files (#770 step 1).

---Does `grp` pass the view's active expansion/category filters?
---
---A plain function rather than a method because both grids' row builders run during the base
---TableFrame construction — before the subclass's methods are mixed onto the instance.
---
---PTR preview is never filtered (a small upcoming-only list with no category), so the dropdowns
---apply to the live grid only.
---Is the "wanted only" (★) filter actually in force?
---
---**Not under PTR preview.** The upcoming list is a handful of rows with no collection state behind
---it, so filtering it to what you've flagged mostly empties it — and the expansion/category
---dropdowns are already bypassed there (see `GridMatches` right below). The star was the one filter
---that still bit, because it is applied outside `GridMatches`: once in the row gate of
---`GridRowOrder`, again in each grid's cell builder, and again in each `VisibleCounts`. That left
---PTR preview half-filtered — dropdowns ignored, star honoured — and the header counter, which reads
---`UpcomingCounts()` and honours nothing, contradicting the grid underneath it.
---
---The button keeps its lit state across the toggle rather than being forced off, exactly as the
---dropdowns keep their selection: the filter is the user's standing preference, it simply does not
---apply while previewing.
---@param view table  a DataView / WeaponView instance
---@return boolean
function ns.WantedOnlyActive(view)
  return view._wantedOnly and not view._ptr
end

---@param view table  a DataView / WeaponView instance
---@param grp table  a row source group
---@return boolean
function ns.GridMatches(view, grp)
  if view._ptr then return true end
  if view._expansion ~= "all" and grp.release ~= view._expansion then return false end
  if view._category ~= "all" and grp.category ~= view._category then return false end
  return true
end

---Dropdown option specs for a category filter: "All", then every category actually present in
---`source`. `order` gives the preferred display order; a category present but unlisted is appended
---so the menu can never silently drop one — deliberately, since the data files gain categories
---without the filter code being touched.
---
---Note the appended tail comes off a `pairs` walk, so its order among itself isn't defined. That is
---pre-existing and only affects categories missing from `order`, which is the case the ordering
---list is meant to prevent.
---@param source table[]  the row source (ns.Sets / ns.WeaponSources)
---@param order string[]  preferred display order
---@return table[]  `{ key, label }` specs for `ui.FilterDropdown`
function ns.CategoryOptions(source, order)
  local seen = {}
  for _, g in ipairs(source) do if g.category then seen[g.category] = true end end
  local opts, used = { { key = "all", label = "Category" } }, {}
  for _, c in ipairs(order) do
    if seen[c] then opts[#opts + 1] = { key = c, label = c }; used[c] = true end
  end
  for c in pairs(seen) do
    if not used[c] then opts[#opts + 1] = { key = c, label = c } end
  end
  return opts
end

-- The width of one data column, shared by both grids so they read as the same table (#824).
--
-- They had drifted: armour at 28, weapons at 34. The 34 was sized for a **three-character text
-- caption** ("Wnd", "2Sw", "Xbw") in the original Weapons view (#626); #712/#719 replaced that header
-- with a texture icon, which `TableCol` sizes from `headerHeight` rather than from column width, so
-- the extra 6px stopped buying anything and just made the weapons grid airier and its window ~108px
-- wider. One constant rather than two literals that agree today — that is how they drifted the first
-- time. Cell contents are already identical: both grids build cells with `ns.CompletionCell`.
ns.gridCellWidth = 28

-- 10-shade red→green completion gradient: a cell's uncollected count is tinted by the collected
-- fraction (index 1 = none collected → red, 10 = all → green). Shared so both grids read alike.
ns.gridShades = {
  {165/255, 0/255, 38/255, 1}, {215/255, 48/255, 39/255, 1}, {244/255, 109/255, 67/255},
  {253/255, 174/255, 97/255}, {254/255, 224/255, 139/255}, {217/255, 239/255, 139/255},
  {166/255, 217/255, 106/255}, {102/255, 189/255, 99/255}, {26/255, 152/255, 80/255},
  {0, 104/255, 55/255},
}

-- Fill `cell` (a fresh cell-data table carrying the caller's handlers + identity fields, created if
-- nil) as a completion cell: a centered green check when fully collected (`collected >= total`),
-- else the uncollected count (`total - collected`) tinted by the collected fraction. The shared
-- renderer behind both the armor and weapon grids.
---@param collected number
---@param total number
---@param cell table?  handlers + identity fields to keep (setId/classIndex, or _source/_type)
---@return table
function ns.CompletionCell(collected, total, cell)
  cell = cell or {}
  if collected >= total then
    cell.atlas = ns.icons.CheckGreen
    cell.atlasSize = false
    cell.position = { Center = {}, Size = {13, 13} }
  else
    cell.text = total - collected
    cell.justifyH = ui.justify.Center
    cell.color = ns.gridShades[max(1, floor(collected / total * 10))]
  end
  return cell
end

-- A row's leading name cell: the group's expansion badge (an inline texture escape, auto-sized to the
-- font height via `:0`) followed by its name, with the expansion's own name in a cursor-anchored
-- tooltip on hover — cursor-anchored because the cell spans the whole name column, so a frame anchor
-- would land far off to the side.
--
-- Shared because both grids draw the same badge + name, and there was no reason for only the armour
-- one to say which expansion the badge meant: the weapon rows carried the identical badge and were
-- inert. Callers add their own handlers on top of the returned table — the armour window hangs the
-- lockout-panel click off it, and nothing else does.
---@param grp table  a row source group
---@return table  cell data
function ns.GridNameCell(grp)
  local icon = ns.ReleaseIcons[grp.release]
  local expName = ns.Releases[grp.release]
  return {
    text = icon and ("|T%s:0|t %s"):format(icon, grp.name) or grp.name,
    onEnter = expName and function()
      GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
      GameTooltip:SetText(expName)
      GameTooltip:Show()
    end or nil,
    onLeave = expName and function() GameTooltip:Hide() end or nil,
  }
end

-- Per-cell rating overlays, drawn identically by both grids: a gold "wanted" star (top-left) and the
-- tier letter in its tier colour (top-right), each lazily created on the cell and reused. Only the
-- DRAWING is shared — the caller resolves what the marks mean, which is where the two grids genuinely
-- differ: the armour grid reads a set's own flags, the weapon grid aggregates over the bucket of
-- looks a cell holds (see ns:WeaponCellWanted / ns:WeaponCellRank).
local STAR = 11

---@param cell table  a TableFrame Cell
---@param wanted boolean?  draw the wanted star
---@param rank string?  tier letter to pip, or nil for none
function ns.ApplyCellMarks(cell, wanted, rank)
  if wanted then
    if not cell._wantStar then
      cell._wantStar = Texture:new{
        parent = cell, layer = ui.layer.Overlay,
        atlas = ns.WantedIcon, atlasSize = false,
        position = { TopLeft = {1, -1}, Size = {STAR, STAR} },
      }
    end
    cell._wantStar:Show()
  elseif cell._wantStar then
    cell._wantStar:Hide()
  end

  if rank then
    if not cell._rankPip then
      cell._rankPip = Label:new{
        parent = cell, layer = ui.layer.Overlay, fontObj = "GameFontNormalSmall",
        position = { TopRight = {-1, 0} },
      }
    end
    cell._rankPip:Text(rank)
    cell._rankPip:Color(ns.RankColors[rank])
    cell._rankPip:Show()
  elseif cell._rankPip then
    cell._rankPip:Hide()
  end
end

-- A row's name minus a trailing "(variant)" suffix — the key both grids alphabetize on within an
-- expansion, so a set's variant/difficulty rows stay grouped rather than scattering by suffix.
---@param name string
---@return string
function ns.baseName(name) return (name:gsub("%s*%b()%s*$", "")) end

-- Sort `order` (indices into `source`) by expansion `release` — newest-first when `reverse` — then
-- alphabetically by baseName, then source index (a stable tie-break keeping variant rows in authored
-- order). In place. The shared ordering behind CollectedRows + WeaponRows.
---@param order number[]
---@param source table[]
---@param reverse boolean?
function ns.sortByExpansion(order, source, reverse)
  table.sort(order, function(a, b)
    local ra, rb = source[a].release or 0, source[b].release or 0
    if ra ~= rb then
      if reverse then return ra > rb end
      return ra < rb
    end
    local na, nb = ns.baseName(source[a].name), ns.baseName(source[b].name)
    if na ~= nb then return na < nb end
    return a < b
  end)
end

---Which source rows a grid shows, in the order it shows them: filter, then sort.
---
---Both grids ran the same three steps in the same order — expansion/category filter, "wanted only"
---row gate, `sortByExpansion` — and this is the only part of either grid that can silently change
---**which rows the user sees**, which is why it is pure and why it has specs (#770 step 13).
---
---**The returned values are indices into `source`, not display positions.** That is a contract, not
---an implementation detail: for the armour grid in live mode a group's `source` index is also its
---`ns.Sets` index, and the lockout panel keys off it (`ns.ShowLockoutView(srcIdx, …)`). Renumbering
---these would break lockouts silently — nothing would error, the wrong instance would just open.
---
---The caller picks `source` (the two grids swap different tables under PTR preview) and supplies
---`wantedFn`, since "does this row hold anything wanted" is the one test that differs: a set's
---wanted flag for armour, an appearance's for weapons.
---@param view table  a DataView / WeaponView instance (its filter/sort/PTR flags drive the result)
---@param source table[]  the row source to select from
---@param wantedFn fun(grp: table): boolean  does this group hold anything flagged wanted
---@return number[] order  source indices, in display order
function ns.GridRowOrder(view, source, wantedFn)
  local order = {}
  local wantedOnly = ns.WantedOnlyActive(view)
  for i = 1, #source do
    -- Expansion/category filter, plus (when "wanted only" is on) drop whole rows holding nothing
    -- wanted, so the grid shows just the target list rather than blanked filler rows.
    if ns.GridMatches(view, source[i]) and (not wantedOnly or wantedFn(source[i])) then
      order[#order + 1] = i
    end
  end
  -- Expansion first (newest-first by default), then alphabetically within it; the index tie-break
  -- keeps a set's variant/difficulty rows in authored order.
  ns.sortByExpansion(order, source, view._reverse)
  return order
end

-- Size a grid's name column (`nameCol`) to its widest row label, growing the row area and the frame
-- by the same amount. Both grids autosize a zero-width name column this way, and the two copies had
-- already drifted (one guarded a missing label, the other didn't), so it lives here.
--
-- Measured with `UnboundedWidth` (GetUnboundedStringWidth), NOT `Width` (GetWidth): a cell label is
-- anchored to all four sides of its cell, so once WoW has flushed layout GetWidth reports the
-- anchor-derived width — 0, for a column declared `width = 0` — rather than the text's. Which of the
-- two a constructor-time measurement lands on depends on whether a layout pass happened to run in
-- between, which is why the name column sometimes came up blank on login (#718).
--
-- Fits ONCE, successfully: a pass that lands a non-zero width records it on the grid and every later
-- call returns immediately. The repair callers exist for is a *zero* measurement (GetWidth on an
-- unlaid-out grid), so once there's a real width there's nothing left to repair — and the scan walks
-- every row, which on the several-hundred-row grids is a visible hitch if it runs on every show
-- (it did, on the Armor/Weapons swap). While the width is still 0 the scan is monotonic and applies
-- only the delta, so re-running can never compound it.
---@param grid table  a DataView / WeaponView instance
---@param nameCol number  index of the name column
---@return boolean grew  true when the column actually widened (the host should refit)
function ns.FitNameCol(grid, nameCol)
  local applied = grid._nameColW or 0
  if applied > 0 then return false end   -- already fitted; don't re-walk the rows
  local w = applied
  for _, r in ipairs(grid.cells) do
    local cell = r[nameCol]
    if cell and cell.label then w = max(w, cell.label:UnboundedWidth()) end
  end
  if w <= applied then return false end
  grid._nameColW = w
  grid.cols[nameCol]:Width(w)
  grid.rowArea:Width(grid.rowArea:Width() + (w - applied))
  grid:Width(grid:Width() + (w - applied))
  return true
end

-- Widen `grid`'s name column by `extra` px, growing the row area and the frame with it — the same
-- three-field mutation `FitNameCol` makes, split out so a host can bring a narrower grid up to a
-- wider sibling's total width.
--
-- The armour and weapon grids are genuinely different widths (armour's 13 class columns and long
-- set names against weapons' 17 narrow icon columns and shorter source names — 800 against 704 as
-- measured). A panel that doesn't resize when you toggle between them therefore has to leave one
-- mode short of its own right edge, and it was the weapon grid wearing the whole 96px of it. Padding
-- the narrower grid's NAME column absorbs the difference into left-aligned text with room to spare,
-- rather than into a hole beside the last data column.
--
-- `_nameColW` is kept in step because `FitNameCol` reads it as "the width already applied"; the two
-- must agree or a later fit would compute its delta against a stale number.
---@param grid table
---@param nameCol number  index of the name column
---@param extra number  px to add (no-op at <= 0)
function ns.PadNameCol(grid, nameCol, extra)
  if extra <= 0 then return end
  grid._nameColW = (grid._nameColW or 0) + extra
  grid.cols[nameCol]:Width(grid._nameColW)
  grid.rowArea:Width(grid.rowArea:Width() + extra)
  grid:Width(grid:Width() + extra)
end

-- Lazily build a grid's dressed-cell cursor: one reusable white 4-edge box parented to the row area
-- (so it scrolls with the cells) and lifted above them. Shared by both grids' highlight paths.
--
-- `ui.BorderBox` is exactly this — four edge textures two-point-anchored to their frame's corners at
-- `layer.Overlay`, stretching with it — and LibNUI builds one in this very code path (`Cell.lua`), so
-- the hand-rolled four went (#770 step 17). The `Level` bump stays: the box is still a raised child of
-- the row area, which is what puts it over the cell backdrops.
---@param grid table  a DataView / WeaponView instance
function ns.EnsureDressedCursor(grid)
  if grid._dressedBox then return end
  local box = ui.BorderBox:new{ parent = grid.rowArea, thickness = 2, color = {1, 1, 1, 1} }
  box:Level(grid.rowArea:Level() + 5)
  grid._dressedBox = box
end

-- Box the first cell whose `match(cell.data)` is true, following the grid as it re-resolves; hide the
-- cursor when `match` is nil (cleared) or nothing matches (filtered out). `scroll` asks the host's
-- onEnsureVisible hook to bring the matched row into view. Shared by DataView:HighlightSet +
-- WeaponView:HighlightWeaponCell — each passes a one-line predicate over its own cell identity fields.
---@param grid table
---@param match (fun(data: table): boolean)?
---@param scroll boolean?
function ns.HighlightGridCell(grid, match, scroll)
  if match then
    for r = 1, #grid.cells do
      local row = grid.cells[r]
      for c = 1, #grid.cols do
        local cell = row[c]
        local data = cell and cell.data
        if type(data) == "table" and match(data) then
          ns.EnsureDressedCursor(grid)
          grid._dressedBox:TopLeft(cell, ui.edge.TopLeft, 0, 0)
          grid._dressedBox:BottomRight(cell, ui.edge.BottomRight, 0, 0)
          grid._dressedBox:Show()
          if scroll and grid.onEnsureVisible then
            grid:onEnsureVisible((r - 1) * grid.cellHeight, grid.cellHeight)
          end
          return
        end
      end
    end
  end
  if grid._dressedBox then grid._dressedBox:Hide() end
end

-- Row-area height reserved for a grid's empty-state message. Both grids reach it the same way: the
-- "wanted only" filter matched nothing, ResizeRows(0) collapsed the row area, and a grid that just
-- vanished reads as broken rather than as intentionally empty.
ns.GRID_EMPTY_H = 48

-- Show or hide a centered empty-state message in a grid's row area, reserving GRID_EMPTY_H for it
-- (the host's onResized → _fitToGrid then sizes the window to fit).
--
-- The WORDING lives here too, not just the mechanics: each grid supplies only the noun it has none
-- of, and the two sentences are built from it. Left to the callers, the same two states drifted into
-- two voices — "You don't have any Wanted sets." against "You haven't flagged any weapon looks
-- wanted." — for a message the user reads one toggle apart. The branch stays because the message
-- still has to say WHY it is empty; only the phrasing is now shared.
---@param grid table  a DataView / WeaponView instance
---@param on boolean
---@param noun string  plural noun for what the grid is empty of ("sets" / "weapon looks")
function ns.GridEmptyMessage(grid, on, noun)
  local text = ns.WantedOnlyActive(grid) and ("You haven't flagged any %s wanted."):format(noun)
                                         or  ("No %s match these filters."):format(noun)
  if not on then
    if grid._emptyMsg then grid._emptyMsg:Hide() end
    return
  end
  if not grid._emptyMsg then
    grid._emptyMsg = Label:new{
      parent = grid.rowArea, justifyH = ui.justify.Center,
      color = grid:Theme().colors.muted or {0.6, 0.6, 0.62, 1},
      position = { Center = {} },
    }
  end
  grid._emptyMsg:Text(text)
  grid._emptyMsg:Show()
  grid.rowArea:Height(ns.GRID_EMPTY_H)
  grid:Height(grid.offsetY + ns.GRID_EMPTY_H)
end

-- Dropdown option specs for the expansion filter: "All" (labelled with the dimension, so the button
-- names what it filters when nothing's picked) then one per release present in `source`, newest-first,
-- each label prefixed with the expansion badge; an unresolved release (0) shows as "Other". Shared by
-- both grids' ExpansionOptions (armor over ns.Sets, weapons over ns.WeaponSources).
---@param source table[]
---@return table[]  { key, label } specs for ui.FilterDropdown
function ns.expansionBadgeOptions(source)
  local seen = {}
  for _, g in ipairs(source) do seen[g.release] = true end
  local rels = {}
  for r in pairs(seen) do rels[#rels + 1] = r end
  table.sort(rels, function(a, b) return a > b end)
  local opts = { { key = "all", label = "Expansion" } }
  for _, r in ipairs(rels) do
    local icon = ns.ReleaseIcons[r]
    local name = ns.Releases[r] or (r == 0 and "Other" or tostring(r))
    opts[#opts + 1] = { key = r, label = (icon and ("|T%s:0|t "):format(icon) or "") .. name }
  end
  return opts
end

-- One filter-strip toggle button: a framed control (a recolorable border + a 1px inner border + a
-- Button) carrying either a caption pill (spec.text, BW wide) or a square tinted icon (spec.atlas or
-- spec.tex, BH×BH, with an optional hover tooltip from spec.tip). Returns the border (recolor via
-- :Color) + the face — a Label for text, or the icon Texture (retint via :Color, swap art via
-- :Texture). Both grids' BuildFilterStrip build their toggles through this; the strip's own height is
-- the button height, and gold/divider/caps come from the grid theme.
---@param strip table  the filter strip (its Height() sets the button height)
---@param theme table  the grid's resolved theme (colors.gold/header/divider, fonts.caps)
---@param spec table   { x, text | atlas | tex, active?, tint?, tip?, onClick }
---@return table border, table face
function ns.filterToggle(strip, theme, spec)
  local gold = theme.colors.gold or theme.colors.header
  local divider = theme.colors.divider
  local caps = theme.fonts.caps
  local BH = strip:Height()
  local BW, IB, IPAD, PAD = 48, BH, 2, 8   -- text-pill width; icons are square (BH); glyph inset; label inset
  local isIcon = spec.atlas or spec.tex
  local b = Frame:new{ parent = strip,
    position = { TopLeft = {spec.x, 0}, Width = isIcon and IB or BW, Height = BH } }
  local border = Texture:new{ parent = b, layer = ui.layer.Background, position = { All = true },
    color = spec.active and gold or divider }
  Texture:new{ parent = b, layer = ui.layer.Border, color = {0.05, 0.05, 0.06, 0.92},
    position = { TopLeft = {1, -1}, BottomRight = {-1, 1} } }
  local btn = Button:new{ parent = b, position = { All = true }, OnClick = spec.onClick,
    OnEnter = spec.tip and function(s)
      GameTooltip:SetOwner(s._widget, "ANCHOR_BOTTOMRIGHT")
      GameTooltip:SetText(spec.tip()); GameTooltip:Show()
    end or nil,
    OnLeave = spec.tip and function() GameTooltip:Hide() end or nil,
  }
  if isIcon then
    -- tint=false keeps an already-colored atlas (the gold star) at native color; an explicit color
    -- tints a white silhouette independent of the border; else the glyph tracks the active/off border.
    local vc
    if spec.tint ~= false then vc = spec.tint or (spec.active and gold or divider) end
    local icon = Texture:new{ parent = btn, layer = ui.layer.Artwork,
      atlas = spec.atlas, atlasSize = spec.atlas and false or nil, path = spec.tex,
      vertexColor = vc,
      position = { TopLeft = {IPAD, -IPAD}, BottomRight = {-IPAD, IPAD} } }
    return border, icon
  end
  local label = Label:new{ parent = btn, fontInfo = caps and {caps[1], 10} or nil,
    justifyH = ui.justify.Center, position = { Left = {PAD, 0}, Right = {-PAD, 0} }, text = spec.text }
  return border, label
end
