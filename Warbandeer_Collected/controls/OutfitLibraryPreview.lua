---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Frame, Label, EditBox, Model = ui.Frame, ui.Label, ui.EditBox, ui.Model
local OutfitLibraryWindow = ns.OutfitLibraryWindow
local k = OutfitLibraryWindow._k
-- The armed border colours and the countdown budget went with the gesture, into chrome.lua.
local selBox = ns.SelBox
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
local NO_SELECTION = "Select a look to preview it."

---@class OutfitLibraryWindow
---@field _preview Model  the 3D preview of the selected look
---@field _previewName Label  the selected look's name, class-coloured
---@field _previewOrigin Label  its provenance, or the muted "nothing selected" prompt
---@field _renameBox EditBox  the new name Rename applies
---@field _armed Frame?  the verb awaiting its confirming second click
---@field _armedFor string?  the look that verb was armed about — an arm authorises acting on THAT one only
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
  -- The shared controller (#770 step 7). State stays on `self`, which is what lets this pane and the
  -- dressing room each hold an arm at once with the workspace docked (#713). The resting caption is
  -- read back from the button handle now, so `_armedLabel` is gone.
  ns.ArmConfirm(self, btn, caption, lapsed, subject)
end

---Revert whatever is armed, stopping its countdown. Safe to call when nothing is.
function OutfitLibraryWindow:_disarm()
  ns.Disarm(self)
end

---Enable or grey the three verbs that act on a selection. Built lazily like everything else in this
---pane, so this tolerates being called before `_buildPreview` has run.
---@param on boolean
function OutfitLibraryWindow:_enableVerbs(on)
  for _, btn in ipairs({ self._renameBtn, self._deleteBtn, self._pushBtn }) do
    ns.EnableRowButton(btn, on)
  end
end

---Show `name` on the model and describe it beside. nil clears back to the empty state — which is
---also what a deleted or vanished selection lands on.
---@param name string?
function OutfitLibraryWindow:_showPreview(name)
  self:_disarm()
  local entry = name and ns.LibraryOutfit(name)
  -- Grey the three verbs when there is nothing selected (#716, closed by #770 step 6). They used to
  -- stay lit and print a refusal *after* the click — "Pick a look to delete." — which the room has
  -- never done and which #716 half-fixed here, retro-fitting the armed border but never the disable.
  --
  -- The single choke point for it: every selection change reaches here, from `Select` and from the
  -- list's `Refresh` (which is also what clears a selection whose look has just been deleted). It
  -- sits after `_disarm` deliberately — a disabled button swallows clicks, so an armed one greyed
  -- out would keep counting down toward a confirmation it could no longer accept.
  self:_enableVerbs(entry ~= nil)
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
  local origin = ns.OutfitOriginFull(entry)   -- shared with the list row (#770 step 4)
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
  -- Bound to the look it was armed ABOUT (#770 step 7). Selection changes already disarm through
  -- `_showPreview`, so this is belt-and-braces here — but it is the same rule every surface follows.
  local armed = ns.ArmedFor(self, self._deleteBtn, self._selected)
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
  local armed = ns.ArmedFor(self, self._pushBtn, self._selected)   -- bound to its subject (#770 step 7)
  self:_disarm()
  if not self._selected then
    ns.Print("Pick a look to push.")
    return
  end
  -- Shared rule (#770 step 8) — this pane and the room's outfit row had byte-identical copies of the
  -- whole of Push, chat strings included. Only the arming and the printing are this surface's.
  local res = ns.PushLookToCharacter(self._selected, armed)
  ns.Print(res.message)
  if res.needsConfirm then
    self:_arm(self._pushBtn, "Sure?", "replaced", self._selected)
  end
end
