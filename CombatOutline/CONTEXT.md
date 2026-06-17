# CombatOutline

**Deps:** LibNAddOn · **SavedVars:** `CombatOutlineDB` (unused) · **Commands:** none

Forces the `OutlineEngineMode` CVar on while in combat and restores the user's setting when leaving it, driven by the regen events.

## Files

| File | Purpose |
|---|---|
| `core.lua` | Whole addon. Assignment-form init (`local ns = LibNAddOn(...)`, DB from `X-NUI-DB`); `PLAYER_REGEN_DISABLED` → `self:SetTemporaryCVar("OutlineEngineMode", 1)`, `PLAYER_REGEN_ENABLED` → `self:RestoreCVar("OutlineEngineMode")` (LibNAddOn's CVar helpers). |

## Gotchas

- The toggle is driven by `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED`, which fire on combat enter/leave — not the actual combat-flag transition. `OutlineEngineMode` is not combat-protected, so setting it from these handlers is safe.
- The user's original `OutlineEngineMode` is **backed up and restored** via LibNAddOn's `SetTemporaryCVar`/`RestoreCVar`, which also guarantees a restore on `PLAYER_LOGOUT` — so logging out mid-combat can't leave the outline stuck on. `CombatOutlineDB` is declared but unused.
