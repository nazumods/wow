# WoW AddOn Suite — Claude Context

This context covers the **LibN**, **Warbandeer**, and **ShadowsOfUI** addon suites by Nazuraki, targeting WoW Retail (Interface 120000+). No build step, no package manager. All testing is done in-game.

## Addon Overview

### Libraries
| Addon | Purpose |
|---|---|
| `LibNAddOn` | Bootstrapping factory. Every addon depends on this. |
| `LibNUI` | OOP UI widget library wrapping all Blizzard frame types. |
| `LibNUI_Test` | Visual test harness for LibNUI (LoadOnDemand via `/nui test`). |

### Applications
| Addon | Purpose |
|---|---|
| `Warbandeer_Characters` | Data collection backbone. Records all warband character data; populates `WarbandeerApi`. |
| `Warbandeer` | Main warband viewer UI (tabbed multi-view window). |
| `Warbandeer_Alias` | Prepends a configurable alias to outgoing guild chat messages. |
| `Warbandeer_Collected` | Tracks transmog set collection progress across all expansions. |
| `ShadowsOfUI-XP` | Minimal full-width XP bar pinned to the bottom of the screen. Hides Blizzard's default bar. |

### Dependency Graph
```
LibNAddOn
    ↑
LibNUI ──────────────────────────→ LibNUI_Test (LoadOnDemand)
    ↑
    ├── ShadowsOfUI-XP
    ├── Warbandeer_Alias
    └── Warbandeer_Characters  (populates WarbandeerApi global)
            ↑
            ├── Warbandeer
            └── Warbandeer_Collected
```

`WarbandeerApi` is the inter-addon data bus. `Warbandeer_Characters` populates it; `Warbandeer` and `Warbandeer_Collected` consume it. `ShadowsOfUI-XP` and `Warbandeer_Alias` depend only on `LibNAddOn` + `LibNUI`.

---

## LibNAddOn — Bootstrapping Factory

**Entry point:** `api.lua` — `LibNAddOn(features)` factory function.

### Initialization Patterns
```lua
-- Table form (preferred for complex addons):
LibNAddOn{ name = "MyAddon", addOn = ns, db = "MyAddonDB", settings = {...} }

-- Assignment form (for simple addons):
local ns = LibNAddOn(...)
```

**Namespace convention:** `local _, ns = ...` in every file. `ns` is the addon table.

### What `LibNAddOn()` Wires Up
- `ns.lua` — Lua utilities (maps, sets, lists, class, strings)
- `ns.wow` — WoW globals (maxLevel, Armor, ClassKeys, Specializations, Player)
- `ns.icons` — icon paths
- `ns.Colors` — class colors, `rgba()`, `alpha()`
- `ns.api` — shared inter-addon API global (named by `X-NUI-API` toc field)
- `ns.ui` — LibNUI global (named by `X-NUI-UI` toc field)
- `ns.db` — SavedVariables (named by `X-NUI-DB` toc field), auto-linked on `ADDON_LOADED`
- Event listener (hidden Frame), slash commands, settings registration

### Lifecycle Hooks
- `addOn.onLoad` — called on `ADDON_LOADED`
- `addOn.onLogin` — called on `PLAYER_ENTERING_WORLD` (first login or `/reload` only)
- `addOn.MigrateDB(self, oldVersion)` — called automatically when DB version mismatch

### Event Registration
```lua
ns:registerEvent("EVENT_NAME", function(self, ...) end)
-- or direct assignment:
function ns.EVENT_NAME(self, ...) end
```

### Delay Helper
```lua
ns.delay(milliseconds, fn)  -- runs fn after ms via OnUpdate
```

### Class System (`ns.lua.Class`)
```lua
local MyClass = Class(ParentClass, function(self)
    -- constructor body
end, { defaultField = value })
```
- Single inheritance via `Mixin` + `setmetatable`
- `onLoad` lifecycle: parent's `onLoad` runs first, then class's
- `new{ option = value }` constructs an instance

### Slash Commands
```lua
ns:registerCommand("cmd", "subcmd", handler, "description")
ns:usage()   -- prints command tree
ns:SlashCmd  -- dispatcher
```

### Custom `.toc` Metadata Fields
| Field | Purpose |
|---|---|
| `X-NUI-DB` | SavedVariables global name (auto-linked as `ns.db`) |
| `X-NUI-DB-VERSION` | DB version for migration check |
| `X-NUI-COMMANDS` | Comma-separated slash commands (e.g. `/warband, /wb`) |
| `X-NUI-COMPARTMENT` | Global function name for addon compartment clicks |
| `X-NUI-API` | Shared global API table name (e.g. `WarbandeerApi`) |
| `X-NUI-UI` | UI library global name (e.g. `LibNUI`) |

---

## LibNUI — UI Widget Library

**Global:** `LibNUI` (also `ns.ui` in consuming addons via `X-NUI-UI`).

### Class Hierarchy
```
Region
├── Texture
├── Label
└── Frame
    ├── BgFrame
    │   ├── TableCol
    │   ├── TableRow
    │   └── CleanFrame
    │       ├── TitleFrame
    │       └── Tooltip
    ├── Button
    │   ├── CheckButton
    │   └── SecureButton
    ├── Dialog
    ├── EditBox
    ├── ScrollFrame
    ├── StatusBar
    └── TableFrame
AutoWidget  (standalone factory)
```

### Construction Pattern
```lua
local frame = ui.TitleFrame:new{
    title = "My Window",
    width = 400, height = 300,
    position = { Center = UIParent },
    special = true,   -- registers in UISpecialFrames (Escape to close)
}
```

### `_widget` Rule
Every instance has `self._widget` — the backing WoW UI object. **Never access `_widget` from outside a class.** Use the exposed methods.

### Getter/Setter Pattern
```lua
function MyClass:Value(v)
    if v == nil then return self._widget:GetValue() end
    self._widget:SetValue(v)
    return self
end
```

### `position` Table (Declarative Anchoring)
```lua
position = {
    TopLeft  = { parent, "BOTTOMLEFT", x, y },  -- table = unpacked args
    Width    = 200,                               -- scalar = single arg
    All      = true,                              -- true = call with no args
    Hide     = false,                             -- false = skip
}
```

### String Constants
```lua
ui.edge    -- "TOPLEFT", "CENTER", etc.
ui.layer   -- "BACKGROUND", "OVERLAY", etc.
ui.justify -- "LEFT", "CENTER", "RIGHT"
ui.wrap    -- "WORD", "NONE"
```

### TableFrame Gotcha
`offsetX`/`offsetY` are computed **once at construction** based on whether `rowNames`/`colNames` are non-nil. For dynamic tables, pass `rowNames = {}` / `colNames = {}` so offsets are correct before calling `addRow`/`addCol`.

### Naming Conventions
| Pattern | Convention |
|---|---|
| Public methods | `PascalCase` |
| Lifecycle hooks / callbacks | `camelCase` (`onLoad`, `onUpdate`) |
| Constructor init fields | `camelCase` (`cellWidth`, `headerHeight`) |
| Internal fields | `_prefixed` (`_widget`, `_tabs`) |

### `special = true`
Registers the frame in `_G` and `UISpecialFrames` so pressing Escape closes it. Only for top-level addon windows.

### SecureButton Warning
Uses `SecureActionButtonTemplate`. Never call `SetAttribute` during combat (taint).

---

## Warbandeer_Characters — Data Layer

**SavedVariables:** `WarbandeerCharDB` (current version: 6)
**Shared API global:** `WarbandeerApi`

### `WarbandeerApi` — Public Interface
```lua
WarbandeerApi.GetCurrentCharacter()    -- Character for logged-in toon
WarbandeerApi.GetCharacterData(char?)  -- Full data for specific character
WarbandeerApi.GetNumCharacters()
WarbandeerApi.GetNumMaxLevel()
WarbandeerApi.GetAllCharacters()
WarbandeerApi.GetAllianceCharacters()
WarbandeerApi.GetHordeCharacters()
```

### Character Struct Fields (top-level)
`name`, `classId`, `classKey`, `className`, `race`, `raceId`, `raceIdx`, `isAlliance`, `realm`, `IsLegionTimerunner`

Sub-tables populated by brokers: `basic`, `equipment`, `currency`, `items`, `weeklies`, `instances`, `quests`, `daily`, `professions`, `artifacts`

### Broker System
Each broker (defined in `data/`) has:
- `name` — broker identifier
- `fields` — map of field definitions:
  - `get(self, toon, currentValue)` — fetch current value
  - `event` + `eventFilter?` + `eventDelay?` + `eventHandler?` — auto-update on WoW events
  - `resetOn` — `ns.RESET_DAILY`, `ns.RESET_WEEKLY`, or `ns.RESET_SUNDAY`
  - `maxLevel = true` — skip update for non-max-level characters

Brokers: `basic`, `currency`, `items`, `professions`, `quests`, `daily`, `weekly`, `instances`, `equipment`, `artifacts`

### Refresh Flow
On login: `ns:InitBrokers()` (checks resets) → `ns:refresh()` (queues all brokers, drains one per 100ms via `ns.delay`)

---

## Warbandeer — Main UI

**Dependencies:** `LibNAddOn`, `LibNUI`, `Warbandeer_Characters`
**Slash commands:** `/warband`, `/wb`
**SavedVariables:** `WarbandeerDB`

### Views
`Overview`, `SummaryView`, `GearView`, `DetailView`, `RoleView`, `RaceView`, `Remix`, `Legion`, `Midnight`

Each view: `Class(Frame, ...)` with `name = "viewname"` and `_title = "Display Title"`. Registered in `ns.views` at load time.

### Window
`MainWindow` subclasses `TitleFrame`. Icon click shows a `Tooltip`-based view selector. `ns:Open()` lazily creates the window on first call.

### Key Helpers
- `IlvlColor(ilvl)` — color-coded ilvl string using WoW quality color globals
- `ns.NormalizeRaceId(raceId)` → `(raceIdx, isAlliance)`

---

## Warbandeer_Alias — Chat Prefix Utility

Single-file addon (`addon.lua`). Hooks `ChatFrame[i]EditBox.SendText`. If the character name matches the configured alias and chat type is `"GUILD"`, prepends `"(alias) "` to outgoing text, then restores original so history is clean.

Settings UI: `ui.SettingsFrame` + `ui.TextSetting` + `ui.ToggleSetting`. Registers under `WarbandeerApi.SettingsCategory` if available.

---

## Warbandeer_Collected — Transmog Tracker

**Dependencies:** `LibNAddOn`, `LibNUI`, `Warbandeer_Characters`
**Slash commands:** `/collected`, `/collect`
**SavedVariables:** `WarbandeerCollectedDB` (version 2)

### Data Model (`ns.Sets`)
Large table in `data/sets.lua`. Each entry is a raid group:
```lua
{ id = n, name = "...", release = "...", instance = id, difficulty = id,
  sets = { { id = n, name = "...", classId = n }, ... } }
```
Class slot position (1–13) matches column index in the UI grid. Empty `{}` for slots that don't exist (e.g. Monks in old raids).

### Scan Command
`/collected scan` — calls `C_TransmogSets.IsBaseSetCollected()` and `C_TransmogSets.GetSetPrimaryAppearances()` to compute `collected/total` per set. Stored in `WarbandeerCollectedDB.sets[groupId][setId]`.

### UI
- `DataView` (TableFrame subclass): columns = class icon headers + lock + name; rows = raid groups. Cells show remaining piece count, color-coded red→green (10-shade gradient).
- `InfoTip` (CleanFrame): per-slot item names with red/green collect status.
- `LockoutView` (CleanFrame): characters with lockout status from `toon.instances.locks[instance][difficulty]`.
- Compartment: left click = open window, right click = `/scan`.

---

## ShadowsOfUI-XP — XP Bar

**Dependencies:** `LibNAddOn`, `LibNUI`
**Category:** Shadows of UI
**Files:** `ShadowsOfUI-XP.toc`, `ExpBar.lua` (single-file addon, no SavedVariables, no settings)

### What It Does
- Hides `StatusTrackingBarManager` (Blizzard's default XP/rep bar system).
- Creates a 7px-tall `StatusBar` pinned full-width to the very bottom of the screen.
- Only instantiated when the player is **below max level** (`Player:isMaxLevel()` check in `ns:onLoad`).
- On hover: percent labels fade in instantly; on leave: 500ms fade-out via `onUpdate` animation loop.

### Class Structure
```lua
local ns = LibNAddOn(...)  -- assignment form; no db, no slash commands

local ExpBar = Class(StatusBar, function(self)
    -- child widget setup
end, {
    parent   = UIParent,
    name     = "ShadowsOfUIExpBar",
    position = { Height = 7, BottomLeft = {}, BottomRight = {} },
    events   = { "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE",
                 "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION", "PLAYER_UPDATE_RESTING" },
    backdrop = { 0, 0, 0, 0.3 },
    fill     = { color = {1,1,1}, blend = "ADD",
                 gradient = {"HORIZONTAL", UnrestedGradientStart, UnrestedGradientEnd} },
})
```

`events` in the defaults causes `Frame`'s constructor to register each event and route `OnEvent` to methods named after the event (e.g. `PLAYER_XP_UPDATE` dispatches to `ExpBar:PLAYER_XP_UPDATE()`).

### Child Widgets
| Field | Type | Purpose |
|---|---|---|
| `self.edge` | `Texture` | 3px vertical dark gradient at top — cosmetic depth |
| `self.fade` | `Texture` | Dark gradient bleeding 3px above bar — softens edge |
| `self.secondary` | `Texture` | Blue texture anchored to `self.fill`'s right edge — rested XP extent |
| `self.textPercent` | raw `FontString` | Current XP % label, tracks fill's right edge |
| `self.restPercent` | raw `FontString` | Rested XP % label, tracks fill's right edge |
| `self.notch1`–`self.notch9` | `Texture` | 3px-wide 10%-interval tick marks, created once on login |

`self.textPercent` and `self.restPercent` use `self._widget:CreateFontString(...)` directly — the one place raw WoW API is used because LibNUI has no child-Label factory at this level.

### Key Methods
- `ExpBar:update()` — reads `Player:GetXPPercent()` and `Player:GetRestPercent()`, sizes `self.fill` and `self.secondary`, repositions percent labels.
- `ExpBar:initNotches()` — creates 9 notch textures; called once from `PLAYER_ENTERING_WORLD` on login/reload.
- `ExpBar:onUpdate(elapsed_ms)` — drives label fade-out over `fadeDelay` (500ms); stops `OnUpdate` loop when done.
- `ExpBar:onEnter()` / `ExpBar:onLeave()` — show labels instantly / start fade timer.

### Player Data Helpers Used
```lua
Player:GetXPPercent()   -- UnitXP / UnitXPMax → 0–1 float
Player:GetRestPercent() -- max(0, GetXPExhaustion() / 2 / UnitXPMax) → 0–1 float
Player:isMaxLevel()     -- UnitLevel == ns.wow.maxLevel
```

### Animation Pattern
```lua
-- Start on mouse leave:
self.fadeTimer = self.fadeDelay  -- 500 (ms)
self:startUpdates()              -- enables onUpdate loop (Frame method)

-- In onUpdate(elapsed_ms):
self.fadeTimer = self.fadeTimer - elapsed
self.textPercent:SetTextColor(1, 1, 1, self.fadeTimer / self.fadeDelay)
if self.fadeTimer == 0 then self:stopUpdates() end
```
`startUpdates()` / `stopUpdates()` are `Frame` methods from LibNUI. `elapsed` arrives in milliseconds (Frame multiplies WoW's seconds by 1000).

### Colors
```lua
local UnrestedGradientStart = rgba(88,  0, 145, 0.5)   -- purple
local UnrestedGradientEnd   = rgba(154, 8, 252, 0.5)   -- bright purple
local RestedGradientStart   = rgba(0,  32, 128, 0.5)   -- blue (currently unused)
local RestedGradientEnd     = rgba(0,  64, 255, 0.5)   -- bright blue (currently unused)
```
`rgba(r, g, b, a)` — r/g/b as 0–255 integers, a as 0–1 float.

---

## Cross-Cutting Conventions

| Convention | Detail |
|---|---|
| Namespace | `local _, ns = ...` in every file |
| Class definition | `local Foo = Class(Parent, function(self) ... end, { defaults })` |
| Addon init | `LibNAddOn{ name=..., addOn=ns, ... }` or `local ns = LibNAddOn(...)` |
| DB migration | `MigrateDB()` auto-called by LibNAddOn on version mismatch |
| Event handling | `ns:registerEvent("EVENT", handler)` |
| UI widget access | Always via `self._widget`; never from outside the class |
| Shared API data | Access via `ns.api.*` (bound from `X-NUI-API` toc field) |
| LuaLS annotations | `---@class`, `---@field`, `---@param`, `---@return` on all classes and public methods |
| No error handling | WoW API errors surface in-game; no defensive nil-checks on internal invariants |
| No standalone utilities | Everything belongs on a class or the addon namespace |
| Testing | In-game only via `/reload` and `/nui test [key]` for UI |
