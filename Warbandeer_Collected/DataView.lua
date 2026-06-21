---@type Warbandeer_Collected
local ns = select(2, ...)
local floor, max = math.floor, math.max
local ui, api, Colors = ns.ui, ns.api, ns.Colors
local lists, prepend = ns.lua.lists, ns.lua.lists.prepend
local Class = ns.lua.Class
local TableFrame, Texture = ui.TableFrame, ui.Texture

local GreenCheck = {
  atlas = ns.icons.CheckGreen,
  atlasSize = false,
  -- Centered, ~one character wide so it lines up with the numeric count cells.
  position = { Center = {}, Size = {13, 13} },
}

-- A class set counts as fully collected when the scan flagged the base set (true)
-- or every appearance is owned (remaining <= 0). The `or` short-circuits before
-- indexing `status`, so passing the boolean `true` is safe.
local function isComplete(status)
  return status == true or status.collected >= status.total
end

local _arrow = nil
local _selectedRow = nil

local shades = {
  {165/255,   0/255,  38/255, 1},
  {215/255,  48/255,  39/255, 1},
  {244/255, 109/255,  67/255},
  {253/255, 174/255,  97/255},
  {254/255, 224/255, 139/255},
  {217/255, 239/255, 139/255},
  {166/255, 217/255, 106/255},
  {102/255, 189/255,  99/255},
  { 26/255, 152/255,  80/255},
  {      0, 104/255,  55/255},
}

---Main grid: one row per set group (lock icon + name), one column per class,
---cells show missing-piece counts color-shaded by completion.
---@class DataView: TableFrame
---@field _reverse boolean? render newest set-group first (defaults true; see ToggleOrder)
---@field _wantedOnly boolean? blank cells for sets that aren't flagged wanted (see ToggleWantedOnly)
---@field _playerRace number? cached canonical race id the rank pips resolve against
local DataView = Class(TableFrame, function(self)
  -- autoadjust name width
  local w = 0
  for _,r in ipairs(self.cells) do
    if #r > 2 then
      w = max(w, r[2].label:Width())
    end
  end
  self.cols[2]:Width(w)
  self.rowArea:Width(self.rowArea:Width() + w)
  self:Width(self:Width() + w)
  self:_refreshMarks()   -- the constructor-time update() ran before our override was mixed in
end, {
  headerHeight = 28,
  _reverse = true,   -- default to newest set-group first
  _wantedOnly = false,
  colInfo = prepend(
    lists.map(ns.icons.classes, function(icon)
      return {
        atlas = icon,
        atlasSize = false,
        width = 28,
        padding = 2,
        justifyH = ui.justify.Center,
        backdrop = {color = ns.Colors.TransparentBlack},
      }
    end),
    { width = 15, backdrop = {color = ns.Colors.TransparentBlack} },
    { width =  0, backdrop = {color = ns.Colors.TransparentBlack} }
  ),
  GetData = function(self)
    local toon = api:GetCharacterData(api:GetCurrentCharacter())
    -- Display order: ns.Sets oldest-first by default; _reverse → newest-first.
    -- `srcIdx` is the real ns.Sets index (the lockout panel keys off it); `dispIdx`
    -- is the on-screen row position (row/cell highlight + arrow key off that). They
    -- differ once reversed, so keep them separate.
    local order = {}
    for i = 1, #ns.Sets do order[i] = self._reverse and (#ns.Sets - i + 1) or i end
    return lists.map(order, function(srcIdx, dispIdx)
      local grp = ns.Sets[srcIdx]
      local lock = toon.instances.locks and toon.instances.locks[grp.instance] and toon.instances.locks[grp.instance][grp.difficulty]
      local gsets = ns.db.sets[grp.id]
      -- Always emit a positional cell per class (blank {} where there's no set, e.g.
      -- Evoker in pre-Dragonflight raids). Returning nil would make table.insert drop
      -- the slot, shifting later classes left and leaving stale cells on re-sort.
      local r = lists.map(grp.sets, function(set)
        local status = gsets and gsets[set.id]
        if not status then return {} end
        -- "Wanted only" blanks the cell (no content/click/marks) for sets that
        -- aren't flagged, so the grid shows just the target list in context.
        if self._wantedOnly and not ns:IsWanted(set.id) then return {} end
        -- Same per-slot source tooltip on every cell, complete or partial — for a
        -- fully-collected set every slot shows green.
        local onEnter = function(cell)
          ns.ShowInfoTip(grp, set, cell, {
            BottomRight = {cell, ui.edge.Top, -2, 2},
          })
        end
        local onLeave = function() ns.HideInfoTip() end
        -- Left-click previews the set; Shift-click flags/unflags it as wanted.
        local onClick = function(cell)
          if IsShiftKeyDown() then
            local nowWanted = ns:ToggleWanted(set.id)
            if self._wantedOnly and not nowWanted then
              self.data = self:GetData(); self:update()   -- it left the filtered view
            else
              self:_applyCellMarks(cell, set.id)
            end
            if ns.window then ns.window:RefreshWanted() end
            ns.RefreshInfoTip()
          else
            ns.ShowDressingRoom(grp, set, self._reverse)
          end
        end
        if isComplete(status) then
          return {
            setId = set.id,
            atlas = GreenCheck.atlas, atlasSize = GreenCheck.atlasSize,
            position = GreenCheck.position,
            onEnter = onEnter, onLeave = onLeave, onClick = onClick,
          }
        end
        return {
            setId = set.id,
            text = status.total - status.collected,
            justifyH = ui.justify.Center,
            color = shades[max(1,floor(status.collected / status.total * 10))],
            onEnter = onEnter,
            onLeave = onLeave,
            onClick = onClick,
          }
      end)
      -- grp.sets can stop short of the newest classes (e.g. no Demon Hunter/Evoker
      -- entry in a Vanilla raid), leaving those columns without a cell. Pad to the
      -- full class count so they get a blank cell and don't keep another row's value
      -- on re-sort.
      for i = #r + 1, #ns.icons.classes do r[i] = {} end
      tinsert(r, 1, {
        text = lock and Colors.Strings.Icons.Lock or Colors.Strings.Icons.Empty,
      })
      tinsert(r, 2, {
        text = grp.name,
        onClick = function()
          ns.ShowLockoutView(srcIdx, ns.window, {
            TopRight = {ns.window, ui.edge.TopLeft, -25, 0},
            BottomRight = {ns.window, ui.edge.BottomLeft, -25, 0},
          })
          local row = self.rows[dispIdx]
          if _selectedRow ~= nil then
            self.cells[_selectedRow][2].label:Color(WHITE_FONT_COLOR)
          end
          _selectedRow = dispIdx
          self.cells[dispIdx][2].label:Color(NORMAL_FONT_COLOR:GetRGBA())
          if not _arrow then
            _arrow = Texture:new{
              parent = self,
              path = "interface/common/commonicons",
              coords = {
                0.02654,
                0.10273,
                0.2529296875,
                0.5029296875
              },
            }
          end
          _arrow._widget:SetSize(14, 16)
          _arrow:TopRight(row, ui.edge.TopLeft, -3, -2)
        end,
      })
      return r
    end)
  end,
})

---Flip the raid (row) order between oldest-first (ns.Sets order) and newest-first.
---Clears any active lockout selection first — its row index moves on re-sort — then
---rebuilds the grid in place.
---@return boolean reversed  the new order state
function DataView:ToggleOrder()
  self._reverse = not self._reverse
  if _selectedRow and self.cells[_selectedRow] and self.cells[_selectedRow][2] then
    self.cells[_selectedRow][2].label:Color(WHITE_FONT_COLOR)
  end
  _selectedRow = nil
  if _arrow then _arrow:Hide() end
  ns.HideLockoutView()
  self.data = self:GetData()
  self:update()
  return self._reverse
end

---Toggle the "wanted only" filter, rebuilding the grid so non-wanted cells blank out.
---@return boolean wantedOnly  the new filter state
function DataView:ToggleWantedOnly()
  self._wantedOnly = not self._wantedOnly
  self.data = self:GetData()
  self:update()
  return self._wantedOnly
end

-- Per-cell rating overlays: a gold "wanted" star (top-left) and a small
-- tier-colored rank pip (top-right), both lazily created on the cell and reused.
-- Driven entirely by live DB state, so re-applying after any toggle / re-sort is
-- enough — the cell data carries only the setId to look them up by.
local STAR, PIP = 11, 7

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
      cell._rankPip = Texture:new{
        parent = cell, layer = ui.layer.Overlay,
        position = { TopRight = {-1, -1}, Size = {PIP, PIP} },
      }
    end
    cell._rankPip:Color(ns.RankColors[rank])
    cell._rankPip:Show()
  elseif cell._rankPip then
    cell._rankPip:Hide()
  end
end

-- Re-apply every cell's overlays from current DB state. Cheap enough to run on
-- every update()/re-sort; cells persist across re-sorts so their overlays do too.
function DataView:_refreshMarks()
  self._playerRace = ns:PlayerRace()
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

-- Refresh overlays after the base table (re)builds its cells.
function DataView:update()
  TableFrame.update(self)
  self:_refreshMarks()
end

---@class Warbandeer_Collected
---@field DataView DataView
ns.DataView = DataView
