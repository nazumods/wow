# MouselookToggle

**Deps:** LibNAddOn (no LibNUI) · **Commands:** none · **DB:** `MouselookToggleDB` (v1)

Keybind-toggled mouselook with a cursor-centering reticle. While toggled, the
`CursorFreelookCentering` + `CursorCenteredYPos` CVars snap the hidden cursor (and
`@cursor` macro targeting) to a fixed screen position; a crosshair reticle tracks
`GetCursorPosition` whenever mouselook is active, fading in debounced during held
right-click freelook (optional).

## Files

| File | Purpose |
|---|---|
| `addon.lua` | Everything: binding global + `MouselookToggle_Toggle()`, CVar lock/unlock, reticle OnUpdate (debounce + fade), settings |
| `Bindings.xml` | `MOUSELOOKTOGGLE_TOGGLE` → `MouselookToggle_Toggle()` (category "Shadows of UI") |

## Behavior

- `lock()`: `MouselookStart()`, then arms the centering CVars **one frame later** via `ns:after(0, ...)`.
- `unlock()`: `toggled = false` + `ns:RestoreCVars()`. Called from the keybind (explicit stop) and from the reticle OnUpdate when mouselook ends any other way.
- **Right-click cancel** while toggled is handled in the reticle OnUpdate, not natively: with `CursorFreelookCentering` live the client's own right-click-cancel stops firing (#339), so the OnUpdate edge-detects a RightButton release (up-edge, LeftButton not also down — else `MouselookStop()` leaves the character auto-running) and stops mouselook itself.
- CVars go through `ns:SetTemporaryCVar` so a logout/disable mid-toggle can't leave them stuck.
- Reticle: toggled mouselook fades the crosshair in immediately (`FADE_TIME` 0.2s); untoggled (held right-click) waits `SHOW_DELAY` 0.3s first — quick camera flicks never show it — and is gated by `db.showHeld`.

## DB (`MouselookToggleDB`, v1)

| Key | Default | Meaning |
|---|---|---|
| `reticleHeight` | `50` | Percent of screen height the centered cursor sits at while toggled (`CursorCenteredYPos` = value/100) |
| `showHeld` | `true` | Show the reticle during mouselook not started by the toggle |

## Gotchas

- **`CursorFreelookCentering` must be set *after* `MouselookStart()`** — if it's already 1 when mouselook starts, the camera jolts by the cursor-to-center vector (Blizzard bug since 10.2, [WoWUIBugs #504](https://github.com/Stanzilla/WoWUIBugs/issues/504)). Hence the deferred `ns:after(0, ...)` and never leaving the CVar set outside a toggle.
- The keybind is ignored while a mouse button is held: `MouselookStop()` mid-click leaves the character auto-running.
- The reticle container frame is always shown — a hidden frame's OnUpdate never fires, so it could never notice mouselook starting again; the OnUpdate shows/hides the texture instead.
- `GetCursorPosition` during mouselook returns the frozen (or centered) cursor position — exactly what `@cursor` macros target — so the reticle just tracks it in both modes.
