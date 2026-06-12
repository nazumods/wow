# LibNAddOn

**Deps:** none (base library) · **Commands:** `/lib` · **Exposes:** `LibNAddOn(features, o)` factory + `ns.lua`, `ns.wow`, `ns.icons`, `ns.Colors`

Bootstrapping factory every other addon depends on. `LibNAddOn(features)` wires an addon namespace with common functions, globals, an event listener, DB linkage, settings, and slash commands. Also ships the shared `lua`/`wow`/`icons`/`Colors` utility tables.

## Files

| File | Purpose |
|---|---|
| `functions.lua` | `ns.linkCommonFunctions(addOn, name)` → `GetMetadata`, `Print`, `hook`, `_NAME`, `_TITLE`. Self-bootstraps own namespace |
| `lua/lua.lua` | `ns.lua` root table; `Select(k)` key-extractor higher-order fn |
| `lua/maps.lua` | `ns.lua.maps` — `merge`, `fill`, `map`, `toMap`, `toList`, `any`, `anyKey` |
| `lua/sets.lua` | `ns.lua.sets` — `Set(list)`, `values(t)` (values used as keys verbatim) |
| `lua/lists.lua` | `ns.lua.lists` — `values`, `generate`, `map`, `filter`, `find`, `fold`, `prepend` |
| `lua/class.lua` | `ns.lua.Class(parent, fn, defaults, ...)` — OOP class factory |
| `lua/strings.lua` | `ns.lua.strings` — `startsWith(str, start)`, `split(token, str)` |
| `slashCommands.lua` | `ns.registerSlashCommands`; adds `registerCommand`/`SlashCmd`/`usage` to addon. Self-bootstraps `/lib` |
| `globals/colors.lua` | `ns.Colors` — class colors (0–1), `Strings` (color/icon escape codes), `rgba(r255,g255,b255,a01)`, `alpha(color, a)` |
| `globals/wow.lua` | `ns.wow` — `maxLevel`, `Armor` (+`byClass`/`types`), `ClassKeys`, `ClassByKey`, `Specializations` |
| `globals/player.lua` | `ns.wow.Player`, `ns.wow.GreatVault`; `/lib player <method>` dump command |
| `globals/icons.lua` | `ns.icons` — atlas/path constants for classes, roles, specs, factions, common UI |
| `globals/items.lua` | `ns.wow.Items` — `GetIcon(itemID)`, `GetNumSlots(containerIndex)` |
| `globals.lua` | `ns.linkGlobals(addOn, features)` — wires `lua`/`wow`/`icons`/`Colors`/`api`/`ui` onto the namespace |
| `eventListener.lua` | `ns.createEventListener(addOn)` — event frame, `registerEvent`/`unregisterEvent`/`delay`, `onLoad`/`onLogin` hooks |
| `database.lua` | `ns.setupDB(name, addOn, ops)` — links `_G[dbName]` → `addOn.db`, triggers `MigrateDB` on version mismatch |
| `settings.lua` | `ns.registerSettings(addOn, name, features)` — Blizzard Settings API (checkbox/slider/dropdown) |
| `api.lua` | `LibNAddOn(features, o)` — top-level factory function (global) |

## Factory: `LibNAddOn(features)`

```lua
LibNAddOn{ name = "MyAddon", addOn = ns, db = {...}, settings = {...} }  -- table form
local ns = LibNAddOn("MyAddon", ns)                                      -- assignment form
```

### `features` fields

| Field | Type | Description |
|---|---|---|
| `name` | string | Addon name (must match TOC filename) |
| `addOn` | table | The addon namespace (`ns`) |
| `db` | table? | `{ name, version }`; auto-built from `X-NUI-DB`/`X-NUI-DB-VERSION` if omitted |
| `settings` | table? | Settings category definitions (requires `db`) |
| `slashCommands` | table? | Manual `{base = {cmd, ...}}` map; else auto from `X-NUI-COMMANDS` |
| `compartmentFn` | string? | Global fn name for compartment clicks; else `X-NUI-COMPARTMENT` |
| `lua`/`wow`/`icons`/`colors` | string? | Override the namespace key for each global table |
| `api` | string? | Shared API global name → `ns.api`; else `X-NUI-API` |
| `ui` | string? | UI library global name → `ns.ui`; else `X-NUI-UI` |

### Wiring order

`linkCommonFunctions` → `linkGlobals` → `createEventListener` → `setupDB` (if db) → `registerSettings` (if settings) → `registerSlashCommands` → compartment handler.

`setupDB`/`registerSettings` register `ADDON_LOADED` handlers at positions **1** and **2** (db links + migrates, then settings register) so both run before `onLoad`.

## Resulting namespace

```
addOn._NAME, addOn._TITLE
addOn._eventListener (Frame), addOn._eventHandlers (table)
addOn.lua, addOn.wow, addOn.icons, addOn.Colors
addOn.api (shared global, if configured), addOn.ui (LibNUI global, if configured)
addOn.db (linked on ADDON_LOADED), addOn.commands, addOn.settingsCategory
Methods:   GetMetadata, Print, hook, registerEvent, unregisterEvent, delay, after,
           registerCommand, SlashCmd, usage
Lifecycle: onLoad, onLogin, MigrateDB, settingChanged, CompartmentClick
```

## Class system

```lua
local MyClass = Class(Parent, function(self) ... end, { defaults })
local instance = MyClass:new{ field = value }
```

Construction order: `fill(o, defaults)` → `parent:new(o)` → `Mixin(o, parent, class)` → `setmetatable` → `fn(o)` → `parent.onLoad(o)` → `class.onLoad(o)` → `defaults.onLoad(o)`.

## Lua utilities

### `ns.lua.maps`
| Function | Signature | Notes |
|---|---|---|
| `merge` | `(dest, ...) → dest` | Deep-merge; overwrites scalars, recurses sub-tables; skips `__index` |
| `fill` | `(dest, ...) → dest` | Like merge but does NOT overwrite existing keys (shallow) |
| `map` | `(t, f) → table` | `f(v, k)`, same keys |
| `toMap` | `(t, f?) → table` | List→map; each value becomes a key. `f(v,i)` produces the mapped value |
| `toList` | `(t, f) → list` | Map→list via `f(k, v)` |
| `any` / `anyKey` | `(t, f) → bool` | `f(v)` / `f(k)` truthy for any value/key |

### `ns.lua.lists`
| Function | Signature | Notes |
|---|---|---|
| `values` | `(...) → list` | Flatten all values from multiple tables |
| `generate` | `(f, n, start?) → list` | `f(i)` for `i=start..n` |
| `map` | `(t, f?) → list` | `f(v, k)`; nil `f` copies as-is |
| `filter` | `(t, f) → list` | Keep where `f(v, k)` truthy |
| `find` | `(t, value) → idx[, v]` | Function pred returns `idx, v`; scalar returns `idx` |
| `fold` | `(t, n) → list-of-lists` | Round-robin distribute into `n` sub-lists |
| `prepend` | `(t, ...) → t` | Insert varargs at position 1, mutates `t` |

### `ns.lua.strings`
| Function | Signature |
|---|---|
| `startsWith` | `(str, start) → bool` (nil-safe on `str`) |
| `split` | `(token, str) → list` — **token is the FIRST arg**; splits on any char in `token` |

## Event system

```lua
function addOn.EVENT_NAME(self, ...) end          -- method dispatch (named after event)
addOn:registerEvent("EVENT_NAME", handler, idx?)  -- handler list; idx inserts at position
addOn:unregisterEvent("EVENT_NAME", handler?)     -- nil handler clears all
```

Dispatch order: the same-named method first, then the handler list in order. `delay(ms, fn)` is a one-shot debounce timer (OnUpdate); `fn` may be a function or a method-name string — a second call replaces the pending callback. `after(ms, fn)` fires `fn` once after `ms` milliseconds via `C_Timer.After`; supports unlimited concurrent calls. `onLogin(isLogin, isReload)` fires on `PLAYER_ENTERING_WORLD` only when `onLogin` is defined.

## Player API (`ns.wow.Player`)

Colon methods (take `self`): `GetClassName`, `GetHealthPercent`, `GetHealthValues`, `GetPower(idx)`, `GetPowerMax(idx)`, `GetPowerPercent(idx)`, `GetPowerValues(idx)`, `GetXPPercent`, `GetRestPercent`, `isMaxLevel`, `GetProfessions`, `GetRewardOptions`.

Dot functions (no self): `GetAverageItemLevel`, `GetClassId`, `GetHealth`, `GetHealthMax`, `GetLevel`, `GetMaxXP`, `GetMountIcon`, `GetName`, `GetPetHealthValues`, `GetPowerType`, `GetShapeshiftFormID`, `GetActiveSpecialization`, `GetPrimarySpecialization`, `GetRace`, `GetXP`, `GetXPExhaustion`, `HasTarget`, `HasToy`, `InCombat`, `IsAFK`, `isRested`, `IsResting`, `IsMountUsable`, `IsMountCollected`, `IsSpellKnown`, `Cast`, `Mount`, `UseToy`.

`GetProfessions()` returns/caches `{prof1, prof2, archaeology, fishing, cooking}`, each a `Profession` with `GetInfo()`. `GetRewardOptions()`/`ns.wow.GreatVault.getRewardOptions()` returns a `VaultRewards` (`rewards`, `counts`, `progress`, `best`, `bestN`) from the weekly-rewards API.

## Colors & icons

- Class colors: `ns.Colors.DeathKnight = {0.77, 0.12, 0.23}` … (0–1 float lists). `TransparentBlack = {0,0,0,0}`.
- `rgba(r, g, b, a)` → `ColorMixin` (r/g/b 0–255, a 0–1). `alpha(color, a)` → `{r,g,b,a}` list (accepts `ColorMixin` or list).
- `ns.Colors.Strings` — chat escape codes (`GREEN`/`WHITE`/`ORANGE`/`GREY`/`END`) and `Icons` texture markup.
- `ns.icons` simple keys: `CheckGreen`, `RedX`, `Vault`, `Theatre`, `Treasure`, `BackArrow`, `preMidnight`, `Nightfall`, `Alliance`, `Horde`, `Bag`, `Backpack`.
- Complex keys (`{path, coords, vertexColor?}`): `AllianceLight`, `HordeLight`, `DAMAGER`, `HEALER`, `TANK`, `Arcane`, `Fury`, `Holy`, `Preservation`, `Shadow`, `Vengeance`.
- `ns.icons.classes` — indexed 1–13 matching WoW class IDs (`classicon-warrior` … `classicon-evoker`).

## Settings

```lua
features.settings = {
  { title = "Category Title", fields = {
    { typ = "checkbox", name = "settingName", key = "dbKey",
      table = function(db) return db end,
      label = "Display Label", default = true, tooltip = "Help text",
      callback = function(setting, value) end },
    { typ = "slider", min = 0, max = 100, step = 1, ... },
    { typ = "dropdown", options = {"Option 1", "Option 2"}, ... },
  } },
}
```

Default callback calls `addOn:settingChanged(key, value, variable, setting)`.

## TOC metadata fields

| Field | Effect |
|---|---|
| `X-NUI-DB` | SavedVariables global name → `ns.db` |
| `X-NUI-DB-VERSION` | DB version used for migration |
| `X-NUI-COMMANDS` | Comma-separated slash command bases |
| `X-NUI-COMPARTMENT` | Compartment click handler global name |
| `X-NUI-API` | Shared API global name → `ns.api` (created if absent) |
| `X-NUI-UI` | UI library global name → `ns.ui` |

## Gotchas

- **`split(token, str)` takes the token FIRST**, opposite the usual convention; the token is a char class, so each character splits independently.
- **`delay` keeps only one active timer per addon** — a second `delay` call replaces the pending OnUpdate, dropping the first callback. Use `after` when multiple concurrent timers are needed.
- **`maps.fill` is shallow** — it never recurses into existing sub-tables (the recursive branch is commented out); only `maps.merge` deep-merges.
- **`sets.Set` iterates with `ipairs`** — only array-style input works; map-style arguments (`Set{q=123}`) silently produce an empty set.
- **DB migration runs only when `version ~= db.version` AND `MigrateDB` is defined** — a fresh DB starts with `version == nil`, so the addon's `MigrateDB` must seed it from scratch.
- **`Print` prefix shortcut**: calling `self:Print(...)` where `self` is a string prepends that string as a sub-prefix; otherwise it prints under the addon's `_TITLE`.
