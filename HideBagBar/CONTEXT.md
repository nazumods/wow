# HideBagBar

**Deps:** none (raw WoW API) · **SavedVars:** none · **Category:** Shadows of UI

Hides Blizzard's bag bar buttons on load. No LibNAddOn, no DB, no LibNUI.

## Files

| File | Purpose |
|---|---|
| `addon.lua` | On `ADDON_LOADED` (self), looks each frame in `FRAME_NAMES` up in `_G` and calls `SetShown(false)` on the ones that exist: the backpack button, bag-bar expand toggle, the four bag slots, the reagent bag slot, and the Forever key ring. |
| `spec/addon_spec.lua` | busted: the original seven frames hidden, a missing frame does not stop the later ones, `KeyRingButton` hidden when present, another addon's `ADDON_LOADED` ignored. |

Frames hidden: `MainMenuBarBackpackButton`, `BagBarExpandToggle`, `CharacterBag0Slot`–`CharacterBag3Slot`, `CharacterReagentBag0Slot`, `KeyRingButton`.

## Gotchas

- Frames are looked up by NAME in `_G`, never listed as values: a nil in a literal `ipairs` list ends the loop there and leaves every later frame shown. `KeyRingButton` is nil on Retail.
- Hiding `KeyRingButton` is an assumption (roshne to confirm), recorded in the README.
