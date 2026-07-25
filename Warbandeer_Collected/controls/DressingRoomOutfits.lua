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
-- The row below it is the share row (#643, controls/DressingRoomOutfitShare.lua), whose columns
-- are aligned to this one's; it is a separate row only because this one is full at 568 of 572.
--
-- **The dropdown lists the account-wide LIBRARY**, not the game's custom sets — those are
-- per-character (measured), so a look saved there can't follow you to an alt. `Push` is the bridge:
-- it copies the selected look into *this* character's custom sets, for wearing at a transmogrifier.
--
-- Deliberately no `ui.Dialog` name prompt: rename needs a name field regardless, so one inline
-- field serves both and stays visible instead of appearing modally. Nothing else in the suite
-- uses Dialog, so this also avoids being its first caller for one string.
--
-- Anything destructive or lossy ARMS before it fires — the button relabels with the seconds left
-- and a second click inside CONFIRM_S commits, covering Delete, an overwriting Save, and a Push that
-- would replace a same-named set, without a modal. Letting the countdown run out says so in chat.

local DROPW, NAMEW, BTNW, GAP = 150, 140, 62, 6
-- Floor for the outfit menu's height. The measured room is normally far more than this; the floor
-- only guards the degenerate case where a short window would otherwise leave a menu too small to
-- scroll usefully — better to overhang slightly than to offer a two-row list.
local MIN_MENU_H = 120
-- The dropdown key for the one trailing entry that isn't a library look. A STRING so it can't be
-- mistaken for a library outfit name — those are user-typed and trimmed, so they can never be
-- empty or contain the sentinel's markers.
--
-- A second sentinel used to sit beside it opening the library window, put in the menu because this
-- row is full at 568 of GRIDW's 572px. #687 replaced it with a real button on a row of its own: a
-- pull-down is a poor home for an opener, and the `Select()` re-point it needed — to stop the
-- dropdown reading "Manage Library…" as though that were the loaded look — went with it.
local NEW_SET = "\0new"
local CONFIRM_S = 4      -- seconds an armed button stays armed before reverting, counted in its caption

---One labelled button in a control row: a framed box with a click target and a centered caption,
---whose text can be swapped when armed. Returns a small handle the actions drive.
---
---A method rather than a local because the share row (controls/DressingRoomOutfitShare.lua) builds
---its buttons the same way, in its own parent at its own width — the two rows sit under each other
---and have to look identical.
---@param row Frame  the control row to build into
---@param x number
---@param w number
---@param label string
---@param onClick fun()
---@return table  { box, border, label, text }
function DressingRoom:_rowButton(row, x, w, label, onClick)
  local box = Frame:new{
    parent = row, position = { TopLeft = {x, 0}, Width = w, Height = ROWH },
  }
  local btn = { box = box, border = selBox(box), text = label }
  -- `wordWrap = false` is structural, not cosmetic: the box is a fixed ROWH tall, so a caption that
  -- wraps grows the label out of it and over the row below (an armed "Replace <name>?" did exactly
  -- that across three lines). What it does INSTEAD of wrapping is ellipsize, which is why an armed
  -- caption is `Sure?` rather than the verb: the string that has to fit these 58px is `Sure? 4`,
  -- countdown digit included — 46.5px in the theme's Geist-13 body font, where `Confirm 4` and
  -- `Replace 4` measure 60.0px and lose the DIGIT, the visible half of #698, to the ellipsis.
  -- Measured, not guessed; the filter strip next door records the same font truncating "Any armour"
  -- at only 1.8px over its budget (OutfitLibraryWindow.lua). Which look is at risk goes to chat
  -- instead, where there is width to name it.
  btn.label = Label:new{ parent = box, justifyH = ui.justify.Center, wordWrap = false,
    position = { Left = {2, 0}, Right = {-2, 0} }, text = label }
  -- Disabled buttons grey their caption and swallow the click, rather than firing and printing a
  -- refusal — the same "don't offer what won't work" Blizzard's own name prompt uses.
  Button:new{ parent = box, position = { All = true },
    OnClick = function() if not btn.disabled then onClick() end end }
  return btn
end

---Enable/disable one row button, greying its caption to match. A method for the same reason as
---`_rowButton` — the share row greys its Import button the same way.
---@param btn table
---@param on boolean
---
---**Disabling disarms (#716).** `Button.OnClick` swallows every click once `disabled` is set, so an
---armed button left greyed goes on asking once a second for a confirmation it can no longer accept,
---and then prints a lapse notice for a question that stopped being answerable. Reachable wherever
---something greys a button out from under an arm: `/collected outfit delete` on the loaded look
---(`RefreshOutfits` clears the selection), the share row's Import doing the same, and clearing the
---name field while an overwrite-armed Save has no selection to fall back on.
function DressingRoom:_enableRow(btn, on)
  btn.disabled = not on or nil
  -- Before the recolour: `_disarmOutfit` restores the resting caption, which then greys with it.
  if btn.disabled and self._armed == btn then self:_disarmOutfit() end
  btn.label:Color(on and "text" or "muted")
end

---Put a row button into its armed state (gold border + a warning caption counting the seconds down),
---reverting after CONFIRM_S so an armed Delete can't sit waiting indefinitely. Only one button is
---ever armed at a time. A method rather than a local so the action half
---(DressingRoomOutfitActions.lua) can arm too.
---
---**Both halves of the lapse are signals, and both are load-bearing (#698).** The revert used to be
---silent, which made a late second click pixel-identical to a first one: an armed button and a
---freshly re-armed button looked the same, so "I clicked Delete twice and it's gone" and "…and
---nothing happened" were indistinguishable at the button. The caption's countdown makes the lapse
---visible as it happens; the chat line is the half that survives walking away — a commit prints
---`Deleted.`, so a lapse has to print its opposite in the same place.
---**The lapse notice names the look (#716).** The armed caption can't — `Sure? 4` already fills the
---62px button — so without a name in chat the line describes nothing in particular. That matters
---once the workspace is docked (#713): this row and the library window's preview pane hold their
---armed state independently, so both Deletes can be armed at once, and two bare
---`nothing was deleted` lines are byte-identical for a message whose whole job is telling you which
---click didn't land.
---@param btn table
---@param caption string  the armed caption; the seconds left are appended to it
---@param lapsed string  past participle for the lapse notice ("deleted", "replaced")
---@param subject string  the look the lapse notice names
function DressingRoom:_armOutfit(btn, caption, lapsed, subject)
  self:_disarmOutfit()
  self._armed = btn
  btn.border:Color(SELECTED)
  local left = CONFIRM_S
  local function paint() btn.label:Text(("%s %d"):format(caption, left)) end
  paint()
  -- A ticker rather than a one-shot: the caption repaints every second and the final tick IS the
  -- revert. Only this path prints — disarming because another button was clicked is a deliberate
  -- abandonment and needs no notice.
  self._armTimer = C_Timer.NewTicker(1, function()
    left = left - 1
    if left > 0 then return paint() end
    self._armTimer = nil
    self:_disarmOutfit()
    ns.Print(("Confirmation expired — \"%s\" was not %s."):format(subject, lapsed))
  end, CONFIRM_S)
end

---Revert whichever button is armed back to its resting caption, stopping its countdown.
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
  -- Cap the menu to the room it actually has, so a large library can't spill past the window's
  -- bottom edge (#699). `FilterDropdown` scrolls whatever exceeds `maxMenuHeight` rather than
  -- growing, but its 400px default is far more than this window offers beneath the outfit row —
  -- and the list is as long as the user's library, so there is no count to design around.
  --
  -- Measured off `controls` rather than the constants because the race panels below are sized at
  -- runtime: `controlsH` (and so the window's height) isn't knowable from `ROW*` alone. The frame's
  -- border sits a few px below `controls`, which is what the trailing margin leaves room for.
  local menuRoom = controls:Height() - (ROW3 + ROWH) - 4
  self._outfitDrop = FilterDropdown:new{
    parent = self._outfitRow, bordered = true, width = DROPW, options = {},
    maxMenuHeight = menuRoom > MIN_MENU_H and menuRoom or MIN_MENU_H,
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
  local row = self._outfitRow
  self._outfitSave   = self:_rowButton(row, bx,                    BTNW, "Save",   function() self:SaveOutfit() end)
  self._outfitRename = self:_rowButton(row, bx + BTNW + GAP,       BTNW, "Rename", function() self:RenameOutfit() end)
  self._outfitDelete = self:_rowButton(row, bx + 2 * (BTNW + GAP), BTNW, "Delete", function() self:DeleteOutfit() end)
  self._outfitPush   = self:_rowButton(row, bx + 3 * (BTNW + GAP), BTNW, "Push",   function() self:PushOutfit() end)

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
---
---**An armed verb never survives the selection moving out from under it (#715).** The verbs read
---`_outfitSel` at commit time, so an armed Delete that outlived a dropdown change would still read
---as armed while pointing at a different look — and its confirming click would delete that one,
---with no second confirmation for the look it actually removed. The load half of this is disarmed
---inside `LoadOutfit`, which is also where `/collected outfit load` moves the selection; the "+ New
---Look" branch below clears it and so disarms here.
---@param key string  a library outfit name, or the NEW_SET sentinel
function DressingRoom:_selectOutfit(key)
  if key ~= NEW_SET then return self:LoadOutfit(key) end
  self:_disarmOutfit()
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
  self:_enableRow(self._outfitSave, selected or named)   -- overwriting a selected look needs no name
  self:_enableRow(self._outfitRename, selected and named)
  self:_enableRow(self._outfitDelete, selected)
  self:_enableRow(self._outfitPush, selected)
end

---Build the fifth control row: the one button that opens the outfit library (#687).
---
---A row of its own because the outfit row above is full at 568 of GRIDW's 572px. The opener used to
---be a `⚙ Manage Library…` entry inside that row's dropdown — the only place that cost no width —
---which buried the library behind a pull-down and needed a `Select()` re-point so the dropdown
---didn't sit there naming a "look" that was really a command.
---
---The ratings row above is deliberately NOT reused, though a loaded outfit hides it and it can look
---like free space: it is a feature slot the weapon ratings are owed, not whitespace.
---
---Sized to `DROPW` so the button lines up under the outfit dropdown directly above it.
---@param controls Frame
function DressingRoom:_buildLibraryRow(controls)
  local row = Frame:new{
    parent = controls, position = { TopLeft = {0, -k.ROW5}, Width = GRIDW, Height = ROWH },
  }
  self:_rowButton(row, 0, DROPW, "Outfit Library…", function() ns.OpenOutfitLibrary() end)
end
