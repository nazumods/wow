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
local myAddOn = LibNAddOn(...)
```

## Options

Options can be specified by passing them to the function as table values:

```lua
local ADDON_NAME, myAddOn = ...
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

#### `myAddOn.lua`

For the purposes of the descriptions below:
- **List** refers to a table with numeric keys and a size
- **Map** refers to a table with string keys
- **Set** refers to a table with string keys with the value `true`, e.g. `if aSet[key] then ...`
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
- `sets.Set(list)` - create a Set from a list of values, e.g. `Set{123, 456} -- {"123": true, "456": true}`
- `sets.values(tbl)` - return the values of a table as a Set
- `strings.startsWith(str, start)` - returns true if str starts with start
- `strings.split(token, str)` - returns a List of the substrings in str that are separated by token

Also includes the `Class` function for defining inheritable, instantiatable objects.
