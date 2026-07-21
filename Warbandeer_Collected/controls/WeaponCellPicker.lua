---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Frame, Label, Texture = ui.Frame, ui.Label, ui.Texture
local VirtualList = ui.VirtualList
local C_Timer = C_Timer
local GetItemNameByID = C_Item.GetItemNameByID
local RequestLoadItemDataByID = C_Item.RequestLoadItemDataByID
local DressingRoom = ns.DressingRoom
local k = DressingRoom._k
local selBox, SELECTED, IDLE, PAD = k.selBox, k.SELECTED, k.IDLE, k.PAD

-- Weapon-cell chooser: a pane docked to the dressing room's right edge listing the cell's individual
-- looks (the previewed weapon-cell set's `_looks`). Clicking a look previews it; **↑/↓ steps through
-- the list** (see _stepWeaponPiece) and **←/→ jumps to the source's adjacent weapon type** (see Step).
-- Each row shows a ★ when its look is Wanted, and its name is tinted green when collected. Mutually
-- exclusive with the look-builder picker (a weapon-cell preview closes that), so both dock to the same
-- edge. Reopens the DressingRoom class.

local PANEW = 340                              -- docked pane width (wide enough for a name + difficulty tag)
local GAP   = 6                                -- gap between the window and the pane
local ROW_H = 28                               -- list row height
local PANEL = { 0.05, 0.05, 0.06, 0.96 }       -- opaque pane fill (a standalone frame's theme bg is alpha-0)
local OWNED = { 0.30, 0.85, 0.40 }             -- collected tint

-- Build the docked pane (an opaque, 1px-outlined panel) + its scrollable look list. Lazy.
function DressingRoom:_buildCellChooser()
  local pane = Frame:new{
    parent = self, background = PANEL,
    position = {
      TopLeft    = {self, ui.edge.TopRight, GAP, 0},
      BottomLeft = {self, ui.edge.BottomRight, GAP, 0},
      Width = PANEW, Hide = true,
    },
  }
  Texture:new{ parent = pane, layer = ui.layer.Border, color = IDLE,
    position = { TopLeft = {-1, 1}, BottomRight = {1, -1} } }
  Label:new{ parent = pane, fontObj = "GameFontNormal",
    position = { TopLeft = {PAD, -PAD} }, text = "Weapons from this source" }
  self._cellPane = pane

  self._cellList = VirtualList:new{
    parent = pane, rowHeight = ROW_H, spacing = 1, emptyText = "No weapons.",
    createRow = function(list) return self:_makeCellRow(list) end,
    updateRow = function(_, row, item) return self:_fillCellRow(row, item) end,
    position = {
      TopLeft     = {PAD, -(PAD + 20)},
      BottomRight = {pane, ui.edge.BottomRight, -PAD, PAD},
    },
  }
end

-- One pooled row: selection border, name (green when collected), and a right-aligned wanted ★.
---@param list VirtualList
---@return Frame
function DressingRoom:_makeCellRow(list)
  local row = Frame:new{ parent = list:Content(), position = { Height = ROW_H } }
  row.border = selBox(row)
  row.name = Label:new{ parent = row, justifyH = ui.justify.Left, wordWrap = false,
    position = { TopLeft = {6, 0}, Right = {-20, 0} } }
  row.star = Texture:new{ parent = row, layer = ui.layer.Artwork, atlas = ns.WantedIcon, atlasSize = false,
    position = { Right = {-5, 0}, Size = {12, 12}, Hide = true } }
  row._widget:EnableMouse(true)
  row._widget:SetScript("OnMouseUp", function() self:SelectCellLook(row._idx) end)
  return row
end

-- Re-point a pooled row at a look `{ idx, look = {visualID, itemID, isCollected} }`: name from the live
-- item name (async; a fallback until cached), green when collected, ★ when Wanted, gold border on the
-- currently-shown look (self._weaponPiece).
---@param row Frame
---@param item table
---@return number
function DressingRoom:_fillCellRow(row, item)
  row._idx = item.idx
  local look = item.look
  local nm = GetItemNameByID(look.itemID)
  if not nm then RequestLoadItemDataByID(look.itemID); nm = "Appearance " .. look.visualID end
  -- Suffix the boss-drop difficulty (muted gold) so a cell's same-named difficulty recolours read
  -- apart — "Brazier of the Dissonant Dirge  Heroic". Non-drop looks (quest/vendor) show just the name.
  if look.difficulty then nm = nm .. "  |cffb0a060" .. look.difficulty .. "|r" end
  row.name:Text(nm)
  row.name:Color(look.isCollected and OWNED or "muted")
  row.star:SetShown(ns:IsWeaponWanted(look.visualID))
  row.border:Color(item.idx == (self._weaponPiece or 1) and SELECTED or IDLE)
  return ROW_H
end

-- Populate + show the chooser for `looks` (the previewed weapon-cell set's `_looks`). Names load async,
-- so refresh once shortly after so blank names + collected/wanted marks fill in.
---@param looks table[]
function DressingRoom:ShowCellChooser(looks)
  if not self._cellPane then self:_buildCellChooser() end
  local items = {}
  for i, lk in ipairs(looks or {}) do items[#items + 1] = { idx = i, look = lk } end
  self._cellList:SetItems(items)
  self._cellPane:Show()
  if self._cellNameTimer then self._cellNameTimer:Cancel() end
  self._cellNameTimer = C_Timer.NewTimer(0.3, function()
    self._cellNameTimer = nil
    if self._cellPane and self._cellPane._widget:IsShown() then self._cellList:Refresh() end
  end)
end

function DressingRoom:HideCellChooser()
  if self._cellPane then self._cellPane:Hide() end
end

-- Select a look in the chooser: preview it, then refresh the ★ + row highlight.
---@param idx number
function DressingRoom:SelectCellLook(idx)
  self._weaponPiece = idx
  self:Dress()
  self:_refreshRatings()
  if self._cellList then self._cellList:Refresh() end
end
