# ShadowsOfUI-Known

Adds a **"Learnable by:"** line to recipe item tooltips, telling you at a glance which of
your characters could still learn that recipe.

Hover any recipe, pattern, plans, schematic, formula, technique or design — in your bags,
at a vendor, in the Auction House, in chat links — and the tooltip gains a short list of
your alts that:

- **have the matching profession**, and
- **haven't learned the recipe yet**.

A character whose profession skill is too low to learn it right now is shown in **red**.
Characters who already know the recipe are left off the list — and if *every* character
who has the profession already knows it, the tooltip simply reads **"Already known"** so
you can see at a glance the recipe isn't needed.

The list is ordered with your designated **main crafter** first, then **secondaries**,
then everyone else, each group sorted by character level and then profession skill. (The
main/secondary designation comes from Warbandeer — see Requirements.) One character shows
on a single line; several become a short header + list, capped so the tooltip stays small:
at most five names, or four names plus "and N more." beyond that.

`/sknown <itemID>` prints the same list to chat for a given recipe item — a debugging aid;
you won't normally need it.

## Requirements

- **LibNAddOn**
- **Warbandeer_Characters** — provides the per-character profession and learned-recipe
  data this addon reads.
- **Warbandeer** *(optional)* — supplies the main/secondary crafter designation. Without
  it, the list still works but is ordered purely by level and skill.

## Notes

- A character's recipes are only known to the addon after you've **opened that profession's
  window** on them at least once (that's when Warbandeer_Characters records what they know).
  Until then they may appear as able to learn a recipe they actually already have.
- There is no window, no settings, and no saved data of its own.
