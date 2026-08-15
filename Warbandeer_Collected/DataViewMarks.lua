---@type Warbandeer_Collected
local ns = select(2, ...)
local DataView = ns.DataView

-- Drop any active lockout-panel row selection (its row index moves on re-sort / a
-- dataset swap): un-highlight the name, hide the arrow, close the panel. Window-only
-- — embedded hosts have no lockout selection. Selection state (`self._selectedRow` /
-- `self._arrow`) is set by the name-cell click handler in DataViewData.lua.
function DataView:_clearSelection()
  -- Nothing selected, nothing to clear — and callers no longer have to know whether this grid can even
  -- have a selection (#864). It replaces three `if not self.embedded then` guards at the call sites,
  -- and closes a latent cross-host bug those guards were the only defence against: `ns.HideLockoutView`
  -- is global, so an embedded grid re-filtering would have closed the STANDALONE window's lockout panel.
  if not self._selectedRow then return end
  -- `_selectedRow` is a DATA index; under virtualisation `cells` is keyed by viewport slot, so the
  -- translation has to go through ns.ResidentCell (nil when the row isn't on screen — normal, and
  -- nothing to un-highlight in that case).
  local cell = ns.ResidentCell(self, self._selectedRow, DataView.NAME_COL)
  if cell then cell.label:Color(WHITE_FONT_COLOR) end
  self._selectedRow = nil
  if self._arrow then self._arrow:Hide() end
  ns.HideLockoutView()
end

-- Re-apply the lockout selection's highlight after a rebind has moved which slot holds the selected
-- DATA row (`ns.OnGridRebind`). Without this, scrolling the selected row out of view and back leaves
-- its name white and the arrow parked on whatever row inherited the slot.
function DataView:_reapplySelection()
  if not self._selectedRow then return end
  -- Reset every resident name cell to white before re-golding the selected one. Under virtualisation a
  -- slot the selected row scrolled out of keeps its gold colour when it recycles to another row —
  -- name-cell data carries no `color`, so Cell:Label's guarded re-apply never clears it — and the gold
  -- would smear across rows as the selection scrolls (#921). Same "reset all, then set the one"
  -- discipline ns.RefreshGridMarks uses for the star/pip overlays.
  for r = 1, #self.cells do
    local rowCells = self.cells[r]
    local nameCell = rowCells and rowCells[DataView.NAME_COL]
    if nameCell and nameCell.label then nameCell.label:Color(WHITE_FONT_COLOR) end
  end
  local cell = ns.ResidentCell(self, self._selectedRow, DataView.NAME_COL)
  if cell then cell.label:Color(NORMAL_FONT_COLOR:GetRGBA()) end
  local row = ns.ResidentRow(self, self._selectedRow)
  if self._arrow then
    if row then
      self._arrow:TopRight(row, ns.ui.edge.TopLeft, -3, -2)
      self._arrow:Show()
    else
      self._arrow:Hide()   -- selected row scrolled out of the resident window
    end
  end
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

---What a ratings broadcast means for THIS grid (#768 L-8) — the armour half of a decision each grid
---answers for itself, so neither host has to know which key belongs to which grid.
---
---Armour cells are keyed by `setId`, so a weapon-only change cannot have altered a single one of
---them and the whole grid is skipped rather than walked.
---@param setId number?  the armour set that changed
---@param visualID number?  the weapon appearance that changed
---@return boolean affected  false when nothing here can have changed
---@return fun(data: table): boolean|nil only  the cell predicate, nil meaning "every cell"
function DataView:_ratingScope(setId, visualID)
  if visualID and not setId then return false end
  return true, setId and function(data) return data.setId == setId end or nil
end
