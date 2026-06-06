# Warbandeer_Bars

Headless data layer for action bar / keybind / macro / pet bar / outfit layout profiles, auto-tracked
per character + spec. No UI — exposes `WarbandeerBarsApi` for a consuming UI (e.g. a future Warbandeer
view) to preview any character/spec's setup and import it onto the current character. Stores structured
profiles keyed by `[charName][specID]`.

## TOC
```
Interface: 120001, Dependencies: LibNAddOn (no LibNUI — headless)
SavedVariables: WarbandeerBarsDB (version 1)
SavedVariablesPerCharacter: WarbandeerBarsSettings
X-NUI-API: WarbandeerBarsApi
X-NUI-COMMANDS: /wbbars, /wbb
```

## Files

| File | Purpose |
|---|---|
| `init.lua` | Assignment-form bootstrap, `MigrateDB`, per-char settings init (`WarbandeerBarsSettings`) |
| `libs/base64.lua`, `libs/crc32.lua` | Export-string codec (base64 + CRC32 integrity) |
| `capture.lua` | `ns.Capture` → profile table. `ProfileMeta`: `specID`, `classID`, `realm`, `level`, `captured` |
| `restore.lua` | `ns.Restore(profile, include, silent?)` — incl. macro recreate-on-import |
| `serialize.lua` | `ns.Encode`/`ns.Decode` portable text encoding |
| `tracker.lua` | Auto-snapshot on `onLogin` (2 s settle), `ACTIVE_TALENT_GROUP_CHANGED` (500 ms settle), `PLAYER_LOGOUT` (also fires on /reload). Combat- and cursor-guarded. Always captures full fidelity |
| `api.lua` | `WarbandeerBarsApi` methods |
| `commands.lua` | `/wbb` inspection commands (data layer has no window) |

## WarbandeerBarsApi Methods

```lua
WarbandeerBarsApi:GetCurrentCharacter()              → string
WarbandeerBarsApi:GetCurrentSpecID()                 → number
WarbandeerBarsApi:GetProfiles(char?)                 → { [specID] = profile }?
WarbandeerBarsApi:GetProfile(char?, specID?)         → profile?
WarbandeerBarsApi:ListCharacters()                   → string[]   (sorted)
WarbandeerBarsApi:GetAllProfiles()                   → profile[]  (flat)
WarbandeerBarsApi:Snapshot()                         → profile?   (capture+store now)
WarbandeerBarsApi:DeleteProfile(char, specID)
WarbandeerBarsApi:Restore(profile, include?, silent?)
WarbandeerBarsApi:RestoreProfile(char, specID, include?, silent?) → boolean
WarbandeerBarsApi:Capture(include?, accountMacros?, charMacros?)   → profile  (no store)
WarbandeerBarsApi:Encode(profile) / :Decode(text)
WarbandeerBarsApi:GetIncludeSettings()               → include table (live)
```

## Profile table
```lua
{
  version=1, captured=<serverTime>,
  char, realm, class (file token), classID, specID, spec (name), specIcon, level,
  slots    = { { id, type, index?, strindex? }, ... },
  binds    = { { command, key1?, key2? }, ... },
  macros   = { { id, name, icon, body }, ... },
  petslots = { { id, type, index?, strindex? }, ... },
  outfits  = { "Set Name", ... },
}
```

## SavedVariables (`WarbandeerBarsDB`)
```lua
{ version = 1, profiles = { [charName] = { [specID] = profile } } }
```

## Per-character settings (`WarbandeerBarsSettings`)
```lua
-- RESTORE filter only; capture always stores full fidelity (tracker.lua).
{ include = { bars=true, macros=true, petbar=true, bindings=false, outfits=false },
  accountMacros = true, charMacros = true }
```

## Capture model
Full-fidelity capture (all options on), filtered restore. Stored under `[char][specID]`, overwriting the
previous profile for that slot. Restore defaults to bars + macros + pet bar (bindings/outfits off so an
import doesn't silently rewrite keybinds); a consuming UI overrides `include` per call.
