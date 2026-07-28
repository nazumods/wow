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
-- Above the list sits the one control that acts on the SHOWN look: the hand selector. Mutually
-- exclusive with the look-builder picker — both dock to the same edge, and whichever was clicked
-- last is the one there. Reopens the DressingRoom class. The room-side state and staging this drives
-- live in the companion controls/WeaponCellPreview.lua.
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
-- **The pane no longer carries a tier row of its own (#827).** #688 put one here because the room's
-- ratings row rated the previewed armour SET whether or not a weapon was browsed, and one control
-- can't be two targets. The cost was two identical strips inches apart writing to different objects
-- with nothing on screen saying which: clicking the room's row while browsing a weapon silently
-- ranked the last armour set, and the weapon grid's pip — correctly — didn't move.
--
-- `_focus` is what resolves that. It already decides what ←/→ ↑/↓ drive and what the window title
-- says, so the room's row (and its ★) now follow it too: browsing a weapon points both at the shown
-- look, keyed by its visualID, under a title that names it. `_ratedWeapon` below is that predicate,
-- and the three methods beside it are the weapon half of the room's row — the armour half stays in
-- controls/DressingRoomActions.lua, which delegates here when a weapon is focused.
--
-- **`_focus` therefore has a write consequence now, so every path that sets it was re-checked**
-- (#827). Three write it: `_load` → "armor", `_loadCell` → "weapons", `EnterOutfitMode` → "armor"
-- (clearing `_cell` with it). Two paths deliberately leave it alone — clicking an armour SLOT (the
-- worn→hidden→empty toggle, a visibility gesture on the set already previewed) and clicking a look
-- slot (which opens the look builder over this pane). In both the title still names the weapon, so
-- the subject the row writes to is still the one the room is announcing.
--
-- There is no "This race" for a weapon: it renders identically on every race, so the armour row's
-- per-race override has nothing to say about one and greys out while a weapon is focused.

local PANEW = 340                              -- docked pane width (wide enough for a name + difficulty tag)
local GAP   = 6                                -- internal spacing between the pane's own control rows
local ROW_H = 28                               -- list row height
local BTNW  = 104                              -- hand-button width
local OWNED = ns.collectedTint                 -- shared with the look-builder picker (DockedPane.lua)
local TITLEH = 20                              -- title line height the rows below clear

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

  -- The list starts directly under the hand buttons. A tier row used to sit between them (#688);
  -- the room's own row rates the shown look now, so the space goes back to the list.
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

-- ── The weapon half of the room's ratings row ───────────────────────────────--
-- The armour half stays in controls/DressingRoomActions.lua; each of its three entry points asks
-- `_ratedWeapon` first and delegates here when the answer isn't nil. Split this way because the
-- room's file knows nothing about cells, and this one already owns every other thing a browsed
-- weapon does.

---The weapon look the room's ratings row acts on, or nil when the subject is the previewed armour
---set. The same predicate ←/→ ↑/↓ use (`_focus` plus a browsed cell), so the arrows, the window
---title and the ratings row can never disagree about which surface is being driven.
---@return table?  the shown cell look, or nil
function DressingRoom:_ratedWeapon()
  if self._focus ~= "weapons" then return nil end
  return self:_shownCellLook()
end

---Paint the room's ratings row from a weapon look: ★ from its Wanted flag, the gold border on its
---tier, and "This race" greyed — a weapon has no per-race override to offer.
---
---The row is SHOWN here rather than assumed visible. Outfit mode hides it (a loaded look has no set
---id to rate) and browsing a weapon doesn't leave outfit mode, so without this an outfit loaded
---before a weapon was browsed would leave that weapon unrateable anywhere.
---@param look table  as returned by `_ratedWeapon`
function DressingRoom:_paintWeaponRatings(look)
  if self._wantBox then self._wantBox:Show() end
  if self._ratingsBoxes then for _, b in ipairs(self._ratingsBoxes) do b:Show() end end
  self:_enableRaceOnly(false)
  self._wantedBorder:Color(ns:IsWeaponWanted(look.visualID) and SELECTED or IDLE)
  local shown = ns:WeaponRank(look.visualID)
  for letter, b in pairs(self._rankBtns) do
    b.border:Color(letter == shown and SELECTED or IDLE)
  end
end

---Rate the shown weapon look, keyed by its visualID — or clear it, by passing nil or by re-clicking
---the tier it already has (the armour row's gesture, on the same buttons).
---@param look table  as returned by `_ratedWeapon`
---@param letter string?  a tier from ns.Ranks, or nil to clear
function DressingRoom:_rateWeapon(look, letter)
  if ns:WeaponRank(look.visualID) == letter then letter = nil end
  ns:SetWeaponRank(look.visualID, letter)
  self:_afterWeaponRating(look)
end

---Flag/unflag the shown weapon look — the room's ★ while a weapon is focused.
---@param look table  as returned by `_ratedWeapon`
function DressingRoom:_wantWeapon(look)
  ns:ToggleWeaponWanted(look.visualID)
  self:_afterWeaponRating(look)
end

---Repaint everything a weapon rating change is visible in: the room's row, the Weapons grid's cell
---(whose pip aggregates the bucket's best tier), and the chooser row's own pip/★.
---
---Broadcast by visualID and not setId: a weapon cell has no set id, and the armour grid holds
---nothing this can have changed, so it is skipped entirely (#768 L-8).
---@param look table
function DressingRoom:_afterWeaponRating(look)
  self:_paintWeaponRatings(look)
  self:_ratingsChanged(nil, look.visualID)
  if self._cellList then self._cellList:Refresh() end
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
  -- The room's ratings row acts on the same shown look, so every gesture that moves the selection
  -- repaints it here — the dock, ↑/↓, a chooser row, a ←/→ type step.
  self:_refreshRatings()
end

---Shift-click gesture on a chooser row: flag that weapon look Wanted — the row under the cursor,
---which is what makes it a different gesture from the room's ★ (that one acts on the look actually
---on the doll). The armour grid's cells carry the same shift-click, as does the appearance picker.
---@param idx number  index into the browsed cell's looks
function DressingRoom:_toggleCellWanted(idx)
  local look = self._cell and self._cell.set._looks[idx]
  if not look then return end
  ns:ToggleWeaponWanted(look.visualID)
  self:_ratingsChanged(nil, look.visualID)
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
