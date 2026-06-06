# ShadowsOfUI-XP

## TOC
```
Interface: 120001, Category: Shadows of UI
Dependencies: LibNAddOn, LibNUI, X-NUI-UI: LibNUI
No SavedVariables, no slash commands
```

Single file: `ExpBar.lua`. Assignment form `local ns = LibNAddOn(...)`.

**Only created if player is below max level.**

Hides `StatusTrackingBarManager`. Creates 7px-tall StatusBar pinned full-width at screen bottom.

### ExpBar (extends StatusBar)
| Child | Type | Purpose |
|---|---|---|
| `self.edge` | Texture | 3px dark gradient at top |
| `self.fade` | Texture | 3px dark gradient above bar |
| `self.secondary` | Texture | Blue rested XP extent |
| `self.textPercent` | raw FontString | XP % label |
| `self.restPercent` | raw FontString | Rested % label |
| `self.notch1-9` | Texture | 10% tick marks |

### Events
`PLAYER_ENTERING_WORLD` (initNotches + update), `PLAYER_XP_UPDATE`, `PLAYER_LEVEL_UP`, `UPDATE_EXHAUSTION`, `PLAYER_UPDATE_RESTING` (all → update)

### Animation
Hover: labels alpha=1 instantly. Leave: 500ms fade-out via `onUpdate` loop.

### Colors
```lua
UnrestedGradientStart = rgba(88, 0, 145, 0.5)   -- purple
UnrestedGradientEnd   = rgba(154, 8, 252, 0.5)   -- bright purple
```
