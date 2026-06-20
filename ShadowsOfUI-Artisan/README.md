# ShadowsOfUI-Artisan

Adds a small **currency badge** to each profession on the spellbook's **Professions** page,
showing how much of that profession's **expansion crafting currency** (the "Artisan's … Moxie"
family) the current character holds — right where you look at your professions, without opening
the crafting window.

Open your spellbook (default **P**) and switch to the **Professions** tab. Each profession —
the crafting ones *and* the gathering ones (Herbalism, Mining, Skinning), since every
profession has its own Moxie — gains a little icon + amount. Only the secondary slots (Cooking,
Fishing, Archaeology) have no such currency, so they show nothing.

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
