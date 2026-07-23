---@type Warbandeer_Collected
local ns = select(2, ...)
local GetHyperlink = C_TransmogCollection.GetCustomSetHyperlinkFromItemTransmogInfoList
local GetListFromHyperlink = C_TransmogCollection.GetItemTransmogInfoListFromCustomSetHyperlink

-- Outfit interchange (#643): the game's **chat hyperlink** format, and the one door every pasted
-- outfit comes in through. The `/customset v1` string half is outfitcodec.lua (pure, so it's
-- unit-tested); this file is its WoW-side sibling, kept out of outfit.lua only for file size.
--
-- The two formats are equivalent in reach — a probe (issue #643, 2026-07-22) confirmed a link
-- generated from a **loaded, unowned** appearance round-trips losslessly, so a wishlist look
-- shares either way. They differ in ergonomics: the string pastes into the game's own
-- `/customset` and needs no addon at the other end, while the link is clickable and opens the
-- recipient's dress-up frame.
--
-- Both `C_TransmogCollection` calls are plain addon-callable functions (`SecretArguments =
-- "AllowedWhenUntainted"`, no secure-execution requirement), and Blizzard registers the receiving
-- side as `LinkUtil.RegisterLinkHandler(LinkTypes.TransmogCustomSet, …)` — so a link we emit
-- behaves exactly like one from the default UI.

---@class Warbandeer_Collected
---@field ShareableOutfit fun(list: table[], keepEmpty: table<number, true>?, hideFor: fun(slotID: number): number?): table[]
---@field OutfitHyperlink fun(list: table[]): string?, string?
---@field PostOutfitToChat fun(list: table[]): boolean, string?
---@field ParseOutfitInput fun(str: string): table[]?, string?

---Turn a composed look into the one that should go on the wire: every slot the preview renders
---**bare** gets that slot's hide visual instead of `0` (#666). Mutates and returns `list`, like
---`ns.SanitizeOutfit` — `ComposeOutfit` hands out a fresh list per call, so there's nothing shared
---to corrupt.
---
---**Why the shared artifact has to differ from the stored one.** `appearanceID = 0` means "no
---transmog on this slot", not "this slot is bare". `DressUpItemTransmogInfoList` dresses the actor
---as the *viewer's* character and only then applies the list slot by slot — it never undresses
---first — so a `0` leaves whatever the recipient is wearing. Our own `ApplyOutfit` clears every
---slot before applying, which is exactly why the same list looked right in Collected and wrong in
---Blizzard's frame. Blizzard's own links don't hit this because theirs come from
---`playerActor:GetItemTransmogInfoList()` and are **dense**; ours are sparse by construction, since
---the room previews a bare body plus the set's pieces.
---
---**`keepEmpty` is the one exception, and it matters.** #654 made *hidden* and *empty* two states
---the user picks between, and `empty` means precisely "no transmog — show the wearer's own gear".
---Baring those too would silently override a deliberate choice, so the caller passes the slots that
---asked for it. Everything else bare on screen — a slot the set doesn't fill, a cleared shirt, an
---imported look's `0` — is bare because nothing chose otherwise, and shares as bare.
---
---`hideFor` returns nil for a slot with no hide visual, which leaves it at `0`: **the two weapon
---slots have none** (nothing at `Enum.TransmogCollectionType` 12+ carries the flag), so a look with
---no main-hand still shows the viewer's weapon and nothing in the format can say otherwise.
---@param list table[]  as produced by ns.ComposeOutfit
---@param keepEmpty table<number, true>?  slots the user explicitly left untransmogged
---@param hideFor fun(slotID: number): number?  ns.HideVisual, injected so this stays testable
---@return table[]
function ns.ShareableOutfit(list, keepEmpty, hideFor)
  for _, slotID in ipairs(ns.OutfitSlotOrder) do
    local info = list[slotID]
    if info and (info.appearanceID or 0) == 0 and not (keepEmpty and keepEmpty[slotID]) then
      local hide = hideFor(slotID)
      if hide then info.appearanceID = hide end
    end
  end
  return list
end

---A chat hyperlink for an outfit, or nil and why not.
---
---**The generator is gated, never called speculatively.** It *throws* on some inputs — and throws
---rather than returning nil, despite being documented `MayReturnNothing = true` — so an unguarded
---call surfaces a Lua error in the user's chat frame. The measured failure had item data still
---streaming, which is exactly what `ns.OutfitIssues` reports as `pending`, so this is the same
---pre-flight the save path runs. (Ownership is *not* a constraint on either side; see the file
---header and `ns.OutfitIssues`.)
---@param list table[]
---@return string? link, string? err  exactly one is non-nil
function ns.OutfitHyperlink(list)
  local issues = ns.OutfitIssues(list)
  if issues.filled == 0 then return nil, "the preview is empty" end
  if issues.pending then return nil, "item data is still loading — try again in a moment" end
  -- Documented `MayReturnNothing`, so an empty return is a contract the caller has to handle,
  -- not an internal invariant we can assume away.
  local link = GetHyperlink(list)
  if not link then return nil, "the game wouldn't make a link for this look" end
  return link
end

---Put an outfit's hyperlink into the chat edit box, opening one if none is focused.
---
---`InsertLink` then `OpenChat` is Blizzard's own order in `DressUpModelFrameLinkButtonMixin:OnShow`
---— insert into whatever the user is already typing in, and only open a fresh line when there is
---nothing to insert into. Deliberately stops at the edit box: posting the message is the user's
---send to press, not ours.
---@param list table[]
---@return boolean ok, string? err
function ns.PostOutfitToChat(list)
  local link, err = ns.OutfitHyperlink(list)
  if not link then return false, err end
  if not ChatFrameUtil.InsertLink(link) then ChatFrameUtil.OpenChat(link) end
  return true
end

---Decode whatever the user pasted — a `/customset v1 …` command, a bare `v1 …` payload, or a
---chat hyperlink — into an outfit list.
---
---The single entry point for every import path (the row's field and `/collected outfit import`),
---so the two can't drift. Routing is `ns.OutfitInputKind`'s call; the link branch is the game's
---own decoder, since only it can read the format. Every refusal comes back as a message, matching
---the tone of the game's own `TRANSMOG_CUSTOM_SET_LINK_INVALID` — a malformed paste is a user
---mistake, not a Lua error.
---@param str string
---@return table[]? list, string? err  exactly one is non-nil
function ns.ParseOutfitInput(str)
  local kind = ns.OutfitInputKind(str)
  if kind == "link" then
    -- The whole `|H…|h[…]|h` string, which is what the game's own link handler passes in — with
    -- `||` folded back to `|` first, since a link typed or pasted into an edit box arrives with
    -- its pipes escaped, and the C decoder wants the unescaped form. A shift-click into the slash
    -- command delivers it unescaped already, so this is a no-op on that path.
    local link = str:gsub("^%s+", ""):gsub("%s+$", ""):gsub("||", "|")
    local list = GetListFromHyperlink(link)
    if not list then return nil, "that transmog link couldn't be read" end
    return list
  end
  if kind == "v1" then return ns.DecodeOutfit(str) end
  return nil, "that isn't a /customset string or a transmog link"
end
