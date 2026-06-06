# Warbandeer_Collected

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
