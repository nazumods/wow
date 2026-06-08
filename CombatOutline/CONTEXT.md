# CombatOutline

**Deps:** LibNAddOn · **SavedVars:** `CombatOutlineDB` (unused) · **Commands:** none

Toggles the `OutlineEngineMode` CVar on while in combat and off when leaving it, driven by the regen events.

## Files

| File | Purpose |
|---|---|
| `core.lua` | Whole addon. Table-form `LibNAddOn` init; `PLAYER_REGEN_DISABLED` sets `OutlineEngineMode` to 1, `PLAYER_REGEN_ENABLED` resets it to 0. |

## Gotchas

- The toggle is driven by `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED`, which fire on combat enter/leave — not the actual combat-flag transition. `OutlineEngineMode` is not combat-protected, so setting it from these handlers is safe.
- Leaving combat hard-resets the CVar to `0`; any prior user setting is not saved/restored (see the `todo` in `core.lua`). `CombatOutlineDB` is declared but unused.
