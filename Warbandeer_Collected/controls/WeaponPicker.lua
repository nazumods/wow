---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Frame, Label, Texture, Button = ui.Frame, ui.Label, ui.Texture, ui.Button
local FilterDropdown, VirtualList = ui.FilterDropdown, ui.VirtualList
local GameTooltip, C_Timer = GameTooltip, C_Timer
local GetItemNameByID = C_Item.GetItemNameByID
local RequestLoadItemDataByID = C_Item.RequestLoadItemDataByID
local QUALITY = _G.ITEM_QUALITY_COLORS   -- [Enum.ItemQuality] = { r, g, b, hex, color }
local DressingRoom = ns.DressingRoom
local k = DressingRoom._k
local selBox, SELECTED, IDLE, PAD, ROWH = k.selBox, k.SELECTED, k.IDLE, k.PAD, k.ROWH

-- Weapon + illusion "look builder" picker (#596): a pane docked to the dressing room's right
-- edge that browses weapon appearances by type AND enchant illusions, laying the picked pieces
-- onto the previewed model's hands — composing armor set + main-hand + off-hand + illusion in one
-- preview. Reopens the DressingRoom class.
--
-- Docked as a SIBLING pane (anchored to the window's right edge, own opaque backdrop), NOT a
-- resize of the window. Built lazily on first open. A "Weapons | Illusions" tab row switches the
-- pane between two modes (illusions are a peer of weapons, not a weapon "type", so they get their
-- own tab rather than hiding among the weapon-category dropdown): Weapons mode shows the category
-- dropdown + weapon list; Illusions mode drops the dropdown and shows the illusion list. Both are
-- scoped to the PREVIEWED SET's class (self._classIndex), not the logged-in viewer's (#608): the
-- weapon dropdown lists that class's usable types and the illusion tab that class's illusions.
-- _rescopePicker re-derives both when the previewed class changes (Step across class columns).
--
-- Composition (the look is three independent slots, re-applied together by _applyLook):
--   * main-hand weapon  self._lookMH   (a weapon appearance sourceID)
--   * off-hand weapon   self._lookOH   (shields / holdables / a second 1H)
--   * illusion          self._lookIllusion  (rides the main-hand — the picked weapon, else the
--                       character's equipped host weapon, since a shimmer needs a weapon to sit on)
-- Each SlotTransmog is re-applied across the model's async re-skins, so the look survives a race
-- change. Clicking the applied piece again clears that slot.

local PICKERW = 264               -- docked pane width
local GAP     = 6                 -- gap between the window and the pane
local ROW_H   = 34                -- list row height
local PANEL   = { 0.05, 0.05, 0.06, 0.96 }   -- opaque pane fill (a standalone frame's theme bg is alpha-0)
local OWNED   = { 0.30, 0.85, 0.40 }         -- collected tint (illusions have no item quality)

-- Show/hide the docked picker pane (building + populating it on first open). `force` sets an
-- explicit state; nil toggles. `hand` re-targets the picker at the main/off-hand slot: it filters
-- the category dropdown to that hand's weapon types and routes picks there (the weapon slots are
-- the entry point — see DressingRoomWeaponSlots.lua).
---@param force boolean?
---@param hand string?  "main" | "off"
function DressingRoom:ToggleWeaponPicker(force, hand)
  if not self._picker then self:_buildWeaponPicker() end
  if hand then self._pickerHand = hand end
  if force == nil then force = not self._picker._widget:IsShown() end
  if force then
    -- Opening: re-scope to the previewed class if it changed (Steps while closed don't rescope) —
    -- which re-applies the hand filter too — else just (re)apply the current target hand.
    if self._pickerClass ~= self._classIndex then self:_rescopePicker() else self:_applyPickerHand() end
  end
  self._picker:SetShown(force)
  self:UpdateWeaponSlots()   -- reflect the open/targeted state on the weapon-slot borders
end

-- Build the docked pane: an opaque, 1px-outlined panel down the window's right edge, with a drag
-- header, the Weapons|Illusions tab row, the weapon-category dropdown, and the scrollable list.
function DressingRoom:_buildWeaponPicker()
  self._pickerClass = self._classIndex
  self._pickerCats = ns.WeaponCategories(self._classIndex)
  self._pickerCatByID = {}
  for _, c in ipairs(self._pickerCats) do self._pickerCatByID[c.category] = c end

  local pane = Frame:new{
    parent = self, background = PANEL,
    position = {
      TopLeft    = {self, ui.edge.TopRight, GAP, 0},
      BottomLeft = {self, ui.edge.BottomRight, GAP, 0},
      Width = PICKERW, Hide = true,
    },
  }
  Texture:new{ parent = pane, layer = ui.layer.Border, color = IDLE,
    position = { TopLeft = {-1, 1}, BottomRight = {1, -1} } }
  self._picker = pane

  -- The pane's header is a drag strip for the WHOLE window (Warbandeer house style: a docked/
  -- anchored pane moves the entire frame, not itself). setDragTarget moves the room's widget and
  -- the pane, a child, follows. The pane is built after RememberPosition ran (so its titlebar/body
  -- hooks don't cover this path), so mirror the save here to persist the dragged point.
  local strip = Frame:new{
    parent = pane,
    position = { TopLeft = {1, -1}, TopRight = {-1, -1}, Height = PAD + 18 },
  }
  strip._widget:EnableMouse(true)
  strip:setDragTarget(self._widget)
  strip._widget:HookScript("OnMouseUp", function()
    if not self._posStore then return end
    local point, _, relPoint, x, y = self._widget:GetPoint(1)
    self._posStore.point, self._posStore.relPoint, self._posStore.x, self._posStore.y = point, relPoint, x, y
  end)
  Label:new{ parent = strip, fontObj = "GameFontNormal",
    position = { TopLeft = {PAD, -PAD} }, text = "Weapon Look Builder" }

  -- Weapons | Illusions mode tabs.
  self._pickerTabs = Frame:new{
    parent = pane,
    position = { TopLeft = {PAD, -(PAD + 22)}, Width = PICKERW - 2 * PAD, Height = ROWH },
  }
  self._modeTab = {}
  self._pickerTabBox = {}   -- tab boxes, so _applyPickerHand can hide the Illusions tab for the off-hand
  local tw = (PICKERW - 2 * PAD - 4) / 2
  local function tab(mode, label, x)
    local box = Frame:new{ parent = self._pickerTabs, position = { TopLeft = {x, 0}, Width = tw, Height = ROWH } }
    self._pickerTabBox[mode] = box
    self._modeTab[mode] = selBox(box)
    Button:new{ parent = box, position = { All = true }, glow = false, OnClick = function() self:_setPickerMode(mode) end }
    Label:new{ parent = box, justifyH = ui.justify.Center, position = { Left = {2, 0}, Right = {-2, 0} }, text = label }
  end
  tab("weapons", "Weapons", 0)
  tab("illusions", "Illusions", tw + 4)

  -- Weapon-category dropdown (Weapons mode only; hidden in Illusions mode by _setPickerMode).
  local opts = {}
  for _, c in ipairs(self._pickerCats) do opts[#opts + 1] = { key = c.category, label = c.name } end
  self._pickerCat = FilterDropdown:new{
    parent = pane, bordered = true, width = PICKERW - 2 * PAD, options = opts,
    selected = self._pickerCats[1] and self._pickerCats[1].category,
    onSelect = function(_, key) self:_pickCategory(key) end,
    position = { TopLeft = {self._pickerTabs, ui.edge.BottomLeft, 0, -4} },
  }

  self._pickerList = VirtualList:new{
    parent = pane, rowHeight = ROW_H, spacing = 1, emptyText = "Nothing here.",
    createRow = function(list) return self:_makeRow(list) end,
    updateRow = function(_, row, item) return self:_fillRow(row, item) end,
    position = {
      TopLeft     = {self._pickerCat, ui.edge.BottomLeft, 0, -PAD},
      BottomRight = {pane, ui.edge.BottomRight, -PAD, PAD},
    },
  }

  self:_setPickerMode("weapons")
end

-- Switch the pane between "weapons" and "illusions": recolor the tabs, show/hide the weapon
-- dropdown, re-anchor the list (below the dropdown in weapons mode, below the tabs in illusions
-- mode so the freed space is used), and repopulate.
---@param mode string  "weapons" | "illusions"
function DressingRoom:_setPickerMode(mode)
  self._pickerMode = mode
  self._modeTab.weapons:Color(mode == "weapons" and SELECTED or IDLE)
  self._modeTab.illusions:Color(mode == "illusions" and SELECTED or IDLE)
  self._pickerCat:SetShown(mode == "weapons")
  self._pickerList:ClearAllPoints()
  self._pickerList:Position{
    TopLeft     = {mode == "weapons" and self._pickerCat or self._pickerTabs, ui.edge.BottomLeft, 0, -PAD},
    BottomRight = {self._picker, ui.edge.BottomRight, -PAD, PAD},
  }
  if mode == "weapons" then
    self:_pickCategory(self._pickerCategory or (self._pickerCats[1] and self._pickerCats[1].category))
  else
    self:_populateIllusions()
  end
end

-- Re-scope the picker to the currently previewed set's class: rebuild the weapon-category list +
-- dropdown for that class (keeping the current category if the new class still has it, else the
-- first available), and repopulate the active mode (the illusion list is class-scoped too). Called
-- when the previewed class changes with the pane already built — Stepping across class columns
-- (from _load, while shown) or reopening the pane after such a Step.
function DressingRoom:_rescopePicker()
  self._pickerClass = self._classIndex
  self._pickerCats = ns.WeaponCategories(self._classIndex)
  self._pickerCatByID = {}
  for _, c in ipairs(self._pickerCats) do self._pickerCatByID[c.category] = c end
  self:_applyPickerHand()
end

-- Apply the current target hand (self._pickerHand) to the pane: filter the weapon-category
-- dropdown to that hand's categories (main-hand = anything not off-hand-only; off-hand = canOffHand), keeping the current category if
-- it's still valid else the first available; hide the Illusions tab for the off-hand (illusions
-- ride the main hand, so they're only offered there); then repopulate the active mode. Shared by
-- the open path and the class re-scope so both honour the hand + class scoping in one place.
function DressingRoom:_applyPickerHand()
  local off = self._pickerHand == "off"
  self._pickerTabBox.illusions:SetShown(not off)
  if off and self._pickerMode == "illusions" then self._pickerMode = "weapons" end
  local opts, valid = {}, false
  for _, c in ipairs(self._pickerCats) do
    -- Main-hand dropdown = everything that isn't off-hand-ONLY: 2H, ranged, and wands all report
    -- canMainHand=false (that flag means "one-handed main-hand") but canOffHand=false, so include
    -- them via `not canOffHand`. Only shields/holdables (canOffHand, not canMainHand) are kept out.
    -- Off-hand dropdown = canOffHand (1H weapons + shields + holdables).
    if (off and c.canOffHand) or (not off and (c.canMainHand or not c.canOffHand)) then
      opts[#opts + 1] = { key = c.category, label = c.name }
      if c.category == self._pickerCategory then valid = true end
    end
  end
  if not valid then self._pickerCategory = opts[1] and opts[1].key end
  self._pickerCat:SetOptions(opts, self._pickerCategory)
  self:_setPickerMode(self._pickerMode or "weapons")
end

-- One list row: a selection border, a name line, and a subtitle. Clickable (applies the piece to
-- the look), and hover shows a weapon's real item tooltip (illusions have no item, so no tooltip).
---@param list VirtualList
---@return Frame
function DressingRoom:_makeRow(list)
  local row = Frame:new{ parent = list:Content(), position = { Height = ROW_H } }
  row.border = selBox(row)
  row.name = Label:new{ parent = row, justifyH = ui.justify.Left, wordWrap = false,
    position = { TopLeft = {6, -3}, Right = {-6, 0} } }
  row.src = Label:new{ parent = row, fontObj = "GameFontDisableSmall", justifyH = ui.justify.Left,
    wordWrap = false, position = { TopLeft = {row.name, ui.edge.BottomLeft, 0, -1}, Right = {-6, 0} } }
  row._widget:EnableMouse(true)
  row._widget:SetScript("OnEnter", function(f)
    if not row._itemID then return end
    GameTooltip:SetOwner(f, "ANCHOR_LEFT")
    GameTooltip:SetItemByID(row._itemID)
    GameTooltip:Show()
  end)
  row._widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
  row._widget:SetScript("OnMouseUp", function() self:_equipRow(row._item) end)
  return row
end

-- Re-point a pooled row at a weapon (`{kind="w", visualID, src}`) or illusion (`{kind="i", ill}`):
-- weapons show the item name quality-coloured + source line + item tooltip; illusions show the
-- illusion name tinted by collected state. The gold border marks the piece applied to its slot.
---@param row Frame
---@param item table
---@return number
function DressingRoom:_fillRow(row, item)
  row._item = item
  if item.kind == "i" then
    local ill = item.ill
    row._itemID = nil
    row.name:Text(ill.name or ("Illusion " .. ill.sourceID))
    row.name:Color(ill.isCollected and OWNED or "muted")
    row.src:Text("")
    row.border:Color(ill.sourceID == self._lookIllusion and SELECTED or IDLE)
  else
    local src = item.src
    row._itemID = src.itemID
    local name = GetItemNameByID(src.itemID)
    if not name then RequestLoadItemDataByID(src.itemID) end
    row.name:Text(name or ("Appearance " .. item.visualID))
    local qc = src.quality and QUALITY[src.quality]
    row.name:Color(qc and {qc.r, qc.g, qc.b} or (src.isCollected and OWNED or "muted"))
    row.src:Text(src.text or "")
    local applied = self._pickerSlotOff and self._lookOH or self._lookMH
    row.border:Color(src.sourceID == applied and SELECTED or IDLE)
  end
  return ROW_H
end

-- Switch the weapon list to category `categoryID`. Repoints the dropdown (no re-fire), records
-- whether the category equips to the off-hand, and rebuilds the collected appearance rows.
---@param categoryID number
function DressingRoom:_pickCategory(categoryID)
  self._pickerCategory = categoryID
  self._pickerCat:Select(categoryID)
  self:_populateWeapons()
end

-- Populate the active weapon category's COLLECTED appearances, each resolved to its WeaponSource.
-- `_pickerSlotOff` follows the target hand (the dropdown is already filtered to hand-appropriate
-- categories), so clicks and the selection border target the right slot.
function DressingRoom:_populateWeapons()
  self._pickerSlotOff = self._pickerHand == "off"   -- the dropdown is hand-filtered, so route by hand
  local items = {}
  for _, app in ipairs(ns.WeaponAppearances(self._pickerCategory, self._classIndex)) do
    if app.isCollected then
      local src = ns.WeaponSource(app.visualID)
      if src then items[#items + 1] = { kind = "w", visualID = app.visualID, src = src } end
    end
  end
  self._pickerList:SetItems(items)
  self:_scheduleNameFill()
end

-- Populate the previewed set's class's enchant illusions (via ns.Illusions), skipping the "no
-- illusion" hide entry. Names resolve synchronously, so no async name-fill needed.
function DressingRoom:_populateIllusions()
  self._pickerSlotOff = false
  local items = {}
  for _, ill in ipairs(ns.Illusions(self._classIndex)) do items[#items + 1] = { kind = "i", ill = ill } end
  self._pickerList:SetItems(items)
end

-- Weapon item names load async; refresh once shortly so blank names fill in (guarded, cancelable).
function DressingRoom:_scheduleNameFill()
  if self._pickerNameTimer then self._pickerNameTimer:Cancel() end
  self._pickerNameTimer = C_Timer.NewTimer(0.3, function()
    self._pickerNameTimer = nil
    if self._picker._widget:IsShown() then self._pickerList:Refresh() end
  end)
end

-- Toggle a clicked piece into/out of the look: an illusion, or a weapon in its slot (off-hand for
-- shields/holdables, else main-hand). Clicking the applied piece again clears that slot.
---@param item table
function DressingRoom:_equipRow(item)
  if item.kind == "i" then
    local sid = item.ill.sourceID
    self._lookIllusion = (self._lookIllusion == sid) and nil or sid
  elseif self._pickerSlotOff then
    local sid = item.src.sourceID
    self._lookOH = (self._lookOH == sid) and nil or sid
  else
    local sid = item.src.sourceID
    self._lookMH = (self._lookMH == sid) and nil or sid
  end
  self:_applyLook()
  self._pickerList:Refresh()   -- re-color the selection borders
end

-- Re-assert the whole look on the model's hands: main-hand = the picked weapon (else, when only
-- an illusion is chosen, the character's equipped host weapon so the shimmer has somewhere to
-- render), with the illusion layered on; off-hand = the picked off-hand. Bare (appearance 0) where
-- nothing's chosen. SlotTransmog remembers each across async re-skins.
function DressingRoom:_applyLook()
  local m = self._model
  if self._lookIllusion then
    local host = self._lookMH or ns.HostWeaponAppearance() or 0
    m:SlotTransmog(INVSLOT_MAINHAND, host, { illusionID = self._lookIllusion })
  else
    m:SlotTransmog(INVSLOT_MAINHAND, self._lookMH or 0)
  end
  m:SlotTransmog(INVSLOT_OFFHAND, self._lookOH or 0)
  self:UpdateWeaponSlots()   -- keep the bottom weapon slots showing the current look
end
