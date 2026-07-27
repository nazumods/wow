---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Frame = ui.Frame
-- No `ns.DressingRoom._k.selBox` reach any more: `ns.RowButton` owns the framed box, so this file
-- no longer depends on the dressing room at all (#770 step 6).

-- **Two buttons on the game's own transmogrifier** (#699) — this addon's only presence on a
-- Blizzard frame. The transmogrifier is where looks actually get built, yet until now one staged
-- there could only reach the account-wide library by being rebuilt by hand in our dressing room.
--
-- **The frame is `TransmogFrame`, not `WardrobeTransmogFrame`.** Retail 12.x replaced the NPC UI
-- wholesale: `Blizzard_Wardrobe` is now only the Appearances journal, and the transmogrifier lives
-- in the load-on-demand `Blizzard_Transmog` as `TransmogFrame` (mixin `TransmogFrameMixin`). So
-- nothing here may touch the frame at file-load time — it does not exist yet.
--
-- Setup hangs off `PLAYER_INTERACTION_MANAGER_FRAME_SHOW` rather than `ADDON_LOADED`: the
-- interaction manager is what loads `Blizzard_Transmog` in the first place, so by the time that
-- event fires the frame is guaranteed to exist and no load-order guessing is needed.
-- `TRANSMOGRIFY_OPEN` is deliberately unused — on retail it is a Classic-only event and never fires.

local SAVE_POPUP    = "WARBANDEER_COLLECTED_SAVE_LOOK"
local REPLACE_POPUP = "WARBANDEER_COLLECTED_REPLACE_LOOK"
-- Sized to the captions rather than to a round number; "Outfit Library" is the longer of the two.
local BTNW, BTNH = 104, 22
-- **The two buttons FLANK Blizzard's slot icons rather than sitting under them.** The weapon slots
-- of `CharacterPreview.BottomSlots` occupy the middle of this band, so a tightly-paired row centred
-- beneath them read as crowding their furniture. This gap is wide enough to leave that cluster its
-- own clear column between the two buttons, which is why it is a centre gap and not a margin.
local CENTER_GAP = 170
-- `BottomSlots` is anchored at BOTTOM y=48, so the free band is the 48px beneath it. Within that
-- band this sits level with the **Link** button off to the left — which is NOT Blizzard's (nothing
-- in `Blizzard_Transmog` creates one, so it belongs to another addon) and therefore cannot be
-- anchored to without depending on a frame that won't exist for everyone. The alignment is a
-- measured offset instead, so this is the one number to nudge if the two ever drift apart.
local BOTTOM_Y = 16

---One labelled button: framed box, centred caption, click target. The same idiom as the library
---window's strip buttons — a peer class can't reach the room's `_rowButton`.
---@param parent Frame
---@param x number
---@param label string
---@param onClick fun()
local function rowButton(parent, x, label, onClick)
  -- `opaque` because these alone sit on BLIZZARD's frame, where there is nothing behind them: a bare
  -- border and a caption would read as text floating over the transmogrifier rather than as buttons.
  -- The two sibling surfaces sit on our own opaque windows and need no fill (#770 step 6).
  return ns.RowButton{ parent = parent, x = x, w = BTNW, label = label,
    onClick = onClick, height = BTNH, opaque = true }.box
end

---The dialog's edit box. Retail has moved this between a plain field and an accessor across
---revisions, so both are tried rather than betting on one.
---@param dialog table
---@return table?
local function editBoxOf(dialog)
  return dialog.editBox or (dialog.GetEditBox and dialog:GetEditBox()) or nil
end

---The look currently ON the transmogrifier's model: the applied transmog plus whatever is staged
---and not yet applied. That is precisely "what I can see", which is what Save should capture.
---
---Returns nil until the model scene's player actor exists, so every caller guards — a frame being
---open does not mean its actor is ready.
---@return table[]?
local function stagedLook()
  local preview = TransmogFrame and TransmogFrame.CharacterPreview
  return preview and preview:GetItemTransmogInfoList() or nil
end

---The look on the model right now, checked over and ready to store — or nil, having already said
---why not.
---
---**Read once, when the user commits a name, and carried from there (#757).** The replace confirm
---below is a StaticPopup: those are not modal, and this one has `timeout = 0`, so it can sit
---unanswered while the user wanders back to the wardrobe and stages something else. Re-reading the
---model at accept time meant Yes stored whatever was on it *then*, under the name it had asked
---about — and the library is the only copy of a saved look, so there was nothing to recover from.
---Same rule #729 gave the dressing room's armed verbs: a confirm acts on the look it asked about.
---
---The checks live here rather than at the write so an unsaveable look never reaches the prompt:
---being asked to replace something and only then told there was nothing to save reads as a bug.
---@return table[]?
local function captureLook()
  local list = stagedLook()
  if not list then
    ns.Print("The transmogrifier isn't ready yet — try again in a moment.")
    return
  end
  local issues = ns.OutfitIssues(list)
  if issues.filled == 0 then
    ns.Print("Nothing to save — there are no appearances on the model.")
    return
  end
  -- Item data still streaming means the look can't be read completely yet, and saving now would
  -- store a quietly incomplete one. The room waits this out on a retry timer; here it is rarer
  -- (the pieces are equipped or staged, so mostly already cached) and a re-click is cheap.
  if issues.pending then
    ns.Print("Item data is still loading — try again in a moment.")
    return
  end
  return list
end

---Write a captured look into both stores under `name`.
---
---The two-store rule itself — library primary, game custom set best-effort — is
---`ns.SaveLookToBoth` (outfitsave.lua), where it is unit-tested. This only supplies the look and
---the provenance, and reports whatever came back. It never reads the model: the list is whatever
---`captureLook` handed its caller, which is the whole point of #757.
---@param name string
---@param list table[]
local function saveLook(name, list)
  ns.Print(ns.SaveLookToBoth(name, list, ns.LocalOutfitMeta(list)).message)
end

-- The name AND the look awaiting a replace answer. A file-local because a StaticPopup's OnAccept
-- is a bare callback with no closure over the click that armed it.
local pendingLook

---Validate a typed name and either save under it or ask before replacing.
---@param name string
local function commitName(name)
  name = (name or ""):match("^%s*(.-)%s*$")
  if name == "" then
    ns.Print("Give the look a name to save it.")
    return
  end
  local list = captureLook()
  if not list then return end
  -- Never replace silently. A name already in the library is the NORMAL case here rather than the
  -- odd one — the library is account-wide and spans every character, so "TWW 1" saved on an alt is
  -- exactly what a second alt is about to type (the same collision #663 met importing).
  -- The library's own spelling, not what was typed (#728): the match is case-insensitive, so the
  -- popup has to name the entry actually at risk — asking "replace boylane 3?" about a look listed
  -- as "Boylane 3" describes something the user can't find.
  local existing = ns.LibraryOutfit(name)
  if existing then
    pendingLook = { name = existing.name, list = list }
    StaticPopup_Show(REPLACE_POPUP, existing.name)
    return
  end
  saveLook(name, list)
end

-- A popup rather than a name field parked on Blizzard's frame: there is no band there that wouldn't
-- collide with the transmogrifier's own furniture, and naming is a once-per-save answer rather than
-- something you sit and edit.
StaticPopupDialogs[SAVE_POPUP] = {
  text = "Name this look",
  button1 = SAVE, button2 = CANCEL,
  hasEditBox = 1, maxLetters = 64,
  timeout = 0, whileDead = 1, hideOnEscape = 1, exclusive = 1,
  OnShow = function(self)
    local box = editBoxOf(self)
    if box then box:SetText(""); box:SetFocus() end
  end,
  OnAccept = function(self)
    local box = editBoxOf(self)
    commitName(box and box:GetText() or "")
  end,
  EditBoxOnEnterPressed = function(self)
    local dialog = self:GetParent()
    commitName(self:GetText() or "")
    if dialog and dialog.Hide then dialog:Hide() end
  end,
  EditBoxOnEscapePressed = function(self)
    local dialog = self:GetParent()
    if dialog and dialog.Hide then dialog:Hide() end
  end,
}

StaticPopupDialogs[REPLACE_POPUP] = {
  text = "\"%s\" is already in your library. Replace it?",
  button1 = YES, button2 = NO,
  timeout = 0, whileDead = 1, hideOnEscape = 1, showAlert = 1,
  -- The captured look, not the model — see `captureLook` (#757).
  OnAccept = function()
    if pendingLook then saveLook(pendingLook.name, pendingLook.list) end
    pendingLook = nil
  end,
  OnCancel = function() pendingLook = nil end,
}

-- Built once, on the first transmogrifier visit of the session, and kept — it is parented to the
-- Blizzard frame, so it shows and hides along with it without any help from us.
local _row

local function build()
  if _row then return end
  local preview = TransmogFrame and TransmogFrame.CharacterPreview
  if not preview then return end

  _row = Frame:new{
    parent = preview,
    position = { Bottom = {0, BOTTOM_Y}, Width = 2 * BTNW + CENTER_GAP, Height = BTNH },
  }
  -- Above the model scene, which fills CharacterPreview — and above `CharacterPreview.SavedFrame`,
  -- a hidden full-width overlay that flashes its glow across this band during the save animation.
  _row._widget:SetFrameLevel(preview:GetFrameLevel() + 20)

  rowButton(_row, 0, "Save Look", function() StaticPopup_Show(SAVE_POPUP) end)
  rowButton(_row, BTNW + CENTER_GAP, "Outfit Library", function() ns.OpenOutfitLibrary() end)
end

ns:registerEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(_, kind)
  if kind ~= Enum.PlayerInteractionType.Transmogrifier then return end
  build()
end)
