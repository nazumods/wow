# ShadowsOfUI-PostOffice — CONTEXT

**Deps:** LibNAddOn, LibNUI · **Commands:** `/spost` · **DB:** `ShadowsOfUI_PostOfficeDB` (v3) · **UI lib:** LibNUI (copy window only)

Headless mailbox helper (no window of its own). Re-derives Postal modules in LibNAddOn
style — augments the native mail frames + exposes Settings-panel toggles. Phase 1 (Rake,
TradeBlock, Wire, Express) is pure logic; Phase 2 (Forward, CarbonCopy) injects buttons
onto the open-letter frames. LibNUI is pulled in solely for CarbonCopy's shared copy
window (the Delves precedent). Ongoing port is scoped in the Postal fork's
`docs/postoffice-port.md`; **re-derive, never copy Postal verbatim** (ARR license +
Ace3→LibNAddOn mismatch).

## Files

| File | Purpose |
|---|---|
| `core.lua` | `LibNAddOn` init, `Defaults`/`MigrateDB`, the mailbox lifecycle + `OnOpenMailUpdate` dispatch (see below), settings-change routing, `RegisterSettings` (7 toggles), `ns.PlainCoins` helper, changelog button, `/spost`. |
| `rake.lua` | Snapshot `GetMoney()` on mail open, print the gain (`GetCoinTextureString`) on close. Report-only; does not auto-loot. |
| `tradeBlock.lua` | `ns:SetTemporaryCVar("BlockTrades", 1)` on open, `RestoreCVar` on close; reacts to a live toggle while `ns._atMailbox`. |
| `wire.lua` | Installs an `onValueChangedFunc` on `SendMailMoney` (lazily, first open) to fill a blank `SendMailSubjectEditBox` with `ns.PlainCoins`; only overwrites its own prior value. |
| `express.lua` | Modifier-click shortcuts (lazy install, first open): replaces `InboxFrame_OnClick` for ctrl-click-return, posthooks `HandleModifiedItemClick` for alt-click-attach (+ optional auto-send), posthooks `InboxFrameItem_OnEnter` + `ns:OnItemTooltip` for hint lines. `db.express` / `db.expressAutoSend`. |
| `forward.lua` | "Forward" button on `OpenMailFrame` (beside Reply). Switches to Send Mail, sets `FW:` subject + body, then shuttles attachments letter→bag→outgoing one at a time via an event-driven state machine (`TakeInboxItem` → `BAG_UPDATE_DELAYED` → `locate` by `itemID`+count; merged stacks are isolated through an empty bag slot: `SplitContainerItem` → `CURSOR_CHANGED` → park → `BAG_UPDATE_DELAYED` → pick up whole → `ClickSendMailItemButton`). Stackable-safe. Disabled on money/COD/insufficient bag space. `db.forward`. |
| `carbonCopy.lua` | Small grow-on-hover button on `OpenMailScrollFrame` that copies the letter's sender/subject/body (+ auction invoice breakdown) into `ns.ui.ShowCopyWindow`. `db.carbonCopy`. |
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

## Settings-change routing

`ns.OnSettingChanged(key, fn)` registers a reaction; `ns:settingChanged(key, value)`
(the LibNAddOn default settings callback) dispatches to it. Used by TradeBlock to
un-block immediately when disabled at the mailbox.

## DB (`ShadowsOfUI_PostOfficeDB`, v3)

Flat feature flags: `rake`, `tradeBlock`, `wire`, `express`, `forward`, `carbonCopy`
(all default `true`) and `expressAutoSend` (default `false`). `MigrateDB` adds missing
keys non-destructively (v2 added `express*`; v3 added `forward` + `carbonCopy`).

## Gotchas

- **`SendMailMoney` is load-on-demand.** It only exists after `Blizzard_MailFrame`
  loads (first mailbox open), so Wire installs its hook lazily inside `OnMailShow`,
  guarded by a `wired` flag and a `SendMailMoney` presence check. Blizzard leaves
  `SendMailMoney.onValueChangedFunc` unset, so we own it.
- **Coin strings are plain text** (`ns.PlainCoins`), not `GetCoinTextureString` — mail
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
  them — a deliberate improvement over the reference.)
- **A split stack can't be attached straight from the cursor.** `SplitContainerItem` is
  async — the bag still shows the old count in the same frame — and a split held on the
  cursor never fires `BAG_UPDATE_DELAYED`; `ClickSendMailItemButton` on that cursor
  silently no-ops. `CURSOR_CHANGED` is the real "split landed on the cursor" signal.
  Hence the isolate dance: split → `CURSOR_CHANGED` → park in an empty bag slot →
  `BAG_UPDATE_DELAYED` (verified non-empty) → pick the stack up whole → attach. Also:
  emptying a letter flips the mailbox back to the Inbox tab, so re-assert the Send
  Mail tab (`MailFrameTab_OnClick(nil, 2)`) before every deposit.

## Express notes

- **Shift-click loot is left to native** (`InboxFrame_OnModifiedClick` → `AutoLootMailItem`
  on the MAILAUTOLOOTTOGGLE modifier); we only add ctrl-return + alt-attach.
- **Ctrl-return replaces `InboxFrame_OnClick`** (not a posthook) so it can suppress the
  open; mail frames aren't protected, so this is taint-safe. The wrapper falls through to
  the original for non-ctrl clicks and when `db.express` is off.
- **Not ported from Postal:** the ctrl-click "bulk-attach similar items" pass (multi-pass
  quality/subtype matching + soulbound tooltip scan) — omitted as low-clarity for v1.
