# ShadowsOfUI-WarbandInventory

Adds a **"Warband Inventory"** block to item tooltips, telling you at a glance how many of an
item your whole account is holding — and where.

Hover any item — in your bags, at a vendor, in the Auction House, in a chat link — and the
tooltip gains a short breakdown:

- one **class-coloured line per character** that has any, with a `(Bags: N, Bank: N, Mail: N)`
  source breakdown (only the places they actually hold it). Characters on a **different realm**
  get their realm name appended, e.g. `Kurorin (Norgannon)`,
- the shared **warband (account) bank**,
- each **guild bank** you can see,
- and a **Total owned** grand total on the bottom line.

Characters are listed most-first, capped so the tooltip stays small: up to sixteen names,
then a `+N more — /swinv <itemID> for the full list` hint pointing at the slash command below.

**Hold Shift to hide the block** — handy when you want the plain tooltip (or are comparing
gear, which Shift already does).

`/swinv <itemID or item link>` prints the same breakdown to chat for a given item — both a
debugging aid and a quick "where is my…?" lookup you can run without finding the item first.

## Requirements

- **LibNAddOn**
- **Warbandeer_Characters** — provides the per-character bag/bank item counts this addon
  reads. (No extra scanning is added here; it surfaces data Warbandeer_Characters already
  collects.)
- **Warbandeer** *(optional)* — not required; listed only so load order is sensible when
  it's installed.

## Notes

- Counts are **last-seen**. A character's bag counts update only while that character is
  logged in; bank and guild-bank counts update when you **open that bank**. So a freshly
  installed setup shows little until you've logged your alts in and opened their banks once.
- The warband bank is **account-wide**, so it's counted once (not per character).
- There is no window and no saved data of its own — it reads Warbandeer_Characters' cache.
