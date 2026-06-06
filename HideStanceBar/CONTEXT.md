# HideStanceBar

## TOC
```
Interface: 120000, Category: Shadows of UI
Dependencies: LibNAddOn, LibNUI
SavedVariables: HideStanceBarDB (version 1), X-NUI-UI: LibNUI
```

Single file: `addon.lua`. Assignment form.

**DB:** `{ hide = { [classId] = true/nil } }`

Hides StanceBar by reparenting to a hidden `Hider` frame. Settings UI with per-class toggles (Warrior/Paladin/Rogue/Priest/Druid). Registered under "Shadows of UI" settings category.
