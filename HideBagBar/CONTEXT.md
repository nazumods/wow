# HideBagBar

**Deps:** none (raw WoW API) · **SavedVars:** none · **Category:** Shadows of UI · **Clients:** Retail + Forever

Hides Blizzard's bag bar buttons on load. No LibNAddOn, no DB, no LibNUI.

## Files

| File | Purpose |
|---|---|
| `addon.lua` | On `ADDON_LOADED` (self), looks each frame in `FRAME_NAMES` up in `_G` and calls `SetShown(false)` on the ones that exist: the backpack button, bag-bar expand toggle, the four bag slots, and the reagent bag slot. |
| `spec/addon_spec.lua` | busted: every listed frame hidden, a missing frame does not stop the later ones, `KeyRingButton` left shown when present, another addon's `ADDON_LOADED` ignored. |

Frames hidden: `MainMenuBarBackpackButton`, `BagBarExpandToggle`, `CharacterBag0Slot`–`CharacterBag3Slot`, `CharacterReagentBag0Slot`.

## Gotchas

- Frames are looked up by NAME in `_G`, never listed as values: a nil in a literal `ipairs` list ends the loop there and leaves every later frame shown. A frame a client lacks is simply skipped.
- Forever's bag bar adds `KeyRingButton` (`Blizzard_MainMenuBarBagButtons/Camelot`). It is deliberately NOT hidden: roshne's choice, 2026-10-15 ("the key ring is left visible on Forever"). It is nil on Retail.
