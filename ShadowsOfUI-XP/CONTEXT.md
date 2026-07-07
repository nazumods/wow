# ShadowsOfUI-XP

**Deps:** LibNAddOn, LibNUI · **SavedVars:** none · **Commands:** none · **UI:** LibNUI

Minimal full-width XP bar pinned to the screen bottom. Hides Blizzard's `StatusTrackingBarManager` **unconditionally and permanently** (by design — see Gotchas); the custom bar is only created while the player is below max level, so at max level the screen is clean (no XP bar, no rep/honor/azerite tracking bars).

## Files

| File | Purpose |
|---|---|
| `ExpBar.lua` | Whole addon. `ns` init (assignment form). `ExpBar` (extends `StatusBar`) — 7px bar with rested-XP overlay, 10% notches, hover-reveal `%` labels. `ns:onLoad` hides the Blizzard bar and creates `ns.xpBar` if not max level |
| `changelog.lua` | `ns.changelog` — newest-first `{version, notes}` release history for the in-game **Changelog** viewer (LibNAddOn). **Generated** — `release.sh` prepends each release; not hand-edited |

## ExpBar (extends StatusBar)

Anchored full-width along screen bottom (`BottomLeft`/`BottomRight` of `UIParent`), height 7.

| Child | Type | Purpose |
|---|---|---|
| `edge` | Texture | Dark vertical gradient on bar's top 3px |
| `fade` | Texture | Dark gradient fading into UI above the bar |
| `secondary` | Texture | Blue rested-XP extent, drawn right of `fill` |
| `textPercent` | FontString | XP % label (raw `CreateFontString`) |
| `restPercent` | FontString | Rested % label (raw `CreateFontString`) |
| `notch1..9` | Texture | 10% tick marks, built in `initNotches` |

**Fill:** horizontal purple gradient (`rgba(88,0,145,.5)` → `rgba(154,8,252,.5)`), `ADD` blend.

**Events** (`PLAYER_ENTERING_WORLD` → `initNotches`+`update` on login/reload; all others → `update`): `PLAYER_XP_UPDATE`, `PLAYER_LEVEL_UP`, `UPDATE_EXHAUSTION`, `PLAYER_UPDATE_RESTING`.

**Hover:** `onEnter` sets label alpha to 1 instantly; `onLeave` fades both labels out over `fadeDelay` (500ms) via an `onUpdate` loop, then stops updates.

## Gotchas

- **`StatusTrackingBarManager:Hide()` in `onLoad` is intentionally unconditional.** It is *not* scoped to "below max" and is never re-shown — at max level the addon wants a fully clean screen (no XP bar **and** no Blizzard tracking bars). Do not "fix" it by gating on level or re-showing on `PLAYER_LEVEL_UP`; that would resurrect the rep/honor bar at max, contradicting the README ("Hidden entirely at max level (and Blizzard's bar stays hidden with it)").
- Labels start at alpha 0 — they're invisible until hover, then fade back out.
- `RestedGradientStart`/`End` and the `secondary` gradient are defined but commented out; the rested overlay is currently a flat blue.
