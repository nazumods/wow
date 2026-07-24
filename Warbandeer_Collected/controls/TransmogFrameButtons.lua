---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Frame, Label, Button = ui.Frame, ui.Label, ui.Button
-- The room's framed-box helper rather than a third copy of it; controls/OutfitLibraryWindow.lua
-- reaches for the same one for the same reason.
local selBox = ns.DressingRoom._k.selBox

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
local BTNW, BTNH, GAP = 132, 22, 6
-- Clear of `CharacterPreview.BottomSlots`, which Blizzard anchors at BOTTOM y=48; below it the band
-- down to the frame's edge holds no interactive child of theirs.
local BOTTOM_Y = 14

---One labelled button: framed box, centred caption, click target. The same idiom as the library
---window's strip buttons — a peer class can't reach the room's `_rowButton`.
---@param parent Frame
---@param x number
---@param label string
---@param onClick fun()
local function rowButton(parent, x, label, onClick)
  local box = Frame:new{ parent = parent, position = { TopLeft = {x, 0}, Width = BTNW, Height = BTNH } }
  selBox(box)
  Label:new{ parent = box, justifyH = ui.justify.Center, wordWrap = false,
    position = { Left = {2, 0}, Right = {-2, 0} }, text = label }
  Button:new{ parent = box, position = { All = true }, glow = false, OnClick = onClick }
  return box
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

---Write the staged look into both stores under `name`.
---
---The two-store rule itself — library primary, game custom set best-effort — is
---`ns.SaveLookToBoth` (outfitsave.lua), where it is unit-tested. This only supplies the look and
---the provenance, and reports whatever came back.
---@param name string
local function saveStaged(name)
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
  ns.Print(ns.SaveLookToBoth(name, list, ns.LocalOutfitMeta(list)).message)
end

-- The name awaiting a replace answer. A file-local because a StaticPopup's OnAccept is a bare
-- callback with no closure over the click that armed it.
local pendingName

---Validate a typed name and either save under it or ask before replacing.
---@param name string
local function commitName(name)
  name = (name or ""):match("^%s*(.-)%s*$")
  if name == "" then
    ns.Print("Give the look a name to save it.")
    return
  end
  -- Never replace silently. A name already in the library is the NORMAL case here rather than the
  -- odd one — the library is account-wide and spans every character, so "TWW 1" saved on an alt is
  -- exactly what a second alt is about to type (the same collision #663 met importing).
  if ns.LibraryOutfit(name) then
    pendingName = name
    StaticPopup_Show(REPLACE_POPUP, name)
    return
  end
  saveStaged(name)
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
  OnAccept = function() if pendingName then saveStaged(pendingName) end; pendingName = nil end,
  OnCancel = function() pendingName = nil end,
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
    position = { Bottom = {0, BOTTOM_Y}, Width = 2 * BTNW + GAP, Height = BTNH },
  }
  -- Above the model scene, which fills CharacterPreview — and above `CharacterPreview.SavedFrame`,
  -- a hidden full-width overlay that flashes its glow across this band during the save animation.
  _row._widget:SetFrameLevel(preview:GetFrameLevel() + 20)

  rowButton(_row, 0, "Save Look", function() StaticPopup_Show(SAVE_POPUP) end)
  rowButton(_row, BTNW + GAP, "Outfit Library", function() ns.OpenOutfitLibrary() end)
end

ns:registerEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(_, kind)
  if kind ~= Enum.PlayerInteractionType.Transmogrifier then return end
  build()
end)
