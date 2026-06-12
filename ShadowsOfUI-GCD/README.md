# ShadowsOfUI-GCD

A **slim global-cooldown sweep bar** that sits flush between your primary and secondary
resource bars. When you cast, the bar fills and drains over the global cooldown, then
hides — a clean visual metronome for your rotation without watching action button
sweeps.

- Anchors itself to fill the gap between the primary and secondary resource bars
  (falls back to a fixed bottom-center position if those aren't available).
- Uses the base 1.5 s GCD as its duration.
- No settings, no commands, no saved data.

## Requirements

**LibNAddOn** and **LibNUI**.
