---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Frame, Label, EditBox, Model = ui.Frame, ui.Label, ui.EditBox, ui.Model
local C_Timer = C_Timer
local OutfitLibraryWindow = ns.OutfitLibraryWindow
local k = OutfitLibraryWindow._k
local roomK = ns.DressingRoom._k
local selBox, IDLE, SELECTED = roomK.selBox, roomK.IDLE, roomK.SELECTED
local RIGHTW, GAP, STRIPH, LISTH = k.RIGHTW, k.GAP, k.STRIPH, k.LISTH

-- The library window's **right column** (#699): a model showing the selected look, what is known
-- about where it came from, and the three verbs that act on it. Reopens OutfitLibraryWindow; the
-- shell, filter strip and list are controls/OutfitLibraryWindow.lua. Split for file size, the same
-- way the dressing room is.
--
-- **Why this pane exists at all.** Before it, the window could name a look but never show one, so
-- "loading" one meant handing it to the dressing room's model — the only preview surface there was.
-- That coupling is gone with the pane (see the file comment next door).
--
-- **The body is loaded once, at build.** `Model:Unit` is an async re-skin; doing it per selection
-- would restart the load on every click for a body that never changes (always the logged-in
-- character). Selecting only writes the per-slot overrides, which `Model` re-applies across any
-- re-skin of its own accord.

-- The column starts a few px below the filter strip beside it.
local PANE_TOP = 3
-- …and ends level with the footer's Import button, so the verb row and Import share a line. The
-- left column runs strip + gap + list + gap + footer; the pane gives its own top offset back out of
-- its height so its BOTTOM still lands exactly there.
local PANEH = STRIPH + GAP + LISTH + GAP + STRIPH - PANE_TOP
-- The model is inset from the pane's top rather than sitting flush against it.
local MODEL_TOP = 10
-- Everything under the model (name, provenance, the rename field and the verb row, with their gaps)
-- costs a fixed 86px; the model takes whatever is left. Running the column down to the footer line
-- is what buys it the extra height — at the old height the character's head clipped against the
-- model frame's top edge, and a taller frame is the only thing that fixes that.
local MODELH = PANEH - 86 - MODEL_TOP
-- What everything below the model hangs from, so the inset is only applied once.
local MODEL_BOTTOM = MODEL_TOP + MODELH
local BTNW = 80          -- three verbs across RIGHTW with the gaps
local CONFIRM_S = 4      -- seconds an armed button stays armed before reverting, as the room uses
local NO_SELECTION = "Select a look to preview it."

---@class OutfitLibraryWindow
---@field _preview Model  the 3D preview of the selected look
---@field _previewName Label  the selected look's name, class-coloured
---@field _previewOrigin Label  its provenance, or the muted "nothing selected" prompt
---@field _renameBox EditBox  the new name Rename applies
---@field _armed Frame?  the verb awaiting its confirming second click
---@field _armedLabel string?  that verb's resting caption, to restore when it disarms
---@field _armTimer table?  the 1s ticker that counts the armed caption down and reverts it

---Build the right column. Anchored off the filter strip so the two columns share a top edge, and
---sized to the strip + list beneath it so the pane bottoms out level with the list.
---@param strip Frame
function OutfitLibraryWindow:_buildPreview(strip)
  local pane = Frame:new{
    parent = self,
    position = { TopLeft = {strip, ui.edge.TopRight, GAP, -PANE_TOP},
                 Width = RIGHTW, Height = PANEH },
  }

  self._preview = Model:new{
    parent = pane, position = { TopLeft = {0, -MODEL_TOP}, Width = RIGHTW, Height = MODELH },
  }
  -- **Normalisation, set BEFORE the re-skin.** Without it the model renders at raw size and a tall
  -- silhouette — a hat, high shoulders — overruns the frame's top edge; no amount of nudging the
  -- frame fixes that, because the content is what doesn't fit. The room sets the same strength for
  -- the same reason, and the ordering matters for the reason it documents: `Model:Unit` arms the
  -- re-apply machinery right then, and a synchronous load (the viewer's own race, already in
  -- memory) re-applies immediately, so the strength has to already be correct.
  self._preview:Aggressiveness(ns.NORMALIZE_AGGRESSIVENESS)
  self._preview:Scale(1)
  -- The viewer's own character, once. Nothing here previews another race: this window is about
  -- finding a saved look, and a race selector is the dressing room's job.
  self._preview:Unit("player")

  self._previewName = Label:new{
    parent = pane, justifyH = ui.justify.Left, wordWrap = false,
    position = { TopLeft = {2, -(MODEL_BOTTOM + 6)}, Width = RIGHTW - 4 },
  }
  self._previewOrigin = Label:new{
    parent = pane, justifyH = ui.justify.Left, wordWrap = false, color = "muted",
    position = { TopLeft = {2, -(MODEL_BOTTOM + 22)}, Width = RIGHTW - 4 },
  }

  local box = Frame:new{
    parent = pane,
    position = { TopLeft = {0, -(MODEL_BOTTOM + 40)}, Width = RIGHTW, Height = STRIPH },
  }
  selBox(box)
  self._renameBox = EditBox:new{ parent = box, position = { TopLeft = {6, -1}, BottomRight = {-4, 1} } }
  self._renameBox._widget:SetScript("OnEscapePressed", function(f) f:ClearFocus() end)
  self._renameBox._widget:SetScript("OnEnterPressed", function() self:RenameSelected() end)

  local verbs = Frame:new{
    parent = pane,
    position = { TopLeft = {0, -(MODEL_BOTTOM + 40 + STRIPH + GAP)}, Width = RIGHTW, Height = STRIPH },
  }
  self._renameBtn = self:_paneButton(verbs, 0, BTNW, "Rename", function() self:RenameSelected() end)
  self._deleteBtn = self:_paneButton(verbs, BTNW + GAP, BTNW, "Delete", function() self:DeleteSelected() end)
  self._pushBtn   = self:_paneButton(verbs, 2 * (BTNW + GAP), BTNW, "Push", function() self:PushSelected() end)
end

---Arm a verb: its second click inside CONFIRM_S commits. The same arm-then-confirm the outfit row
---uses, so a destructive click is never a single one — including its countdown caption and its
---lapse notice (#698), because a silent revert here made a late second click indistinguishable from
---a first one exactly as it did there.
---
---**Gold border and relabelled caption, both (#716).** This used to swap only the caption, so the
---pane carried one of the two signals the room carries for the same mechanic — and one of them
---the `CONTEXT.md` row describes as part of it. `_paneButton` keeps the border for this.
---
---**The lapse notice names the look.** `Sure? 4` fills the button, so the name has to go to chat;
---and with the workspace docked (#713) this pane and the outfit row hold their armed state
---independently, so both can be armed at once and two anonymous lapse lines would be identical.
---@param btn Frame
---@param caption string  the armed caption; the seconds left are appended to it
---@param lapsed string  past participle for the lapse notice ("deleted", "replaced")
---@param subject string  the look the lapse notice names
function OutfitLibraryWindow:_arm(btn, caption, lapsed, subject)
  self:_disarm()
  self._armed, self._armedLabel = btn, btn.label:Text()
  btn.border:Color(SELECTED)
  local left = CONFIRM_S
  local function paint() btn.label:Text(("%s %d"):format(caption, left)) end
  paint()
  self._armTimer = C_Timer.NewTicker(1, function()
    left = left - 1
    if left > 0 then return paint() end
    self._armTimer = nil
    self:_disarm()
    ns.Print(("Confirmation expired — \"%s\" was not %s."):format(subject, lapsed))
  end, CONFIRM_S)
end

---Revert whatever is armed, stopping its countdown. Safe to call when nothing is.
function OutfitLibraryWindow:_disarm()
  if self._armTimer then self._armTimer:Cancel(); self._armTimer = nil end
  if self._armed then
    self._armed.label:Text(self._armedLabel)
    self._armed.border:Color(IDLE)
    self._armed, self._armedLabel = nil, nil
  end
end

---Show `name` on the model and describe it beside. nil clears back to the empty state — which is
---also what a deleted or vanished selection lands on.
---@param name string?
function OutfitLibraryWindow:_showPreview(name)
  self:_disarm()
  local entry = name and ns.LibraryOutfit(name)
  if not entry then
    -- An empty list bares the model rather than leaving the last look on a cleared selection.
    ns.DressModelFromList(self._preview, ns.EmptyOutfitList())
    self._previewName:Text("")
    self._previewOrigin:Text(NO_SELECTION)
    self._renameBox:Text("")
    return
  end

  local list, err = ns.LibraryOutfitList(name)
  if not list then
    -- A hand-edited SavedVariables file must not dress the model from half an outfit, so the
    -- decoder's complaint is shown instead of a partial look.
    ns.DressModelFromList(self._preview, ns.EmptyOutfitList())
    self._previewName:Text(ns.ClassColored(name, entry.class))
    self._previewOrigin:Text("Couldn't read this look: " .. err)
    self._renameBox:Text(name)
    return
  end

  ns.DressModelFromList(self._preview, list)
  self._previewName:Text(ns.ClassColored(name, entry.class))
  local origin = ns.OutfitOrigin(entry)
  local forClass = entry.forClass and ns.ClassLabel(entry.forClass)
  if forClass then
    forClass = ("a %s look"):format(forClass)
    origin = origin ~= "" and (origin .. "   ·   " .. forClass) or forClass
  end
  self._previewOrigin:Text(origin ~= "" and origin or "")
  -- Seeded with the current name so Rename edits it rather than starting from blank.
  self._renameBox:Text(name)
end

---Rename the selected look to whatever is in the pane's name field.
function OutfitLibraryWindow:RenameSelected()
  self:_disarm()
  if not self._selected then
    ns.Print("Pick a look to rename.")
    return
  end
  local newName = (self._renameBox:Text() or ""):match("^%s*(.-)%s*$")
  local ok, err = ns.RenameLibraryOutfit(self._selected, newName)
  if not ok then
    ns.Print("Couldn't rename: " .. err)
    return
  end
  ns.Print(("Renamed to \"%s\"."):format(newName))
  -- Follow the look through the rename rather than dropping the selection: the pane is still
  -- showing it, so a cleared selection would contradict what is on screen. The rename's own
  -- notification refreshed both surfaces already; this second one is for the selection move, which
  -- no store change can describe (#727).
  self._selected = newName
  self:Refresh()
end

---Delete the selected look. Arms first — the second click inside CONFIRM_S commits.
function OutfitLibraryWindow:DeleteSelected()
  local armed = self._armed == self._deleteBtn
  self:_disarm()
  if not self._selected then
    ns.Print("Pick a look to delete.")
    return
  end
  if not armed then
    self:_arm(self._deleteBtn, "Sure?", "deleted", self._selected)
    return
  end
  -- Named before the delete, not after: the store's change notification refreshes this window from
  -- inside the call below, and that refresh is what clears the selection it can no longer find
  -- (#727) — so there is no refresh of our own to make here either.
  local name = self._selected
  ns.DeleteLibraryOutfit(name)
  ns.Print(("Deleted \"%s\"."):format(name))
end

---Copy the selected look into THIS character's transmog sets, so it can be worn at a
---transmogrifier — the bridge from our account-wide store to the game's per-character one, and the
---only place Blizzard's name filter and 25-set cap apply.
function OutfitLibraryWindow:PushSelected()
  local armed = self._armed == self._pushBtn
  self:_disarm()
  if not self._selected then
    ns.Print("Pick a look to push.")
    return
  end
  local list, err = ns.LibraryOutfitList(self._selected)
  if not list then
    ns.Print("Couldn't read that look: " .. err)
    return
  end
  local existing
  for _, s in ipairs(ns.CustomSets()) do if s.name == self._selected then existing = s.id end end
  if existing and not armed then
    -- Named in chat rather than on the button, exactly as the room's Push does.
    ns.Print(("\"%s\" is already one of this character's sets — click Push again to replace it.")
      :format(self._selected))
    self:_arm(self._pushBtn, "Sure?", "replaced", self._selected)
    return
  end
  local id, saveErr = ns.SaveCustomSet(self._selected, list, existing)
  if not id then
    ns.Print("Couldn't push: " .. saveErr)
    return
  end
  ns.Print(("Pushed \"%s\" to this character's transmog sets."):format(self._selected))
end
