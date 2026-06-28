# ShadowsOfUI-Castbar

**Deps:** LibNAddOn, LibNUI · **SavedVars:** `ShadowsOfUI_CastbarDB` (v1) · **UI:** LibNUI · **Settings:** subcategory under the shared "Shadows of UI" parent · **Slash:** `/scast`

Two movable, cosmetic cast bars — one for the **target** unit, one for the **focus** unit —
in the suite's minimal style (siblings to `ShadowsOfUI-XP` / `ShadowsOfUI-GCD`). Built on
LibNUI's `StatusBar`. Reads `UnitCastingInfo` / `UnitChannelInfo` only (no secret/stat APIs),
so it's purely cosmetic and combat-safe (insecure frames, no `SetAttribute`).

## Files

| File | Purpose |
|---|---|
| `core.lua` | Bootstrap (assignment form). `MigrateDB` seeds `textSize` + per-bar `*Enabled` flags + `*Pos` tables. `ns:RegisterSettings` (two enable checkboxes + an 8–18px text-size slider) nested under the **Shadows of UI** parent. `onLoad` builds `ns.bars` (`target` + `focus` `CastBar`s) and calls `ns:WireEditMode`. `ns:SetBarEnabled`/`ns:ApplyTextSize` apply settings live. `SLASH_SUI_CASTBAR1 = "/scast"` (base opens settings, `dump` prints state). |
| `CastBar.lua` | `ns.CastBar` — a `StatusBar` subclass per unit. Icon (inset top-left) + spell-name `Label` + remaining-time `Label` + darkened top edge. Registers the `UNIT_SPELLCAST_*` events **per-unit** via `RegisterUnitEvent` (so "target"/"focus" follow the live unit) plus the `PLAYER_TARGET_CHANGED`/`PLAYER_FOCUS_CHANGED` change event (passed as the `events` option); every one just calls `Refresh`. `Refresh` re-reads `UnitCastingInfo`→`UnitChannelInfo`, paints, and shows. The fill is the **native `StatusBar`** (`SetMinMaxValues(startMS, endMS)` + per-frame `SetValue(GetTime()*1000)`) so the engine computes it in C — Lua never does arithmetic on the **secret** cast times (see gotcha); hiding is driven by the `*_STOP` events, not a Lua compare against the secret end time. `onUpdate` only computes the time text when the timing is readable. `SetConfig(on)` is the Edit Mode placement sample; `enableDrag` arms left-drag → writes the CENTER offset back into the DB `pos` table. `SetEnabled`/`SetTextSize` back the settings. |
| `editmode.lua` | `ns:WireEditMode` `hooksecurefunc`s `EditModeManagerFrame:EnterEditMode`/`ExitEditMode` → `ns:SetConfigMode(on)`, which flips every bar's `SetConfig`. Guarded so a missing/renamed mixin just leaves the bars in live mode. |

## Gotchas

- **`core.lua` loads first** (it's the `LibNAddOn(...)` setup file, so `ns.ui`/`ns.Colors` exist for the other files); `ns.CastBar` / `ns:WireEditMode` are only *used* in `onLoad`, which runs long after all files load.
- **Edit Mode is not a real registration.** WoW has no public Edit Mode API for third-party frames, so the bars piggy-back on the manager's enter/exit hooks to show a draggable sample. This is the intended approach (see issue #263), not a true Edit Mode "system".
- **Position is a live DB reference.** Each bar's `pos` is the actual `db.targetPos`/`db.focusPos` table, so a drag mutates the DB directly; `applyPosition` re-anchors `CENTER → UIParent CENTER` with the saved offset. Offsets assume the bar and `UIParent` share an effective scale (both parent to `UIParent`).
- **Per-unit events, not global.** `RegisterUnitEvent(event, "target"|"focus")` means each bar only wakes for its own unit; on a target/focus change the change-event handler re-`Refresh`es to catch an already-in-progress cast.
- **Secret cast values (anti-automation).** An enemy target/focus's `UnitCastingInfo` timing (`startMS`/`endMS`) and `notInterruptible` flag are **secret** values — tainted addon code may *pass* them to C but not do arithmetic/boolean tests on them (else `attempt to … a secret … value, while execution tainted`). So the fill is driven by handing the secret times to the native `StatusBar` (C does the math), the interrupt colour is only applied when `canaccessvalue(notInterruptible)`, and the **time text only shows when `canaccessvalue(endMS)`** (i.e. your own / friendly casts; blank for enemies). Name/icon/texture are *not* secret. This hinges on the engine accepting secret values *through* `SetMinMaxValues`/`SetValue` (a "pass, don't inspect" use) — **pending in-game confirmation**; if it rejects them, the fallback is to reskin Blizzard's own (secure) target/focus cast bars. See [[reference_wow_secret_values]].
- **Settings variable keys must be unique.** The two enable checkboxes use distinct DB keys (`targetEnabled` / `focusEnabled`) because `ns.registerSettings` derives the (addon-global) Settings variable id from the key — a shared `enabled` key would collide.
- **Font size via a borrowed path.** `FONT_PATH = GameFontHighlightSmall:GetFont()` — the name/time `Label`s use `{FONT_PATH, size}` so the slider can resize them at runtime without shipping a font.

## SavedVariables (`ShadowsOfUI_CastbarDB`)

```lua
{
  textSize      = 12,                -- spell-name / time font size, 8–18
  targetEnabled = true,             -- show the target bar for real casts
  focusEnabled  = true,             -- show the focus bar for real casts
  targetPos     = { x = 0, y = 160 }, -- CENTER offset from UIParent
  focusPos      = { x = 0, y = 124 },
}
```
`MigrateDB` only ensures each key exists; non-destructive.
