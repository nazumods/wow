# WoW AddOn Suite — Claude Instructions

## First Step: Read CONTEXT.md

**At the start of every session, read `CONTEXT.md` in this directory.** It is the top-level index: the dependency graph, a one-line summary per addon, and the global slash command registry. Each addon's full code reference — file maps, class hierarchies, API surfaces, data structures, and constructor options — lives in its own `<addon>/CONTEXT.md` (linked from the root index). Load only the per-addon files relevant to the task; together they eliminate the need to re-read source files.

## Project Overview

WoW Retail addon suite by Nazuraki (Interface 120000+). No build step, no package manager. All testing is done in-game via `/reload`.

Addons: LibNAddOn, LibNUI, LibNUI_Test, Warbandeer (Characters, main UI, Alias, Collected), ShadowsOfUI-XP, HideStanceBar, HideBagBar, CombatOutline, Recycle.

## Coding Conventions

| Convention | Detail |
|---|---|
| Namespace | `local _, ns = ...` in every file |
| Class definition | `local Foo = Class(Parent, function(self) ... end, { defaults })` |
| Addon init | `LibNAddOn{ name=..., addOn=ns, ... }` (table form) or `local ns = LibNAddOn(...)` (assignment form) |
| DB migration | `MigrateDB()` auto-called by LibNAddOn on version mismatch |
| Event handling | `ns:registerEvent("EVENT", handler)` or define `function ns.EVENT_NAME(self, ...) end` |
| UI widget access | Always via `self._widget`; **never access `_widget` from outside a class** |
| Shared API data | Access via `ns.api.*` (bound from `X-NUI-API` toc field) |
| LuaLS annotations | `---@class`, `---@field`, `---@param`, `---@return` |
| No error handling | WoW API errors surface in-game; no defensive nil-checks on internal invariants |
| No standalone utilities | Everything belongs on a class or the addon namespace |
| Testing | In-game only via `/reload` and `/nui test [key]` for UI |

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

## DB Backwards Compatibility

- DB upgrades must be **non-destructive**: new keys are added, old keys are never removed or repurposed by `MigrateDB`.
- A user must be able to rollback to any earlier revision within the same patch cycle (or a prior cycle) with no data loss or corruption.
- If old keys become stale after an upgrade, expose a **cleanup command** (e.g. `/addon cleanup`) that removes them explicitly. Never run cleanup automatically — only after the user confirms the upgrade is stable.

## File Size

Keep individual files to **200–300 lines maximum**. If a file grows beyond that, split it by responsibility (e.g. separate data, view, and controller concerns into distinct files listed in the `.toc`).

## In-Game Debugging

Use `/dump <expr>` or `/run <lua>` to inspect live data. Output appears in the chat window — can't be copy/pasted and truncates if too long. Use these to check what WoW API calls actually return (e.g. `/run print(C_MajorFactions.GetMajorFactionData(2742))` or `/dump C_DelvesUI.GetDelvesFactionForSeason()`).

## Key Gotchas

- **TableFrame offsetX/offsetY** are computed once at construction based on whether `rowNames`/`colNames` are non-nil. For dynamic tables, pass `rowNames = {}` / `colNames = {}`.
- **SecureButton**: Never call `SetAttribute` during combat (taint).
- **`special = true`**: Registers frame in `_G` and `UISpecialFrames` (Escape closes it). Only for top-level windows.
- **Frame `onUpdate` elapsed**: arrives in **milliseconds** (Frame multiplies WoW's seconds by 1000).
- **`ns.delay(ms, fn)`**: Only one active timer per addon — a new call overwrites the pending one.
- **`rgba(r, g, b, a)`**: r/g/b are 0–255 integers, a is 0–1 float.
