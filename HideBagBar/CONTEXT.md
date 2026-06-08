# HideBagBar

**Deps:** none (raw WoW API) · **SavedVars:** none · **Category:** Shadows of UI

Hides Blizzard's bag bar buttons on load. No LibNAddOn, no DB, no LibNUI.

## Files

| File | Purpose |
|---|---|
| `addon.lua` | On `ADDON_LOADED` (self), `SetShown(false)` on the backpack button, bag-bar expand toggle, the four bag slots, and the reagent bag slot. |

Frames hidden: `MainMenuBarBackpackButton`, `BagBarExpandToggle`, `CharacterBag0Slot`–`CharacterBag3Slot`, `CharacterReagentBag0Slot`.
