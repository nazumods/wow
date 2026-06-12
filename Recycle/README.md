# Recycle

**Vendor trash, handled.** Recycle automatically sells your grey (Poor quality) items
every time you open a merchant — plus any other items you've marked for sale.

## Marking items

Hold the modifier key (**Ctrl** by default) and **right-click** an item in your bags to
mark it. Marked items show a coin overlay in your bags and are sold at the next
merchant visit. Mark the same item again to unmark it.

Marks apply to the item, not the stack — every copy of a marked item is sold. Items
with no vendor price are never sold.

## Commands

| Command | What it does |
|---|---|
| `/recycle` | Show status |
| `/recycle clear` | Unmark everything |
| `/recycle key CTRL\|SHIFT\|ALT` | Change the marking modifier key |

## Settings

Found in the Blizzard settings panel:

- **Sell Grey Items** — auto-sell Poor quality items (on by default).
- **Silent** — suppress the gold summary printed after selling.
- **Modifier Key** — Ctrl / Shift / Alt for the mark gesture.

## Integration

If **Baganator** is installed, marked items are registered as a junk plugin so they're
highlighted in Baganator too.

## Requirements

**LibNAddOn** and **LibNUI**.

## Saved data

`RecycleDB` (per-character): your marked items and settings.
