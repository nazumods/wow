# LibNAddOn

`LibNAddON` is an addOn for bootstrapping other addOns. It provides a single global function
that takes a table of options, detailed below.

## Usage

List it in your `.toc`:

```World of Warcraft Addon Data
## Dependencies: LibNAddOn
```

A minimal example:

```lua
---@class MyAddOn: AddOn
local myAddOn = LibNAddOn(...)
```

The `---@class MyAddOn: AddOn` annotation types your namespace for the Lua language
server. Files other than the setup file import the namespace with:

```lua
---@type MyAddOn
local myAddOn = select(2, ...)
```

## Options

Options can be specified by passing them to the function as table values:

```lua
local ADDON_NAME = ...
---@class MyAddOn: AddOn
local myAddOn = select(2, ...)
LibNAddOn{
  name = ADDON_NAME,
  addOn = myAddOn,
  db = {
    name = "MyAddOnDB",
    defaults = {
      version = 1,
      -- initial values
    },
  },
  settings = {
    {
      title = "MyAddon",
      fields = {
        {
          name = "setting name",
          typ = "checkbox",
          default = 1,
          table = function(db) return db.settings end,
          key = "settingName",
          label = "basic setting",
          tooltip = "select value",
        },
        {
          name = "setting name",
          typ = "slider",
          -- everything from checkbox, plus:
          min = 1,
          max = 10,
          step = 1,
        },
        {
          name = "setting name",
          typ = "dropdown",
          -- everything from checkbox, plus:
          options = {"Option 1", "Option 2"},
        },
      },
    },
  },
  slashCommands = {
    myAddonName = {"/command1", "/command2"},
  },
  compartmentFn = "MY_ADDON_COMPARTMENT_CLICK",
  api = MyAPI,
  ui = LibNUI,
}
```

`api` and `ui` will link the respective globals by those names to `myAddOn.api` and `myAddOn.ui`.

Most of the options can also simply be specified in the .toc:

```
## X-NUI-DB: MyAddOnDB
## X-NUI-DB-VERSION: 1
## X-NUI-COMMANDS: /myaddon, /myaddon1
## X-NUI-COMPARTMENT: MyAddOn_OnAddonCompartmentClick
## X-NUI-API: SomeApi
## X-NUI-UI: LibNUI
```

Settings can't be expressed in the `.toc` either; with the vararg form, register them with
`RegisterSettings` at file-load time (it queues the registration for `ADDON_LOADED`):

```lua
---@class MyAddOn: AddOn
local myAddOn = LibNAddOn(...)

myAddOn:RegisterSettings{
  {
    title = "MyAddon",
    fields = {
      -- same field definitions as the `settings` option above
    },
  },
}
```

You can't set database defaults this way, but since it calls `MigrateDB` on load of your addon
when the database doesn't exist (as the versions don't match), you can initialize your db then:

```lua
local myAddOn = LibNAddOn(...)

function myAddOn:MigrateDB()
  if not self.db.version then
    -- initialize db
  end
end
```

## Details

The following will be added to your addon namespace `myAddOn`:

### function Print(...)

Prints any passed arguments, with `<ADDON_NAME>:` prepended.

### an EventListener

Adds a lightweight hidden frame on `_eventListener` and two functions:

#### registerEvent(eventName, handlerFn?, idx?)

If no handler function is given, hooks up the event to call `myAddOn.EVENT_NAME()`.

If a handler function _is_ provided, hooks up the event to call it, bound to the addon.

If `idx` is specified, inserts the handler at the specific index. Generally used to
make sure the handler is called before other previously registered handlers (by passing
1 as the idx).

#### unregisterEvent(eventName, handlerFn?)

If `handlerFn` is provided, removes the specified callback.

If `handlerFn` is _not_ provided, removes **all** callbacks.

#### delay(ms, fn)

One-shot debounce timer: calls `fn` (a function, or the name of a method on the addon)
after `ms` milliseconds. Only **one** timer is active per addon — a second call replaces
the pending callback.

#### after(ms, fn)

Fires `fn` once after `ms` milliseconds. Unlike `delay`, supports any number of
concurrent timers.

### Temporary CVar overrides

For an addon that flips a console variable for the duration of some state (e.g. forcing a
CVar on in combat), these back up the user's original value and **guarantee it is restored
on logout** — so disabling or uninstalling the addon while an override is live can never
leave the CVar stuck at the addon's value.

#### SetTemporaryCVar(cvar, value)

Sets `cvar` to `value`, remembering the user's original value the first time (a repeated
call won't overwrite the remembered original) and arming a `PLAYER_LOGOUT` restore.

#### RestoreCVar(cvar) / RestoreCVars()

Restore one / all overridden CVars to their original values now (logout calls
`RestoreCVars` for you). A CVar the addon never set is left untouched.

### Item-tooltip hooks

#### OnItemTooltip(fn)

Registers `fn(tooltip, data)` as a post-call on item tooltips (a `TooltipDataProcessor`
hook for `Enum.TooltipDataType.Item`), so an addon can append lines to any item tooltip
without re-implementing the boilerplate. The callback runs only after the standard guards:
the tooltip isn't forbidden (Blizzard's secure/inspect tooltips) and `data` is non-nil. Any
further gating — `data.id`, shift-to-hide, an opt-out flag — stays in the callback. If the
client lacks `TooltipDataProcessor`, no hook is installed (the call is a no-op).

```lua
ns:OnItemTooltip(function(tooltip, data)
  if not data.id then return end
  tooltip:AddLine("Item " .. data.id)
end)
```

### An event handler for ADDON_LOADED

Calls `myAddOn.onLoad` when the event is fired for `ADDON_NAME`.

If `myAddOn.onLogin` is defined, registers for the event `PLAYER_ENTERING_WORLD`, calling
`myAddOn.onLogin` if it was a login or reload event.

### Globals

Links most of the global wow functions, including convenience wrappers for some.

#### `myAddOn.Colors`

Contains various color-related constants and convenience functions:

- `rgba(r, g, b, a)` -- converts hex r/g/b values, returning a WoW Color table representation
- `alpha(color, alpha)` -- returns a copy of the Color with the new alpha value
- `hex(color)` -- the 6-digit hex string (`"RRGGBB"`) for a `{r, g, b}` (0–1) colour, for embedding in an escape
- `code(color)` -- the opening colour escape (`"|cffRRGGBB"`) for a colour; pair with `|r` (or use `wrap`)
- `wrap(text, color)` -- wraps `text` in a colour escape: `"|cffRRGGBB<text>|r"`
- `className(name, classKey)` -- wraps a character name in its class colour (PascalCase keys, e.g. `"DeathKnight"`, matching `Character.classKey`); returns the name unchanged when the class is unknown

#### `myAddOn.lua`

For the purposes of the descriptions below:
- **List** refers to a table with numeric keys and a size
- **Map** refers to a table with string keys
- **Set** refers to a table whose keys are the member values, each mapped to `true`, e.g. `if aSet[key] then ...`
Generally for Lists the code uses `ipairs`, while Maps use `pairs`.

Includes various convenience methods for working with Lists, Maps, Sets, Strings, and tables in general:

- `Select(key)` - returns a function that transforms a provided table to a value by selecting the given key
- `lists.values(...)` - creates a new list with the values from the provided lists
- `lists.generate(func, num, start?)` - generate an list by calling a function 1..n times with the index
- `lists.map(tbl, func)` - return a new table by transforming each value by the given function
- `lists.find(tbl, val)` - find a value in a list, returning the index. If val is a function it will be called with
  each value, returning the index for which it returns true
- `lists.prepend(list, ...)` - prepend values to a list
- `maps.merge(tgt, ...)` - merge multiple tables into the first one, overwriting existing keys
- `maps.fill(tgt, ...)` - fill the destination table from the source tables, without overwriting existing keys
- `maps.map(map, func)` - return a new table by transforming each value by the given function
- `maps.toMap(map, func)` - return a new table by mapping each value by the given function
- `maps.any(map, func)` - return true if the function returns true for any value in the table
- `maps.anyKey(map, func)` - return true if the function returns true for any key in the table
- `sets.Set(list)` - create a Set from a list of values, e.g. `Set{123, 456} -- {[123] = true, [456] = true}`
- `sets.values(tbl)` - return the values of a table as a Set
- `strings.startsWith(str, start)` - returns true if str starts with start
- `strings.split(token, str)` - returns a List of the substrings in str that are separated by token

Also includes the `Class` function for defining inheritable, instantiatable objects.

## Global slash commands

Because LibNAddOn is a dependency of every addon in the suite and always loaded, it also
registers a small set of suite-wide convenience slash commands. These are unscoped — they
aren't tied to any one addon's namespace — and are available as soon as LibNAddOn loads:

- `/rl` — reload the UI (`ReloadUI()`)
- `/fs` — toggle the frame stack (Blizzard's `/framestack` debug tooltip)
- `/etc` — open Edit Mode

## In-game changelog

An addon can surface its release history in-game, viewable from a **Changelog** button in
its Settings category. Two pieces:

1. Ship a `changelog.lua` data file — a newest-first list of `{ version, notes }` entries.
   The release tooling (`.github/scripts/release.sh`) appends to this automatically at
   release time, from the same conventional-commit grouping used for the GitHub/CurseForge
   release notes, so it's never maintained by hand. Add the file to your `.toc`:

   ```lua
   ---@class MyAddOn
   local ns = select(2, ...)

   ---@type { version: string, notes: string }[]
   ns.changelog = {
     { version = "12.0.7-r1", notes = "### Features\n- did a thing" },
   }
   ```

2. Call `myAddOn:RegisterChangelog()` once (e.g. in your setup file). If your addon already
   has a settings category (top-level or a subcategory under a shared parent) the button lands
   on it. If it has **no** settings of its own, one is created to host the button — pass a
   parent name to nest it as a subcategory there (e.g. `myAddOn:RegisterChangelog("Shadows of UI")`),
   or omit it for a top-level category. The notes open in LibNUI's shared scrollable
   **CopyWindow** (using the addon's own UI binding, or the global `LibNUI` if it's loaded);
   an addon with no LibNUI at all falls back to printing to chat. `myAddOn:ShowChangelog()`
   opens it directly.
