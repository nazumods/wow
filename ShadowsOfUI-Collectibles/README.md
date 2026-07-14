# ShadowsOfUI-Collectibles

Tints the icons of items you **already know** — and items you can **still collect** — on the
merchant window and the Auction House browse list. See at a glance whether a recipe, toy, mount,
pet, transmog appearance or housing decoration is worth buying, without hovering every single item.

## What it marks

For every item on those frames:

- **Already known** → tinted your chosen colour (blue by default). Covers profession recipes,
  toys, mounts, battle pets (including caged pets in the AH), housing decor, and a handful of
  hand-tracked quest blueprints and bundles. (Transmog/cosmetic appearances are not marked.)
- **Still collectible** → tinted **green** (a collectible you don't have yet). Turn this off if
  you only want the "already known" marking.
- **Everything else** → left alone.

### Recipes are checked across your whole warband

Unlike a plain "do *I* know this" check, profession **recipes** are marked known if **any of your
characters** has already learned them — using the data collected by **Warbandeer_Characters**. So a
pattern your alt bank-crafter already knows shows as known even while you're on a different
character. (A character's recipes are only counted once you've opened that profession's window on
them at least once. If Warbandeer isn't installed, recipes fall back to a current-character check.)

Everything else (toys, mounts, pets, decor) is account-wide in the game already, so it's marked
from your live collection regardless of which character you're on.

## Settings

Open the game's **Settings → AddOns → Shadows of UI → Collectible Tints** panel:

- **Known-item tint** — at the top of the panel, a **controls column** on the left uses the **◄ ►**
  arrows to cycle through the tints — Blue / Cyan / Orange / Gold / Purple / Pink / Gray (bold, legible
  tints; wrapping around at the ends). For any other colour, use `/scollect custom`. A **live preview**
  on the right pairs three sample vendor items (common / rare / epic) — an untinted control beside its
  tinted result — so you can see the effect on real item icons, with sliders (in the controls column)
  to preview muting the icon and text.
- **Desaturate known** — also grey out the icons of already-known items.
- **Mark collectible** — tint still-collectible items green (on by default).
- **Vendor / Auction House** — turn the tint on or off per frame.
- **Changelog** — a button that opens this addon's release history (newest first) in a scrollable, copyable window.

The guild bank isn't supported yet — its UI was reworked in 12.0; support will return once the
new frame is handled.

## Commands

- `/scollect` — print the current settings.
- `/scollect custom` — open a colour picker for a custom known-item tint.
- `/scollect itemtest` — (dev aid) print whether the item under your cursor reads as known /
  collectible.

## Dependencies

- **LibNAddOn**
- **Warbandeer_Characters** *(optional)* — enables the cross-alt recipe check. Without it, recipes
  are checked against the current character only; all other collectibles work regardless.
- **ShadowsOfUI-HousingVendor** *(optional)* — when installed, decor owned-state is read from it
  rather than recomputed, so decor tints and the vendor overlay stay consistent.

## Saved data

`ShadowsOfUI_CollectiblesDB` stores your tint colour and per-frame toggles. Nothing else.
