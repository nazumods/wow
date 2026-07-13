# ShadowsOfUI-Delves

Shows **how long a delve usually takes you** — and, while you're leveling, **how much XP it's
worth** — right on its map pin, so you can pick a run that fits the time you have.

The addon quietly times every delve you complete and keeps a personal rolling average. Then,
when you open the map and hover a delve's entrance pin, the tooltip gains a line:

> **Avg completion (T11):** 6:32  · 5 runs

The tier shown is the one you'd actually run — **Tier 11 once you're at max level**. Below
the level cap (where delve tiers don't apply) it falls back to an average across every tier
you've run, labelled *(all tiers)*. A delve you've entered but never finished, or one you
haven't run yet, simply reads *No timed runs yet*.

**While leveling**, a second line shows the average XP that delve earns you — with, in brackets,
how much of your **current level** that is — and the resulting XP-per-hour, so you can judge
whether it's worth your time:

> **Avg XP:** 42,300 [12%]  · 745.0k XP/hr

The `[12%]` is the run's average XP as a share of your whole current level (start to next ding).
This line is **leveling-only** — it disappears at max level, where delves no longer grant XP.

Hold **Shift** while hovering to hide the lines.

## How the timing works

- A run is timed from the moment you enter the delve to its completion. Only **completed**
  runs count — bailing out or teleporting away records nothing.
- The average is a **rolling window of your most recent runs**, so it keeps up as your
  character gears up and gets faster.
- Timing survives a `/reload` mid-run (it's anchored to server time), so you won't lose a run
  you reload during.
- The average XP (and XP/hr) is a **rolling window** of your recent runs too, tracked the same
  way — so it reflects your current leveling pace, not a stale number.
- `/sdelves` shows the live delve state (a dev/diagnostic aid); `/sdelves dump` shows the
  recorded average time **and XP** for the delve you're currently in. Both open a **copyable
  window** so the output can be pasted. (Your full per-character history is visible via
  Warbandeer_Characters' `/wbc dump delves`.)

## Changelog

A **Changelog** button in this addon's settings (Options → AddOns → Shadows of UI → Delves) opens its release history in a scrollable, copyable window.

## Dependencies

- **LibNAddOn**
- **LibNUI** — provides the shared copyable window the `/sdelves` dev commands render into
- **Warbandeer_Characters** — does the actual timing and stores the run history per character
  (so the data is shared with the rest of the Warbandeer suite); this addon only draws the
  tooltip line from it.

## Notes

- Run history is **per character** and **last-seen**: each character builds up its own
  averages as you play it. A brand-new setup starts empty and fills in as you run delves.
- There is no window and no saved data of its own — the timings live in
  `Warbandeer_Characters`' saved data.
