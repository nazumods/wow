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
---@field ModeToggle fun(spec: table): table
---@field gridShades number[][]  10-shade red→green completion gradient (shared cell coloring)
---@field CompletionCell fun(collected: number, total: number, cell: table?): table
---@field ApplyCellMarks fun(cell: table, wanted: boolean?, rank: string?)  wanted star + tier pip overlays
---@field GRID_EMPTY_H number  row-area height reserved for a grid's empty-state message
---@field GridEmptyMessage fun(grid: table, on: boolean, text: string)
---@field baseName fun(name: string): string
---@field sortByExpansion fun(order: number[], source: table[], reverse: boolean?)
---@field FitNameCol fun(grid: table, nameCol: number): boolean
---@field GridMatches fun(view: table, grp: table): boolean
---@field CategoryOptions fun(source: table[], order: string[]): table[]
---@field BuildGridStrip fun(grid: table, parent: table, onModeChanged: fun()?, words: string): table
---@field EnsureDressedCursor fun(grid: table)
---@field HighlightGridCell fun(grid: table, match: (fun(data: table): boolean)?, scroll: boolean?)
---@field expansionBadgeOptions fun(source: table[]): table[]
---@field filterToggle fun(strip: table, theme: table, spec: table): table, table

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

-- Lazily build a grid's dressed-cell cursor: one reusable white 4-edge box parented to the row area
-- (so it scrolls with the cells) and lifted above them. Shared by both grids' highlight paths.
---@param grid table  a DataView / WeaponView instance
function ns.EnsureDressedCursor(grid)
  if grid._dressedBox then return end
  local box = Frame:new{ parent = grid.rowArea }
  box:Level(grid.rowArea:Level() + 5)
  local function edge(pos)
    Texture:new{ parent = box, layer = ui.layer.Overlay, color = {1, 1, 1, 1}, position = pos }
  end
  edge{ TopLeft = {0, 0}, TopRight = {0, 0}, Height = 2 }
  edge{ BottomLeft = {0, 0}, BottomRight = {0, 0}, Height = 2 }
  edge{ TopLeft = {0, 0}, BottomLeft = {0, 0}, Width = 2 }
  edge{ TopRight = {0, 0}, BottomRight = {0, 0}, Width = 2 }
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
-- (the host's onResized → _fitToGrid then sizes the window to fit). The wording is the caller's, so
-- each grid names what it has none of.
---@param grid table  a DataView / WeaponView instance
---@param on boolean
---@param text string
function ns.GridEmptyMessage(grid, on, text)
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

-- ── The Armor | Weapons mode toggle ────────────────────────────────────────────--
--
-- Built the same way wherever it appears (#653): the collection window's strip row and the
-- dressing room's control row. Two halves in one framed box, the active one bordered gold — the
-- room's copy is a remote for `MainWindow:SetMode`, so a second hand-rolled build would be two
-- implementations of one control, which is the thing this file exists to prevent.
local SEG_OFF = {0.05, 0.05, 0.06, 0.92}

---Build an Armor|Weapons segmented toggle.
---
---`onClick(weapons)` fires with the mode that half selects. The returned handle's `Select(weapons)`
---repaints it — and `Select(nil)` lights NEITHER half, which is what the dressing room shows while
---it's previewing something that belongs to neither grid (a loaded library look).
---@param spec table  { parent, theme, position (anchor only), width, height, weapons?, onClick }
---@return table  { armor: Texture, weapons: Texture, Select: fun(self, weapons: boolean?) }
function ns.ModeToggle(spec)
  local theme, w, h = spec.theme, spec.width, spec.height
  local gold = theme.colors.gold or theme.colors.header
  local caps = theme.fonts.caps
  -- The caller supplies the anchor; the size is this control's own business.
  local pos = {}
  for key, value in pairs(spec.position) do pos[key] = value end
  pos.Width, pos.Height = w, h

  local seg = Frame:new{ parent = spec.parent, position = pos }
  Texture:new{ parent = seg, layer = ui.layer.Background, position = { All = true }, color = SEG_OFF }

  local function half(x, label, weapons)
    local cell = Frame:new{ parent = seg, position = { TopLeft = {x, 0}, Width = w / 2, Height = h } }
    local border = Texture:new{ parent = cell, layer = ui.layer.Background, position = { All = true },
      color = SEG_OFF }
    Texture:new{ parent = cell, layer = ui.layer.Border, color = {0.09, 0.09, 0.11, 0.95},
      position = { TopLeft = {1, -1}, BottomRight = {-1, 1} } }
    local btn = Button:new{ parent = cell, position = { All = true },
      OnClick = function() spec.onClick(weapons) end }
    Label:new{ parent = btn, fontInfo = caps and {caps[1], 10} or nil, justifyH = ui.justify.Center,
      position = { All = true }, text = label, color = theme.colors.text }
    return border
  end

  local toggle = { armor = half(0, "Armor", false), weapons = half(w / 2, "Weapons", true) }

  ---@param weapons boolean?  true = Weapons, false = Armor, nil = neither
  function toggle:Select(weapons)
    self.armor:Color(weapons == false and gold or SEG_OFF)
    self.weapons:Color(weapons == true and gold or SEG_OFF)
  end

  toggle:Select(spec.weapons)
  return toggle
end
