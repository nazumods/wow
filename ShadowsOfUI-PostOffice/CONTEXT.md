# ShadowsOfUI-PostOffice — CONTEXT

**Deps:** LibNAddOn, LibNUI · **OptionalDeps:** Warbandeer_Characters (alts menu) · **Commands:** `/spost` · **DB:** `ShadowsOfUI_PostOfficeDB` (v7) · **UI lib:** LibNUI (copy window only)

Headless mailbox helper (no window of its own). Re-derives Postal modules in LibNAddOn
style — augments the native mail frames + exposes Settings-panel toggles. Phase 1 (Rake,
TradeBlock, Wire, Express) is pure logic; Phase 2 (Forward, CarbonCopy) injects buttons
onto the open-letter frames; Phase 3 (BlackBook, QuickAttach) is the Send-Mail frame;
Phase 4 (DoNotWant, Select) is the inbox rows via a shared decorator. LibNUI is pulled in
solely for CarbonCopy's shared copy window (the Delves precedent). The port is complete;
scoped in the Postal fork's `docs/postoffice-port.md`; **re-derive, never copy Postal
verbatim** (ARR license + Ace3→LibNAddOn mismatch).

**Postal's OpenAll is intentionally NOT ported** — Blizzard now ships a native "Open All"
button (`OpenAllMailMixin`: `StartOpening`/`ShouldSkipCurrentMail`/…) that opens all mail
event-driven (via `C_Mail.SetOpeningAll` + `MAIL_INBOX_UPDATE`), skips GM/CoD mail, and
handles failed/bag-full items. Re-deriving it would reinvent a better-tested wheel for no
user gain, so we leave the native button in place. (Our Select gives per-letter batch
control on top; DoNotWant gives per-letter return/delete.)

## Files

| File | Purpose |
|---|---|
| `core.lua` | `LibNAddOn` init, `Defaults`/`MigrateDB`, the mailbox lifecycle + `OnOpenMailUpdate` + `OnInboxRow` dispatches (see below), `ns.RefreshInbox`, settings-change routing, `RegisterSettings` (11 toggles), changelog button, `/spost`. |
| `rake.lua` | Snapshot `GetMoney()` on mail open, print the gain (`GetCoinTextureString`) on close. Report-only; does not auto-loot. |
| `tradeBlock.lua` | `ns:SetTemporaryCVar("BlockTrades", 1)` on open, `RestoreCVar` on close; reacts to a live toggle while `ns._atMailbox`. |
| `wire.lua` | Installs an `onValueChangedFunc` on `SendMailMoney` (lazily, first open) to fill a blank `SendMailSubjectEditBox` with `ns.wow.CoinString`; only overwrites its own prior value. |
| `express.lua` | Modifier-click shortcuts (lazy install, first open): replaces `InboxFrame_OnClick` for ctrl-click-return, posthooks `HandleModifiedItemClick` for alt-click-attach (+ optional auto-send), posthooks `InboxFrameItem_OnEnter` + `ns:OnItemTooltip` for hint lines. `db.express` / `db.expressAutoSend`. |
| `forward.lua` | "Forward" button on `OpenMailFrame` (beside Reply). Switches to Send Mail, sets `FW:` subject + body, then shuttles attachments letter→bag→outgoing one at a time via an event-driven state machine (`TakeInboxItem` → `BAG_UPDATE_DELAYED` → `locate` by `itemID`+count; merged stacks are isolated through an empty bag slot: `SplitContainerItem` → `CURSOR_CHANGED` → park → `BAG_UPDATE_DELAYED` → pick up whole → `ClickSendMailItemButton`). Stackable-safe. Disabled on money/COD/insufficient bag space. `db.forward`. |
| `carbonCopy.lua` | Small grow-on-hover button on `OpenMailScrollFrame` that copies the letter's sender/subject/body (+ auction invoice breakdown) into `ns.ui.ShowCopyWindow`. `db.carbonCopy`. |
| `blackBook.lua` | Recipient picker + autocomplete on the "To:" field: arrow button beside `SendMailNameEditBox` → `MenuUtil` menu (recently mailed inline, then Alts / Friends / Guild submenus, `SetScrollMode` 400, class-coloured via `ns.Colors.className`); inline `OnChar` completion from the same lists; Blizzard's autocomplete popup suppressed while on. Recent capture: `SendMailFrame_SendMail` posthook → commit on `MAIL_SEND_SUCCESS` (+ `AddHistoryLine`). Alts via optional `WarbandeerApi:GetAllCharacters()`. `db.blackBook`, `db.blackBookRecent`. |
| `quickAttach.lua` | Column of ~12 trade-goods category buttons off the right edge of `MailFrame` (parented to `SendMailFrame`). Left-click bulk-attaches every matching stack from bags 0..reagent: `GetItemInfoInstant` class/subclass filter (`Enum.ItemClass.Tradegoods`, `sub == -1` = all), skip soulbound (`GetItemInfo` bindType == `Enum.ItemBind.OnAcquire`), whole-stack `PickupContainerItem` → `ClickSendMailItemButton(firstFreeSendSlot())` until the letter fills. Whole stacks are synchronous, so no split machinery. `db.quickAttach`. |
| `doNotWant.lua` | Per-row return/delete icon on each inbox letter (first consumer of `ns.OnInboxRow`). Icon parented to `MailItemNExpireTime` so it follows the row layout; texture/tooltip per `InboxItemCanDelete` (delete vs return). Click returns (`ReturnInboxItem`) or deletes (`DeleteInboxItem`) with confirm popups for item/coin loss, each carrying the letter it was opened for as its own StaticPopup payload (`{sig, index, money}`); the delete target is re-picked at accept time by `ns.ResolveDeleteIndex` (captured click-time index while it still holds the clicked letter, else a fingerprint scan — see gotcha). `db.doNotWant`. |
| `select.lua` | Checkbox per inbox row + Open/Return buttons on `InboxFrame`. **Owns the row re-layout** (indent rows / shrink width to make room for the checkboxes; DoNotWant's icon follows via the moved expire frame). Multi-select: plain / shift-range / ctrl-same-sender. Batch open/return is a throttled state machine (`_selectStep` on a raw-frame ticker, ~0.3s), processing selected indices **highest-first** so an emptied letter auto-deleting never shifts an index still queued; open takes attachments (highest slot first) then coin, skips CoD, stops on full bags. `db.select`. |
| `changelog.lua` | `ns.changelog` release history (release.sh appends). |

## Mailbox lifecycle (core.lua)

Retail drives the mail window via the player-interaction manager; the legacy
`MAIL_SHOW`/`MAIL_CLOSED` are not fired for the mailbox. So core registers
`PLAYER_INTERACTION_MANAGER_FRAME_SHOW`/`_HIDE` and filters to
`Enum.PlayerInteractionType.MailInfo`.

- `ns.OnMailShow(fn)` / `ns.OnMailHide(fn)` — feature subscription lists, called at
  file-load time (feature files load after core per the toc order).
- Each callback checks its own `ns.db.<flag>` so a settings toggle takes effect on
  the next visit without re-subscribing.
- `ns._atMailbox` (bool) — current state, used by live-toggle reactions.
- Defining `ns.EVENT_NAME` methods is not enough — core also calls
  `ns:registerEvent(...)` for both, since the listener only dispatches registered
  events.
- `ns.OnOpenMailUpdate(fn)` — open-letter refresh dispatch. Core posthooks Blizzard's
  `OpenMail_Update` once (lazily on first mailbox open, since it's load-on-demand) and
  fans out to subscribers. Forward + CarbonCopy use it to refresh their buttons whenever
  a letter is opened or an attachment is taken.
- `ns.OnInboxRow(fn)` — **shared inbox-row decorator.** Core posthooks `InboxFrame_Update`
  once (lazily) and calls each subscriber for all 7 visible rows with a `row` table
  (`i`, `index`, `present`, `item` = `MailItemN`, `expire` = `MailItemNExpireTime`).
  Features register ONE per-row callback instead of racing their own `InboxFrame_Update`
  hooks. Per-row widgets anchor to `row.item`/`row.expire` so they follow the active row
  layout; the row layout itself is owned by whichever feature changes it (Select).
  `ns.RefreshInbox()` re-runs `InboxFrame_Update` to apply a live toggle (no-op away from
  an open mailbox).

## Settings-change routing

`ns.OnSettingChanged(key, fn)` registers a reaction; `ns:settingChanged(key, value)`
(the LibNAddOn default settings callback) dispatches to it. Used by TradeBlock to
un-block immediately when disabled at the mailbox.

## DB (`ShadowsOfUI_PostOfficeDB`, v7)

Flat feature flags: `rake`, `tradeBlock`, `wire`, `express`, `forward`, `carbonCopy`,
`blackBook`, `quickAttach`, `doNotWant`, `select` (all default `true`) and `expressAutoSend`
(default `false`), plus `blackBookRecent` (recently-mailed names, newest first, cap 15 —
seeded explicitly in `MigrateDB`, kept out of `Defaults` so no instance aliases the shared
table). `MigrateDB` adds missing keys non-destructively (v2 added `express*`; v3 `forward`
+ `carbonCopy`; v4 `blackBook` + `blackBookRecent`; v5 `quickAttach`; v6 `doNotWant`;
v7 `select`).

## Gotchas

- **`SendMailMoney` is load-on-demand.** It only exists after `Blizzard_MailFrame`
  loads (first mailbox open), so Wire installs its hook lazily inside `OnMailShow`,
  guarded by a `wired` flag and a `SendMailMoney` presence check. Blizzard leaves
  `SendMailMoney.onValueChangedFunc` unset, so we own it.
- **Coin strings are plain text** (`ns.wow.CoinString`), not `GetCoinTextureString` — mail
  subjects and the copy window don't render texture escapes.
- **`BlockTrades` CVar** is set via `SetTemporaryCVar` (auto-restores on logout as a
  safety net if a close is missed).
- **`GetInboxText` returns `isInvoice` at position 5** (`bodyText, stationeryID1,
  stationeryID2, isTakeable, isInvoice`). Postal's CarbonCopy reads it from position 4 —
  a latent bug; our re-derivation reads 5.
- **Forward can't move attachments directly** letter→outgoing, so it shuttles via bags.
  It locates each taken item by `itemID`+count (not by which slot newly filled); a mail
  attachment never exceeds the item's max stack, so after taking there's always a slot
  with >= that count. (Postal disabled stackables here; this re-derivation supports
  them — a deliberate improvement over the reference.) All three bag scans run `0..LAST_BAG`
  (`= (NUM_BAG_SLOTS or 4)+1`, like QuickAttach) so reagents auto-routed into the reagent
  bag by `TakeInboxItem` are still found, not silently dropped.
- **Forward tears down on mailbox close.** The async shuttle registers `BAG_UPDATE_DELAYED`/
  `CURSOR_CHANGED`; `ns.OnMailHide(reset)` unregisters them and clears state (mirrors
  `select.lua`) so a later bag/cursor change can't deposit into a closed mail frame. An
  `active` flag guards re-entry — a second Forward click while a shuttle runs is ignored
  (the handler list has no dedup, so a re-register would double-fire).
- **A split stack can't be attached straight from the cursor.** `SplitContainerItem` is
  async — the bag still shows the old count in the same frame — and a split held on the
  cursor never fires `BAG_UPDATE_DELAYED`; `ClickSendMailItemButton` on that cursor
  silently no-ops. `CURSOR_CHANGED` is the real "split landed on the cursor" signal.
  Hence the isolate dance: split → `CURSOR_CHANGED` → park in an empty bag slot →
  `BAG_UPDATE_DELAYED` (verified non-empty) → pick the stack up whole → attach. Also:
  emptying a letter flips the mailbox back to the Inbox tab, so re-assert the Send
  Mail tab (`MailFrameTab_OnClick(nil, 2)`) before every deposit.
- **DoNotWant delete targets the captured index first, the fingerprint second.** A confirm
  dialog leaves the mailbox live, so the clicked letter can shift (arriving mail inserts at
  index 1 and bumps every index up). `ns.InboxFingerprint` (sender+subject+money+cod+itemCount,
  deliberately *omitting* the ticking daysLeft) is **not** unique — two "Auction expired"
  letters for the same item at different counts collide — so `ns.ResolveDeleteIndex` deletes
  the **captured click-time index** while its fingerprint still matches (exact even for twins)
  and only falls back to the first-match fingerprint scan once the index has shifted; when the
  letter is simply gone it deletes nothing. This restores the pre-#449 exactness that the
  fingerprint-only #449 fix regressed (#581). Pure logic, unit-tested in `spec/doNotWant_spec.lua`.
- **A confirm dialog must carry its letter, never module state.** The item and coin confirms are
  distinct `StaticPopupDialogs` entries, so they take separate popup frames and can sit open at
  once — a shared pending slot made whichever one was answered act on whatever was clicked *most
  recently*, irreversibly destroying the wrong letter (#732). Each `StaticPopup_Show` therefore
  passes the captured `{sig, index, money}` as the dialog's payload (4th arg), which Blizzard hands
  back to that dialog's own `OnAccept`/`OnShow`; `cancels` cross-links the pair on top of that so
  only one is ever on screen. Same rule for any future confirm here. Covered in
  `spec/doNotWant_spec.lua` by driving the registered dialogs' handlers over a fake inbox.

## BlackBook notes

- **Native autocomplete popup suppression:** `AutoComplete_Update` bails when the edit
  box has no `autoCompleteParams`, so nilling that field kills the (dead-Tab) popup;
  restore = `AutoCompleteEditBox_SetAutoCompleteSource(box, C_AutoComplete.GetAutoCompleteResults,
  AUTOCOMPLETE_LIST.MAIL.include, AUTOCOMPLETE_LIST.MAIL.exclude)`. Toggled live via
  `OnSettingChanged("blackBook")`.
- **Recent capture is two-step** — the name is read in a `SendMailFrame_SendMail`
  posthook (before Blizzard clears the box) but only committed on `MAIL_SEND_SUCCESS`,
  so failed sends never pollute the list. No raw hooks (Postal RawHooked
  `SendMailFrame_Reset` for this).
- **Alts come from the warband roster** (`WarbandeerApi:GetAllCharacters()` —
  `name`/`realm`/`classKey`), not Postal's manual login-tracking. The API global is
  created by LibNAddOn even when Warbandeer_Characters is absent, so guard on the
  *method* (`ns.api.GetAllCharacters`), not the table.
- **Guild roster names are realm-qualified** (`Name-Realm`); our own realm's suffix is
  stripped for plain-name mailing (spaces removed when comparing, matching WoW's
  qualified-name format).
- **Not ported from Postal:** manual contacts add/remove, the AutoFill-on-tab-open
  option, and the native-popup flag filtering (our lists replace it wholesale).

## QuickAttach notes

- **Whole stacks, synchronous** — attaches entire matching stacks (no partial split), so
  `PickupContainerItem` + `ClickSendMailItemButton(slot)` run straight in the click
  handler; none of Forward's async split/isolate dance is needed.
- **Class/subclass filter uses `GetItemInfoInstant`** (returns `classID`/`subClassID` at
  positions 6/7, never async); only the soulbound check needs `GetItemInfo` bindType
  (cached for bag items). Warbound (bindType 7/8) is left attachable — it still mails to
  your own alts.
- **Not ported from Postal:** per-category default recipient (right-click) and per-bag
  enable toggles — BlackBook already covers recipient selection, and scanning all bags
  (0..reagent) is the sensible default. Trimmed the button set to the common retail
  trade-goods categories.

## Select notes

- **Owns the inbox row layout.** `applyLayout(on)` toggles between Blizzard's values and
  the indented ones (MailItem1 at 29/-68 vs 28/-80, width 280 vs 305, expire frame nudged).
  DoNotWant re-uses the moved expire frame, so its icon follows for free — the whole point
  of the shared decorator. Layout is idempotent and reverts on toggle-off.
- **Batch state machine is idempotent by design.** Takes are async; the tick re-scans the
  highest occupied attachment each step, so a take that hasn't registered just re-targets
  the same (now-empty → no-op) slot next tick and self-corrects — no double-take harm.
  Highest-index-first means an emptied letter auto-deleting never shifts a queued index.
- **Deferred vs Postal (v1):** the front-insert re-index guard (Postal's `GetUniqueID`
  tracking for mail arriving at the *front* mid-batch — rare, small window), `DisableInbox`
  during processing (checkboxes hide + buttons disable instead), the KeepFreeSpace / verbose
  / stack-merge-when-full refinements, and the "too much mail" chat rerouting.

## Express notes

- **Shift-click loot is left to native** (`InboxFrame_OnModifiedClick` → `AutoLootMailItem`
  on the MAILAUTOLOOTTOGGLE modifier); we only add ctrl-return + alt-attach.
- **Ctrl-return replaces `InboxFrame_OnClick`** (not a posthook) so it can suppress the
  open; mail frames aren't protected, so this is taint-safe. The wrapper falls through to
  the original for non-ctrl clicks and when `db.express` is off.
- **Not ported from Postal:** the ctrl-click "bulk-attach similar items" pass (multi-pass
  quality/subtype matching + soulbound tooltip scan) — omitted as low-clarity for v1.
