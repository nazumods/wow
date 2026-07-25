---@type Warbandeer_Collected
local ns = select(2, ...)
local WeaponView = ns.WeaponView

-- Per-cell rating overlays for the Weapons grid, and its empty state. The star + tier pip are drawn
-- by ns.ApplyCellMarks and the message by ns.GridEmptyMessage, both shared with the armor grid; what
-- lives here is the weapon RESOLUTION — what a weapon cell's marks mean.
--
-- A weapon cell is a (source × weapon type) bucket holding several appearances (one raid can drop
-- four daggers), so its marks aggregate over the looks inside it: wanted when any one of them is,
-- pipped with the best tier present. That's the same aggregation the armor grid's row-level
-- `groupWanted` does over a group's class sets. The armor analogue of this file is DataViewMarks.lua.
--
-- Driven entirely by live DB state, so re-applying after any toggle / re-sort is enough — the cell
-- data carries only the `_source`/`_type` identity to resolve its look list by (the same identity
-- the dressed-cell cursor matches on).

---@param cell Cell
---@param visuals number[]?  the cell's appearance list, or nil for a blank / name cell
function WeaponView:_applyCellMarks(cell, visuals)
  ns.ApplyCellMarks(cell,
    visuals and ns:WeaponCellWanted(visuals),
    visuals and ns:WeaponCellRank(visuals))
end

-- Re-apply every cell's overlays from current DB state. Cheap enough to run on every update()/
-- re-sort; cells persist across rebuilds, so their overlays do too.
function WeaponView:_refreshMarks()
  for r = 1, #self.cells do
    local row = self.cells[r]
    for c = 1, #self.cols do
      local cell = row[c]
      if cell then
        local data = cell.data
        local grp = type(data) == "table" and data._source or nil
        self:_applyCellMarks(cell, grp and grp.types[data._type] or nil)
      end
    end
  end
end

-- Show or hide the centered empty-state message: "wanted only" is on and nothing matched, so the
-- grid reads as intentionally empty rather than blank/broken. ResizeRows already collapsed the row
-- area; the shared helper reserves the height back and the host's onResized refits the window.
---@param on boolean
function WeaponView:_setEmpty(on)
  ns.GridEmptyMessage(self, on, "You haven't flagged any weapon looks wanted.")
end
