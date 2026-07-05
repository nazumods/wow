# Tooling

Reusable development tooling for the suite. **Not an addon** — nothing here is
shipped, listed in a `.toc`, or picked up by the release pipeline (`release.sh`
skips folders without a `.toc`, and `Tooling` is on its `NON_ADDON_DIRS` list).

Check this directory **before writing a new one-off script** — the job may
already be solved here. When a scratchpad script proves reusable, promote it
into this directory with a docstring and an entry in the table below.

| Script | Purpose |
|---|---|
| `make_addon_logo.py` | **Canonical addon-logo generator.** Reuses the `Warbandeer_Collected` photo flag: inpaints out its word and re-sets the given text in the measured house typography (Old English Text MT 230, condensed to 740px, +2 stroke, pale halo, flow-curve warp). Only the text varies — every logo comes out in the identical style. `python Tooling/make_addon_logo.py Inventory --out <addon>/logo.png` |
| `procedural_flag_logo.py` | Superseded reference: draws the whole flag scene procedurally in PIL (no photo base). Kept for the sampled palette/geometry constants. |

## Logo generation notes

- `make_addon_logo.py` produces the **green-flag style of the Warbandeer
  family** (Warbandeer, Characters, Collected, Bars, Alias, WarbandInventory).
  The **ShadowsOfUI family uses a different style** — purple crescent moon +
  cherry blossoms on black with white serif text (see `ShadowsOfUI-XP/logo.png`)
  — for which no generator exists; those originals live with nazumods.

- Requires `pillow`, `numpy`, `opencv-python-headless`, and the Windows font
  **Old English Text MT** (`C:/Windows/Fonts/OLDENGL.TTF`).
- Output is a 1024×1024 PNG, same as the sibling logos
  (`Warbandeer*/logo.png`).
- The run is deterministic: same text + same library versions → byte-identical
  output (verified against the shipped ShadowsOfUI-WarbandInventory logo).
- Style constants were **measured from the original logos** (tall-letter
  height 166px, ~24px stems, word width ~688px, halo ≈ rgb(175,205,120)) —
  don't tweak them ad hoc or the family stops matching.
