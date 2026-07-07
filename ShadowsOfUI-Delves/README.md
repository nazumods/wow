# ShadowsOfUI-Delves

Shows **how long a delve usually takes you** right on its map pin, so you can pick a run
that fits the time you have.

The addon quietly times every delve you complete and keeps a personal rolling average. Then,
when you open the map and hover a delve's entrance pin, the tooltip gains a line:

> **Avg completion (T11):** 6:32  · 5 runs

The tier shown is the one you'd actually run — **Tier 11 once you're at max level**. Below
the level cap (where delve tiers don't apply) it falls back to an average across every tier
you've run, labelled *(all tiers)*. A delve you've entered but never finished, or one you
haven't run yet, simply reads *No timed runs yet*.

Hold **Shift** while hovering to hide the line.

## How the timing works

- A run is timed from the moment you enter the delve to its completion. Only **completed**
  runs count — bailing out or teleporting away records nothing.
- The average is a **rolling window of your most recent runs**, so it keeps up as your
  character gears up and gets faster.
- Timing survives a `/reload` mid-run (it's anchored to server time), so you won't lose a run
  you reload during.
- `/sdelves` prints the live delve state (a dev/diagnostic aid); `/sdelves dump` prints the
  recorded average for the delve you're currently in. (Your full per-character history is
  visible via Warbandeer_Characters' `/wbc dump delves`.)

## Changelog

A **Changelog** button in this addon's settings (Options → AddOns → Shadows of UI → Delves) opens its release history in a scrollable, copyable window.

## Requirements

- **LibNAddOn**
- **Warbandeer_Characters** — does the actual timing and stores the run history per character
  (so the data is shared with the rest of the Warbandeer suite); this addon only draws the
  tooltip line from it.

## Notes

- Run history is **per character** and **last-seen**: each character builds up its own
  averages as you play it. A brand-new setup starts empty and fills in as you run delves.
- There is no window and no saved data of its own — the timings live in
  `Warbandeer_Characters`' saved data.
