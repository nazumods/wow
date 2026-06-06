# LibNAddOn

Bootstrapping factory. Every addon depends on this.

## Files

| File | Purpose |
|---|---|
| `LibNAddOn/functions.lua` | `GetMetadata`, `Hook`, `linkCommonFunctions`. Bootstraps LibNAddOn's own namespace |
| `LibNAddOn/lua/lua.lua` | `ns.lua = {}` with `Select(k)` higher-order extractor |
| `LibNAddOn/lua/maps.lua` | `ns.lua.maps` — `merge`, `fill`, `map`, `toMap`, `toList`, `any`, `anyKey` |
| `LibNAddOn/lua/sets.lua` | `ns.lua.sets` — `Set(list)`, `values(t)` |
| `LibNAddOn/lua/lists.lua` | `ns.lua.lists` — `values`, `generate`, `map`, `filter`, `find`, `fold`, `prepend` |
| `LibNAddOn/lua/class.lua` | `ns.lua.Class(parent, fn, defaults, ...)` |
| `LibNAddOn/lua/strings.lua` | `ns.lua.strings` — `startsWith(str, start)`, `split(token, str)` |
| `LibNAddOn/slashCommands.lua` | Slash command registration/dispatch. Self-bootstraps `/lib` |
| `LibNAddOn/globals/colors.lua` | `ns.Colors` — class colors, `rgba(r255,g255,b255,a01)`, `alpha(color, a)` |
| `LibNAddOn/globals/wow.lua` | `ns.wow` — `maxLevel`, `Armor`, `ClassKeys`, `ClassByKey`, `Specializations` |
| `LibNAddOn/globals/player.lua` | `ns.wow.Player`, `Profession`, `GreatVault`, `/lib player` command |
| `LibNAddOn/globals/factions.lua` | `ns.wow.Factions` — lazy-cached faction lookup |
| `LibNAddOn/globals/icons.lua` | `ns.icons` — atlas/path constants for classes, roles, specs, factions, UI |
| `LibNAddOn/globals/items.lua` | `ns.wow.Items` — `GetIcon(itemID)`, `GetNumSlots(containerIndex)` |
| `LibNAddOn/globals.lua` | `ns.linkGlobals(addOn, features)` — wires lua/wow/icons/Colors/api/ui |
| `LibNAddOn/eventListener.lua` | `ns.createEventListener(addOn, name)` — event frame, lifecycle hooks, `delay()` |
| `LibNAddOn/database.lua` | `ns.setupDB(name, addOn, ops)` — SavedVariables linkage + migration |
| `LibNAddOn/settings.lua` | `ns.registerSettings(addOn, name, features)` — Blizzard Settings API |
| `LibNAddOn/api.lua` | `LibNAddOn(features, o)` — main factory function |

## Factory: `LibNAddOn(features)`

```lua
-- Table form:
LibNAddOn{ name = "MyAddon", addOn = ns, db = "MyDB", settings = {...} }
-- Assignment form:
local ns = LibNAddOn(...)
```

### `features` Fields

| Field | Type | Description |
|---|---|---|
| `name` | string | Addon name (must match TOC filename) |
| `addOn` | table | The addon namespace (`ns`) |
| `db` | table? | `{ name = "GlobalVarName", version = number }` or auto from TOC |
| `settings` | table? | Settings category definitions (requires `db`) |
| `slashCommands` | table? | Manual slash command map; auto from `X-NUI-COMMANDS` |
| `compartmentFn` | string? | Global function name for compartment clicks; auto from `X-NUI-COMPARTMENT` |
| `lua/wow/icons/colors` | string? | Override key names on namespace |
| `api` | string? | Shared API global name; auto from `X-NUI-API` |
| `ui` | string? | UI library global name; auto from `X-NUI-UI` |

### Wiring Order

1. `linkCommonFunctions` → `GetMetadata`, `Print`, `hook`
2. `linkGlobals` → `lua`, `wow`, `icons`, `Colors`, `api`, `ui`
3. `createEventListener` → event frame, lifecycle
4. `setupDB` → SavedVariables linkage (if db configured)
5. `registerSettings` → Blizzard Settings (if settings provided)
6. `registerSlashCommands` → from features or TOC
7. Compartment click handler

### ADDON_LOADED Handler Ordering

| Position | Source | What |
|---|---|---|
| 1 | `database.lua` | Links `_G[dbName]` → `addOn.db`, triggers migration |
| 2 | `settings.lua` | Registers Blizzard Settings UI |
| (appended) | `eventListener.lua` | Calls `onLoad()`, sets up `onLogin` |

## Resulting Namespace

After `LibNAddOn(features)`, the addon namespace has:

```
addOn._NAME, addOn._TITLE
addOn._eventListener (Frame), addOn._eventHandlers (table)
addOn.lua, addOn.wow, addOn.icons, addOn.Colors
addOn.api (shared global), addOn.ui (LibNUI global)
addOn.db (SavedVariables, linked on ADDON_LOADED)
addOn.commands (slash command tree), addOn.settingsCategory
Methods: GetMetadata, Print, hook, registerEvent, unregisterEvent,
         delay, registerCommand, SlashCmd, usage
Lifecycle: onLoad, onLogin, MigrateDB, settingChanged, CompartmentClick
```

## Class System

```lua
local MyClass = Class(Parent, function(self) ... end, { defaults })
local instance = MyClass:new{ field = value }
```

Construction order: `fill(o, defaults)` → `parent:new(o)` → `Mixin(o, parent, class)` → `setmetatable` → `fn(o)` → `parent.onLoad(o)` → `class.onLoad(o)` → `defaults.onLoad(o)`

## Lua Utilities

### `ns.lua.maps`
| Function | Signature | Notes |
|---|---|---|
| `merge` | `(dest, ...) → dest` | Deep-merge, overwrites scalars, recursively merges sub-tables |
| `fill` | `(dest, ...) → dest` | Like merge but does NOT overwrite existing keys |
| `map` | `(t, f) → table` | `f(v, k)`, returns new table with same keys |
| `toMap` | `(t, f?) → table` | List→map, each value becomes key. `f(v,i)` produces value |
| `toList` | `(t, f) → list` | Map→list via `f(k, v)` |
| `any` | `(t, f) → bool` | `f(v)` truthy for any value |
| `anyKey` | `(t, f) → bool` | `f(k)` truthy for any key |

### `ns.lua.lists`
| Function | Signature | Notes |
|---|---|---|
| `values` | `(...) → list` | Flatten all values from multiple tables |
| `generate` | `(f, n, start?) → list` | `f(i)` for `i=start..n` |
| `map` | `(t, f?) → list` | `f(v, k)`, nil copies as-is |
| `filter` | `(t, f) → list` | Keep where `f(v, k)` truthy |
| `find` | `(t, value) → idx?, v?` | Function pred: `(idx, v)`. Scalar: `idx` |
| `fold` | `(t, n) → list-of-lists` | Round-robin distribute into `n` sub-lists |
| `prepend` | `(t, ...) → t` | Insert varargs at position 1, mutates `t` |

### `ns.lua.strings`
| Function | Signature |
|---|---|
| `startsWith` | `(str, start) → bool` (nil-safe on str) |
| `split` | `(token, str) → list` (token is FIRST arg) |

## Event System

```lua
-- Method dispatch (define method named after event):
function addOn.EVENT_NAME(self, ...) end

-- Handler registration:
addOn:registerEvent("EVENT_NAME", function(self, ...) end)
addOn:registerEvent("EVENT_NAME", handler, 1)  -- insert at position
addOn:unregisterEvent("EVENT_NAME", handler?)

-- Dispatch order: method first, then handler list in order
```

### `delay(ms, fn)`
One-shot timer. Only one active per addon. `fn` can be a function or method name string.

## Player API (`ns.wow.Player`)

### Colon methods (receive self)
`GetClassName`, `GetHealthPercent`, `GetHealthValues`, `GetPower(idx)`, `GetPowerMax(idx)`, `GetPowerPercent(idx)`, `GetPowerValues(idx)`, `GetXPPercent`, `GetRestPercent`, `isMaxLevel`, `GetProfessions`, `GetRewardOptions`

### Dot functions (no self)
`GetAverageItemLevel`, `GetClassId`, `GetHealth`, `GetHealthMax`, `GetLevel`, `GetMaxXP`, `GetMountIcon`, `GetName`, `GetPetHealthValues`, `GetPowerType`, `GetShapeshiftFormID`, `GetActiveSpecialization`, `GetPrimarySpecialization`, `GetRace`, `GetXP`, `GetXPExhaustion`, `HasTarget`, `HasToy`, `InCombat`, `IsAFK`, `isRested`, `IsResting`, `IsMountUsable`, `IsMountCollected`, `IsSpellKnown`, `Cast`, `Mount`, `UseToy`

## Colors

Class colors: `ns.Colors.DeathKnight = {0.77, 0.12, 0.23}` etc. (0-1 floats)
`rgba(r, g, b, a)` — r/g/b 0-255, a 0-1 → `ColorMixin`
`alpha(color, a)` → `{r, g, b, a}` list

## Icons

Simple: `CheckGreen`, `RedX`, `Vault`, `Theatre`, `Treasure`, `BackArrow`, `preMidnight`, `Nightfall`, `Alliance`, `Horde`, `Bag`, `Backpack`
Complex (table with `path`, `coords`, optional `vertexColor`): `AllianceLight`, `HordeLight`, `DAMAGER`, `HEALER`, `TANK`, `Arcane`, `Fury`, `Holy`, `Preservation`, `Shadow`, `Vengeance`
`ns.icons.classes` — indexed 1-13 matching WoW class IDs: `classicon-warrior` through `classicon-evoker`

## Settings System

```lua
features.settings = {
  {
    title = "Category Title",
    fields = {
      { typ = "checkbox", name = "settingName", key = "dbKey",
        table = function(db) return db end,
        label = "Display Label", default = true, tooltip = "Help text",
        callback = function(setting, value) end },
      { typ = "slider", min = 0, max = 100, step = 1, ... },
      { typ = "dropdown", options = {"Option 1", "Option 2"}, ... },
    },
  },
}
```

Default callback calls `addOn:settingChanged(key, value, variable, setting)`.

## TOC Metadata Fields

| Field | Purpose |
|---|---|
| `X-NUI-DB` | SavedVariables global name → `ns.db` |
| `X-NUI-DB-VERSION` | DB version for migration |
| `X-NUI-COMMANDS` | Comma-separated slash commands |
| `X-NUI-COMPARTMENT` | Compartment click function name |
| `X-NUI-API` | Shared API global name → `ns.api` |
| `X-NUI-UI` | UI library global name → `ns.ui` |
