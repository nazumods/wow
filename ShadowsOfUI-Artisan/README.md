# ShadowsOfUI-Artisan

Adds a small **currency badge** to the **profession (crafting) window**, right beside Blizzard's
own Concentration readout, showing how much of that profession's **expansion crafting currency**
(the "Artisan's … Moxie" family) the current character holds — so you see your Moxie next to your
Concentration without digging into the currency tracker.

Open any profession's window and the badge sits at the top, just to the right of the
Concentration count, with the Moxie's own icon and amount. It follows whichever profession you
have open. Every profession has its own Moxie — the gathering ones (Herbalism, Mining, Skinning)
included.

The same badge also shows on the **Crafting Orders tab** of that window (top-left header), so
your Moxie stays visible while you browse and fill orders.

It also appears on the **spellbook's Professions page** (open the spellbook, **Professions**
tab): each profession there gets the same badge tucked beneath its spell-button labels, so you
can read every profession's Moxie at a glance.

**Hover the badge** for an account-wide breakdown: every character that has this profession,
class-coloured, with how much of the currency each one holds — your **main crafter** first,
then secondaries, then the rest. The character you're logged in on is marked **(here)** and
shows its live amount; alts show the amount last recorded when you played them.

`/sartisan [name]` prints the same breakdown to chat — a debugging aid; you won't normally
need it.

## Requirements

- **LibNAddOn**
- **Warbandeer_Characters** — records each character's profession list and currency amounts,
  so the hover breakdown can list your alts.
- **Warbandeer** *(optional)* — supplies the main/secondary crafter designation used to order
  the breakdown. Without it, the list is ordered by amount.

## Notes

- An alt's currency amount is only known to the addon after you've **played that character**
  since installing it (that's when its amount is recorded). Until then it shows **0**.
- The badge shows the **current expansion's** crafting currency only.
- There is no window, no settings, and no saved data of its own.
