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

-- Weapon-cell chooser: a pane docked to the dressing room's right edge listing the cell's individual
-- looks (the previewed weapon-cell set's `_looks`). Clicking a look previews it; **↑/↓ steps through
-- the list** (see _stepWeaponPiece) and **←/→ jumps to the source's adjacent weapon type** (see Step).
-- Each row shows a ★ when its look is Wanted, and its name is tinted green when collected. Mutually
-- exclusive with the look-builder picker (a weapon-cell preview closes that), so both dock to the same
-- edge. Reopens the DressingRoom class.
--
-- **The hand buttons (#656)** under the title are how a weapon found in the Weapons view joins the
-- composed look. Before them, clicking a weapon cell was a pure *browse* — `_dressWeapon` renders
-- the cell's colour variants on a bare body and deliberately never writes `_lookMH`/`_lookOH` — so
-- the only route into a look was the look-builder picker under the model, and a weapon found here
-- couldn't come with you. Going to the Weapons view *to choose a weapon* is the obvious reading of
-- what that view is for, which is why it was reported as a bug.
--
-- Only the hands the cell's weapon TYPE can occupy are offered (`ns.WeaponHands`): both for a
-- one-hander and for the Titan's Grip two-handers (2H axe/mace/sword — #661), main only for a
-- polearm/staff/ranged/wand, off only for a shield or holdable. No class is consulted, here least
-- of all: a weapon-cell preview has none (`_classIndex` is nil for it). The gold
-- border is the feedback — the staged weapon can't show on the model here, since this mode renders a
-- bare body with the previewed piece as the focus, and appears the moment an armour set is previewed
-- again (one view toggle away, now that the toggle restores it).

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

---Stage the currently-shown look into a hand of the composed look — the Weapons view's own route
---into a look, with no trip through the look-builder picker (#656). Clicking the hand a look is
---already staged into clears it, through the shared `_togglePick`.
---@param hand string  "main" | "off"
function DressingRoom:_useCellLook(hand)
  local look = self._set and self._set._looks and self._set._looks[self._weaponPiece or 1]
  if not look then return end
  local sid = look.sourceID
  if hand == "off" then
    self._lookOH = DressingRoom._togglePick(self._lookOH, sid)
  elseif self._lookMH == sid then
    self._lookMH, self._lookNoOH = nil, nil          -- staging the applied weapon off
  else
    self._lookMH = sid
    -- Grey the off-hand behind a main-hand that leaves no room for one, exactly as the picker's own
    -- path does (#618, #661). The cell's weapon TYPE is the category, carried on the synthetic
    -- group by PreviewWeaponCell.
    self._lookNoOH = ns.SuppressesOffHand(self._group and self._group._type) or nil
  end
  -- The model can't show this: a weapon-cell preview renders a bare body with the previewed piece
  -- as its focus, and the composed-look slots are hidden in that mode. So say what happened, and
  -- let the button's gold border carry the state from here on.
  local slot = hand == "off" and "off hand" or "main hand"
  local staged = hand == "off" and self._lookOH or self._lookMH
  local name = GetItemNameByID(look.itemID) or ("appearance " .. look.visualID)
  ns.Print(staged and ("Added %s to your look's %s — preview an armor set to see it."):format(name, slot)
    or ("Cleared your look's %s."):format(slot))
  self:_syncCellActions()
end

---Re-sync the hand buttons to the look currently shown: grey the hand this weapon type can't
---occupy, and gold the one it's already staged into. Runs wherever the shown look can change —
---opening the chooser, clicking a row, and ↑/↓ stepping.
function DressingRoom:_syncCellActions()
  if not self._cellUse then return end
  local main, off = ns.WeaponHands(self._group and self._group._type)
  self:_enableRow(self._cellUse.main, main)
  self:_enableRow(self._cellUse.off, off)
  local look = self._set and self._set._looks and self._set._looks[self._weaponPiece or 1]
  local sid = look and look.sourceID
  self._cellUse.main.border:Color(sid and self._lookMH == sid and SELECTED or IDLE)
  self._cellUse.off.border:Color(sid and self._lookOH == sid and SELECTED or IDLE)
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
  self:_syncCellActions()
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
  self:_syncCellActions()   -- the hand buttons track the SHOWN look, not the cell
  if self._cellList then self._cellList:Refresh() end
end
