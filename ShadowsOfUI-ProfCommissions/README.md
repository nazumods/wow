# ShadowsOfUI-ProfCommissions

Shows **what a crafting order actually rewards** — right in the order list, without hovering.

On the profession **Crafting Orders** browse list, **Patron** (NPC) orders pay a gold commission
*and* hand out bonus items or currency on top. Blizzard hides those behind a single generic
**treasure-chest icon** in the Commission column — you have to hover each order, one at a time, to
find out what's inside.

This addon **removes that chest** and draws the **actual reward icons** in its place, right next to
the commission amount. A glance down the Commission column now tells you which orders reward the
thing you want. Each icon still **shows the full item or currency tooltip on hover**, and item
rewards get a **quality-coloured border** so rare/epic rewards stand out. Stacked rewards show their
count.

Nothing else changes — the commission gold, sorting, and every other column stay exactly as
Blizzard draws them.

## The "Info" column

It also **replaces** the stock **Reagents** column (the "Some / None / All" text) with an **Info**
column of two at-a-glance status icons:

- **First-craft bonus** — a book icon appears when crafting that order's recipe would still earn
  you the **first-craft bonus** (i.e. you haven't crafted it before). If you **haven't learned** the
  recipe, a red ⊗ shows instead — the bonus isn't claimable until you learn it.
- **Reagents** — who supplies the materials: a green **check** when the customer provides *all*
  reagents, or a **warning** when *you'll* be providing some (yellow) or all (red) of them.

Hover the column for a short explanation of each. It sits in the same spot as the old Reagents
column and still **sorts by reagent state** when you click the header — you just get the reagent
info as a glanceable icon, plus the first-craft flag the default UI doesn't surface in the list at
all.

`/sprofcomm` prints whether the hook is active and the current icon size; `/sprofcomm size <n>`
retunes the icon size live (applies on the next list refresh). Both are tuning/debug aids you won't
normally need.

## Changelog

A **Changelog** button in this addon's settings (Options → AddOns → Shadows of UI → Prof Commissions) opens its release history in a scrollable, copyable window.

## Requirements

- **LibNAddOn**

## Notes

- Only **Patron** orders carry rewards, so the icons appear on that tab; Public/Guild/Personal
  orders that have no reward simply show the commission on its own (no chest, as before).
- Reward icons render **in place of** the chest, in the Commission column — reward 1 leftmost,
  next to the money.
- There is no window, no settings, and no saved data of its own.
