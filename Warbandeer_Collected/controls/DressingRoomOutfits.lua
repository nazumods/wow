---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Frame, Button, Label = ui.Frame, ui.Button, ui.Label
local FilterDropdown, EditBox = ui.FilterDropdown, ui.EditBox
local C_Timer = C_Timer
local DressingRoom = ns.DressingRoom
local k = DressingRoom._k
local selBox, IDLE, SELECTED = k.selBox, k.IDLE, k.SELECTED
local GRIDW, ROWH, ROW3 = k.GRIDW, k.ROWH, k.ROW3

-- The outfit row (#642): the third bottom control row, wiring the dressing room to the game's own
-- **custom sets** store — save the composed look into it, load one back out. Reopens the
-- DressingRoom class; the store wrappers and validation are outfit.lua, the compose/apply and
-- outfit mode are controls/DressingRoomOutfit.lua.
--
--   [ Outfit ▾ ] [ name ] [ Save ] [ Rename ] [ Delete ]
--
-- Deliberately no `ui.Dialog` name prompt: rename needs a name field regardless, so one inline
-- field serves both and stays visible instead of appearing modally. Nothing else in the suite
-- uses Dialog, so this also avoids being its first caller for one string.
--
-- Both destructive/lossy actions ARM before they fire — the button relabels and a second click
-- inside CONFIRM_S commits. That covers "delete this set" and "save a look with slots this
-- character can't collect" (the game drops those silently) without a modal.

local DROPW, NAMEW, BTNW, GAP = 180, 170, 66, 6
-- Dropdown key for the trailing "create a new set" entry. A STRING so it can never collide with a
-- custom set id — those are small non-negative integers and `0` is a real one (measured in game).
local NEW_SET = "__new__"
local CONFIRM_S = 4      -- seconds an armed button stays armed before reverting

-- One labelled button in the row: a framed box with a click target and a centered caption, whose
-- text can be swapped when armed. Returns a small handle the actions drive.
---@param room DressingRoom
---@param x number
---@param label string
---@param onClick fun()
---@return table  { box, border, label, text }
local function rowButton(room, x, label, onClick)
  local box = Frame:new{
    parent = room._outfitRow, position = { TopLeft = {x, 0}, Width = BTNW, Height = ROWH },
  }
  local btn = { box = box, border = selBox(box), text = label }
  btn.label = Label:new{ parent = box, justifyH = ui.justify.Center,
    position = { Left = {2, 0}, Right = {-2, 0} }, text = label }
  -- Disabled buttons grey their caption and swallow the click, rather than firing and printing a
  -- refusal — the same "don't offer what won't work" Blizzard's own name prompt uses.
  Button:new{ parent = box, position = { All = true }, glow = false,
    OnClick = function() if not btn.disabled then onClick() end end }
  return btn
end

-- Enable/disable one row button, greying its caption to match.
---@param btn table
---@param on boolean
local function enable(btn, on)
  btn.disabled = not on or nil
  btn.label:Color(on and "text" or "muted")
end

---Put a row button into its armed state (gold border + a warning caption), reverting after
---CONFIRM_S so an armed Delete can't sit waiting indefinitely. Only one button is ever armed at a
---time. A method rather than a local so the action half (DressingRoomOutfitActions.lua) can arm too.
---@param btn table
---@param caption string
function DressingRoom:_armOutfit(btn, caption)
  self:_disarmOutfit()
  self._armed = btn
  btn.label:Text(caption)
  btn.border:Color(SELECTED)
  self._armTimer = C_Timer.NewTimer(CONFIRM_S, function()
    self._armTimer = nil
    self:_disarmOutfit()
  end)
end

---Revert whichever button is armed back to its resting caption.
function DressingRoom:_disarmOutfit()
  if self._armTimer then self._armTimer:Cancel(); self._armTimer = nil end
  local btn = self._armed
  if not btn then return end
  self._armed = nil
  btn.label:Text(btn.text)
  btn.border:Color(IDLE)
end

-- Build the outfit row. Called by the constructor after _buildControls, so it sits below the
-- ratings row and above the race panels.
---@param controls Frame  the bottom controls strip built by the constructor
function DressingRoom:_buildOutfits(controls)
  self._outfitRow = Frame:new{
    parent = controls, position = { TopLeft = {0, -ROW3}, Width = GRIDW, Height = ROWH },
  }

  -- Saved-set dropdown. Options keep `GetCustomSets()`'s own order — custom set ids are REUSED
  -- after a delete (a new set came back as id 5 with six sets already saved), so id order says
  -- nothing about creation order and must not be sorted on.
  self._outfitDrop = FilterDropdown:new{
    parent = self._outfitRow, bordered = true, width = DROPW, options = {},
    onSelect = function(_, key) self:_selectOutfit(key) end,
    position = { TopLeft = {0, 0} },
  }

  local nameBox = Frame:new{
    parent = self._outfitRow,
    position = { TopLeft = {DROPW + GAP, 0}, Width = NAMEW, Height = ROWH },
  }
  selBox(nameBox)
  self._outfitName = EditBox:new{
    parent = nameBox, position = { TopLeft = {6, -1}, BottomRight = {-4, 1} },
  }
  self._outfitName._widget:SetScript("OnEscapePressed", function(f) f:ClearFocus() end)
  -- Enter commits whatever the field is FOR in the current mode: while a set is selected the name
  -- belongs to Rename (Save overwrites and ignores it), and only "+ New Custom Set" makes it the
  -- name of something being saved. Routing Enter to Save in both modes silently discarded a name
  -- typed against a selected set.
  self._outfitName._widget:SetScript("OnEnterPressed", function(f)
    f:ClearFocus()
    if self._outfitID then self:RenameOutfit() else self:SaveOutfit() end
  end)
  self._outfitName._widget:SetScript("OnTextChanged", function() self:_syncOutfitButtons() end)

  local bx = DROPW + GAP + NAMEW + GAP
  self._outfitSave   = rowButton(self, bx,                     "Save",   function() self:SaveOutfit() end)
  self._outfitRename = rowButton(self, bx + BTNW + GAP,        "Rename", function() self:RenameOutfit() end)
  self._outfitDelete = rowButton(self, bx + 2 * (BTNW + GAP),  "Delete", function() self:DeleteOutfit() end)

  -- Reopen on the set last loaded (db.lastOutfit), if it still exists. The name field is seeded
  -- too, but the look is NOT applied — the room opens on whatever set was clicked, and loading is
  -- an explicit act.
  local last = ns.db and ns.db.lastOutfit
  if last then
    for _, s in ipairs(ns.CustomSets()) do
      if s.id == last then self._outfitID = last; self._outfitName:Text(s.name) end
    end
  end
  self:RefreshOutfits()
  -- Another addon (or Blizzard's own UI) can add, rename or delete a set behind our back.
  ns:registerEvent("TRANSMOG_CUSTOM_SETS_CHANGED", function() self:RefreshOutfits() end)
end

---Repopulate the dropdown from the store, keeping the current selection if it still exists.
function DressingRoom:RefreshOutfits()
  if not self._outfitDrop then return end
  local opts, stillThere = {}, false
  for _, s in ipairs(ns.CustomSets()) do
    opts[#opts + 1] = { key = s.id, label = s.name }
    if s.id == self._outfitID then stillThere = true end
  end
  if not stillThere then self._outfitID = nil end
  -- The trailing "new" entry mirrors Blizzard's own custom-set dropdown: creating is a mode the
  -- user CHOOSES, not something inferred from having edited the name field.
  opts[#opts + 1] = { key = NEW_SET, label = "+ New Custom Set" }
  self._outfitDrop:SetOptions(opts, self._outfitID or NEW_SET)
  self:_syncOutfitButtons()
end

---Dropdown handler: load a saved set, or switch the row into "create a new one" mode.
---@param key number|string  a custom set id, or the NEW_SET sentinel
function DressingRoom:_selectOutfit(key)
  if key ~= NEW_SET then return self:LoadOutfit(key) end
  self._outfitID = nil
  self._outfitName:Text("")
  self._outfitName._widget:SetFocus()
  self:_syncOutfitButtons()   -- Text("") on an already-empty box fires no OnTextChanged
end
---The name in the field, trimmed. "" when empty. A method for the same reason as `_armOutfit`.
---@return string
function DressingRoom:_typedOutfitName()
  return (self._outfitName:Text() or ""):match("^%s*(.-)%s*$")
end

---Grey the row buttons that can't act right now, so a dead click is impossible rather than
---explained after the fact: Save needs a name while creating, Rename needs a selected set *and* a
---name, Delete needs a selected set. Re-run whenever the selection or the name field changes.
function DressingRoom:_syncOutfitButtons()
  if not self._outfitSave then return end
  local named = self:_typedOutfitName() ~= ""
  local selected = self._outfitID ~= nil
  enable(self._outfitSave, selected or named)   -- overwriting a selected set needs no name
  enable(self._outfitRename, selected and named)
  enable(self._outfitDelete, selected)
end
