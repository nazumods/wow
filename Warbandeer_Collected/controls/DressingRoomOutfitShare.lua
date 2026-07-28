---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Frame, Label, EditBox = ui.Frame, ui.Label, ui.EditBox
local DressingRoom = ns.DressingRoom
local k = DressingRoom._k
local selBox = k.selBox
local GRIDW, ROWH, ROW4 = k.GRIDW, k.ROWH, k.ROW4

-- The share row (#643): the fourth bottom control row, and both directions of outfit interchange.
-- Reopens the DressingRoom class. The hyperlink half lives in outfitshare.lua, the `/customset v1`
-- codec in outfitcodec.lua, and the compose/apply in controls/DressingRoomOutfit.lua.
--
--   [ paste a /customset string or link ] [ Export ] [ Post to Chat ] [ Import ]
--
-- A row of its own because the outfit row above is FULL — 568 of GRIDW's 572 — not because the
-- two are unrelated. The field is exactly as wide as that row's dropdown + name field, and the
-- three buttons span its four, so the columns line up and the pair reads as one block.
--
-- Everything here acts on the room's **current composed look**, never on a saved entry, so an
-- unsaved preview can be shared straight out of the window.
--
-- Deliberately no modal import prompt, for the reason the outfit row's own header records: an
-- inline field stays visible instead of appearing on demand, and one more `ui.EditBox` beats being
-- the suite's first `ui.Dialog` caller for a single string.

local FIELDW, BTNW, GAP = 296, 86, 6
-- What the field is for, shown over it while it's empty. A Label rather than seeded text: ghost
-- text in the box itself would be indistinguishable from a real paste on the way to the decoder.
local HINT = "Paste a /customset string or link"

-- Build the share row. Called by the constructor right after _buildOutfits, so it sits below the
-- outfit row and above the race panels.
---@param controls Frame  the bottom controls strip built by the constructor
function DressingRoom:_buildShare(controls)
  self._shareRow = Frame:new{
    parent = controls, position = { TopLeft = {0, -ROW4}, Width = GRIDW, Height = ROWH },
  }

  local box = Frame:new{
    parent = self._shareRow, position = { TopLeft = {0, 0}, Width = FIELDW, Height = ROWH },
  }
  selBox(box)
  -- Same inset as the outfit row's name field, so the two boxes' text sits on one left edge.
  self._shareField = EditBox:new{
    parent = box, position = { TopLeft = {6, -1}, BottomRight = {-4, 1} },
  }
  -- Parented to the EditBox, not its framing box, so the prompt sits on the same left edge the
  -- typed text will appear on rather than a hand-guessed approximation of the template's inset.
  self._shareHint = Label:new{
    parent = self._shareField, color = "muted", wordWrap = false,
    position = { Left = {6, 0}, Right = {-4, 0} }, text = HINT,
  }

  self._shareField._widget:SetScript("OnEscapePressed", function(f) f:ClearFocus() end)
  -- Enter imports, matching the name field above, where Enter commits the row's primary verb.
  self._shareField._widget:SetScript("OnEnterPressed", function(f)
    f:ClearFocus()
    self:ImportOutfit()
  end)
  self._shareField._widget:SetScript("OnTextChanged", function() self:_syncShare() end)

  -- Only Import is kept: it's the one that greys. Export and Post never need touching again.
  local row, bx = self._shareRow, FIELDW + GAP
  self:_rowButton(row, bx,              BTNW, "Export",       function() self:ExportOutfit() end)
  self:_rowButton(row, bx + BTNW + GAP, BTNW, "Post to Chat", function() self:PostOutfit() end)
  self._shareImport = self:_rowButton(row, bx + 2 * (BTNW + GAP), BTNW, "Import",
    function() self:ImportOutfit() end)

  self:_syncShare()
end

---The paste field's contents, trimmed. "" when empty.
---@return string
function DressingRoom:_pastedOutfit()
  return (self._shareField:Text() or ""):match("^%s*(.-)%s*$")
end

-- Show the prompt only over an empty field, and grey Import while there is nothing to import —
-- the same "don't offer what won't work" rule the outfit row's buttons follow. Export and Post
-- stay live: what they act on is the model, which is never empty for long, and both say so
-- themselves when it is.
function DressingRoom:_syncShare()
  local pasted = self:_pastedOutfit() ~= ""
  self._shareHint:SetShown(not pasted)
  self:_enableRow(self._shareImport, pasted)
end

---The look to put on the wire, plus how many slots it actually fills.
---
---Both share paths go through here so they can't diverge: what Export writes into the copy window
---and what Post turns into a link are the same list.
---
---**`filled` is measured BEFORE baring, and that ordering is load-bearing.** `ns.ShareableOutfit`
---writes a hide visual into every slot the preview renders bare (#666), so an *empty* preview
---would come back with eleven filled slots — silently disarming the "nothing to export" guard, and
---inflating the count printed to chat to include slots carrying nothing.
---
---The slots the user explicitly cycled to *empty* are handed over as the exception: that state
---means "no transmog — show the wearer's own gear" (#654), and it's the one thing baring must not
---override. `_hiddenSlots` is the room's, so translating it into that set is the room's job.
---@return table[]? list, number filled  nil when there is nothing worth sharing
function DressingRoom:_shareList()
  local list = self:ComposeOutfit()
  local issues = ns.OutfitIssues(list)
  if issues.filled == 0 then return nil, 0 end
  local keepEmpty
  for slotID, state in pairs(self._hiddenSlots) do
    if state == k.EMPTY then keepEmpty = keepEmpty or {}; keepEmpty[slotID] = true end
  end
  return ns.ShareableOutfit(list, keepEmpty, ns.HideVisual), issues.filled
end

---The composed look as a shareable `/customset v1` string, in a copy window alongside a per-slot
---listing so the string can be eyeballed against the model.
---
---The string is first so it's at the top of the pre-selected text. Shared with
---`/collected outfit export`, which calls straight into this.
function DressingRoom:ExportOutfit()
  local list, filled = self:_shareList()
  if not list then
    ns.Print("Nothing to export — the preview is empty.")
    return
  end

  -- The listing summarises the SHARED list, not the composed one, so what it names is what the
  -- recipient gets — the bared slots read as "Hidden Cloak" rather than being omitted, which is
  -- how the divergence went unnoticed in the first place.
  local body = { ns.EncodeOutfit(list), "", ns.OutfitSummary(list) }
  if ns.OutfitIssues(list).pending then
    body[#body + 1] = ""
    body[#body + 1] = "NOTE: some item data is still loading — re-run to re-check."
  end
  ui.ShowCopyWindow("Outfit export", table.concat(body, "\n"))
  ns.Print(("Exported %d slots."):format(filled))
end

---Put the composed look's chat hyperlink into the chat edit box, ready to send.
---
---Stops at the edit box deliberately — which channel it goes to, and whether it goes at all, is
---the user's call. `ns.PostOutfitToChat` carries the pre-flight that keeps the link generator from
---throwing into the chat frame.
function DressingRoom:PostOutfit()
  local list = self:_shareList()
  if not list then
    ns.Print("Nothing to post — the preview is empty.")
    return
  end
  local ok, err = ns.PostOutfitToChat(list)
  if not ok then
    ns.Print("Couldn't post that look: " .. err)
    return
  end
  ns.Print("Link ready in your chat box — pick a channel and send it.")
end

---Dress the room from a pasted `/customset` string or transmog link, switching it into outfit mode.
---
---`str` is for the command form; the button passes nothing and reads the row's field. Either way
---this is the only import path, so the two can't diverge.
---
---`title` exists for the one caller that knows whose look this is — `/collected outfit inspect`
---(#819) reads a targeted player's transmog and can title the room after them. Every other path has
---nothing better to say than the default.
---@param str string?
---@param title string?
function DressingRoom:ImportOutfit(str, title)
  local pasted = str or self:_pastedOutfit()
  local list, err = ns.ParseOutfitInput(pasted)
  if not list then
    ns.Print("Couldn't read that: " .. err)
    return
  end
  -- Named for what it is rather than left titled as whatever set was last previewed: an imported
  -- look has no name of its own until it's saved, and the title is what tells you the model is no
  -- longer showing the set you clicked.
  self:EnterOutfitMode(title or "Imported look", list)
  self._outfitSel = nil
  self._outfitName:Text("")
  self:RefreshOutfits()
  -- The field has done its job; clearing it restores the prompt and re-greys Import, so the row
  -- can't re-import the same string on a stray second click.
  self._shareField:Text("")
  self:_syncShare()
  ns.Print(("Imported %d slots into the preview."):format(ns.OutfitIssues(list).filled))
end
