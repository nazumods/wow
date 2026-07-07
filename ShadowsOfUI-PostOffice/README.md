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

## Commands

| Command | Effect |
|---|---|
| `/spost` | Open the Post Office settings. |

## Settings

Found under **Settings → AddOns → Shadows of UI → Post Office** (or `/spost`). One
checkbox per feature, plus a **Changelog** button.

## Saved data

`ShadowsOfUI_PostOfficeDB` — your feature toggles. Nothing account- or character-
sensitive is stored.

## Dependencies

- **LibNAddOn** (required)
