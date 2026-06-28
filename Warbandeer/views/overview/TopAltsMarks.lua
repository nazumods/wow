---@type Warbandeer
local ns = select(2, ...)
local ui = ns.ui
local Texture, Label = ui.Texture, ui.Label
local TopAlts = ns.overview.TopAlts

local STAR = 11   -- wanted-star overlay size (matches the /collected DataView grid)

-- Apply (or clear) one cell's rating overlays from live Collected DB state: a gold
-- wanted star top-left, the tier letter in its tier color top-right. Cells carry only
-- their setId, so a re-apply after any toggle / re-sort / rating edit is enough; the
-- overlay children are created lazily and reused (shown/hidden), like the Collected grid.
---@param cell Cell
---@param setId number?
function TopAlts:_applyCellMarks(cell, setId)
  local api = WarbandeerCollectedApi
  if api and setId and api:IsWanted(setId) then
    if not cell._wantStar then
      cell._wantStar = Texture:new{
        parent = cell, layer = ui.layer.Overlay,
        atlas = api.WantedIcon, atlasSize = false,
        position = { TopLeft = {1, -1}, Size = {STAR, STAR} },
      }
    end
    cell._wantStar:Show()
  elseif cell._wantStar then
    cell._wantStar:Hide()
  end

  local rank = api and setId and api:EffectiveRank(setId, self._playerRace)
  if rank then
    if not cell._rankPip then
      cell._rankPip = Label:new{
        parent = cell, layer = ui.layer.Overlay, fontObj = "GameFontNormalSmall",
        position = { TopRight = {-1, 0} },
      }
    end
    cell._rankPip:Text(rank)
    cell._rankPip:Color(api.RankColors[rank])
    cell._rankPip:Show()
  elseif cell._rankPip then
    cell._rankPip:Hide()
  end
end

-- Re-apply every cell's overlays from current Collected DB state (non-set cells carry
-- no setId, so they blank). Cheap enough to run on every update()/re-sort and the
-- ratings-changed refresher; cells persist across re-sorts so their overlays do too.
function TopAlts:_refreshMarks()
  local api = WarbandeerCollectedApi
  self._playerRace = api and api:PlayerRace()
  for r = 1, #self.cells do
    local row = self.cells[r]
    for c = 1, #self.cols do
      local cell = row[c]
      if cell then
        local data = cell.data
        self:_applyCellMarks(cell, type(data) == "table" and data.setId or nil)
      end
    end
  end
end
