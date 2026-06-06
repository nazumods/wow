# Warbandeer_Alias

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
