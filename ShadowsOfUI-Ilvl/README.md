# ShadowsOfUI-Ilvl

Shows the **item level** of your gear right on its icon, plus a compact
**upgrade-track badge** (e.g. `C2` for Champion 2, `H6` for Hero 6) so you can
read at a glance how far an upgradeable piece has been crafted up.

- **Bags, bank, loot, guild bank** — the item level is drawn on top of the icon
  (top-right), with the track badge in the bottom-left corner.
- **Bagnon / Bagnonium** (if installed) — the same on-icon overlay is drawn on its
  bag, bank and guild-bank item buttons.
- **Baganator** (if installed) — adds an **Upgrade Track** corner widget (use
  Baganator's own Item Level widget for the ilvl).
- **Character & inspect panels** — by default the item level and track sit *next
  to* each slot, toward the inside of the panel, so the whole set reads as a tidy
  column you can scan top to bottom. You can switch either panel back to the
  on-icon overlay instead.
- Item level is colored by item quality; the track badge is gold.

The track letters are **A**dventurer, **V**eteran, **C**hampion, **H**ero and
**M**yth, followed by the current rank within that track.

## Settings

Options are under **Game Menu → Options → AddOns → Shadows of UI → Item Level**:

- A toggle for each place it can appear: bags, bank, loot, guild bank, Baganator
  (track widget), Bagnon, character pane, inspect pane.
- **Character: inset** / **Inspect: inset** — beside the icon (on) vs over the
  icon (off).
- **Minimum quality** — only tag gear of this quality or better (Poor, Common,
  Uncommon, Rare, Epic). Defaults to Uncommon.

Changes apply immediately to anything already on screen.

## Commands

- `/silvl <itemID or item link>` — prints an item's level, quality and track
  (a small developer/debug helper).

## Requirements

**LibNAddOn**. Baganator and Bagnon (or Bagnonium) are optional — their integrations
appear automatically when installed.

## Saved data

`ShadowsOfUI_IlvlDB` (account-wide), holding the settings above.
