# CLAUDE.md — LibNUI

## Environment

- WoW addon library — no build step, no test runner, no package manager
- Changes cannot be verified from the CLI; they must be loaded in-game (`/reload`)
- Target: WoW Retail (Interface version in `LibNUI.toc`)
- Depends on `LibNAddOn` (`ns.lua.Class`, `ns.lua.maps`, etc.)

## Adding a New Class

Follow the established pattern exactly:

```lua
local _, ns = ...
local ui = ns.ui
local Class = ns.lua.Class
local Frame = ui.Frame  -- or whichever parent

---@class MyWidget: Frame
---@field someField string   description
local MyWidget = Class(Frame, function(self)
  -- constructor body; self fields are the options passed to :new{}
end, {
  -- default option values — use strings/values not local constants
  someField = "default",
})
ui.MyWidget = MyWidget

---@param value string
---@return MyWidget
function MyWidget:SomeMethod(value) end
```

- Register on `ui` so it's accessible via `LibNUI.MyWidget`
- Add the file to `LibNUI.toc` in the appropriate section
- Add a visual test in the adjacent `LibNUI_Test` add-on (see **Testing** below)

## Conventions

| Thing | Convention |
|---|---|
| Public methods | `PascalCase` |
| Lifecycle hooks / callbacks | `camelCase` (`onLoad`, `onUpdate`, `OnLogin`) |
| Constructor init fields | `camelCase` (`cellWidth`, `headerHeight`) |
| Constants | `ui.edge`, `ui.layer`, `ui.justify`, `ui.wrap` |
| Backing widget | Always `self._widget` |

## Lua language server annotations

Every class and public method must be annotated for LuaLS.

**Class block** (above `Class(...)`):
```lua
---@class MyWidget: Frame
---@field publicField  string   description
---@field optionalCb   fun(self: MyWidget)?  optional callback
---@field _internal    table    internal state (still annotate it)
```

**Methods**:
```lua
---@param index number
---@return Frame
function MyWidget:Tab(index) end

-- getter/setter: annotate the setter signature; the get path is implicit
---@param v string?
---@return string|MyWidget
function MyWidget:Value(v) end
```

- Use `?` on `---@field` and `---@param` for optional values
- `---@return` is required on all non-void public methods

## Getter/Setter pattern

Methods that read or write a single value should follow the nil-check pattern:

```lua
function MyWidget:Value(v)
  if v == nil then return self._widget:GetValue() end
  self._widget:SetValue(v)
  return self  -- allow chaining when setting
end
```

## What to avoid

- **Don't add standalone utility functions** — everything belongs on a class
- **Don't add defensive nil-checks for internal invariants** — trust that callers pass valid options
- **Don't add error handling for WoW API calls** — let errors surface naturally in-game
- **Don't create new files for one-off helpers** — put it on the relevant class
- **Don't use `self._widget` from outside a class** — expose a method instead
- **Don't break the getter/setter pattern** — no separate `GetFoo`/`SetFoo` pairs

## TableFrame dynamic construction

`offsetX` and `offsetY` are baked in at construction time based on whether `rowNames`/`colNames` are non-nil. When building a table with `addRow`/`addCol` instead of pre-declaring names, pass empty tables so the offsets are correct — otherwise row data and headers will overlap:

```lua
TableFrame:new{
  rowNames    = {},  -- ensures offsetX = headerWidth
  colNames    = {},  -- ensures offsetY = headerHeight
  headerWidth = 70,
  ...
}
```

## Secure frames

`SecureButton` uses `SecureActionButtonTemplate`. Never call `SetAttribute` on it during combat (taint). `special = true` on `Frame` registers it as a `UISpecialFrame` (Escape key closes it) and puts the widget in `_G` — only use for top-level addon windows.

## Testing

Visual tests live in the adjacent `LibNUI_Test` add-on (`../LibNUI_Test/`). It is `LoadOnDemand` and launched via `/nui test [key]` in-game.

Each test is a separate file with a `make*()` factory and a `table.insert` registration:

```lua
local window   = LibNUITest.window    -- creates a TitleFrame helper
local toggling = LibNUITest.toggling  -- wraps factory as a toggle-aware launcher

---@return TitleFrame
local function makeMyWidget()
  local f = window("My Widget", 300, 200)
  -- build widget, anchor inside f ...
  return f
end

table.insert(LibNUITest.tests, {
  key  = "mywidget",
  name = "My Widget",
  desc = "One-line description shown in the selector",
  run  = toggling(makeMyWidget),
})
```

Add the file to `LibNUI_Test/LibNUI_Test.toc` before `entry.lua`.

## position table reference

```lua
position = {
  TopLeft  = {target, "TOPLEFT", x, y},  -- SetPoint args
  Width    = 100,                          -- scalar → called as self:Width(100)
  All      = true,                         -- SetAllPoints
  Hide     = true,                         -- Hide after anchoring
}
```

Any key that maps to a method on `Region` is valid. Values are unpacked if a table, called directly if scalar, skipped if `false`.
