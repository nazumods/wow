# ShadowsOfUI-Known

Adds profession recipe-knowledge lines to tooltips, telling you at a glance which of your
characters can learn — or already know — a recipe.

## Learnable by

Adds a **"Learnable by:"** line to recipe item tooltips, telling you at a glance which of
your characters could still learn that recipe.

Hover any recipe, pattern, plans, schematic, formula, technique or design — in your bags,
at a vendor, in the Auction House, in chat links — and the tooltip gains a short list of
your alts that:

- **have the matching profession**, and
- **haven't learned the recipe yet**.

A character whose profession skill is too low to learn it right now is shown in **red**.
Characters who already know the recipe aren't listed here — instead they appear on a
separate **"Known by:"** line just below (see below), so you can see at a glance who can
already craft it and who still needs to learn it.

The list is ordered with your designated **main crafter** first, then **secondaries**,
then everyone else, each group sorted by character level and then profession skill. (The
main/secondary designation comes from Warbandeer — see Requirements.) One character shows
on a single line; several become a short header + list, capped so the tooltip stays small:
at most five names, or four names plus "and N more." beyond that.

## Known by

Hover a recipe and the tooltip gains a **"Known by:"** line naming the characters that
already know it (class-coloured, main crafter first, capped at five like the Learnable
list). It shows in two places:

- **On the recipe item itself** — in your bags, at a vendor, in the Auction House or a chat
  link — alongside the "Learnable by:" line, matched by recipe name.
- **On the Place Crafting Order browse list** — matched on the *exact* recipe, so it's not
  thrown off by similarly named items. Here, if **none** of your characters know it, the line
  instead reads **"Not Known: \<Profession\>"** in red (e.g. "Not Known: Jewelcrafting") — so
  you can tell at a glance whether you can craft it yourself, and which profession you'd need.

`/sknown <itemID>` prints the Learnable list to chat for a given recipe item, and `/sknown
knownby <recipeID>` prints the Known-by list for a recipe — debugging aids; you won't
normally need them.

## Changelog

A **Changelog** button in this addon's settings (Options → AddOns → Shadows of UI → Recipe Learners) opens its release history in a scrollable, copyable window.

## Dependencies

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
