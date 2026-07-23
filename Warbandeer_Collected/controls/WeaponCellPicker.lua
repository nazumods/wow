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
local selBox, SELECTED, IDLE, PAD, ROWH = k.selBox, k.SELECTED, k.IDLE, k.PAD, k.ROWH

-- Weapon-cell chooser: a pane docked to the dressing room's right edge listing the browsed cell's
-- individual looks (`_cell.set._looks`). Clicking a row puts that look on the doll; **↑/↓ steps the
-- list** and **←/→ jumps to the source's adjacent weapon type**. Each row shows a ★ when its look is
-- Wanted (shift-click toggles it), and its name is tinted green when collected. Mutually exclusive
-- with the look-builder picker — both dock to the same edge, and whichever was clicked last is the
-- one there. Reopens the DressingRoom class. The room-side state and staging this drives live in the
-- companion controls/WeaponCellPreview.lua.
--
-- **The hand buttons are a selector, not a staging gesture (#673).** Browsing a weapon now puts it
-- straight into the composed look, live on the same paper doll armour is built on, so there is
-- nothing left to "add": the shown look is already in a hand, and these say which one. Under the two
-- dolls (#656) they were the only route a weapon found here could take into a look at all — the model
-- couldn't show the result, so clicking one printed *"Added X to your look's main hand — preview an
-- armor set to see it"* and left the gold border to carry the state. The doll carries it now, and the
-- chat line is gone with the second doll it was standing in for.
--
-- Only the hands the cell's weapon TYPE can occupy are offered (`ns.WeaponHands`): both for a
-- one-hander and for the Titan's Grip two-handers (2H axe/mace/sword — #661), main only for a
-- polearm/staff/ranged/wand, off only for a shield or holdable. No class is consulted, here least of
-- all: a weapon cell has no class column at all.

local PANEW = 340                              -- docked pane width (wide enough for a name + difficulty tag)
local GAP   = 6                                -- gap between the window and the pane
local ROW_H = 28                               -- list row height
local BTNW  = 104                              -- hand-button width
local PANEL = { 0.05, 0.05, 0.06, 0.96 }       -- opaque pane fill (a standalone frame's theme bg is alpha-0)
local OWNED = { 0.30, 0.85, 0.40 }             -- collected tint
local TITLEH = 20                              -- title line height the rows below clear

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

  -- The hand buttons get a row of their own so `_rowButton` (DressingRoomOutfits.lua) can lay them
  -- out exactly as the bottom control rows are — same box, same height, same gold-border idiom, so
  -- a pane docked to the side of the window still reads as part of it.
  --
  -- Both are always built and always visible; the one this weapon type can't occupy is GREYED
  -- rather than hidden (`_enableRow` also swallows its click). A disabled button says "not for this
  -- weapon"; a missing one would just look like the feature isn't there, and a shifting single
  -- button would move under the cursor as you step between cells.
  local actions = Frame:new{ parent = pane,
    position = { TopLeft = {PAD, -(PAD + TITLEH)}, Width = PANEW - 2 * PAD, Height = ROWH } }
  self._cellUse = {
    main = self:_rowButton(actions, 0, BTNW, "Main hand", function() self:_useCellLook("main") end),
    off  = self:_rowButton(actions, BTNW + GAP, BTNW, "Off hand", function() self:_useCellLook("off") end),
  }

  self._cellList = VirtualList:new{
    parent = pane, rowHeight = ROW_H, spacing = 1, emptyText = "No weapons.",
    createRow = function(list) return self:_makeCellRow(list) end,
    updateRow = function(_, row, item) return self:_fillCellRow(row, item) end,
    position = {
      TopLeft     = {PAD, -(PAD + TITLEH + ROWH + GAP)},
      BottomRight = {pane, ui.edge.BottomRight, -PAD, PAD},
    },
  }
end

---Move the browsed weapon to `hand` — the selector gesture. A no-op on the hand it's already in,
---so the pair reads as a radio and there's no way to click the weapon off the doll by accident;
---taking it off is the weapon slot's own right-click, which is where every other pick is cleared.
---@param hand string  "main" | "off"
function DressingRoom:_useCellLook(hand)
  if hand == self._cellHand then return end
  self:_stageCellLook(hand)
end

---Re-sync the hand buttons: grey the hand this weapon type can't occupy, and gold the one the
---browsed weapon is actually in. Runs wherever that can change — docking the chooser, clicking a
---row, ↑/↓ stepping, and the selector itself.
function DressingRoom:_syncCellActions()
  if not self._cellUse then return end
  local main, off = ns.WeaponHands(self._cell and self._cell.group._type)
  self:_enableRow(self._cellUse.main, main)
  self:_enableRow(self._cellUse.off, off)
  self._cellUse.main.border:Color(self._cellHand == "main" and SELECTED or IDLE)
  self._cellUse.off.border:Color(self._cellHand == "off" and SELECTED or IDLE)
end

---Shift-click gesture on a chooser row: flag that weapon look Wanted. The ratings row's ★ rates the
---previewed armour SET and can't be two targets at once (#673), so weapon Wanted lives here — the
---same shift-click the appearance picker uses for a shirt or tabard, on the same kind of row.
---@param idx number  index into the browsed cell's looks
function DressingRoom:_toggleCellWanted(idx)
  local look = self._cell and self._cell.set._looks[idx]
  if not look then return end
  ns:ToggleWeaponWanted(look.visualID)
  self:_ratingsChanged()
  self._cellList:Refresh()   -- the row's ★ tracks it
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
  row._widget:SetScript("OnMouseUp", function()
    if IsShiftKeyDown() then self:_toggleCellWanted(row._idx) else self:SelectCellLook(row._idx) end
  end)
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

-- Populate + show the chooser for `looks` (the browsed cell's `_looks`). Names load async, so
-- refresh once shortly after so blank names + collected/wanted marks fill in.
---@param looks table[]
function DressingRoom:ShowCellChooser(looks)
  if not self._cellPane then self:_buildCellChooser() end
  local items = {}
  for i, lk in ipairs(looks or {}) do items[#items + 1] = { idx = i, look = lk } end
  self._cellList:SetItems(items)
  self:_syncCellActions()
  if self._picker then self:TogglePicker(false) end   -- same dock edge; last clicked wins
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

-- Select a look in the chooser: put it on the doll in place, and move the row highlight to it.
---@param idx number
function DressingRoom:SelectCellLook(idx)
  self._weaponPiece = idx
  self:_stageCellLook()
end
