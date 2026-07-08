# Post Office

Small, headless mailbox helper — a few quality-of-life tweaks that augment WoW's
native mail window. No extra window of its own; everything is a toggle in the
Blizzard **Settings** panel.

Part of the **Shadows of UI** family. Requires **LibNAddOn**.

## Features

Each is independently toggleable (all on by default):

| Feature | What it does |
|---|---|
| **Report coin collected** | Prints the coin you looted each time you close the mailbox. |
| **Block trades at the mailbox** | Declines incoming trade requests while the mailbox is open, then restores your trade setting when you close it. |
| **Auto-subject for coin** | When you enter a coin amount to send, fills a blank Send-Mail subject with that amount (e.g. `12g 30s`). Never overwrites a subject you typed yourself. |
| **Modifier-click shortcuts** | **Ctrl-click** an inbox letter to return it to sender; **Alt-click** a bag item to attach it to the letter you're writing. (Optional: alt-click also *sends* the letter — off by default.) |
| **Forward button** | Adds a **Forward** button to an open letter — re-sends its text and item attachments (stackables included) to another player. Disabled for letters with money/COD, or when your bags are too full to hold the attachments. |
| **Copy-mail button** | Adds a small button to an open letter that copies its text — and, for auction invoices, the sale/purchase breakdown — into a selectable window you can Ctrl-C. |
| **Recipient menu + autocomplete** | Adds a menu beside the **To:** field — recently mailed, your warband alts (class-coloured), friends, and guild mates — and auto-completes names from those lists as you type. Replaces Blizzard's autocomplete popup. |
| **Quick-attach buttons** | Adds a column of trade-goods category buttons beside the Send Mail frame. Click one (Cloth, Herb, Ore, …) to attach **every stack of that type** from your bags to the letter — handy for mailing mats to an alt. Skips soulbound items. |
| **Inbox return/delete icons** | Shows a small icon on each inbox letter — click it to **return** the letter to its sender, or **delete** it (whichever it would do on expiry). Deletions that would lose items or coin ask for confirmation first. |
| **Inbox select checkboxes** | Adds a checkbox to each inbox letter plus **Open** and **Return** buttons. Tick the letters you want, then batch-open them (takes all attachments and coin) or return them all. **Shift-click** a checkbox to select a range; **Ctrl-click** to select every letter from the same sender. Skips CoD letters. |

## Commands

| Command | Effect |
|---|---|
| `/spost` | Open the Post Office settings. |

## Settings

Found under **Settings → AddOns → Shadows of UI → Post Office** (or `/spost`). One
checkbox per feature, plus a **Changelog** button.

## Saved data

`ShadowsOfUI_PostOfficeDB` — your feature toggles and the recently-mailed name list
(up to 15 names). Nothing else is stored.

## Dependencies

- **LibNAddOn** (required)
- **LibNUI** (required — used for the copy-mail window)
- **Warbandeer** (optional — with its Characters module installed, the recipient menu
  and autocomplete include all your warband alts)
