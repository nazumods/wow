---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Frame, Label, Texture = ui.Frame, ui.Label, ui.Texture
local VirtualList = ui.VirtualList
local GetItemNameByID = C_Item.GetItemNameByID
local RequestLoadItemDataByID = C_Item.RequestLoadItemDataByID
local DressingRoom = ns.DressingRoom
local k = DressingRoom._k
local selBox, SELECTED, IDLE, PAD, ROWH = k.selBox, k.SELECTED, k.IDLE, k.PAD, k.ROWH

-- Weapon-cell chooser: a pane docked to the dressing room's right edge listing the browsed cell's
-- individual looks (`_cell.set._looks`). Clicking a row puts that look on the doll; **↑/↓ steps the
-- list** and **←/→ jumps to the source's adjacent weapon type**. Each row shows its look's tier pip
-- and a ★ when it's Wanted (shift-click toggles it), and its name is tinted green when collected.
-- Above the list sit the two controls that act on the SHOWN look: the hand selector and the S–F
-- tier row. Mutually exclusive
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
--
-- **The S–F tier row is here rather than in the room's ratings row (#688).** That row rates the
-- previewed armour SET, browsing a weapon or not — the same "one control can't be two targets"
-- reason its ★ doesn't reach a weapon look (#673). So the tier lands where weapon Wanted already
-- lives: this pane, on the shown look, keyed by its visualID. There is no "This race" beside it —
-- a weapon renders identically on every race, so the armour row's per-race override has nothing to
-- say about one.

local PANEW = 340                              -- docked pane width (wide enough for a name + difficulty tag)
local GAP   = 6                                -- internal spacing between the pane's own control rows
local ROW_H = 28                               -- list row height
local BTNW  = 104                              -- hand-button width
local OWNED = ns.collectedTint                 -- shared with the look-builder picker (DockedPane.lua)
local TITLEH = 20                              -- title line height the rows below clear
local TW, TGAP, CLRW = 30, 3, 24               -- tier-button width / gap / clear-button width (match the room's row)

-- Build the docked pane (an opaque, 1px-outlined panel) + its scrollable look list. Lazy.
function DressingRoom:_buildCellChooser()
  -- Shell from the shared builder (DockedPane.lua); everything below is this pane's own furniture.
  local pane = self:_buildDockedPane(PANEW, "Weapons from this source")
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

  -- Tier row, directly under the hand buttons: the pane's two control rows both act on the SHOWN
  -- look, and the list below them is the selector that says which one that is. Built with the same
  -- box/colour/gold-border idiom as the room's own ratings row so the two read as one control.
  self:_buildCellRanks(pane, PAD + TITLEH + ROWH + GAP)

  self._cellList = VirtualList:new{
    parent = pane, rowHeight = ROW_H, spacing = 1, emptyText = "No weapons.",
    createRow = function(list) return self:_makeCellRow(list) end,
    updateRow = function(_, row, item) return self:_fillCellRow(row, item) end,
    position = {
      TopLeft     = {PAD, -(PAD + TITLEH + 2 * (ROWH + GAP))},
      BottomRight = {pane, ui.edge.BottomRight, -PAD, PAD},
    },
  }
end

-- The S A B C F + clear strip. Each tier is a box tinted its own colour with a gold border when
-- it's the shown look's; clear ("–") is the same gesture as re-clicking the active tier.
---@param pane Frame  the chooser pane
---@param y number  the row's top inset within the pane
function DressingRoom:_buildCellRanks(pane, y)
  local row = Frame:new{ parent = pane,
    position = { TopLeft = {PAD, -y}, Width = PANEW - 2 * PAD, Height = ROWH } }
  self._cellRankBtns = {}
  local x = 0
  for _, letter in ipairs(ns.Ranks) do
    local box = Frame:new{ parent = row, position = { TopLeft = {x, 0}, Width = TW, Height = ROWH } }
    self._cellRankBtns[letter] = { border = selBox(box) }
    Texture:new{ parent = box, layer = ui.layer.Artwork, color = ns.RankColors[letter],
      position = { TopLeft = {2, -2}, BottomRight = {-2, 2} } }
    ui.Button:new{ parent = box, position = { All = true },
      OnClick = function() self:SetCellRank(letter) end }
    Label:new{ parent = box, justifyH = ui.justify.Center, position = { All = true },
      color = {0.08, 0.08, 0.08}, text = letter }
    x = x + TW + TGAP
  end
  local clearBox = Frame:new{ parent = row,
    position = { TopLeft = {x, 0}, Width = CLRW, Height = ROWH } }
  selBox(clearBox)
  ui.Button:new{ parent = clearBox, position = { All = true },
    OnClick = function() self:SetCellRank(nil) end }
  Label:new{ parent = clearBox, justifyH = ui.justify.Center, position = { All = true }, text = "–" }
end

---Rate the SHOWN weapon look, keyed by its visualID — or clear it, by passing nil or by re-clicking
---the tier it already has (the armour row's gesture, so the two rate the same way).
---@param letter string?  a tier from ns.Ranks, or nil to clear
function DressingRoom:SetCellRank(letter)
  local look = self:_shownCellLook()
  if not look then return end
  if ns:WeaponRank(look.visualID) == letter then letter = nil end
  ns:SetWeaponRank(look.visualID, letter)
  self:_syncCellRanks()
  self:_ratingsChanged()   -- the Weapons grid's cell pip aggregates this look's tier
  self._cellList:Refresh() -- …and so does the row's own pip
end

---Move the gold border to the shown look's tier, lighting none when it's unranked. Called from
---`_syncCellActions`, so every gesture that changes which look is shown repaints it: ↑/↓, a chooser
---row, a ←/→ type step, and the initial dock.
function DressingRoom:_syncCellRanks()
  if not self._cellRankBtns then return end
  local look = self:_shownCellLook()
  local shown = look and ns:WeaponRank(look.visualID)
  for letter, b in pairs(self._cellRankBtns) do
    b.border:Color(letter == shown and SELECTED or IDLE)
  end
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
  self:_syncCellRanks()   -- the row below is the same "acts on the shown look" state
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

-- One pooled row: selection border, name (green when collected), then the look's tier pip and a
-- right-aligned wanted ★. The pip is what makes the tiers legible across a cell without stepping
-- through it — the tier row above only ever shows the one look that's on the doll.
---@param list VirtualList
---@return Frame
function DressingRoom:_makeCellRow(list)
  local row = Frame:new{ parent = list:Content(), position = { Height = ROW_H } }
  row.border = selBox(row)
  row.name = Label:new{ parent = row, justifyH = ui.justify.Left, wordWrap = false,
    position = { TopLeft = {6, 0}, Right = {-36, 0} } }
  row.pip = Label:new{ parent = row, fontObj = "GameFontNormalSmall", justifyH = ui.justify.Right,
    position = { Right = {-22, 0}, Hide = true } }
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
  local rank = ns:WeaponRank(look.visualID)
  if rank then row.pip:Text(rank); row.pip:Color(ns.RankColors[rank]) end
  row.pip:SetShown(rank ~= nil)
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
  self:_fillNamesShortly("cellNames", self._cellPane, self._cellList)
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
