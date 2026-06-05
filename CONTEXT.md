# WoW AddOn Suite — Full Code Context

> **Purpose:** Complete code reference so Claude doesn't have to re-read source files.
> Covers every Nazuraki addon: LibNAddOn, LibNUI, Warbandeer suite, ShadowsOfUI suite, CombatOutline, Recycle, ShadowsOfUI-DMF.

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
    +-- Warbandeer_Bars_RGS  (LibNUI, no Warbandeer_Characters dep)
    +-- CombatOutline    (LibNAddOn only, no LibNUI)
    +-- ShadowsOfUI-DMF (LibNAddOn only, no LibNUI)

(no LibN dependency):
    HideBagBar  (raw WoW API only)
```

---

## Table of Contents

1. [LibNAddOn](#1-libnaddontoc)
2. [LibNUI](#2-libnutoc)
3. [Warbandeer_Characters](#3-warbandeer_characters)
4. [Warbandeer](#4-warbandeer-main-ui)
5. [Warbandeer_Alias](#5-warbandeer_alias)
6. [Warbandeer_Collected](#6-warbandeer_collected)
7. [ShadowsOfUI-XP](#7-shadowsofui-xp)
8. [HideStanceBar](#8-hidestancebar)
9. [HideBagBar](#9-hidebagbar)
10. [CombatOutline](#10-combatoutline)
11. [Recycle](#11-recycle)
12. [ShadowsOfUI-DMF](#12-shadowsofui-dmf)
13. [Warbandeer_Bars_RGS](#13-warbandeer_bars_rgs)

---

# 1. LibNAddOn

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

---

# 2. LibNUI

OOP UI widget library. Global: `LibNUI` (also `ns.ui` in consuming addons).

## Files

| File | Purpose |
|---|---|
| `LibNUI/globals.lua` | Bootstrap, create `LibNUI` global, `/nui version`, `/nui test` |
| `LibNUI/constants.lua` | `ui.edge`, `ui.layer`, `ui.wrap`, `ui.justify`, `ui.fonts` |
| `LibNUI/Region.lua` | Abstract base — root of widget hierarchy |
| `LibNUI/Texture.lua` | Wraps WoW Texture objects |
| `LibNUI/Label.lua` | Wraps FontString objects |
| `LibNUI/Frame.lua` | Core frame wrapper (events, dragging, animation) |
| `LibNUI/BgFrame.lua` | Frame with auto-created backdrop Texture |
| `LibNUI/Dialog.lua` | WoW Dialog frame (DIALOG strata, title bar, Escape) |
| `LibNUI/StatusBar.lua` | Wraps WoW StatusBar with fill/backdrop |
| `LibNUI/Button.lua` | Interactive button with glow, keybinds, cooldown, tooltip |
| `LibNUI/SecureButton.lua` | SecureActionButtonTemplate (spells/toys in combat) |
| `LibNUI/CheckButton.lua` | Toggle checkbox |
| `LibNUI/AutoWidget.lua` | Factory: auto-selects Label, Texture, or Button |
| `LibNUI/EditBox.lua` | Text input field |
| `LibNUI/ScrollFrame.lua` | Scrollable container |
| `LibNUI/CleanFrame.lua` | Styled frame with dark background and border |
| `LibNUI/Cell.lua` | Table cell, auto-renders as Label or Texture |
| `LibNUI/TableCol.lua` | Column header strip; `header` is a Frame so it can carry mouse scripts (e.g. `tooltip`). The Label/Texture content is parented inside and surfaced as `header.label` / `header.texture` |
| `LibNUI/TableRow.lua` | Row header strip |
| `LibNUI/TableFrame.lua` | Full data grid with headers and cells |
| `LibNUI/TitleFrame.lua` | Windowed frame with title bar, icon, close button |
| `LibNUI/TabFrame.lua` | Tabbed container with button bar |
| `LibNUI/Tooltip.lua` | Custom tooltip with line pooling |
| `LibNUI/settings/SettingsFrame.lua` | WoW Settings panel container |
| `LibNUI/settings/TextSetting.lua` | Label + EditBox setting control |
| `LibNUI/settings/ToggleSetting.lua` | Label + CheckButton setting control |

## Class Hierarchy

```
Region
 +-- Texture
 +-- Label
 +-- Frame
      +-- BgFrame
      |    +-- TableCol
      |    +-- TableRow
      +-- Dialog
      +-- StatusBar
      +-- Button
      |    +-- SecureButton
      |    +-- CheckButton
      +-- EditBox
      +-- ScrollFrame
      +-- CleanFrame
      |    +-- TitleFrame
      |    +-- Tooltip
      +-- TabFrame
      +-- SettingsFrame
      +-- TextSetting
      +-- ToggleSetting
Cell (Frame subclass, standalone)
AutoWidget (standalone, no parent class)
```

## Constants

### `ui.edge`
`Top`, `Center`, `TopLeft`, `TopRight`, `Bottom`, `BottomLeft`, `BottomRight`, `Left`, `Right`

### `ui.layer`
`Background`, `Border`, `Artwork`, `Overlay`, `Highlight`

### `ui.justify`
`Left`, `Center`, `Right`, `Top`, `Middle`, `Bottom`

### `ui.wrap`
`Clamp`, `Repeat`, `Mirror`

### `ui.fonts`
`GameFontHighlight`, `GameFontHighlightSmall`, `SystemFont_Med2`

## Region (Base Class)

### Constructor
Calls `self:CreateWidget()` (subclass provides), then applies `position` and `alpha`.

### Methods
| Method | Description |
|---|---|
| `Parent(parent)` | Set parent (unwraps `_widget`) |
| `Position(position)` | Apply declarative position table |
| `SetPoint(point, target?, edge?, x?, y?)` | Anchor (auto-unwraps target) |
| `All()` | `SetAllPoints()` |
| `ClearAllPoints()` | `ClearAllPoints()` |
| `Center/Top/TopLeft/TopRight/Bottom/BottomLeft/BottomRight/Left/Right(...)` | Shorthand anchors |
| `Size(x?, y?)` | Getter/setter |
| `Width(w?)` / `Height(h?)` | Getter/setter |
| `Show()` / `Hide()` / `SetShown(bool)` / `Toggle()` | Visibility |
| `Alpha(a?)` | Getter/setter |

### Position System
```lua
position = {
    TopLeft  = { parent, "BOTTOMLEFT", x, y },  -- table → unpack as args
    Width    = 200,                               -- scalar → single arg
    All      = true,                              -- true → no args
    Hide     = false,                             -- false → skip
}
```
Any key matching a method name on the instance is valid.

## Texture

**Parent:** Region | **Registered:** `ui.Texture`

### Constructor Options
`parent`, `name`, `layer`, `template`, `atlas`, `atlasSize`, `rotation`, `color`, `vertexColor`, `blendMode`, `gradient`, `path`, `coords`

### Methods
`Atlas(...)`, `Texture(texture)`, `Color(r,g,b,a | table | ColorMixin)`, `SetVertexColor(...)`, `Coords(...)`

## Label

**Parent:** Region | **Registered:** `ui.Label`

### Constructor Options
`parent`, `name`, `layer` (default `Artwork`), `font` (default `GameFontHighlight`), `fontObj`, `fontInfo`, `text`, `color`, `justifyH`, `justifyV`

### Methods
`Text(text?)` — getter/setter, returns self when setting
`Color(r,g,b,a | table | ColorMixin)` — returns self

## Frame

**Parent:** Region | **Registered:** `ui.Frame`

### Constructor Options
`type` (default `"Frame"`), `name`, `parent`, `template`, `strata`, `clamped`, `scale`, `level`, `special`, `background`, `drag`, `dragTarget`, `scripts`, `events`, `unitEvents`

### Methods
| Category | Methods |
|---|---|
| Events | `OnEvent`, `RegisterScript(...)`, `SetScript(event, handler)`, `RemoveScript(event)`, `listenForEvents()`, `registerEvent(event)`, `unregisterEvent(event)` |
| Dragging | `makeDraggable()`, `makeContainerDraggable()`, `setDragTarget(target)` |
| Animation | `startUpdates()` (calls `onUpdate(elapsed_ms)` each frame, ms not seconds), `stopUpdates()`, `delay(ms, fn)` |
| Properties | `Attribute(name, value?)`, `Level(level?)` |

**`special = true`**: Registers in `_G` and `UISpecialFrames` (Escape closes it).

**`events`**: List of event names. Frame's `OnEvent` dispatches to `self[eventName](self, ...)`.

## BgFrame

**Parent:** Frame | **Registered:** `ui.BgFrame`

Default backdrop: `{color = {0,0,0,0.8}}`. Creates Texture in OVERLAY layer.

Methods: `backdropColor(...)`, `backdropTexture(...)`

## StatusBar

**Parent:** Frame | **Registered:** `ui.StatusBar` | **Type:** `"StatusBar"`

### Constructor Options
`backdrop`, `fill` (`{color, gradient, blend}`), `color`, `texture` (string or table with `coords`), `orientation`, `min`, `max`

### Methods
`Color(c)`, `Texture(t)`, `SetValue(v)` — custom TexCoord clipping if table-based texture

## Button

**Parent:** Frame | **Registered:** `ui.Button` | **Type:** `"Button"`

### Constructor Options
`normal` (`{texture, coords}`), `onClick`, `bindLeftClick`, `kbLabel`, `glow` (default true), `itemID`, `tooltip`, `OnChange`, `OnClick`

Default scripts: `OnEnter`, `OnLeave`, `OnMouseDown`, `OnMouseUp`, `OnReceiveDrag`

### Tooltip Config
```lua
tooltip = { _widget, owner, point, itemId, toyId, spellId, mountSpellId }
```

## SecureButton

**Parent:** Button | **Registered:** `ui.SecureButton` | **Template:** `"SecureActionButtonTemplate"`

Options: `actions` — list of `{type, target, spell, toy}`

**Warning:** Never `SetAttribute` during combat.

## CheckButton

**Parent:** Button | **Registered:** `ui.CheckButton` | **Type:** `"CheckButton"` | **Template:** `"ChatConfigCheckButtonTemplate"`

Options: `text`, `OnToggle`
Methods: `OnClick()`, `Checked(isChecked?)`

## AutoWidget

**Registered:** `ui.AutoWidget` | Standalone factory.

| Condition | Creates |
|---|---|
| `onClick` set | Button |
| `path` or `atlas` set | Texture |
| Otherwise | Label |

Options: `parent`, `onClick`, `path`, `atlas`, `atlasSize`, `coords`, `vertexColor`, `position`, `label`, `font`, `color`, `justifyH`

## EditBox

**Parent:** Frame | **Registered:** `ui.EditBox` | **Type:** `"EditBox"` | **Template:** `"InputBoxTemplate"`

Options: `fontObj`, `autoFocus`, `text`, `cursorPosition`
Methods: `Text(text?)`

## ScrollFrame

**Parent:** Frame | **Registered:** `ui.ScrollFrame` | **Type:** `"ScrollFrame"` | **Template:** `"UIPanelScrollFrameTemplate"`

Methods: `Child(child?)`

## CleanFrame

**Parent:** Frame | **Registered:** `ui.CleanFrame`

Defaults: `parent=UIParent`, `clamped=true`, `strata="MEDIUM"`, `background={0.114, 0.141, 0.165, 1}`
Creates border Frame child using `BackdropTemplate` with tooltip border.

## TitleFrame

**Parent:** CleanFrame | **Registered:** `ui.TitleFrame`

Defaults: `drag=true` (inherits CleanFrame defaults)
Options: `title`

### Sub-fields
`self.titlebar` (Frame), `self.titlebar.title` (Label), `self.titlebar.icon` (Frame with `.icon` Texture), `self.closeButton` (Frame with `.icon` Texture)

Methods: `Title(text)`

## TabFrame

**Parent:** Frame | **Registered:** `ui.TabFrame`

### Constructor Options
`tabs` (string[]), `tabHeight` (24), `tabWidth` (80), `activeColor`, `inactiveColor`, `onSelect`

### Sub-fields
`self.tabBar`, `self.content`, `self._tabs` (Frame[]), `self._panels` (Frame[]), `self._selected`

### Methods
`Select(index)`, `Tab(index)` → content panel Frame, `Selected()` → index

## TableFrame

**Parent:** Frame | **Registered:** `ui.TableFrame`

### Constructor Options
`colNames`, `rowNames`, `colInfo`, `rowInfo`, `numCols`, `numRows`, `cellWidth` (100), `cellHeight` (20), `headerWidth`, `headerHeight`, `headerFont`, `colHeaderFont`, `rowHeaderFont`, `padding` (2), `autosize`, `backdrop`, `colBackdrop`, `data`, `GetData`

### Critical: offsetX / offsetY
Computed **once at construction**: `offsetX = rowNames ~= nil ? headerWidth : 0`. For dynamic tables, pass `rowNames = {}` / `colNames = {}`.

### Sub-fields
`self.cols` (TableCol[]), `self.rows` (TableRow[]), `self.cells` (Cell[][]), `self.rowArea` (Frame)

### Methods
`onLoad()`, `row(n)`, `col(n)`, `set(row, col, element)`, `addCol(info)`, `addRow(info)`, `update()`, `setFooter(data)`

### Footer row (`setFooter(data)`)
Lazily builds a footer TableRow pinned below `rowArea`; `data` is per-column cell data (same shape as a row's cell data) keyed by column index — columns absent from `data` render no footer cell. Re-callable to refresh (reuses footer cells like `update()`). Optional construction fields: `footerHeight` (defaults to `cellHeight`), `footerBackdrop`. Footer cells live in `self.footerCells` / row in `self.footerRow`.

### `colInfo` Fields
`name`, `width`, `atlas`, `atlasSize`, `padding`, `padLeft`, `justifyH`, `color`, `backdrop`, `autosize`, `tooltip` (string or string[] — shown on header hover via `ui.tip`)

### `rowInfo` Fields
`name`, `height`, `atlas`, `atlasSize`, `justifyH`, `color`, `backdrop`

## Tooltip

**Parent:** CleanFrame | **Registered:** `ui.Tooltip`

Defaults: `strata="DIALOG"`, `background={0,0,0,0.7}`, `inset=3`

### Methods
`ClearLines()`, `AddLine(text, r?, g?, b?, a?)`, `AnchorTo(frame, anchor, dx?, dy?)`, `ShowForCharacter(toon, position)`, `MaxWidth(w)` (cap content width; pass nil to clear — deviates from getter pattern since nil is a meaningful set value)

### `maxHeight` (scrolling menus)
Optional constructor field. When the stacked constructor `lines` exceed `maxHeight`, they're
clipped into an inner mouse-wheel-scrollable viewport (the CleanFrame border is anchored outside
`self`, so an inner `_port` frame is clipped, not the tooltip). Only the constructor `lines` path
is scroll-aware (not `AddLine`). Used by the Detail view's character picker.

Singleton: `ui.tip`
Helpers: `ui.ShowCharacterTooltip(toon, frame, position)`, `ui.HideCharacterTooltip()`

## Settings Widgets

### SettingsFrame
**Parent:** Frame | Methods: `AddControl(control)`, `RegisterCategory(name?)`, `RegisterSubcategory(parentCategory, name?)`, `AddTextControl(label, table, field)`, `AddToggleControl(label, table, field)`

### TextSetting
**Parent:** Frame | Options: `label`, `table`, `field`, `editor`, `SettingChanged`

### ToggleSetting
**Parent:** Frame | Options: `label`, `table`, `field`, `SettingChanged`

---

# 3. Warbandeer_Characters

Data collection backbone. Populates `WarbandeerApi` global.

## TOC
```
Interface: 120001, Dependencies: LibNAddOn, LibNUI
SavedVariables: WarbandeerCharDB (version 7)
X-NUI-COMMANDS: /characters, /wbc
X-NUI-API: WarbandeerApi, X-NUI-UI: LibNUI
```

## Files

| File | Purpose |
|---|---|
| `init.lua` | LibNAddOn assignment form bootstrap |
| `types.lua` | LuaLS aliases for `Specialization`, `SpecializationKey` |
| `broker.lua` | `Broker` class, `RegisterBroker`, `InitBrokers`, reset constants |
| `database.lua` | `MigrateDB` (v6), `initialize`, `/characters list/delete` |
| `main.lua` | `refresh`, `refreshQueue` (one broker per 100ms), `/characters refresh/dump` |
| `login.lua` | `onLogin` → `initialize()` then `refresh()` |
| `api.lua` | `WarbandeerApi` public methods |
| `data/basic.lua` | Broker: level, specialization, professions |
| `data/currency.lua` | Broker: `RestoredCofferKey` (currency 3028) |
| `data/items.lua` | Broker: bag inventory |
| `data/professions.lua` | Broker: per-expansion skill levels, spec points, per-expansion learned recipes (ids+names). Also `ns.api.professionInfo` |
| `data/concentration.lua` | Broker: `data` — Midnight concentration currency per crafting prof (qty/max/recharge), keyed by parent skillLineID |
| `data/races.lua` | Race tables, `NormalizeRaceId()` |
| `data/quests.lua` | Broker: `UndermineStoryMode`, `WWIRep`, `delves` |
| `data/daily.lua` | Broker: (empty) |
| `data/playtime.lua` | Broker: `total` seconds, `byPatch` baseline per WoW version |
| `data/weekly.lua` | Broker: `DMF`, `preMidnight`, `caches`, `vault` |
| `data/instances.lua` | Broker: `locks` (instance lockouts) |
| `data/equipment.lua` | Broker: `slots`, `ilvl` |
| `data/artifacts.lua` | Broker: `hidden`, `hiddenColors`, `classHall` |
| `data/reputation.lua` | Broker: `legion` (9 Legion faction standings) |
| `dump.lua` | `stat` command — warband-wide playtime/class statistics |
| `missing.lua` | `missing` command — lists characters missing data (gold, playtime, profession detail, recipe capture, …) |

## WarbandeerApi Methods

```lua
WarbandeerApi:GetCurrentCharacter()       → string
WarbandeerApi:GetCharacterData(char?)     → Character
WarbandeerApi:GetNumCharacters()          → integer
WarbandeerApi:GetNumMaxLevel()            → integer
WarbandeerApi:GetAllCharacters()          → Character[]
WarbandeerApi:GetAllianceCharacters()     → Character[]
WarbandeerApi:GetHordeCharacters()        → Character[]
```

Also on API table: `ALLIANCE_RACES`, `HORDE_RACES`, `professionInfo`, `SettingsCategory`, `AliasSettingsCategory`

## Character Struct

```lua
-- Top-level (set at creation):
name, classId, className, classKey, race, raceId, raceIdx, isAlliance, realm

-- Sub-tables (populated by brokers):
basic = {
  level, specialization = { primary, active, role, key },
  professions = { primary, secondary, fishing, cooking },
}
currency = { RestoredCofferKey }
items = {
  bags = { [1..N] = {id, slots}, GoblinMiniFridge?, ArathorSatchel?, PortableRefridgerator? },
  reagentBag = { id, slots },
}
professions = {
  details = { [skillLineID] = {
    expansions = { {name, skillLevel, maxSkillLevel} }, specPoints?,
    recipes = { [expKey] = { learned = { {id, name} }, total } }?,  -- expKey: midnight/tww/df
  } },
}
concentration = {
  data = { [skillLineID] = { name, currencyId, quantity, maxQuantity,
                             rechargingAmountPerCycle, rechargingCycleDurationMS, lastUpdated } },
}
quests = {
  UndermineStoryMode,
  WWIRep = { complete, missing, Dornogal, Assembly, Hallowfall, Azjkahet, Undermine, Arathi, Karesh },
  delves = { complete, missing, [label] = bool },
}
dailies = {}
weeklies = {
  DMF,
  preMidnight = { eight, three },
  caches,
  vault = { rewards, counts, best, bestN }?,
}
instances = {
  locks = { [instanceID] = { [difficultyID] = { name, total, progress, reset, extended, isRaid } } },
}
equipment = {
  slots = { Head/Neck/Shoulder/.../OffHand = { name, link, ilvl, track?, trackLevel? } },
  ilvl,
}
artifacts = {
  hidden = { [SpecKey] = bool },
  hiddenColors = { wq = {progress, goal}, dungeon = {}, kills = {} },
  classHall,
}
reputation = {
  legion = { [factionID] = { name, done, current, max } },
}
playtime = {
  total,    -- total /played in seconds
  byPatch = { ["12.0.5"] = baseSeconds, ... }, -- /played at first login per patch
}
```

## Broker Definitions

| Broker | Fields | Events | Resets |
|---|---|---|---|
| `basic` | level, specialization, professions | `PLAYER_LEVEL_UP` (500ms delay) | — |
| `currency` | RestoredCofferKey | — | — |
| `items` | bags, reagentBag | — | — |
| `professions` | details (expansions, specPoints, per-exp recipes) | `TRADE_SKILL_SHOW` (500ms C_Timer) | — |
| `concentration` | data (per-prof Midnight concentration currency) | `CURRENCY_DISPLAY_UPDATE` | — |
| `quests` | UndermineStoryMode, WWIRep, delves | `QUEST_TURNED_IN`, `QUEST_ACCEPTED`, `QUEST_REMOVED`, `UNIT_QUEST_LOG_CHANGED` | — |
| `dailies` | (empty) | — | — |
| `weeklies` | DMF, preMidnight, caches, vault | `QUEST_TURNED_IN`, `WEEKLY_REWARDS_UPDATE` (1000ms delay) | DMF: `RESET_SUNDAY`, others: `RESET_WEEKLY` |
| `instances` | locks | `INSTANCE_LOCK_STOP` | `RESET_WEEKLY` |
| `equipment` | slots, ilvl | `PLAYER_EQUIPMENT_CHANGED` (500ms delay + item load) | — |
| `artifacts` | hidden, hiddenColors, classHall | `QUEST_TURNED_IN` | — |
| `reputation` | legion | — | — |
| `playtime` | total, byPatch | `TIME_PLAYED_MSG` (via `GetTimePlayed()` on Init) | — |

Reset constants: `RESET_SUNDAY=0`, `RESET_DAILY=1`, `RESET_WEEKLY=7`

## SavedVariables (`WarbandeerCharDB`)

```lua
{ version, numCharacters, lastDailyReset, lastReset, lastSundayReset,
  characters = { ["Name"] = Character } }
```

---

# 4. Warbandeer (Main UI)

## TOC
```
Interface: 120001, Dependencies: LibNAddOn, LibNUI, Warbandeer_Characters
SavedVariables: WarbandeerDB (version 2)
X-NUI-COMMANDS: /warband, /wb
X-NUI-COMPARTMENT: Warbandeer_OnAddonCompartmentClick
X-NUI-API: WarbandeerApi, X-NUI-UI: LibNUI
```

## Files

| File | Purpose |
|---|---|
| `init.lua` | Table form init with settings (defaultView dropdown). Defines `ns.views`, `ns.viewOrder` (selector order), class/race arrays, `MigrateDB`, `onLoad` |
| `data.lua` | `ns.data` — `gearTiers`, `IlvlColor()`, `minorFactions`, `minorFactionMaxStanding`. Midnight entries: Delves→Valeera (2742→2744, friendship rep), Silvermoon Court subfactions (2710→2711-2714). Profession helpers: `EstimateConcentration`, `FindProf`, `GetProfIntent`, `SetProfIntent`, `GetProfToons`, `GetMainCrafter` |
| `controls/CharacterTooltip.lua` | `CharacterTooltip` singleton (CleanFrame) showing name/spec/class/realm/level |
| `views/Overview.lua` | `TopAlts` + `TabFrame` (Midnight/WWI tabs) + `Factions` + `Achievements`. `Factions` accepts `extraFactionIDs` (deduplicated against `GetMajorFactionIDs`); subfaction rendering has three tiers: major faction renown → friendship rep (Valeera) → standard C_Reputation standings |
| `views/SummaryColumns.lua` | `SummaryColumn` specs + `SummaryColumnsDelayed()` for DMF. Each column has `getData(toon)` for cells and optional `getFooter(toons)` for the footer cell. Footers: Character → max/levelling tally, Bag → total sub-par bags w/ split tooltip, Played → total playtime, Gold → total gold. Extra columns (Played, Gold) are appended from `views/summaryCol/*.lua` |
| `views/SummaryView.lua` | Two `ClassSummary` TableFrames (Alliance/Horde side-by-side). Footer row built via `TableFrame:setFooter` from each column's `getFooter`; a 1px divider still separates max-level from levelling rows |
| `views/GearView.lua` | `TabFrame` per armor type, 21-col TableFrame per tab |
| `views/DetailView.lua` | Single-character detail: level/race/class/realm/ilvl + per-profession intent editor. `BuildFilter` character-picker dropdown; writes `profIntent` via `ns.data.SetProfIntent` |
| `views/RoleView.lua` | `ClassTable` frames grouped by spec |
| `views/RaceView.lua` | 13-class × 29-race grid |
| `views/Legion.lua` | Hidden artifact appearances + Legion achievements |
| `views/Midnight.lua` | 54 achievement IDs in multi-column grid |
| `views/ProfsView.lua` | Top: best skill per expansion grid. Bottom: per-character detail on click |
| `views/MidnightProfs.lua` | One column per prof, one row per character: Midnight skill + concentration |
| `views/CraftingView.lua` | One row per crafting prof: Crafter (intent-based), Concentration, Learned Recipe %. Expansion-filter dropdown (Midnight wired) |
| `views/PlaytimeView.lua` | Per-character playtime breakdown |
| `views/WeeklyView.lua` | Per-character weekly content tracking |
| `window.lua` | `MainWindow` (TitleFrame), view selector, `ns:Open()`, `ns:view(name)`. Calls `view:BuildFilter(titlebar)` if defined, anchored left of close button |
| `commands.lua` | Registers base `""` (open) + one command per view |

## Views

| name | _title | Parent Class | Key Feature |
|---|---|---|---|
| `overview` | Overview | Frame | TopAlts, Factions, Achievements, TabFrame |
| `summary` | Summary | Frame | Dual ClassSummary tables (Alliance/Horde) |
| `gear` | Gear | TabFrame | 4 armor-type tabs, 16 equipment slot columns |
| `detail` | Detail | Frame | Per-character detail + profession intent editor; `BuildFilter` character picker |
| `roles` | Roles | Frame | ClassTable per class, grouped by spec |
| `races` | Races | TableFrame | 13×29 grid |
| `legion` | Legion | Frame | Hidden artifacts + achievements |
| `midnight` | Midnight | Frame | Achievement grid |
| `profs` | Professions | Frame | Profession skill grid + detail panel |
| `midnightprofs` | Midnight Profs | Frame | Profs × characters grid: Midnight skill + concentration |
| `crafting` | Crafting | Frame | Crafting profs: main crafter, concentration, learned recipe %; `BuildFilter` expansion dropdown |
| `playtime` | Playtime | Frame | Per-character playtime |
| `weekly` | Weekly | Frame | Per-character weekly content |

Views with a `BuildFilter(parent)` method get a filter widget in the title bar (shown only
while that view is active): `summary` (faction toggle), `crafting` (expansion dropdown),
`detail` (character picker).

## Overview — Factions Widget

`Factions` (TableFrame subclass) renders one row per major faction plus optional subfaction rows.

**Constructor options:**
- `expansionLevel` — passed to `C_MajorFactions.GetMajorFactionIDs()`; `10` = TWW, `11` = Midnight
- `extraFactionIDs` — additional IDs to always include, deduped against the API list (used for Midnight factions not returned by the API: Silvermoon Court `2710`, Slayer's Duellum `2770`)

**Subfaction rendering tiers** (tried in order):
1. `C_MajorFactions.GetMajorFactionData(id)` returns `renownLevel` → standard major faction renown display
2. `C_GossipInfo.GetFriendshipReputation(id)` returns `friendshipFactionID > 0` → friendship reputation, shows `currentLevel / maxLevel` from `GetFriendshipReputationRanks` (e.g. Valeera 2744, levels 1–60)
3. Fallback → `C_Reputation.GetFactionDataByID`, shows `currentStanding / minorFactionMaxStanding[parentID]` (e.g. Silvermoon Court subfactions 2711–2714)

**Midnight faction IDs (expansion 11):**
- `GetMajorFactionIDs(11)` returns 7 IDs: 4 zone factions, Delves `2742`, Prey `2764`, Ritual `2792`
- `2710` Silvermoon Court — not in `GetMajorFactionIDs`; added via `extraFactionIDs`. Subfactions: Magisters `2711`, Blood Knights `2712`, Farstriders `2713`, Shades of the Row `2714` (standard rep, max standing 42000)
- `2742` Delves S1 — in `GetMajorFactionIDs`. Subfaction: Valeera `2744` (friendship rep, `GetMajorFactionData` returns nil for 2744)
- `2770` Slayer's Duellum — not in `GetMajorFactionIDs`; added via `extraFactionIDs`

**API pitfalls:**
- `C_MajorFactions.GetMajorFactionData` and `GetMajorFactionRenownInfo` both return nil for Valeera (2744) even though `C_Reputation.IsMajorFaction(2744)` is true. Use `C_GossipInfo.GetFriendshipReputation` instead.
- `C_Reputation.IsFactionParagon` returns true for many in-progress Midnight factions because paragon caches exist from the start. Do NOT use it to determine if a faction is "done" — use `renownLevel == maxLevel` for major factions and `reaction >= 8` for standard reputation subfactions.
- Some standard reputation subfactions (e.g. Slayer's Duellum 2770) have a `friendshipFactionID` but with `maxLevel = 1` (dummy/uninitialized). Guard with `rankInfo.maxLevel > 1` before treating as a real friendship rep.

## MainWindow

Subclasses `TitleFrame`, `special=true`, `level=600`.
- `self.viewSelector` (Tooltip) — lists all views in `ns.viewOrder` (unlisted views appended, sorted by title), click to switch
- `MainWindow:view(name)` — hides current, shows named, updates title+size
- `ns:Open()` — lazy-creates window on first call
- `ns:view(name)` — `Open()` then `view(name)`

## SavedVariables (`WarbandeerDB`)
```lua
{ version = 2, settings = { defaultView = integer },
  -- per-character, per-profession crafting intent (v2): "main" | "secondary" | "gatherer"
  profIntent = { [charName] = { [skillLineID] = intent } } }
```
`MigrateDB`: v1 seeds `settings.defaultView`; v2 adds `profIntent = {}` (non-destructive).

---

# 5. Warbandeer_Alias

## TOC
```
Interface: 120001, Dependencies: LibNAddOn, LibNUI
SavedVariables: Warbandeer_AliasDB (version 1)
X-NUI-API: WarbandeerApi, X-NUI-UI: LibNUI
```

Single file: `addon.lua`

**Hook:** Wraps `ChatFrame[i]EditBox.SendText` for all `NUM_CHAT_WINDOWS`.
- If player name doesn't match alias → prepend `"(alias) "` to guild chat
- Skips messages starting with `/`, `!`, `#`, `@`, `?`
- Sends modified text with `(0)` (no history), then restores original text and manually adds to history
- Two modes: exact match or `startsWith` match

**Settings:** `SettingsFrame` with TextSetting (alias) and ToggleSetting (startsWith). Subcategory under `WarbandeerApi.SettingsCategory`.

**DB:** `{ version=1, settings = { alias, startsWith } }`

---

# 6. Warbandeer_Collected

## TOC
```
Interface: 120001, Dependencies: LibNAddOn, LibNUI, Warbandeer_Characters
SavedVariables: WarbandeerCollectedDB (version 2)
X-NUI-COMMANDS: /collected, /collect
X-NUI-COMPARTMENT: WarbandeerCollected_OnAddonCompartmentClick
X-NUI-API: WarbandeerApi, X-NUI-UI: LibNUI
```

## Files

| File | Purpose |
|---|---|
| `init.lua` | Assignment form init, `MigrateDB` (v2: ensures `db.sets/collected/total`) |
| `commands.lua` | `/collected scan` — iterates `ns.Sets`, calls `C_TransmogSets` APIs |
| `data/sets.lua` | `ns.Sets` array + `ns.Releases` array (Vanilla through TWW) |
| `DataView.lua` | TableFrame subclass — lock + name + 13 class columns, 10-shade gradient |
| `controls/InfoTip.lua` | Per-slot item tooltip (CleanFrame), `ui.ShowInfoTip/HideInfoTip` |
| `controls/LockoutView.lua` | Character lockout list (CleanFrame), `ns.ShowLockoutView/HideLockoutView` |
| `window.lua` | MainWindow (TitleFrame), ScrollFrame, counter label, `ns:Open()`, compartment click |

## Data Model (`ns.Sets`)
```lua
{ id, name, release, instance, difficulty, minLevel?,
  sets = { { id, name, classId }, {}, ... } }  -- 11-13 entries, indexed by class position
```

## Scan Logic
Iterates all groups → `C_TransmogSets.IsBaseSetCollected(set.id)` → if not, `GetSetPrimaryAppearances(set.id)` → stores `{collected, parts, total}`.

## DB (`WarbandeerCollectedDB`)
```lua
{ version=2, collected, total,
  sets = { [groupId] = { [setId] = true | {collected, parts, total} } } }
```

---

# 7. ShadowsOfUI-XP

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

---

# 8. HideStanceBar

## TOC
```
Interface: 120000, Category: Shadows of UI
Dependencies: LibNAddOn, LibNUI
SavedVariables: HideStanceBarDB (version 1), X-NUI-UI: LibNUI
```

Single file: `addon.lua`. Assignment form.

**DB:** `{ hide = { [classId] = true/nil } }`

Hides StanceBar by reparenting to a hidden `Hider` frame. Settings UI with per-class toggles (Warrior/Paladin/Rogue/Priest/Druid). Registered under "Shadows of UI" settings category.

---

# 9. HideBagBar

## TOC
```
Interface: 120000, Category: Shadows of UI
No Dependencies, no SavedVariables, no X-NUI-* fields
```

Single file: `addon.lua`. Raw WoW API only — no LibNAddOn.

Hides: `MainMenuBarBackpackButton`, `BagBarExpandToggle`, `CharacterBag0Slot`–`CharacterBag3Slot`, `CharacterReagentBag0Slot`.

---

# 10. CombatOutline

## TOC
```
Interface: 110002/110005/110007
Dependencies: LibNAddOn (no LibNUI)
SavedVariables: CombatOutlineDB
```

Single file: `core.lua`. Table form init.

`PLAYER_REGEN_DISABLED` → `SetCVar("OutlineEngineMode", 1)`
`PLAYER_REGEN_ENABLED` → `SetCVar("OutlineEngineMode", 0)`

---

# 11. Recycle

## TOC
```
Interface: 120001, Category: Inventory
Dependencies: LibNAddOn, LibNUI
SavedVariablesPerCharacter: RecycleDB (version 1)
X-NUI-COMMANDS: /recycle, X-NUI-UI: LibNUI
```

Single file: `addon.lua`. Assignment form.

**DB (per-character):**
```lua
{ settings = { sellGrey=true, silent=false, modKey="CTRL" },
  itemsToSell = { [itemID] = true }, version=1 }
```

**Features:**
- Auto-sells grey items + manually marked items on `MERCHANT_SHOW`
- Mod+RightClick on bag items to toggle sell mark (coin icon overlay)
- Baganator junk plugin integration if present
- Settings: sellGrey toggle, silent toggle
- `/recycle`, `/recycle clear`, `/recycle key CTRL|SHIFT|ALT`

---

# 12. ShadowsOfUI-DMF

## TOC
```
Interface: 120001, Category: Shadows of UI
Dependencies: LibNAddOn (no LibNUI)
No SavedVariables, no slash commands
```

Single file: `DMF.lua`. Assignment form `local ns = LibNAddOn(...)`.

**Headless Darkmoon Faire helper — no UI, no archaeology.**

### Features
- **Calendar detection** (`checkForDMF`): checks `C_Calendar` holiday textures (235446–235448) to determine if DMF is active; caches `startTime`/`endTime` for fast re-checks
- **Auto-buy**: when opening the merchant on Darkmoon Island during DMF week, automatically purchases required profession quest materials for any profession with skill ≥ 1 and quest not yet done
- **Quest auto-accept**: `QUEST_DETAIL` handler calls `AcceptQuest()` when you use a dungeon/raid/PvP drop item (Imbued Crystal, Monstrous Egg, etc.)
- **Gossip auto-complete**: `GOSSIP_SHOW` handler calls `C_GossipInfo.SelectOption()` for minigame quests you are on, have a token for, and haven't completed
- **Login alert**: prints "Darkmoon Faire is open!" on first login/reload if DMF is active

### Event lifecycle
Dynamic events (merchant, quest, gossip) are registered/unregistered based on DMF active status via `checkDMFStatus()`, called from `PLAYER_ENTERING_WORLD`, `ZONE_CHANGED_NEW_AREA`, and `CALENDAR_UPDATE_EVENT_LIST`.

### Profession data
All primary and secondary professions except Archaeology. Uses `C_TradeSkillUI.GetProfessionInfoBySkillLineID` to sum skill across all expansions for primary professions; uses direct `GetProfessionInfo` values for secondary (fishing, cooking).

### Key tables
| Table | Key → Value |
|---|---|
| `ProfessionQuestData` | professionId → `{ questId, questItems? }` |
| `ProfessionTradeSkillLines` | professionId → `{ skillLineId, ... }` (11 expansions) |
| `turnInItems` | itemId → questId (10 drop items) |
| `gossipQuestIds` | gossipOptionID → questId (7 minigames) |

---

# 13. Warbandeer_Bars_RGS

Action bar, keybind, macro, and outfit profile manager for duplicating setups across same-spec characters.

## TOC
```
Interface: 120001, Dependencies: LibNAddOn, LibNUI
SavedVariables: WarbandeerBarsRGSDB (version 1)
SavedVariablesPerCharacter: WarbandeerBarsRGSSettings
X-NUI-COMMANDS: /bars, /wbars, X-NUI-UI: LibNUI
```

## Files

| File | Purpose |
|---|---|
| `init.lua` | Table-form bootstrap, `MigrateDB`, per-char settings init (`WarbandeerBarsRGSSettings`) |
| `libs/base64.lua` | Base64 encode/decode |
| `libs/crc32.lua` | CRC32 integrity check |
| `capture.lua` | Reads WoW state → profile table: bars, binds, macros, pet bar, outfits |
| `restore.lua` | Applies profile table → WoW state with spell override/fallback chain |
| `serialize.lua` | Binary pack/unpack + base64 + CRC header for portable text encoding |
| `autosave.lua` | Auto-saves on `PLAYER_LOGIN`, `PLAYER_LOGOUT`, `ACTIVE_TALENT_GROUP_CHANGED` |
| `profilelist.lua` | `ns.BuildProfileList(parent, onSelect)` — scrollable profile list widget |
| `window.lua` | TitleFrame UI: profile list, text area, Export/Import/Save/Load/Delete, option checkboxes |

## Public API

```lua
ns.Capture(include, accountMacros, charMacros) → profile
ns.Restore(profile, include)
ns.Encode(profile)                             → string
ns.Decode(text)                                → profile, err
ns.BuildProfileList(parent, onSelect)          → scroll, Refresh(), GetSelected()
ns:Open()
```

## Profile table

```lua
{
  version  = 1,
  char     = "Nazuraki",
  class    = "MAGE",
  spec     = "Frost",
  slots    = { { id, type, index?, strindex? }, ... },
  binds    = { { command, key1?, key2? }, ... },
  macros   = { { id, name, icon, body }, ... },
  petslots = { { id, type, index?, strindex? }, ... },
  outfits  = { "Set Name", ... },
}
```

## SavedVariables (`WarbandeerBarsRGSDB`)

```lua
{ version = 1,
  profiles = { { name, char, class, spec, encoded, autosave? }, ... } }
```

## Per-character settings (`WarbandeerBarsRGSSettings`)

```lua
{ include = { bars=true, bindings=true, macros=true, petbar=false, outfits=true },
  accountMacros = true, charMacros = true }
```

## Auto-save behaviour

Fires `ns.Capture` (all options forced on) on login, logout, and spec change (500 ms delay).
Profile is keyed `"CharName - SpecName"` and overwrites the previous auto-save for that slot.
Auto-saves are flagged `autosave = true` in the profile entry and appear with a grey `[auto]` prefix in the list.

---

# Slash Command Registry

| Addon | Commands | Sub-commands |
|---|---|---|
| LibNAddOn | `/lib` | `player` |
| LibNUI | `/nui` | `version`, `test [key]` |
| Warbandeer_Characters | `/characters`, `/wbc` | `list`, `delete <name>`, `refresh`, `refresh items/locks`, `dump`, `dump bank/gt/locks/artifact`, `missing`, `missing me` |
| Warbandeer | `/warband`, `/wb` | `""` (open), `overview`, `summary`, `gear`, `detail`, `roles`, `races`, `legion`, `midnight`, `profs`, `midnightprofs`, `crafting`, `playtime`, `weekly`, `check legion` |
| Warbandeer_Collected | `/collected`, `/collect` | `scan` |
| Recycle | `/recycle` | `clear`, `key CTRL|SHIFT|ALT` |
| Warbandeer_Bars_RGS | `/bars`, `/wbars` | `""` (open) |
