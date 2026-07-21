---@type Warbandeer_Collected
local ns = select(2, ...)
local floor, max = math.floor, math.max
local ui = ns.ui
local Frame, Texture = ui.Frame, ui.Texture

-- Shared grid primitives used by BOTH the armor grid (DataView*) and the weapon grid (WeaponView*):
-- the red→green completion cell + gradient, the expansion row-sort, and the dressed-cell cursor.
-- The two grids are parallel TableFrame subclasses whose row BUILDERS and per-cell marks genuinely
-- differ, but these primitives were byte-for-byte identical copies — extracted here so there's one
-- implementation and the two can't drift. Everything hangs on `ns`; the grids call these at
-- row-build / highlight time (runtime), so load order relative to the data files doesn't matter.

---@class Warbandeer_Collected
---@field gridShades number[][]  10-shade red→green completion gradient (shared cell coloring)
---@field CompletionCell fun(collected: number, total: number, cell: table?): table
---@field baseName fun(name: string): string
---@field sortByExpansion fun(order: number[], source: table[], reverse: boolean?)
---@field EnsureDressedCursor fun(grid: table)
---@field HighlightGridCell fun(grid: table, match: (fun(data: table): boolean)?, scroll: boolean?)

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
