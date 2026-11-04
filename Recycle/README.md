# Recycle

**Vendor trash, handled.** Recycle automatically sells your grey (Poor quality) items
every time you open a merchant — plus any other items you've marked for sale.

## Marking items

Hold the modifier key (**Ctrl** by default) and **right-click** an item in your bags to
mark it. Marked items show a coin overlay in your bags and are sold at the next
merchant visit. Mark the same item again to unmark it.

Marks on gear (weapons and armor) apply to that *variant* of the item: its item ID, item
context and bonus IDs, as shown in the item link. A Normal and a Mythic copy of the same ring are
different variants, so marking one leaves the other alone — but two identical copies share one
mark, and both are sold. A gear mark is dropped automatically at the next merchant visit once no
copy of it is left in your bags (sold, destroyed, upgraded or banked), so a later identical drop
is not sold by an old mark; `/recycle clear` resets everything. Marks on anything else (trade
goods and the like) apply to the item, so every stack is sold, and marks made before this change
keep that meaning. If an item's link can't be read, it is not marked. Items with no vendor price
are never sold.

## Commands

| Command | What it does |
|---|---|
| `/recycle` | Open settings |
| `/recycle clear` | Unmark everything |
| `/recycle key CTRL\|SHIFT\|ALT` | Change the marking modifier key |

## Settings

Found in the Blizzard settings panel:

- **Sell Grey Items** — auto-sell Poor quality items (on by default).
- **Silent** — suppress the gold summary printed after selling.
- **Modifier Key** — Ctrl / Shift / Alt for the mark gesture.

## WoW: Forever

Loads on **WoW: Forever** (Interface 16001) as well as Retail.

## Dependencies

- **LibNAddOn**
- **LibNUI**
- **Baganator** *(optional)* — marked items are registered as a junk plugin, so they're
  highlighted in Baganator too.

## Saved data

`RecycleDB` (per-character): your marked items and settings.
