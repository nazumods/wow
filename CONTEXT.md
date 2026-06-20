# WoW AddOn Suite — Code Context Index

> **Purpose:** Top-level map of the Nazuraki addon suite. Each addon's full code
> reference now lives in its own `<addon>/CONTEXT.md` — load only the ones you need.
> This root file holds the cross-cutting bits: the dependency graph, a one-line
> summary + pointer per addon, and the global slash command registry.

---

## Runtime Environment

WoW runs **Lua 5.1**. All addon code must be compatible with Lua 5.1 — in particular:

- No `goto` / `::label::` (added in Lua 5.2) — use `if/end` blocks to skip loop iterations
- No integer division operator `//` (added in Lua 5.3) — use `math.floor(a / b)`
- No bitwise operators `&`, `|`, `~`, `<<`, `>>` (added in Lua 5.3) — use `bit.band` etc. (WoW provides the `bit` library)
- No `table.move`, `table.unpack` (5.2+) — use `unpack()`

---

## Dependency Graph (All Addons)

```
LibNAddOn
    |
    +-- LibNUI ──────────────────────────→ LibNUI_Test (LoadOnDemand)
    |     |
    |     +-- ShadowsOfUI-XP
    |     +-- ShadowsOfUI-GCD
    |     +-- HideStanceBar
    |     +-- Warbandeer_Alias
    |     +-- Recycle
    |     +-- Warbandeer_Characters  (populates WarbandeerApi)
    |           |
    |           +-- Warbandeer            (optionally reads WarbandeerBarsApi + WarbandeerCollectedApi + ShadowsOfUI_UpgradeApi)
    |           +-- Warbandeer_Collected  (also populates WarbandeerCollectedApi for Warbandeer)
    |           +-- ShadowsOfUI-Upgrade   (publishes ShadowsOfUI_UpgradeApi; consumed by Warbandeer)
    |
    +-- Warbandeer_Bars      (LibNAddOn only — headless data layer, populates WarbandeerBarsApi)
    +-- CombatOutline    (LibNAddOn only, no LibNUI)
    +-- ShadowsOfUI-DMF (LibNAddOn only, no LibNUI)
    +-- ShadowsOfUI-Ilvl (LibNAddOn only, no LibNUI; optional Baganator + Bagnon/Bagnonium integration)
    +-- ShadowsOfUI-Known (LibNAddOn + Warbandeer_Characters; optional Warbandeer; no LibNUI)
    +-- ShadowsOfUI-Artisan (LibNAddOn + Warbandeer_Characters; optional Warbandeer; no LibNUI)

(no LibN dependency):
    HideBagBar  (raw WoW API only)
    BarNonce    (raw WoW API only)
```

---

## Addon Index

Load the linked `CONTEXT.md` for full file maps, class hierarchies, API surfaces, and data structures.

| Addon | Summary | Reference |
|---|---|---|
| **LibNAddOn** | Bootstrapping factory (`LibNAddOn(features)`), class system, lua utils, event/DB/settings wiring. Every addon depends on it. | [LibNAddOn/CONTEXT.md](LibNAddOn/CONTEXT.md) |
| **LibNUI** | OOP UI widget library; global `LibNUI` / `ns.ui`. Region→Frame hierarchy: Texture, Label, StatusBar, Button, TableFrame, TitleFrame, TabFrame, Tooltip, CopyWindow, settings widgets. Themable via `ui.Theme{}` / `ui.themes.dark`. Shared copy window `ui.ShowCopyWindow` + `/wdebug`; `LibNUIDB` (v1). | [LibNUI/CONTEXT.md](LibNUI/CONTEXT.md) |
| **Warbandeer_Characters** | Data collection backbone; populates `WarbandeerApi`. Broker system, per-character struct, account-wide warband wealth + bank prof-gear cache (warband/character/guild) + equippable-gear cache (bags + warband/personal banks) + per-character world-quest gear-reward cache + per-slot empty-socket counts + per-character secondary-stats snapshot, `WarbandeerCharDB` (v17). | [Warbandeer_Characters/CONTEXT.md](Warbandeer_Characters/CONTEXT.md) |
| **Warbandeer** | Main viewer UI (`/warband`, `/wb`). 13 views, MainWindow, faction widget, `profIntent`, `WarbandeerDB` (v3). | [Warbandeer/CONTEXT.md](Warbandeer/CONTEXT.md) |
| **Warbandeer_Alias** | Guild-chat alias prefix hook. Single file; `Warbandeer_AliasDB` (v1). | [Warbandeer_Alias/CONTEXT.md](Warbandeer_Alias/CONTEXT.md) |
| **Warbandeer_Collected** | Transmog set tracker (`/collected`, `/collect`). DataView grid, scan logic, `WarbandeerCollectedDB` (v2); exposes read-only `WarbandeerCollectedApi` (consumed by Warbandeer's `collected` view). | [Warbandeer_Collected/CONTEXT.md](Warbandeer_Collected/CONTEXT.md) |
| **ShadowsOfUI-XP** | Minimal full-width XP bar at screen bottom (below max level only). Single file, no DB. | [ShadowsOfUI-XP/CONTEXT.md](ShadowsOfUI-XP/CONTEXT.md) |
| **HideStanceBar** | Hides the stance bar via reparenting, per-class toggles. `HideStanceBarDB` (v1). | [HideStanceBar/CONTEXT.md](HideStanceBar/CONTEXT.md) |
| **HideBagBar** | Hides backpack/bag slot buttons. Raw WoW API only — no LibNAddOn. | [HideBagBar/CONTEXT.md](HideBagBar/CONTEXT.md) |
| **ShadowsOfUI-GCD** | Minimal GCD sweep bar anchored between the primary and secondary resource bars. Single file, no DB, no slash commands. | — |
| **BarNonce** | Removes padding and sets 70% opacity on Action Bars 1 and 2. Raw WoW API only — no LibNAddOn. Single file, no DB, no slash commands. | — |
| **CombatOutline** | Toggles `OutlineEngineMode` CVar in/out of combat. Single file. | [CombatOutline/CONTEXT.md](CombatOutline/CONTEXT.md) |
| **Recycle** | Auto-sells grey + marked items at merchants (`/recycle`). Per-character `RecycleDB` (v1). | [Recycle/CONTEXT.md](Recycle/CONTEXT.md) |
| **ShadowsOfUI-DMF** | Headless Darkmoon Faire helper: merchant material auto-buy + waypoint/map-pin guidance to profession quest givers. `/sdmf` dev command. No UI, no DB. | [ShadowsOfUI-DMF/CONTEXT.md](ShadowsOfUI-DMF/CONTEXT.md) |
| **ShadowsOfUI-Ilvl** | Overlay: item level + compact upgrade-track code (`A/V/C/H/M`+rank, e.g. `C2`) on gear icons (bags/bank/loot/guild bank/Baganator/Bagnon), inset-or-overlay per panel on the character/inspect paperdolls. Per-place toggles + min-quality select via Settings panel; `ShadowsOfUI_IlvlDB` (v2). `/silvl` dev dump. | [ShadowsOfUI-Ilvl/CONTEXT.md](ShadowsOfUI-Ilvl/CONTEXT.md) |
| **ShadowsOfUI-Known** | Headless tooltip addon: adds a "Learnable by:" block to recipe item tooltips (alts with the profession that haven't learned it; red if skill too low). Reads `WarbandeerApi` + optional `WarbandeerDB.profIntent`. `/sknown` dev dump. No UI, no DB. | [ShadowsOfUI-Known/CONTEXT.md](ShadowsOfUI-Known/CONTEXT.md) |
| **ShadowsOfUI-Artisan** | Adds a badge — the current-expansion artisan crafting currency (Midnight's per-profession "Artisan's … Moxie", gathering profs included) for the logged-in character — to the crafting window (`ProfessionsFrame`, beside the Concentration readout) and the spellbook professions page (`ProfessionsBookFrame`, under each profession's spell labels), plus an account-wide hover breakdown across alts that have the profession. Reads `WarbandeerApi` (+ optional `WarbandeerDB.profIntent`); pairs with a new `artisanCurrency` broker in Warbandeer_Characters that caches the per-character amount. `/sartisan` dev dump. No UI lib, no DB. | [ShadowsOfUI-Artisan/CONTEXT.md](ShadowsOfUI-Artisan/CONTEXT.md) |
| **ShadowsOfUI-Upgrade** | Headless gear-upgrade finder + tooltip addon: ilvl-gated upgrades per character (bags/bank/warband bank, active world quests, bundled faction-quartermaster gear), stat-tagged from small built-in tables (spec stat-priority + quartermaster gear; standalone). Also flags **missing enchants + empty gem sockets** and recommends the enchant/gem to apply (ClassCodex per-spec when installed, else a bundled fallback). Reads `WarbandeerApi` (+ optional `ClassCodexGearData`), publishes `ShadowsOfUI_UpgradeApi` (consumed by Warbandeer's Summary/Gear/Detail views). `/supgrade` dev dump. No UI, no DB. | [ShadowsOfUI-Upgrade/CONTEXT.md](ShadowsOfUI-Upgrade/CONTEXT.md) |
| **Warbandeer_Bars** | Headless action-bar/keybind/macro profile layer per char+spec; `WarbandeerBarsApi`. `WarbandeerBarsDB` (v2). | [Warbandeer_Bars/CONTEXT.md](Warbandeer_Bars/CONTEXT.md) |

LibNUI_Test is a LoadOnDemand visual test harness for LibNUI (`/nui test [key]`); it has no standalone reference file.

---

## Slash Command Registry

| Addon | Commands | Sub-commands |
|---|---|---|
| LibNAddOn | `/lib` | `player` |
| LibNUI | `/nui`, `/wdebug` | `version`, `test [key]`; `/wdebug <lua>` (raw command: eval Lua → copyable window) |
| Warbandeer_Characters | `/characters`, `/wbc` | `list`, `delete <name>`, `cleanup`, `refresh`, `refresh items/locks`, `dump`, `dump bank/bankgear/gt/locks/artifact/warband/profgear/wq`, `stat`, `missing`, `missing me`, `wmissing` |
| Warbandeer | `/warband`, `/wb` | `""` (open), `overview`, `summary`, `gear`, `detail`, `roles`, `races`, `legion`, `midnight`, `profs`, `midnightprofs`, `crafting`, `playtime`, `bars`, `collected`, `check legion`, `enchants` (list accepted wrong-enchants), `enchants clear` |
| Warbandeer_Collected | `/collected`, `/collect` | `""` (open), `scan`, `model <id>` (dev: preview a raw display id), `scale <n>` (dev: user scale multiplier; no arg dumps scale state), `normalize <0..1>` (dev: tune a race's normalization override), `release <1..12>` (dev: preview an expansion badge by release index) |
| Recycle | `/recycle` | `clear`, `key CTRL|SHIFT|ALT` |
| Warbandeer_Bars | `/wbbars`, `/wbb` | `""` (status), `snapshot`, `list`, `restore <char> [specID]`, `forget <char> [specID]` |
| ShadowsOfUI-Ilvl | `/silvl` | `<itemID\|link>` (dev: dump an item's ilvl/quality/track) |
| ShadowsOfUI-Known | `/sknown` | `<itemID>` (dev: dump learnable-by list for a recipe item) |
| ShadowsOfUI-Artisan | `/sartisan` | `[name]` (dev: dump a character's per-profession artisan-currency breakdown across alts) |
| ShadowsOfUI-Upgrade | `/supgrade` | `[name]` (dev: dump a character's available gear upgrades), `enchants [name]` (dev: copyable enchant-resolution dump — why a slot has no suggested enchant) |
