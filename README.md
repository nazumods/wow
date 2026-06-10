# World of Warcraft Addons

## Contributing
### Code Style
- 2-space indent
- Tables for Object-oriented style
- Sentance case for function names
- Camel case for field names
- Class to ecapsulate

### Namespace Imports

Every file declares the addon namespace with a typed import so the Lua language server can link fields across files.

The setup file (the one that calls `LibNAddOn`):

```lua
---@class MyAddOn: AddOn
local ns = LibNAddOn(...)
```

Every other file:

```lua
---@type MyAddOn
local ns = select(2, ...)
```

The class name is the addon folder name with hyphens replaced by underscores. If a file also needs the addon name, keep it on its own line (`local ADDON_NAME = ...`) above the annotated import.


```
cd _beta_\Interface\Addons
mklink /D HideBagBar ..\..\..\_retail_\Interface\AddOns\HideBagBar
```
