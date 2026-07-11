# ShadowsOfUI-HousingVendor

Tells you, **at a glance while shopping**, which housing decor you already own and which is worth buying — right on the vendor's item icons, without hovering.

Housing decor vendors sell a long grid of furniture, and the item tooltip already buries the useful bits — how many you own, and whether a piece grants a one-time **House XP bonus** the first time you collect it — one hover at a time. This addon surfaces both directly on the icon:

- **Storage count** — the number you have **in storage** (ready to place) is stamped on the bottom-left corner of every decor icon you already own. A greyed-out **0** means you own it but every copy is already placed.
- **First-acquisition star** — a gold **★** on the top-right corner marks decor that awards a **first-time House XP bonus** and that you **don't own yet**. That's the stuff worth grabbing for the bonus.
- **Owned check** *(off by default)* — a green check on the top-left for decor you already own, for anyone who turns the storage count off.

Everything else the vendor draws — price, affordability, Blizzard's own red/grey cues — is left untouched. Non-decor items are ignored entirely.

## Settings

Each indicator is an independent toggle in **Options → AddOns → Shadows of UI → Housing Vendor**:

| Setting | Default | Effect |
|---|---|---|
| Storage count | On | Stamp the in-storage owned count on decor you own |
| First-acquisition star | On | Gold star on unowned decor that grants a first-time House XP bonus |
| Owned check | Off | Green check on decor you already own |

## Commands

- `/shvendor` — print the current indicator settings.
- `/shvendor itemtest` — dump the resolved owned/stored/bonus values for the item currently under your cursor (a diagnostic aid you won't normally need).

## Changelog

A **Changelog** button in this addon's settings opens its release history in a scrollable, copyable window.

## Requirements

- **LibNAddOn**

## Notes

- Overlays appear on the **Merchant** window's Buy tab, on housing-decor items only.
- Ownership data comes from the game's housing catalog, which finishes loading a moment after you log in — the counts fill in on their own and refresh whenever your storage changes.
- No window and no saved data beyond the three indicator toggles.
