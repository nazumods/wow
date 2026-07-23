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

-- The outfit row (#642, retargeted by #655): the third bottom control row. Builds the widgets and
-- owns them; what the buttons do is the sibling controls/DressingRoomOutfitActions.lua. Reopens
-- the DressingRoom class; the library store is outfitlibrary.lua, the game's custom-set wrappers
-- are outfit.lua, and the compose/apply plus outfit mode are controls/DressingRoomOutfit.lua.
--
--   [ Outfit ▾ ] [ name ] [ Save ] [ Rename ] [ Delete ] [ Push ]
--
-- **The dropdown lists the account-wide LIBRARY**, not the game's custom sets — those are
-- per-character (measured), so a look saved there can't follow you to an alt. `Push` is the bridge:
-- it copies the selected look into *this* character's custom sets, for wearing at a transmogrifier.
--
-- Deliberately no `ui.Dialog` name prompt: rename needs a name field regardless, so one inline
-- field serves both and stays visible instead of appearing modally. Nothing else in the suite
-- uses Dialog, so this also avoids being its first caller for one string.
--
-- Anything destructive or lossy ARMS before it fires — the button relabels and a second click
-- inside CONFIRM_S commits, covering Delete, an overwriting Save, and a Push that would replace a
-- same-named set, without a modal.

local DROPW, NAMEW, BTNW, GAP = 150, 140, 62, 6
-- Dropdown key for the trailing "save a new one" entry. A STRING so it can't be mistaken for a
-- library outfit name — those are user-typed and trimmed, so they can never be empty or contain
-- the sentinel's markers.
local NEW_SET = "\0new"
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
  -- `wordWrap = false` is structural, not cosmetic: the box is a fixed ROWH tall, so a caption that
  -- wraps grows the label out of it and over the row below (an armed "Replace <name>?" did exactly
  -- that across three lines). Armed captions are kept short too — this just makes the layout
  -- impossible to break from a caption alone.
  btn.label = Label:new{ parent = box, justifyH = ui.justify.Center, wordWrap = false,
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

  -- Library dropdown, in the store's own insertion order — the order the user added looks in, and
  -- the order re-saving one preserves.
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
  -- Enter is **always Save**, never Rename. The field names what you're saving, so committing it
  -- means "save under this name" — and Save is now non-destructive to other entries, while Rename
  -- moves an existing look and can't be undone. An earlier revision routed Enter to Rename while a
  -- look was selected; typing a new name and pressing Enter then RENAMED the loaded look instead
  -- of saving a new one, which is exactly the surprise a keyboard shortcut must never spring.
  -- Renaming is the Rename button's job, deliberately requiring a deliberate click.
  self._outfitName._widget:SetScript("OnEnterPressed", function(f)
    f:ClearFocus()
    self:SaveOutfit()
  end)
  self._outfitName._widget:SetScript("OnTextChanged", function() self:_syncOutfitButtons() end)

  local bx = DROPW + GAP + NAMEW + GAP
  self._outfitSave   = rowButton(self, bx,                     "Save",   function() self:SaveOutfit() end)
  self._outfitRename = rowButton(self, bx + BTNW + GAP,        "Rename", function() self:RenameOutfit() end)
  self._outfitDelete = rowButton(self, bx + 2 * (BTNW + GAP),  "Delete", function() self:DeleteOutfit() end)
  self._outfitPush   = rowButton(self, bx + 3 * (BTNW + GAP),  "Push",   function() self:PushOutfit() end)

  -- The row starts NEUTRAL — "+ New Look", empty field. It deliberately doesn't reopen on the look
  -- last loaded: the room opens on whatever grid cell was clicked, so a seeded selection would
  -- describe a look that isn't on screen, and the typed name is what Save targets. The row's whole
  -- contract is that it describes what the model is showing.
  self:RefreshOutfits()
end

---Repopulate the dropdown from the library, keeping the current selection if it still exists.
function DressingRoom:RefreshOutfits()
  if not self._outfitDrop then return end
  local opts, stillThere = {}, false
  for _, o in ipairs(ns.LibraryOutfits()) do
    -- Class-coloured by **who saved it**, so the tint means one consistent thing wherever a look
    -- appears. Deliberately not `forClass`: two classes are in play (the saver, and the class whose
    -- set the look was built from) and one label can only carry one, so tinting by the set's class
    -- made a Warrior's look read as Druid. `forClass` is a weak cross-character signal anyway — a
    -- leather set sits in one class column but rogue, druid, monk and DH can all wear it, which is
    -- what `armor` is stored for. It shows as text in `/collected outfit list`, where there's width
    -- to say it unambiguously. 150px has no room for "— Triandra (Warrior)"; the colour is free.
    opts[#opts + 1] = { key = o.name, label = ns.ClassColored(o.name, o.class) }
    if o.name == self._outfitSel then stillThere = true end
  end
  if not stillThere then self._outfitSel = nil end
  -- The trailing "new" entry mirrors Blizzard's own custom-set dropdown: creating is a mode the
  -- user CHOOSES, not something inferred from having edited the name field.
  opts[#opts + 1] = { key = NEW_SET, label = "+ New Look" }
  self._outfitDrop:SetOptions(opts, self._outfitSel or NEW_SET)
  self:_syncOutfitButtons()
end

---Dropdown handler: load a saved look, or switch the row into "save a new one" mode.
---@param key string  a library outfit name, or the NEW_SET sentinel
function DressingRoom:_selectOutfit(key)
  if key ~= NEW_SET then return self:LoadOutfit(key) end
  self._outfitSel = nil
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
---explained after the fact: Save needs a name while creating, Rename needs a selected look *and* a
---name, Delete and Push need a selected look. Re-run whenever the selection or the field changes.
function DressingRoom:_syncOutfitButtons()
  if not self._outfitSave then return end
  local named = self:_typedOutfitName() ~= ""
  local selected = self._outfitSel ~= nil
  enable(self._outfitSave, selected or named)   -- overwriting a selected look needs no name
  enable(self._outfitRename, selected and named)
  enable(self._outfitDelete, selected)
  enable(self._outfitPush, selected)
end
