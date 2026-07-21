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

-- Weapon-cell chooser: a pane docked to the dressing room's right edge listing the cell's distinct
-- weapons (the cell's looks grouped by item name in ns.PreviewWeaponCell). Clicking a weapon previews
-- it on the character; ↑/↓ then cycles that weapon's colour variants (see _stepWeaponPiece). Each row
-- shows a ★ when any of its variants is Wanted, and its name is tinted green when any is collected.
-- Mutually exclusive with the look-builder picker (a weapon-cell preview closes that), so both can
-- dock to the same edge. Reopens the DressingRoom class.

local PANEW = 210                              -- docked pane width
local GAP   = 6                                -- gap between the window and the pane
local ROW_H = 28                               -- list row height
local PANEL = { 0.05, 0.05, 0.06, 0.96 }       -- opaque pane fill (a standalone frame's theme bg is alpha-0)
local OWNED = { 0.30, 0.85, 0.40 }             -- collected tint

-- Build the docked pane (an opaque, 1px-outlined panel) + its scrollable weapon list. Lazy.
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
    position = { TopLeft = {PAD, -PAD} }, text = "Weapons in this cell" }
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
  row._widget:SetScript("OnMouseUp", function() self:SelectCellWeapon(row._idx) end)
  return row
end

-- Re-point a pooled row at a weapon `{ idx, weapon = { name, looks = { {visualID, itemID, isCollected} } } }`.
-- Name from the first look's live item name (async; falls back to the grouped name); variant count in
-- parentheses when > 1; green tint if any variant is collected; ★ if any variant is Wanted; gold border
-- on the currently-selected weapon.
---@param row Frame
---@param item table
---@return number
function DressingRoom:_fillCellRow(row, item)
  row._idx = item.idx
  local w = item.weapon
  local first = w.looks[1]
  local nm = GetItemNameByID(first.itemID)
  if not nm then RequestLoadItemDataByID(first.itemID); nm = w.name end
  local variants = #w.looks
  row.name:Text(variants > 1 and ("%s  (%d)"):format(nm, variants) or nm)
  local owned, wanted = false, false
  for _, lk in ipairs(w.looks) do
    if lk.isCollected then owned = true end
    if ns:IsWeaponWanted(lk.visualID) then wanted = true end
  end
  row.name:Color(owned and OWNED or "muted")
  row.star:SetShown(wanted)
  row.border:Color(item.idx == (self._weaponItem or 1) and SELECTED or IDLE)
  return ROW_H
end

-- Populate + show the chooser for `weapons` (the previewed weapon-cell set's `_weapons`). Names load
-- async, so refresh once shortly after so grouped names/marks fill in.
---@param weapons table[]
function DressingRoom:ShowCellChooser(weapons)
  if not self._cellPane then self:_buildCellChooser() end
  local items = {}
  for i, w in ipairs(weapons or {}) do items[#items + 1] = { idx = i, weapon = w } end
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

-- Select a weapon in the chooser: preview its first colour variant, reset the variant cursor, and
-- refresh the ★ + row highlights. ↑/↓ then cycles this weapon's variants.
---@param idx number
function DressingRoom:SelectCellWeapon(idx)
  self._weaponItem = idx
  self._weaponPiece = 1
  self:Dress()
  self:_refreshRatings()
  if self._cellList then self._cellList:Refresh() end
end
