# ShadowsOfUI-PostOffice — CONTEXT

**Deps:** LibNAddOn · **Commands:** `/spost` · **DB:** `ShadowsOfUI_PostOfficeDB` (v1) · **UI lib:** none (headless)

Headless mailbox helper. Re-derives the "pure logic" subset of Postal (Rake,
TradeBlock, Wire) in LibNAddOn style — no widgets, only native-mail augmentation +
Settings-panel toggles. Ongoing port is scoped in the Postal fork's
`docs/postoffice-port.md`; **re-derive, never copy Postal verbatim** (ARR license +
Ace3→LibNAddOn mismatch).

## Files

| File | Purpose |
|---|---|
| `core.lua` | `LibNAddOn` init, `Defaults`/`MigrateDB`, the mailbox lifecycle (see below), settings-change routing, `RegisterSettings` (3 toggles), changelog button, `/spost`. |
| `rake.lua` | Snapshot `GetMoney()` on mail open, print the gain (`GetCoinTextureString`) on close. Report-only; does not auto-loot. |
| `tradeBlock.lua` | `ns:SetTemporaryCVar("BlockTrades", 1)` on open, `RestoreCVar` on close; reacts to a live toggle while `ns._atMailbox`. |
| `wire.lua` | Installs an `onValueChangedFunc` on `SendMailMoney` (lazily, first open) to fill a blank `SendMailSubjectEditBox` with a plain-text coin string; only overwrites its own prior value. |
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

## Settings-change routing

`ns.OnSettingChanged(key, fn)` registers a reaction; `ns:settingChanged(key, value)`
(the LibNAddOn default settings callback) dispatches to it. Used by TradeBlock to
un-block immediately when disabled at the mailbox.

## DB (`ShadowsOfUI_PostOfficeDB`, v1)

Flat feature flags, all default `true`: `rake`, `tradeBlock`, `wire`. `MigrateDB`
adds missing keys non-destructively.

## Gotchas

- **`SendMailMoney` is load-on-demand.** It only exists after `Blizzard_MailFrame`
  loads (first mailbox open), so Wire installs its hook lazily inside `OnMailShow`,
  guarded by a `wired` flag and a `SendMailMoney` presence check. Blizzard leaves
  `SendMailMoney.onValueChangedFunc` unset, so we own it.
- **Coin string for subjects is plain text** (`coinSubject`), not
  `GetCoinTextureString` — mail subjects don't render texture escapes.
- **`BlockTrades` CVar** is set via `SetTemporaryCVar` (auto-restores on logout as a
  safety net if a close is missed).

## Not yet ported

Postal's `Express` (modifier-click loot/return/attach) is the remaining "pure logic"
module. Deferred: shift-click auto-loot is now native
(`InboxFrame_OnModifiedClick` → `AutoLootMailItem`), and adding ctrl-to-return means
replacing that handler rather than a clean posthook — needs in-game validation. See
the port design doc.
