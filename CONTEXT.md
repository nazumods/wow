# WoW AddOn Suite — Code Context Index

> **Purpose:** Top-level map of the Nazuraki addon suite. Each addon's full code
> reference now lives in its own `<addon>/CONTEXT.md` — load only the ones you need.
> This root file holds the cross-cutting bits: the dependency graph, a one-line
> summary + pointer per addon, and the global slash command registry.

---

## Dependency Graph (All Addons)

```
LibNAddOn
    |
    +-- LibNUI ──────────────────────────→ LibNUI_Test (LoadOnDemand)
    |     |
    |     +-- ShadowsOfUI-XP
    |     +-- HideStanceBar
    |     +-- Warbandeer_Alias
    |     +-- Recycle
    |     +-- Warbandeer_Characters  (populates WarbandeerApi)
    |           |
    |           +-- Warbandeer
    |           +-- Warbandeer_Collected
    |
    +-- Warbandeer_Bars      (LibNAddOn only — headless data layer, populates WarbandeerBarsApi)
    +-- CombatOutline    (LibNAddOn only, no LibNUI)
    +-- ShadowsOfUI-DMF (LibNAddOn only, no LibNUI)

(no LibN dependency):
    HideBagBar  (raw WoW API only)
```

---

## Addon Index

Load the linked `CONTEXT.md` for full file maps, class hierarchies, API surfaces, and data structures.

| Addon | Summary | Reference |
|---|---|---|
| **LibNAddOn** | Bootstrapping factory (`LibNAddOn(features)`), class system, lua utils, event/DB/settings wiring. Every addon depends on it. | [LibNAddOn/CONTEXT.md](LibNAddOn/CONTEXT.md) |
| **LibNUI** | OOP UI widget library; global `LibNUI` / `ns.ui`. Region→Frame hierarchy: Texture, Label, StatusBar, Button, TableFrame, TitleFrame, TabFrame, Tooltip, settings widgets. | [LibNUI/CONTEXT.md](LibNUI/CONTEXT.md) |
| **Warbandeer_Characters** | Data collection backbone; populates `WarbandeerApi`. Broker system, per-character struct, `WarbandeerCharDB` (v7). | [Warbandeer_Characters/CONTEXT.md](Warbandeer_Characters/CONTEXT.md) |
| **Warbandeer** | Main viewer UI (`/warband`, `/wb`). 13 views, MainWindow, faction widget, `profIntent`, `WarbandeerDB` (v2). | [Warbandeer/CONTEXT.md](Warbandeer/CONTEXT.md) |
| **Warbandeer_Alias** | Guild-chat alias prefix hook. Single file; `Warbandeer_AliasDB` (v1). | [Warbandeer_Alias/CONTEXT.md](Warbandeer_Alias/CONTEXT.md) |
| **Warbandeer_Collected** | Transmog set tracker (`/collected`, `/collect`). DataView grid, scan logic, `WarbandeerCollectedDB` (v2). | [Warbandeer_Collected/CONTEXT.md](Warbandeer_Collected/CONTEXT.md) |
| **ShadowsOfUI-XP** | Minimal full-width XP bar at screen bottom (below max level only). Single file, no DB. | [ShadowsOfUI-XP/CONTEXT.md](ShadowsOfUI-XP/CONTEXT.md) |
| **HideStanceBar** | Hides the stance bar via reparenting, per-class toggles. `HideStanceBarDB` (v1). | [HideStanceBar/CONTEXT.md](HideStanceBar/CONTEXT.md) |
| **HideBagBar** | Hides backpack/bag slot buttons. Raw WoW API only — no LibNAddOn. | [HideBagBar/CONTEXT.md](HideBagBar/CONTEXT.md) |
| **CombatOutline** | Toggles `OutlineEngineMode` CVar in/out of combat. Single file. | [CombatOutline/CONTEXT.md](CombatOutline/CONTEXT.md) |
| **Recycle** | Auto-sells grey + marked items at merchants (`/recycle`). Per-character `RecycleDB` (v1). | [Recycle/CONTEXT.md](Recycle/CONTEXT.md) |
| **ShadowsOfUI-DMF** | Headless Darkmoon Faire helper: auto-buy mats, auto-accept turn-ins, auto-complete minigames. No UI, no DB. | [ShadowsOfUI-DMF/CONTEXT.md](ShadowsOfUI-DMF/CONTEXT.md) |
| **Warbandeer_Bars** | Headless action-bar/keybind/macro profile layer per char+spec; `WarbandeerBarsApi`. `WarbandeerBarsDB` (v1). | [Warbandeer_Bars/CONTEXT.md](Warbandeer_Bars/CONTEXT.md) |

LibNUI_Test is a LoadOnDemand visual test harness for LibNUI (`/nui test [key]`); it has no standalone reference file.

---

## Slash Command Registry

| Addon | Commands | Sub-commands |
|---|---|---|
| LibNAddOn | `/lib` | `player` |
| LibNUI | `/nui` | `version`, `test [key]` |
| Warbandeer_Characters | `/characters`, `/wbc` | `list`, `delete <name>`, `refresh`, `refresh items/locks`, `dump`, `dump bank/gt/locks/artifact`, `missing`, `missing me` |
| Warbandeer | `/warband`, `/wb` | `""` (open), `overview`, `summary`, `gear`, `detail`, `roles`, `races`, `legion`, `midnight`, `profs`, `midnightprofs`, `crafting`, `playtime`, `weekly`, `check legion` |
| Warbandeer_Collected | `/collected`, `/collect` | `scan` |
| Recycle | `/recycle` | `clear`, `key CTRL|SHIFT|ALT` |
| Warbandeer_Bars | `/wbbars`, `/wbb` | `""` (status), `snapshot`, `list`, `restore <char> [specID]`, `forget <char> [specID]` |
