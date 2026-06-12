# WoW AddOn Suite — Claude Instructions

## First Step: Read CONTEXT.md

**At the start of every session, read `CONTEXT.md` in this directory.** It is the top-level index: the dependency graph, a one-line summary per addon, and the global slash command registry. Each addon's full code reference — file maps, class hierarchies, API surfaces, data structures, and constructor options — lives in its own `<addon>/CONTEXT.md` (linked from the root index). Load only the per-addon files relevant to the task; together they eliminate the need to re-read source files.

## Project Overview

WoW Retail addon suite by Nazuraki (Interface 120000+). No build step, no package manager. Testing is done in-game via `/reload`, except WoW-API-free modules which have busted unit tests.

Addons: LibNAddOn, LibNUI, LibNUI_Test, Warbandeer (Characters, main UI, Alias, Collected, Bars), ShadowsOfUI-XP, ShadowsOfUI-GCD, ShadowsOfUI-DMF, HideStanceBar, HideBagBar, CombatOutline, Recycle, BarNonce. The authoritative list is the root `CONTEXT.md` addon index.

## Documentation

Each doc has a fixed audience — keep them in sync with code changes:

| Doc | Audience | Content |
|---|---|---|
| Root `README.md` | Anyone landing on the repo | Suite overview + addon table (one row per addon, linking its README) |
| `CONTRIBUTING.md` | Contributors | Style, testing, lint, release process |
| `<addon>/README.md` | **End users** | What it does, commands, settings, dependencies, saved data. Written to be reusable verbatim as the CurseForge page — standalone, no repo-relative links. Exception: library addons (LibNAddOn, LibNUI, Warbandeer_Bars) have developer-facing API READMEs |
| `CONTEXT.md` + `<addon>/CONTEXT.md` | Claude / code reference | File maps, classes, APIs, data structures, gotchas |

Upkeep rules:

- **New addon** → end-user `README.md`, a row in the root `README.md` table, its own `CONTEXT.md`, and entries in the root `CONTEXT.md` (dependency graph, addon index, slash registry).
- **Changed slash commands, settings, dependencies, API surface, or DB version** → update the addon's `README.md`, its `CONTEXT.md`, and the root `CONTEXT.md` registry/index in the same change.
- **New/changed public methods or ns fields** → LuaLS annotations are part of the change, not a follow-up.
- Use the `doc:` conventional-commit type for doc-only commits — `.md` changes never trigger a release.

## Coding Conventions

| Convention | Detail |
|---|---|
| Namespace | Typed import in every file — see **Namespace Imports & Typing** below |
| Class definition | `local Foo = Class(Parent, function(self) ... end, { defaults })` |
| Addon init | `LibNAddOn{ name=..., addOn=ns, ... }` (table form) or `local ns = LibNAddOn(...)` (assignment form) |
| DB migration | `MigrateDB()` auto-called by LibNAddOn on version mismatch |
| Event handling | `ns:registerEvent("EVENT", handler)` or define `function ns.EVENT_NAME(self, ...) end` |
| UI widget access | Always via `self._widget`; **never access `_widget` from outside a class** |
| Shared API data | Access via `ns.api.*` (bound from `X-NUI-API` toc field) |
| LuaLS annotations | `---@class`, `---@field`, `---@param`, `---@return` |
| No error handling | WoW API errors surface in-game; no defensive nil-checks on internal invariants |
| No standalone utilities | Everything belongs on a class or the addon namespace |
| Testing | In-game via `/reload` and `/nui test [key]` for UI; busted unit tests in `spec/` for pure-Lua modules (see **Unit Tests** below) |

## Namespace Imports & Typing

Every file imports the addon namespace with a LuaLS annotation so fields link across files.

The setup file (the one that calls `LibNAddOn`):

```lua
---@class Warbandeer_Characters: AddOn
local ns = LibNAddOn(...)
```

All other files:

```lua
---@type Warbandeer_Characters
local ns = select(2, ...)
```

Rules:

- The class name is the addon folder name, with hyphens replaced by underscores (e.g. `ShadowsOfUI_XP`).
- **LibNUI exception**: the class name `LibNUI` belongs to the widget table `ns.ui` (anchored in `LibNUI/globals.lua`); LibNUI's own namespace class is `LibNUI_AddOn`.
- LibNAddOn's own files use `---@class LibNAddOn` on the import instead of `---@type`, since they incrementally define the class.
- Files that add fields to `ns` keep the `---@type` import and re-open the class right before the definitions (`---@class Warbandeer` + `---@field ...` — see `Warbandeer/views/SummaryColumns.lua`).
- Files that also need the addon name keep it on its own line: `local ADDON_NAME = ...` followed by the annotated `select(2, ...)` import (this includes table-form init files like `CombatOutline/core.lua`).
- Typed widget-table alias where useful: `---@type LibNUI` above `local ui = ns.ui`.

## Naming Conventions

| Pattern | Convention |
|---|---|
| Public methods | `PascalCase` |
| Lifecycle hooks / callbacks | `camelCase` (`onLoad`, `onUpdate`) |
| Constructor init fields | `camelCase` (`cellWidth`, `headerHeight`) |
| Internal fields | `_prefixed` (`_widget`, `_tabs`) |

## Getter/Setter Pattern

```lua
function MyClass:Value(v)
    if v == nil then return self._widget:GetValue() end
    self._widget:SetValue(v)
    return self
end
```

## Versioning

The `## Version:` field in each `.toc` uses the format **`MAJOR.MINOR.PATCH-rREVISION`**, where `MAJOR.MINOR.PATCH` mirrors the WoW client version (e.g. `12.0.5-r0`) and `REVISION` is a zero-based counter that resets each patch cycle. `r0` is the initial release adding support for that client version (at minimum a client version bump in the `.toc`). The `v` prefix is added by the release tooling to tags and titles (e.g. `AddonName-v12.0.5-r0`).

**Do not bump the `-rREVISION` in `.toc` files** when making code changes — the release script bumps it automatically. (Other `.toc` fields, e.g. `X-NUI-DB-VERSION` for a DB migration, are still bumped by hand as part of the change.)

## DB Backwards Compatibility

- DB upgrades must be **non-destructive**: new keys are added, old keys are never removed or repurposed by `MigrateDB`.
- A user must be able to rollback to any earlier revision within the same patch cycle (or a prior cycle) with no data loss or corruption.
- If old keys become stale after an upgrade, expose a **cleanup command** (e.g. `/addon cleanup`) that removes them explicitly. Never run cleanup automatically — only after the user confirms the upgrade is stable.

## File Size

Keep individual files to **200–300 lines maximum**. If a file grows beyond that, split it by responsibility (e.g. separate data, view, and controller concerns into distinct files listed in the `.toc`).

## Unit Tests

WoW-API-free code (currently LibNAddOn's `ns.lua.*` modules) has busted specs in `<addon>/spec/` inside each addon folder. Run the whole suite from the AddOns root:

```
~\.lua51\bin\busted.bat
```

- Spec roots are listed in `.busted` at the repo root (`ROOT = {...}`) — add the addon's `spec/` dir there when giving a new addon tests.
- `LibNAddOn/spec/libn.lua` loads LibNAddOn's pure-Lua files into a fresh `ns` with the WoW addon vararg (and stubs `Mixin`); specs call `libn.load()` per test. File paths in loaders are relative to the AddOns root (busted's cwd).
- `spec/` dirs are excluded from the publish pipeline in two places — keep both in sync: the CurseForge zip (`publish.yml` `--exclude "${ADDON}/spec/*"`) and release change-detection (`release.sh` pathspec), so tests are never shipped and test-only commits never trigger a release.
- Spec files are never listed in the `.toc`, so WoW never loads them.
- Specs are linted via the `files["**/spec/**/*.lua"]` override in `.luacheckrc`.
- Spec files must be saved **without a UTF-8 BOM** (Lua 5.1's `loadfile` rejects it).
- CI runs the suite on every PR and push to `main` (`.github/workflows/test.yml`, busted on Lua 5.1). A `luacheck` job runs alongside it and is **strict**: any warning fails the build (the repo lints clean — keep it that way).

## In-Game Debugging

Use `/dump <expr>` or `/run <lua>` to inspect live data. Output appears in the chat window — can't be copy/pasted and truncates if too long. Use these to check what WoW API calls actually return (e.g. `/run print(C_MajorFactions.GetMajorFactionData(2742))` or `/dump C_DelvesUI.GetDelvesFactionForSeason()`).

## Key Gotchas

- **TableFrame offsetX/offsetY** are computed once at construction based on whether `rowNames`/`colNames` are non-nil. For dynamic tables, pass `rowNames = {}` / `colNames = {}`.
- **SecureButton**: Never call `SetAttribute` during combat (taint).
- **`special = true`**: Registers frame in `_G` and `UISpecialFrames` (Escape closes it). Only for top-level windows.
- **Frame `onUpdate` elapsed**: arrives in **milliseconds** (Frame multiplies WoW's seconds by 1000).
- **`ns.delay(ms, fn)`**: Only one active timer per addon — a new call overwrites the pending one.
- **`rgba(r, g, b, a)`**: r/g/b are 0–255 integers, a is 0–1 float.
