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
---@field baseName fun(name: string): string
---@field sortByExpansion fun(order: number[], source: table[], reverse: boolean?)
---@field EnsureDressedCursor fun(grid: table)
---@field HighlightGridCell fun(grid: table, match: (fun(data: table): boolean)?, scroll: boolean?)
---@field expansionBadgeOptions fun(source: table[]): table[]
---@field filterToggle fun(strip: table, theme: table, spec: table): table, table

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
