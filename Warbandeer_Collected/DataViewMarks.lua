---@type Warbandeer_Collected
local ns = select(2, ...)
local DataView = ns.DataView

-- Drop any active lockout-panel row selection (its row index moves on re-sort / a
-- dataset swap): un-highlight the name, hide the arrow, close the panel. Window-only
-- — embedded hosts have no lockout selection. Selection state (`self._selectedRow` /
-- `self._arrow`) is set by the name-cell click handler in DataViewData.lua.
function DataView:_clearSelection()
  if self._selectedRow and self.cells[self._selectedRow] and self.cells[self._selectedRow][2] then
    self.cells[self._selectedRow][2].label:Color(WHITE_FONT_COLOR)
  end
  self._selectedRow = nil
  if self._arrow then self._arrow:Hide() end
  ns.HideLockoutView()
end

-- Per-cell rating overlays (the star + tier pip themselves are drawn by ns.ApplyCellMarks, shared
-- with the weapons grid). This half is the armour resolution: what a set's marks MEAN — its own
-- wanted flag, and its tier as the selected race sees it. Driven entirely by live DB state, so
-- re-applying after any toggle / re-sort is enough — the cell data carries only the setId.
---@param cell Cell
---@param setId number?
function DataView:_applyCellMarks(cell, setId)
  ns.ApplyCellMarks(cell,
    setId and ns:IsWanted(setId),
    setId and ns:EffectiveRank(setId, self._playerRace))
end

-- Box the cell of the set currently previewed in the shared dressing room, following the room as
-- the user arrow-navigates: class nav (Step) slides the box across columns, tier nav (StepTier)
-- moves it to another row. Keyed by setId **and** classIndex — PvP armour-type sets share one base
-- setId across several class columns, so setId alone would box the wrong (first) one. Broadcast from
-- the room via ns:OnDressedSetChanged; nil (close) hides it. `scroll` brings the cell's row into view
-- on open/nav (via the host's onEnsureVisible hook) but not on a passive re-sort re-resolve. The
-- cursor box + cell scan are shared with the weapons grid (ns.HighlightGridCell / EnsureDressedCursor).
---@param setId number?  the previewed set, or nil to clear the cursor
---@param classIndex number?  the set's class column (its slot in the positional grp.sets)
---@param scroll boolean?  scroll the matched cell's row into view
function DataView:HighlightSet(setId, classIndex, scroll)
  self._dressedSetId = setId
  self._dressedClassIndex = classIndex
  ns.HighlightGridCell(self, setId and function(data)
    return data.setId == setId and data.classIndex == classIndex
  end or nil, scroll)
end

-- Re-apply cell overlays from current DB state. Cheap enough to run on every
-- update()/re-sort; cells persist across re-sorts so their overlays do too.
--
-- `only` narrows the pass — used after a single wanted/rank toggle so the clicked cell's *siblings*
-- (other class columns in the same group can share one base setId) update too, not just the clicked
-- cell. It is a **predicate over the cell's data**, not a bare setId, because the weapons grid keys
-- its marks on something else entirely (#770 step 10); the caller builds the comparison.
--
-- The walk itself is `ns.RefreshGridMarks`, shared with the weapons grid.
---@param only fun(data: table): boolean|nil
function DataView:_refreshMarks(only)
  self._playerRace = ns:PlayerRace()
  ns.RefreshGridMarks(self, function(data) return data.setId end, only)
end
