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
--
-- **Takes the same `only` predicate the armour grid does as of #770 step 10** — the enabling half of
-- #768's L-8, where a rating edit walks every cell of BOTH grids because this one had no way to be
-- narrowed. Nothing passes one yet: the ratings broadcast carries a setId, which is meaningless
-- here (a cell is keyed by its source + weapon type, not a set), so scoping this grid needs a
-- weapon-keyed signal rather than just the parameter.
--
-- The walk itself is `ns.RefreshGridMarks`, shared with the armour grid.
---@param only fun(data: table): boolean|nil
function WeaponView:_refreshMarks(only)
  ns.RefreshGridMarks(self, function(data)
    local grp = data._source
    return grp and grp.types[data._type] or nil
  end, only)
end

---What a ratings broadcast means for THIS grid (#768 L-8) — the weapons half; see the armour one in
---DataViewMarks.lua.
---
---This is what L-8 was waiting on. A weapon cell has no set id — it is one `(source, type)` pair
---holding a list of visualIDs — so a `setId` had nothing to narrow here and the grid took a full
---pass on every armour rating change, including while hidden. Given a `visualID` it can now scope to
---the cells whose source actually drops that appearance, and an armour-only change skips it outright.
---@param setId number?  the armour set that changed
---@param visualID number?  the weapon appearance that changed
---@return boolean affected  false when nothing here can have changed
---@return fun(data: table): boolean|nil only  the cell predicate, nil meaning "every cell"
function WeaponView:_ratingScope(setId, visualID)
  if setId and not visualID then return false end
  if not visualID then return true, nil end
  return true, function(data)
    local grp = data._source
    local visuals = grp and grp.types[data._type]
    if not visuals then return false end
    for _, v in ipairs(visuals) do
      if v == visualID then return true end
    end
    return false
  end
end

-- Show or hide the centered empty-state message, so an empty grid reads as intentionally empty
-- rather than blank/broken. ResizeRows already collapsed the row area; the shared helper reserves
-- the height back, phrases both states, and the host's onResized refits the window.
--
-- Shown for ANY empty result since #768 L-5, not just the ★ filter — an expansion × category
-- combination matching nothing left a bare header and no explanation.
---@param on boolean
function WeaponView:_setEmpty(on) ns.GridEmptyMessage(self, on, "weapon looks") end
