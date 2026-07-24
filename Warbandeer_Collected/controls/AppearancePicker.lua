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

-- The shared half of the docked "look builder" picker: the pane itself, its list rows, and the
-- composition of every pick onto the model. The two halves that KNOW what they're browsing are
-- companions — controls/WeaponPicker.lua (weapons + illusions) and controls/CosmeticPicker.lua
-- (shirt + tabard). Split out of WeaponPicker.lua for #641, which needed a second kind of target
-- and would otherwise have duplicated the row factory. Reopens the DressingRoom class.
--
-- Docked as a SIBLING pane (anchored to the window's right edge, own opaque backdrop), NOT a
-- resize of the window. Built lazily on first open, and pointed at one TARGET at a time — the
-- slot a pick lands in. The slot widgets are the entry point: left-click opens/switches the pane
-- to that slot, right-click clears it (DressingRoomWeaponSlots.lua, DressingRoomCosmeticSlots.lua).

local PICKERW = 264               -- docked pane width
local GAP     = 6                 -- gap between the window and the pane
local ROW_H   = 34                -- list row height
local PANEL   = { 0.05, 0.05, 0.06, 0.96 }   -- opaque pane fill (a standalone frame's theme bg is alpha-0)
local OWNED   = { 0.30, 0.85, 0.40 }         -- collected tint (illusions have no item quality)
local MARK    = 12                -- collected/wanted marker size
local NAMEX   = 5 + MARK + 5      -- name inset, clearing the leading collected/missing mark

-- Every slot the picker can point at. `kind` picks the pane's shape and which companion file
-- drives it: a "weapon" target gets the mode tabs + the category dropdown, a "cosmetic" one gets
-- neither (the target IS the category). `look` names the composed-look field a pick there lands
-- in, so the row borders, the clear gesture and the slot widgets can all read one map instead of
-- branching on the target by hand.
local TARGETS = {
  main   = { kind = "weapon",   look = "_lookMH",     title = "Weapon Look Builder" },
  off    = { kind = "weapon",   look = "_lookOH",     title = "Weapon Look Builder" },
  shirt  = { kind = "cosmetic", look = "_lookShirt",  slot = INVSLOT_BODY },
  tabard = { kind = "cosmetic", look = "_lookTabard", slot = INVSLOT_TABARD },
}

-- Shared with the companion picker/slot files, which read a target's look field + slot id.
DressingRoom._TARGETS = TARGETS

-- Toggle a slot's pick: clicking the applied piece again clears it.
--
-- Deliberately a function and not the obvious `(cur == sid) and nil or sid` one-liner — that
-- expression is BROKEN and cannot clear anything. In Lua `true and nil` evaluates to nil, which is
-- falsy, so the `or` branch always wins and the "clear" case re-assigns the same pick. It shipped
-- that way on the illusion and off-hand toggles, where re-clicking the applied piece silently did
-- nothing. Any new toggle goes through here.
---@param cur number?  the slot's current pick
---@param sid number  the clicked piece's sourceID
---@return number?
function DressingRoom._togglePick(cur, sid)
  if cur == sid then return nil end
  return sid
end

-- The composed-look sourceID currently sitting in the target's slot (nil when nothing's picked).
---@return number?
function DressingRoom:_targetLook()
  return self[TARGETS[self._pickerTarget].look]
end

-- Show/hide the docked picker pane (building + populating it on first open). `force` sets an
-- explicit state; nil toggles. `target` re-points the picker at another slot, re-shaping the pane
-- for that target's kind and routing picks there.
---@param force boolean?
---@param target string?  a TARGETS key ("main" | "off" | "shirt" | "tabard")
function DressingRoom:TogglePicker(force, target)
  if not self._picker then self:_buildPicker() end
  if target then self._pickerTarget = target end
  if force == nil then force = not self._picker._widget:IsShown() end
  if force then
    -- Opening: re-scope to the previewed class if it changed (Steps while closed don't rescope) —
    -- which re-applies the target too — else just (re)apply the current one.
    if self._pickerClass ~= self._classIndex then self:_rescopePicker() else self:_applyPickerTarget() end
    -- Both panes dock to the same edge, so only one can be there. Purely a physical constraint,
    -- not a mode: the browsed weapon stays on the doll and in its slot, and clicking a weapon cell
    -- brings the chooser straight back (#673).
    self:HideCellChooser()
  end
  self._picker:SetShown(force)
  -- Reflect the open/targeted state on both sets of slot borders.
  self:UpdateWeaponSlots()
  self:UpdateCosmeticSlots()
end

-- Re-shape the pane for the current target and repopulate its list. The two branches live in the
-- companion files that own each kind of browse.
function DressingRoom:_applyPickerTarget()
  if TARGETS[self._pickerTarget].kind == "cosmetic" then
    self:_applyCosmeticTarget()
  else
    self:_applyWeaponTarget()
  end
end

-- Build the docked pane: an opaque, 1px-outlined panel down the window's right edge, with a drag
-- header, the Weapons|Illusions tab row, the weapon-category dropdown, and the scrollable list.
-- The tabs and dropdown are the weapon target's furniture — a cosmetic target hides both.
function DressingRoom:_buildPicker()
  self:_rescopeWeapons()   -- the dropdown's options need the previewed class's categories

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
  -- the pane, a child, follows. The pane is built after RememberPosition ran (so its titlebar/
  -- body hooks don't cover this path), so mirror the save here to persist the dragged point.
  local strip = Frame:new{
    parent = pane,
    position = { TopLeft = {1, -1}, TopRight = {-1, -1}, Height = PAD + 18 },
  }
  -- Docked (#708), the room is locked to the collection window and can't be dragged on its own — the
  -- host's titlebar moves the whole cluster. Standalone, the strip drags the entire room (its own
  -- titlebar is built after RememberPosition, so mirror the save here to persist the point).
  if not self._docked then
    strip._widget:EnableMouse(true)
    strip:setDragTarget(self._widget)
    strip._widget:HookScript("OnMouseUp", function()
      if not self._posStore then return end
      local point, _, relPoint, x, y = self._widget:GetPoint(1)
      self._posStore.point, self._posStore.relPoint, self._posStore.x, self._posStore.y = point, relPoint, x, y
    end)
  end
  -- Retitled per target (the weapon builder's fixed name, else the cosmetic category's own).
  self._pickerTitle = Label:new{ parent = strip, fontObj = "GameFontNormal",
    position = { TopLeft = {PAD, -PAD} }, text = TARGETS.main.title }

  -- Weapons | Illusions mode tabs.
  self._pickerTabs = Frame:new{
    parent = pane,
    position = { TopLeft = {PAD, -(PAD + 22)}, Width = PICKERW - 2 * PAD, Height = ROWH },
  }
  self._modeTab = {}
  self._pickerTabBox = {}   -- tab boxes, so _applyWeaponTarget can hide the Illusions tab for the off-hand
  local tw = (PICKERW - 2 * PAD - 4) / 2
  local function tab(mode, label, x)
    local box = Frame:new{ parent = self._pickerTabs, position = { TopLeft = {x, 0}, Width = tw, Height = ROWH } }
    self._pickerTabBox[mode] = box
    self._modeTab[mode] = selBox(box)
    Button:new{ parent = box, position = { All = true }, OnClick = function() self:_setPickerMode(mode) end }
    Label:new{ parent = box, justifyH = ui.justify.Center, position = { Left = {2, 0}, Right = {-2, 0} }, text = label }
  end
  tab("weapons", "Weapons", 0)
  tab("illusions", "Illusions", tw + 4)

  -- Weapon-category dropdown (weapon targets only; hidden by _setPickerMode in Illusions mode and
  -- by _applyCosmeticTarget for a cosmetic one).
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

  self:_applyPickerTarget()
end

-- Anchor the list under `anchor`'s bottom edge, filling the rest of the pane. Both targets
-- re-anchor it as their furniture (tabs / dropdown) comes and goes, so the freed space is used.
---@param anchor Frame
function DressingRoom:_anchorPickerList(anchor)
  self._pickerList:ClearAllPoints()
  self._pickerList:Position{
    TopLeft     = {anchor, ui.edge.BottomLeft, 0, -PAD},
    BottomRight = {self._picker, ui.edge.BottomRight, -PAD, PAD},
  }
end

-- One list row: a selection border, a leading collected/missing mark, a name line, a subtitle, and
-- a trailing Wanted star. Clicking applies the piece to the look, shift-clicking flags it wanted,
-- and hover shows a real item tooltip (illusions have no item, so no tooltip).
--
-- The two markers only appear on lists that show uncollected entries — the cosmetic ones. The
-- weapon lists are collected-only, so a check on every row would be noise and a wishlist flag
-- would be meaningless there. The name is inset past the mark either way, so both lists' text
-- starts on the same edge.
---@param list VirtualList
---@return Frame
function DressingRoom:_makeRow(list)
  local row = Frame:new{ parent = list:Content(), position = { Height = ROW_H } }
  row.border = selBox(row)
  row.status = Texture:new{ parent = row, layer = ui.layer.Artwork, atlasSize = false,
    position = { Left = {5, 0}, Size = {MARK, MARK}, Hide = true } }
  row.star = Texture:new{ parent = row, layer = ui.layer.Artwork, atlas = ns.WantedIcon,
    atlasSize = false, position = { Right = {-5, 0}, Size = {MARK, MARK}, Hide = true } }
  row.name = Label:new{ parent = row, justifyH = ui.justify.Left, wordWrap = false,
    position = { TopLeft = {NAMEX, -3}, Right = {-(NAMEX), 0} } }
  row.src = Label:new{ parent = row, fontObj = "GameFontDisableSmall", justifyH = ui.justify.Left,
    wordWrap = false, position = { TopLeft = {row.name, ui.edge.BottomLeft, 0, -1}, Right = {-(NAMEX), 0} } }
  row._widget:EnableMouse(true)
  row._widget:SetScript("OnEnter", function(f)
    if not row._itemID then return end
    GameTooltip:SetOwner(f, "ANCHOR_LEFT")
    GameTooltip:SetItemByID(row._itemID)
    GameTooltip:Show()
  end)
  row._widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
  row._widget:SetScript("OnMouseUp", function()
    if IsShiftKeyDown() then self:_toggleRowWanted(row._item) else self:_equipRow(row._item) end
  end)
  return row
end

-- Re-point a pooled row at an appearance (`{kind="w", visualID, src, showStatus?}` — a weapon,
-- shirt or tabard, all resolved through ns.AppearanceSource to the same shape) or an illusion
-- (`{kind="i", ill}`): appearances show the item name quality-coloured + source line + item
-- tooltip; illusions show the illusion name tinted by collected state. The gold border marks the
-- piece applied to the target. `showStatus` adds the green-check / red-X collected mark and the
-- Wanted star — set only by the cosmetic lists, the ones that show what you don't own.
---@param row Frame
---@param item table
---@return number
function DressingRoom:_fillRow(row, item)
  row._item = item
  local collected
  if item.kind == "i" then
    local ill = item.ill
    row._itemID = nil
    row.name:Text(ill.name or ("Illusion " .. ill.sourceID))
    row.name:Color(ill.isCollected and OWNED or "muted")
    row.src:Text("")
    row.border:Color(ill.sourceID == self._lookIllusion and SELECTED or IDLE)
    collected = ill.isCollected
  else
    local src = item.src
    row._itemID = src.itemID
    local name = GetItemNameByID(src.itemID)
    if not name then RequestLoadItemDataByID(src.itemID) end
    row.name:Text(name or ("Appearance " .. item.visualID))
    local qc = src.quality and QUALITY[src.quality]
    row.name:Color(qc and {qc.r, qc.g, qc.b} or (src.isCollected and OWNED or "muted"))
    row.src:Text(src.text or "")
    row.border:Color(src.sourceID == self:_targetLook() and SELECTED or IDLE)
    collected = src.isCollected
  end
  -- The collected mark + wanted star ride on any list that shows pieces you don't own (the
  -- cosmetic ones and the illusions); the collected-only weapon lists opt out via `showStatus`.
  -- The two wanted stores are keyed differently — visualID for appearances, sourceID for
  -- illusions — so the lookup branches rather than sharing one call.
  if item.showStatus then
    row.status:Atlas(collected and ns.icons.CheckGreen or ns.icons.RedX, false)
    row.status:Show()
    local wanted
    if item.kind == "i" then wanted = ns:IsIllusionWanted(item.ill.sourceID)
    else wanted = ns:IsCosmeticWanted(item.visualID) end
    row.star:SetShown(wanted)
  else
    row.status:Hide()
    row.star:Hide()
  end
  return ROW_H
end

-- Shift-click gesture: flag an appearance wanted (a wishlist mark, since these lists show pieces
-- you don't own). Only the lists that carry the marker respond — a plain weapon row falls through
-- to the ordinary equip click.
---@param item table?
function DressingRoom:_toggleRowWanted(item)
  if not (item and item.showStatus) then return end
  if item.kind == "i" then
    ns:ToggleIllusionWanted(item.ill.sourceID)
  else
    ns:ToggleCosmeticWanted(item.visualID)
  end
  self._pickerList:Refresh()
end

-- Item names load async; refresh once shortly so blank names fill in (guarded, cancelable).
function DressingRoom:_scheduleNameFill()
  if self._pickerNameTimer then self._pickerNameTimer:Cancel() end
  self._pickerNameTimer = C_Timer.NewTimer(0.3, function()
    self._pickerNameTimer = nil
    if self._picker._widget:IsShown() then self._pickerList:Refresh() end
  end)
end

-- Toggle a clicked row into/out of the look, then re-compose. Which look field it lands in is the
-- target's business, so the pick itself is delegated; the apply + re-color tail is shared.
---@param item table
function DressingRoom:_equipRow(item)
  if TARGETS[self._pickerTarget].kind == "cosmetic" then
    self:_equipCosmeticRow(item)
  else
    self:_equipWeaponRow(item)
  end
  self:_applyLook()
  self._pickerList:Refresh()   -- re-color the selection borders
end

-- The main-hand slot's `secondaryAppearanceID` for whatever appearance is going into it. NOT an
-- appearance id — a discriminator; see `ns.PairedArtifactWeapon` for what the two values mean and
-- why leaving it nil is actively wrong (nil defaults to 0 = PAIRED, and a paired main-hand
-- overrides the off-hand, so a Titan's Grip pair rendered as the off-hand alone — #661).
---@param sourceID number  the appearance being put in the main hand
---@return number
local function mainHandSecondary(sourceID)
  return ns.PairedArtifactWeapon(sourceID) and Constants.Transmog.MainHandTransmogIsPairedWeapon
    or Constants.Transmog.MainHandTransmogIsIndividualWeapon
end

-- Re-assert the whole composed look on the model: main-hand = the picked weapon (else, when only
-- an illusion is chosen, the character's equipped host weapon so the shimmer has somewhere to
-- render), with the illusion layered on; off-hand = the picked off-hand; shirt and tabard from
-- their own picks. Bare (appearance 0) where nothing's chosen. SlotTransmog remembers each across
-- the model's async re-skins, so the look survives a race change, a form change and a set Step.
function DressingRoom:_applyLook()
  local m = self._model
  if self._lookIllusion then
    local host = self._lookMH or ns.HostWeaponAppearance() or 0
    m:SlotTransmog(INVSLOT_MAINHAND, host,
      { illusionID = self._lookIllusion, secondaryAppearanceID = mainHandSecondary(host) })
  elseif self._lookMH then
    m:SlotTransmog(INVSLOT_MAINHAND, self._lookMH,
      { secondaryAppearanceID = mainHandSecondary(self._lookMH) })
  else
    self:_bareSlot(INVSLOT_MAINHAND)
  end
  -- A main-hand that leaves no room for an off-hand (a staff, a polearm, a bow) suppresses the
  -- off-hand appearance; the pick is kept and returns when the main-hand empties or becomes
  -- something that pairs — a 1H, or a Titan's Grip two-hander. #618, #661.
  local offHand = not self._lookNoOH and self._lookOH
  if offHand then m:SlotTransmog(INVSLOT_OFFHAND, offHand) else self:_bareSlot(INVSLOT_OFFHAND) end
  -- Shirt and tabard ride here rather than in the previewed set's outfit: transmog sets never
  -- carry either, so these two slots are picker-only and this is their sole apply path (#641).
  if self._lookShirt then m:SlotTransmog(INVSLOT_BODY, self._lookShirt) else self:_bareSlot(INVSLOT_BODY) end
  if self._lookTabard then m:SlotTransmog(INVSLOT_TABARD, self._lookTabard) else self:_bareSlot(INVSLOT_TABARD) end
  self:UpdateWeaponSlots()     -- keep the bottom weapon slots showing the current look
  self:UpdateCosmeticSlots()   -- …and the shirt/tabard slots in the left column
end

-- Take one composed-look slot off the model outright.
--
-- NOT `SlotTransmog(slot, 0)`, which is what this used to do: appearance 0 is `NoTransmogID`, and
-- setting it records "no transmog override for this slot" rather than "wear nothing there" — the
-- actor keeps whatever it was last given, so a cleared shirt went on rendering while its slot icon
-- had already gone empty. `UndressSlot` strips the slot in place (the same primitive ToggleSlot
-- uses for armor, for the same reason its comment gives: TryOn alone can't remove a worn piece),
-- and the override is dropped alongside it so an async re-skin doesn't put the piece back.
---@param slot number  inventory slot id
function DressingRoom:_bareSlot(slot)
  self._model:ClearSlotTransmog(slot)
  self._model:UndressSlot(slot)
end
