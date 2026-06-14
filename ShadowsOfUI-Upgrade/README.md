# ShadowsOfUI-Upgrade

Finds **gear upgrades** for your whole warband and shows them where you make keep-or-sell
decisions: on item tooltips, and across Warbandeer's Summary, Gear and Detail views.

The point is to stop hoarding. Instead of holding onto ten intellect one-handers "just in
case", you can see at a glance which characters an item actually upgrades — and which copy
is the best — so everything else can be vendored.

## What counts as an upgrade

An item is an upgrade for a character when:

- the character can **equip** it (right armour type for their class, a weapon/shield they're
  proficient with — rings, necks, cloaks and trinkets are usable by everyone), **and**
- its **item level beats** what they currently have in that slot (for rings and trinkets,
  it's compared against the *weaker* of the two — the one you'd replace).

**Two-handers** are handled specially: if a character is wielding a two-hander their off-hand
isn't really empty, so a stray off-hand or one-hander on its own is **not** counted as an upgrade
for them. Only a **better two-hander**, or a **main-hand + off-hand pair** whose combined item
level beats the two-hander, is suggested (both halves are marked as part of the swap).

Item level is the gate, but gear carrying the **wrong primary stat** for the spec is skipped
first — an Intellect dagger is rogue-equippable but useless, so it's never offered as an upgrade.
On top of that, the item's secondary stats are checked against the character's spec stat priority
and tagged **good stats** (it carries a top-priority stat) or **off-stats**. The stat priorities
are a small built-in table (derived from current PvE secondary-stat weightings), so this addon is
**fully standalone** — no other addon is needed.

## Held vs. better elsewhere

- An upgrade sitting in a character's **own bags or personal bank** is **held** for them
  (green ▲).
- If the best upgrade for that slot is instead in the **warband bank**, it's flagged gold ▲
  and called out as *"better one in the warband bank"* — so you know to move it over.

## Where it shows up

- **Item tooltips** — hovering any equippable item adds an **"Upgrade for:"** line listing
  the characters it would upgrade, with the item-level gain and the stat tag. **Soulbound**
  items only list the character they're already bound to; **Binds-when-equipped** and
  **Warbound-until-equipped** items are checked against every character, since they can be
  moved.
- **Warbandeer** *(optional)* — when Warbandeer is installed:
  - the **Summary** view gains an **"Up"** column counting each character's available upgrades
    (hover for the list),
  - the **Gear** view marks each slot that has an upgrade with a ▲,
  - the **Detail** view marks each equipped item that can be upgraded, and its **Suggested**
    box lists active **world-quest** rewards that would upgrade a slot (the quest's gear, the
    item-level gain, and where to find it) alongside the ready upgrades — world quests are
    scanned while each character is logged in, so the suggestions persist when you view an alt.
    **Click a world-quest suggestion to open the map to it** (and start tracking the quest).

`/supgrade [name]` prints a character's available upgrades to chat (defaults to the
logged-in character) — a debugging aid; you won't normally need it.

## Requirements

- **LibNAddOn**
- **Warbandeer_Characters** — records the equipped gear, bag gear and warband-bank gear this
  addon reads. Open a character's bags, personal bank and the warband bank at least once so
  their loose gear is scanned.
- **Warbandeer** *(optional)* — for the Summary/Gear/Detail markers. The tooltip line works
  without it.

## Notes

- Bag, bank and warband-bank contents are a **last-seen** cache: a character's loose gear is
  only known after you've had that bank/those bags open on the relevant character.
- Item level is the only gate, so a genuine sidegrade (e.g. a higher-ilvl piece that breaks a
  tier-set bonus, or a duplicate unique-equipped item) can still show as an upgrade — use the
  stat tag and your judgement.
- The class weapon/armour proficiency table is a baseline approximation; a rare spec-only
  quirk may add or drop a single suggestion.
- There is no window, no settings, and no saved data of its own.
