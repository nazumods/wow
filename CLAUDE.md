# WoW AddOn Suite — Claude Instructions

## First Step: Read CONTEXT.md

**At the start of every session, read `CONTEXT.md` in this directory.** It contains the complete code reference for all addons — file maps, class hierarchies, API surfaces, data structures, and constructor options. This eliminates the need to re-read source files.

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
| LuaLS annotations | `---@class`, `---@field`, `---@param`, `---@return` on all classes and public methods |
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

## Key Gotchas

- **TableFrame offsetX/offsetY** are computed once at construction based on whether `rowNames`/`colNames` are non-nil. For dynamic tables, pass `rowNames = {}` / `colNames = {}`.
- **SecureButton**: Never call `SetAttribute` during combat (taint).
- **`special = true`**: Registers frame in `_G` and `UISpecialFrames` (Escape closes it). Only for top-level windows.
- **Frame `onUpdate` elapsed**: arrives in **milliseconds** (Frame multiplies WoW's seconds by 1000).
- **`ns.delay(ms, fn)`**: Only one active timer per addon — a new call overwrites the pending one.
- **`rgba(r, g, b, a)`**: r/g/b are 0–255 integers, a is 0–1 float.
