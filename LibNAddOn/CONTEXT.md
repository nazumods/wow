# LibNAddOn

**Deps:** none (base library) · **Commands:** `/lib`, `/rl`, `/fs`, `/etc` · **Exposes:** `LibNAddOn(features, o)` factory + `ns.lua`, `ns.wow`, `ns.icons`, `ns.Colors`

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
| `lua/strings.lua` | `ns.lua.strings` — `startsWith(str, start)`, `split(token, str)`, `duration(seconds, style?)`, `stripEscapes(str)` (strip `|c`/`|r` colour, `|T…|t` texture, `|A…|a` atlas; nil-safe) |
| `slashCommands.lua` | `ns.registerSlashCommands`; adds `registerCommand`/`SlashCmd`/`usage` to addon. Self-bootstraps `/lib` |
| `globals/globalCommands.lua` | Suite-wide convenience slash commands (unscoped, registered directly on `SlashCmdList`): `/rl` (ReloadUI), `/fs` (framestack toggle), `/etc` (Edit Mode) |
| `globals/colors.lua` | `ns.Colors` — class colors (0–1), `Strings` (color/icon escape codes), `rgba(r255,g255,b255,a01)`, `alpha(color, a)`, `hex(color)`/`code(color)`/`wrap(text, color)` (0–1 `{r,g,b}` → `"RRGGBB"`/`"|cffRRGGBB"`/`"|cff…|r"`), `className(name, classKey)` (class-colour a name) |
| `globals/wow.lua` | `ns.wow` — `maxLevel`, `Armor` (+`byClass`/`types`), `ClassKeys`, `ClassByKey`, `ClassKeyByToken` (locale-independent classToken → PascalCase key), `Specializations` |
| `globals/money.lua` | `ns.wow.CoinString(copper[, opts])` — plain-text coin string (`"1,023g 4s 5c"`, gold thousands-grouped, omits zero denominations, `"0c"` for zero) for editable/plain text where `GetCoinTextureString`'s icon markup won't render. `ns.wow.GoldString(copper[, opts])` — grouped **gold-only, no suffix** (`12345678` → `"1,234"`) for compact gold displays; truncates to whole gold, callers append their own `"g"`. Both thousands-group by default via a shared `grouped` helper (`BreakUpLargeNumbers`, plain `tostring` fallback for specs); pass `{ grouped = false }` to opt out. Spec'd standalone in `money_spec.lua`; `ns.wow`-guarded so load order / spec loading is independent |
| `globals/actionbars.lua` | `ns.wow.ReadActionBars()` — reads the live on-screen buttons addon-agnostically (`LibActionButton-1.0:GetAllButtons()` → Bartender/Dominos/ElvUI + Blizzard fallback) and returns a per-bar map keyed by slot-range bar (`floor((slot-1)/12)+1`, 1-15): `{ orientation=0\|1, numIcons, numRows, enabled, x, y }` (`x`/`y` = bounding-box screen left/top) — real, addon-driven geometry the Edit Mode layout can't give. Also reports the **pet bar** under key `pet` (from `PetActionButton*` geometry), and `mainPage` — the slot-range bar currently paging the main action bar (Bar 1's screen slot), i.e. the active stance/form/override page (lets a consumer tell a real stance bar from a dedicated bar using class-page slots). Built on two public primitives it shares so consumers don't re-derive them: `ns.wow.collectActionButtons()` (addon-agnostic array of on-screen action buttons — LAB + Blizzard name-scan) and `ns.wow.actionSlotOf(btn)` (a button's paged slot, LAB `_state_*` → Blizzard `.action`). Also `ns.wow.classifyBarRects(rects)`, the **pure** orientation/shape classifier. `classifyBarRects`/`actionSlotOf`/`collectActionButtons` are spec'd in `actionbars_spec.lua`; the frame-reading `ReadActionBars` stays in-game-tested |
| `globals/player.lua` | `ns.wow.Player`, `ns.wow.GreatVault`; `/lib player <method>` dump command |
| `globals/icons.lua` | `ns.icons` — atlas/path constants for classes, roles, specs, factions, common UI |
| `globals/items.lua` | `ns.wow.Items` — `GetIcon(itemID)`, `GetNumSlots(containerIndex)` |
| `globals.lua` | `ns.linkGlobals(addOn, features)` — wires `lua`/`wow`/`icons`/`Colors`/`api`/`ui` onto the namespace |
| `eventListener.lua` | `ns.createEventListener(addOn)` — event frame, `registerEvent`/`unregisterEvent`/`delay`/`after`/`coalesce`/`debounce`, `onLoad`/`onLogin` hooks |
| `cvar.lua` | `ns.linkCVarHelpers(addOn)` — `SetTemporaryCVar(cvar, value, enforce?)` (backs up the user's original once, sets the new value, arms a `PLAYER_LOGOUT` restore), `RestoreCVar(cvar)` / `RestoreCVars()` (put originals back now; logout runs `RestoreCVars` automatically). Guards a transient override from getting stuck if the addon is disabled/uninstalled mid-override. **`enforce = true`** additionally re-asserts the value whenever a `CVAR_UPDATE` shows it drifted (user or another addon changed it), guarded by a suppress flag + value-compare so our own writes never loop; enforcement stops when the CVar is restored |
| `tooltip.lua` | `ns.linkTooltipHelpers(addOn)` — `OnItemTooltip(fn)`: registers `fn(tooltip, data)` as a `TooltipDataProcessor` post-call for `Enum.TooltipDataType.Item`, pre-guarded against forbidden tooltips + nil data (and a no-op when the client lacks `TooltipDataProcessor`). Wraps the boilerplate every headless tooltip addon repeated |
| `database.lua` | `ns.setupDB(name, addOn, ops)` — links `_G[dbName]` → `addOn.db`, triggers `MigrateDB` on version mismatch |
| `settings.lua` | `ns.registerSettings(addOn, name, features)` — Blizzard Settings API (checkbox/slider/dropdown/**element**, the last a settingless custom-frame initializer positioned in field order) |
| `changelog.lua` | `ns.registerChangelog(addOn, name, parentName?)` — adds a **"Changelog"** button to the addon's settings category (via `CreateSettingsButtonInitializer` + `Settings.RegisterInitializer`, deferred to `ADDON_LOADED`) that opens `addOn.changelog` (a newest-first `{version, notes}` list from the addon's `changelog.lua`, appended at release by `release.sh`) in LibNUI's shared `CopyWindow`. Uses the addon's own category when it has one — resolved via `addOn.settingsCategoriesByTitle[_TITLE]` (set by `registerSettings`), so it lands on the right page whether that's a **top-level** category (Warbandeer) or a **subcategory** under a shared parent. An addon with **no settings of its own** still gets a home: a subcategory named `_TITLE` under `parentName` when given (the ShadowsOfUI-* addons pass `"Shadows of UI"`), else a top-level category. Display prefers `addOn.ui`, falls back to the global `LibNUI` if loaded, then chat. Adds `addOn:RegisterChangelog`/`ShowChangelog` |
| `api.lua` | `LibNAddOn(features, o)` — top-level factory function (global) |

## Factory: `LibNAddOn(features)`

```lua
LibNAddOn{ name = "MyAddon", addOn = ns, db = {...}, settings = {...} }  -- table form
local ns = LibNAddOn(...)                                                -- assignment form (vararg = name, ns)
ns:RegisterSettings{ {title = ..., fields = {...}}, ... }                -- settings with assignment form (file-load time)
```

All suite addons use the assignment form; everything else comes from `X-NUI-*` toc fields, plus `ns:RegisterSettings` for settings (which can't be expressed in toc metadata). The table form remains supported.

### `features` fields

| Field | Type | Description |
|---|---|---|
| `name` | string | Addon name (must match TOC filename) |
| `addOn` | table | The addon namespace (`ns`) |
| `db` | table? | `{ name, version }`; auto-built from `X-NUI-DB`/`X-NUI-DB-VERSION` if omitted |
| `settings` | table? | Settings category definitions (requires `db`); or call `addOn:RegisterSettings(settings)` after an assignment-form init, at file-load time |
| `slashCommands` | table? | Manual `{base = {cmd, ...}}` map; else auto from `X-NUI-COMMANDS` |
| `compartmentFn` | string? | Global fn name for compartment clicks; else `X-NUI-COMPARTMENT` |
| `lua`/`wow`/`icons`/`colors` | string? | Override the namespace key for each global table |
| `api` | string? | Shared API global name → `ns.api`; else `X-NUI-API` |
| `ui` | string? | UI library global name → `ns.ui`; else `X-NUI-UI` |

### Wiring order

`linkCommonFunctions` → `linkGlobals` → `createEventListener` → `linkCVarHelpers` → `linkTooltipHelpers` → `setupDB` (if db) → `registerSettings` (if settings) → `registerSlashCommands` → compartment handler.

`setupDB`/`registerSettings` register `ADDON_LOADED` handlers at positions **1** and **2** (db links + migrates, then settings register) so both run before `onLoad`.

## Resulting namespace

```
addOn._NAME, addOn._TITLE
addOn._eventListener (Frame), addOn._eventHandlers (table), addOn._cvarBackup (table)
addOn.lua, addOn.wow, addOn.icons, addOn.Colors
addOn.api (shared global, if configured), addOn.ui (LibNUI global, if configured)
addOn.db (linked on ADDON_LOADED), addOn.commands, addOn.settingsCategory
addOn.changelog (release history, if a changelog.lua ships)
Methods:   GetMetadata, Print, hook, registerEvent, unregisterEvent, delay, after, coalesce, debounce,
           registerCommand, SlashCmd, usage, SetTemporaryCVar, RestoreCVar, RestoreCVars,
           OnItemTooltip, RegisterSettings, GetSettingsParent, RegisterChangelog, ShowChangelog
Lifecycle: onLoad, onLogin, MigrateDB, settingChanged, CompartmentClick
```

## Class system

```lua
local MyClass = Class(Parent, function(self) ... end, { defaults })
local instance = MyClass:new{ field = value }
```

Construction order: copy defaults into `o` (missing keys only; plain-table defaults are deep-copied per instance, metatabled values shared by reference) → `parent:new(o)` → `Mixin(o, parent, class)` → `setmetatable` → `fn(o)` → `parent.onLoad(o)` → `class.onLoad(o)` → `defaults.onLoad(o)`.

## Lua utilities

### `ns.lua.maps`
| Function | Signature | Notes |
|---|---|---|
| `merge` | `(dest, ...) → dest` | Deep-merge; overwrites scalars, recurses sub-tables; copies plain sub-tables (never aliases the source), metatabled values by reference; skips `__index` |
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
| `duration` | `(seconds, style?) → string` — clock string; `style` `"m:ss"` (default) \| `"h:mm:ss"` \| `"auto"`; nil/neg → 0, fractions floored. Shared duration formatter (LibNUI Timer, ShadowsOfUI-Delves) |

## Event system

```lua
function addOn.EVENT_NAME(self, ...) end          -- method dispatch (named after event)
addOn:registerEvent("EVENT_NAME", handler, idx?)  -- handler list; idx inserts at position
addOn:unregisterEvent("EVENT_NAME", handler?)     -- nil handler clears all
```

Dispatch order: the same-named method first, then the handler list in order. `delay(ms, fn)` is a one-shot debounce timer (OnUpdate); `fn` may be a function or a method-name string — a second call replaces the pending callback. `after(ms, fn)` fires `fn` once after `ms` milliseconds via `C_Timer.After`; supports unlimited concurrent calls. `coalesce(key, ms, fn)` and `debounce(key, ms, fn)` are the two **keyed** trailing-edge timers — each key independent, unlike `delay`'s single addon-wide slot. They differ in *which* call in a burst fires:

- **`coalesce`** fires `ms` after the **first** call; calls arriving before it fires are dropped; then the key clears so the next call opens a fresh window. Under a sustained stream it keeps firing every `ms` (guaranteed progress).
- **`debounce`** fires `ms` after the **last** call; each call supersedes the pending fire and reschedules (a per-key monotonic generation is the cancel, since `C_Timer.After` can't be cancelled). Under a sustained stream it never fires until the burst settles.

Pick by whether you want the burst to quiet first (`debounce`) or a bounded-latency fire (`coalesce`). Both target high-frequency events (`QUEST_LOG_UPDATE`, `CURRENCY_DISPLAY_UPDATE`, `COMBAT_RATING_UPDATE`) that would otherwise trigger a full refresh dozens of times a second. Warbandeer_Characters' broker `eventDelay` is built on `debounce`. `onLogin(isLogin, isReload)` fires on `PLAYER_ENTERING_WORLD` only when `onLogin` is defined.

## Player API (`ns.wow.Player`)

Colon methods (take `self`): `GetClassName`, `GetHealthPercent`, `GetHealthValues`, `GetPower(idx)`, `GetPowerMax(idx)`, `GetPowerPercent(idx)`, `GetPowerValues(idx)`, `GetXPPercent`, `GetRestPercent`, `isMaxLevel`, `GetProfessions`, `GetRewardOptions`.

Dot functions (no self): `GetAverageItemLevel`, `GetClassId`, `GetHealth`, `GetHealthMax`, `GetLevel`, `GetMaxXP`, `GetMountIcon`, `GetName`, `GetPetHealthValues`, `GetPowerType`, `GetShapeshiftFormID`, `GetActiveSpecialization`, `GetPrimarySpecialization`, `GetRace`, `GetXP`, `GetXPExhaustion`, `HasTarget`, `HasToy`, `InCombat`, `IsAFK`, `isRested`, `IsResting`, `IsMountUsable`, `IsMountCollected`, `IsSpellKnown`, `Cast`, `Mount`, `UseToy`.

`GetProfessions()` returns/caches `{prof1, prof2, archaeology, fishing, cooking}`, each a `Profession` with `GetInfo()`. `GetRewardOptions()`/`ns.wow.GreatVault.getRewardOptions()` returns a `VaultRewards` (`rewards`, `counts`, `progress`, `best`, `bestN`) from the weekly-rewards API.

## Colors & icons

- Class colors: `ns.Colors.DeathKnight = {0.77, 0.12, 0.23}` … (0–1 float lists). `TransparentBlack = {0,0,0,0}`.
- `rgba(r, g, b, a)` → `ColorMixin` (r/g/b 0–255, a 0–1). `alpha(color, a)` → `{r,g,b,a}` list (accepts `ColorMixin` or list).
- Escape-string builders from a `{r,g,b}` (0–1) list: `hex(color)` → `"RRGGBB"`, `code(color)` → `"|cffRRGGBB"` (pair with `|r`), `wrap(text, color)` → `"|cffRRGGBB<text>|r"`. `className(name, classKey)` wraps a name in its class colour (PascalCase keys matching `Character.classKey`), passing the name through unchanged when the class is unknown. Used by the headless tooltip addons + Warbandeer views in place of hand-rolled `("|cff%02x%02x%02x"):format(floor(c*255+0.5)…)`.
- `ns.Colors.Strings` — chat escape codes (`GREEN`/`WHITE`/`ORANGE`/`GREY`/`END`) and `Icons` texture markup.
- `ns.icons` simple keys: `CheckGreen`, `RedX`, `Vault`, `Theatre`, `Treasure`, `BackArrow`, `preMidnight`, `Nightfall`, `Alliance`, `Horde`, `Bag`, `Backpack`.
- Complex keys (`{path, coords, vertexColor?}`): `AllianceLight`, `HordeLight`, `DAMAGER`, `HEALER`, `TANK`, `Arcane`, `Fury`, `Holy`, `Preservation`, `Shadow`, `Vengeance`.
- `ns.icons.classes` — indexed 1–13 matching WoW class IDs (`classicon-warrior` … `classicon-evoker`).

## Settings

```lua
features.settings = {
  { title = "Category Title",
    parent = "Shadows of UI", -- optional: nest as a subcategory under a shared parent group
    fields = {
    { typ = "checkbox", name = "settingName", key = "dbKey",
      table = function(db) return db end,
      label = "Display Label", default = true, tooltip = "Help text",
      callback = function(setting, value) end },
    { typ = "slider", min = 0, max = 100, step = 1, ... },
    { typ = "dropdown", options = {"Option 1", "Option 2"}, ... },
    { typ = "element", template = "MyVirtualFrameTemplate", initData = {} }, -- settingless custom frame
  } },
}
```

The `element` type takes no `key`/`table`/setting — it registers `Settings.CreateElementInitializer(template, initData)` at that position, so a bespoke panel (e.g. a live preview) renders in field order among the stock controls. `template` is a `virtual` XML frame whose mixin builds/updates it; the mixin must be a global (for the XML `mixin=`). Contrast the changelog button, which always appends at the end.

A category with `parent = "<name>"` registers as a Settings **subcategory** under a shared parent group (created+registered once). The parent is keyed by name in a LibNAddOn-global table, so every addon (and every category) using the same name converges on one group. `addOn:GetSettingsParent(name)` exposes the same get-or-create for addons that build their panel another way (e.g. a LibNUI `SettingsFrame:RegisterSubcategory(parent, ...)`). Such addons should assign the returned category to `addOn.settingsCategory`, so `RegisterChangelog`'s button reuses that panel instead of minting a duplicate subcategory — the changelog fallback resolves the addon's category as `settingsCategoriesByTitle[_TITLE]` (declarative path) **or** `settingsCategory` (imperative path).

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
- **`delay` keeps only one active timer per addon** — a second `delay` call replaces the pending OnUpdate, dropping the first callback. Use `after` when multiple concurrent timers are needed, or the keyed `coalesce`/`debounce` to collapse a same-key storm into one fire.
- **`coalesce` fires the FIRST call's `fn`; `debounce` fires the LAST** — they are mirror images. `coalesce` drops later same-key calls in the window (their `fn` never runs), so close over stable state. `debounce` supersedes on each call, so the newest closure wins and the fire slides `ms` past the last call. Reach for `debounce` when the burst should settle first (broker scans), `coalesce` when you need a guaranteed fire within `ms` even under a non-stop stream.
- **`maps.fill` is shallow** — it never recurses into existing sub-tables (the recursive branch is commented out); only `maps.merge` deep-merges.
- **`sets.Set` iterates with `ipairs`** — only array-style input works; map-style arguments (`Set{q=123}`) silently produce an empty set.
- **DB migration runs only when `version ~= db.version` AND `MigrateDB` is defined** — a fresh DB starts with `version == nil`, so the addon's `MigrateDB` must seed it from scratch.
- **`Print` prefix shortcut**: calling `self:Print(...)` where `self` is a string prepends that string as a sub-prefix; otherwise it prints under the addon's `_TITLE`.
