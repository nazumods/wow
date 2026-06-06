# Recycle

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
