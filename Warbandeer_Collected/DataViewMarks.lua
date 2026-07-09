---@type Warbandeer_Collected
local ns = select(2, ...)
local ui = ns.ui
local Texture, Label = ui.Texture, ui.Label
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

-- Per-cell rating overlays: a gold "wanted" star (top-left) and the tier letter
-- in its tier color (top-right), both lazily created on the cell and reused.
-- Driven entirely by live DB state, so re-applying after any toggle / re-sort is
-- enough — the cell data carries only the setId to look them up by.
local STAR = 11

---@param cell Cell
---@param setId number?
function DataView:_applyCellMarks(cell, setId)
  if setId and ns:IsWanted(setId) then
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

  local rank = setId and ns:EffectiveRank(setId, self._playerRace)
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

-- Thickness (px) of the dressed-set cursor's edges.
local CURSOR = 2

-- Lazily build the dressed-set cursor: a single reusable frame outlined by four white
-- edge textures (the house 4-edge-outline idiom, cf. the dressing room's factionPanel),
-- parented to the row area so it scrolls with the cells and lifted above them so the
-- outline sits on top of the cell backdrops.
function DataView:_ensureDressedBox()
  if self._dressedBox then return end
  local box = ui.Frame:new{ parent = self.rowArea }
  box:Level(self.rowArea:Level() + 5)
  local function edge(pos)
    Texture:new{ parent = box, layer = ui.layer.Overlay, color = {1, 1, 1, 1}, position = pos }
  end
  edge{ TopLeft = {0, 0}, TopRight = {0, 0}, Height = CURSOR }
  edge{ BottomLeft = {0, 0}, BottomRight = {0, 0}, Height = CURSOR }
  edge{ TopLeft = {0, 0}, BottomLeft = {0, 0}, Width = CURSOR }
  edge{ TopRight = {0, 0}, BottomRight = {0, 0}, Width = CURSOR }
  self._dressedBox = box
end

-- Draw the cursor box around the exact cell of the set currently previewed in the
-- shared dressing room, following the room as the user arrow-navigates: class nav
-- (Step, same group row) slides the box left/right across columns and tier nav
-- (StepTier, sibling group) moves it up/down to another row. The cell is keyed by
-- setId **and** classIndex (the class column), because PvP armour-type sets share one
-- base setId across several class columns — setId alone would box the wrong (first)
-- one. Broadcast from the room via ns:OnDressedSetChanged; nil (close) hides it.
-- `scroll` brings the cell's row into view on open/nav (via the host's onEnsureVisible
-- hook) but not on a passive re-sort re-resolve.
---@param setId number?  the previewed set, or nil to clear the cursor
---@param classIndex number?  the set's class column (its slot in the positional grp.sets)
---@param scroll boolean?  scroll the matched cell's row into view
function DataView:HighlightSet(setId, classIndex, scroll)
  self._dressedSetId = setId
  self._dressedClassIndex = classIndex
  if setId then
    for r = 1, #self.cells do
      local row = self.cells[r]
      for c = 1, #self.cols do
        local cell = row[c]
        local data = cell and cell.data
        if type(data) == "table" and data.setId == setId and data.classIndex == classIndex then
          self:_ensureDressedBox()
          self._dressedBox:TopLeft(cell, ui.edge.TopLeft, 0, 0)
          self._dressedBox:BottomRight(cell, ui.edge.BottomRight, 0, 0)
          self._dressedBox:Show()
          if scroll and self.onEnsureVisible then
            self:onEnsureVisible((r - 1) * self.cellHeight, self.cellHeight)
          end
          return
        end
      end
    end
  end
  -- Cleared, or the set isn't currently visible (filtered out / other mode).
  if self._dressedBox then self._dressedBox:Hide() end
end

-- Re-apply cell overlays from current DB state. Cheap enough to run on every
-- update()/re-sort; cells persist across re-sorts so their overlays do too.
-- With `onlySetId` set, only cells carrying that setId are refreshed — used after
-- a single wanted/rank toggle so the clicked cell's *siblings* (other class columns
-- in the same group can share one base setId) update too, not just the clicked cell.
---@param onlySetId number?
function DataView:_refreshMarks(onlySetId)
  self._playerRace = ns:PlayerRace()
  for r = 1, #self.cells do
    local row = self.cells[r]
    for c = 1, #self.cols do
      local cell = row[c]
      if cell then
        local data = cell.data
        local setId = type(data) == "table" and data.setId or nil
        if not onlySetId or setId == onlySetId then
          self:_applyCellMarks(cell, setId)
        end
      end
    end
  end
end
