# Warbandeer_Bars (Headless data layer)

**Deps:** LibNAddOn (no LibNUI — headless) · **SavedVars:** `WarbandeerBarsDB` (v2) · **PerChar:** `WarbandeerBarsSettings` · **Commands:** `/wbbars`, `/wbb` · **API:** `WarbandeerBarsApi`

Headless tracker for action bar / keybind / macro / pet bar / outfit layouts, auto-snapshotted per
character + spec. No UI — exposes `WarbandeerBarsApi` for a consuming UI to preview any
character/spec's setup and import it onto the current character. Profiles are stored under
`[charName][specID]`.

## Files

| File | Purpose |
|---|---|
| `init.lua` | Assignment-form bootstrap; `MigrateDB` (v1 seeds `profiles={}`; v2 adds `layouts={}`), `DefaultSettings`, `onLoad` per-char settings init |
| `capture.lua` | `ns.Capture(include, accountMacros, charMacros)` → profile table; per-section capture + spell/flyout override resolution |
| `restore.lua` | `ns.Restore(profile, include, silent?, barFilter?)` — applies a profile, recreating macros on import; flyouts-first pre-pass, spellbook fallbacks, per-bar filter |
| `tracker.lua` | `ns.Snapshot()` + auto-capture triggers (login / spec change / logout); combat- & cursor-guarded |
| `api.lua` | `WarbandeerBarsApi` methods |
| `commands.lua` | `/wbb` inspection sub-commands (no window — data layer only) |

## WarbandeerBarsApi

```lua
:GetCurrentCharacter()                     → string
:GetCurrentSpecID()                        → number
:GetProfiles(char?)                        → { [specID]=profile }?
:GetProfile(char?, specID?)                → profile?
:ListCharacters()                          → string[]  (sorted)
:GetAllProfiles()                          → profile[] (flat)
:Snapshot()                                → profile?  (capture + store now)
:DeleteProfile(char, specID)
:Restore(profile, include?, silent?, barFilter?)
:RestoreProfile(char, specID, include?, silent?, barFilter?) → boolean  (false if no such profile)
:Capture(include?, accountMacros?, charMacros?)  → profile  (no store)
:GetIncludeSettings()                      → include table (live; mutate to change)
```

`char`/`specID`/`include` args default to the current character / spec / per-char settings.
`barFilter` maps **internal** bar numbers (1-15, slot id = `(bar-1)*12 + n`) to bool; `false` leaves
that bar untouched (restore *and* clear pass). `nil` = all bars.

## Commands (`/wbb`)

| Sub-command | Action |
|---|---|
| *(none)* | Print status / usage |
| `snapshot` | Capture the current character now |
| `list` | List stored profiles |
| `restore <char> [specID]` | Restore a stored profile onto the current character (defaults to current spec) |
| `forget <char> [specID]` | Delete one profile, or all of a character's if `specID` omitted |

## Profile table

```lua
{
  version=1, captured=<time()>,
  char, realm, class (file token e.g. "MAGE"), classID,
  specID, spec (name), specIcon, level,
  slots    = { { id, type, index? | strindex? }, ... },   -- action bar slots 1..180
  binds    = { { command, key1?, key2? }, ... },
  macros   = { { id, name, icon, body }, ... },
  petslots = { { id, type="token", strindex } | { id, type="spell", index }, ... },
  outfits  = { "Set Name", ... },                          -- equipment-set names only
}
```

Slot `type` ∈ `spell | item | toy | flyout | companion | summonmount | summonpet | equipmentset | outfit | macro`.
`summonpet` (GUID) and `equipmentset` (set name) use `strindex`; `outfit` (transmog set) carries **both**
its name in `strindex` (identity) and its list position in `index` (fallback); the rest use `index`.

## SavedVariables

```lua
WarbandeerBarsDB       = { version=2, profiles = { [charName] = { [specID] = profile } }, layouts = { [layoutName] = { [barIndex] = {numIcons,numRows,orientation} } } }
WarbandeerBarsSettings = {           -- per-character; RESTORE filter only
  include = { bars=true, macros=true, petbar=true, bindings=false, outfits=false },
  accountMacros = true, charMacros = true,
}
```

`MigrateDB` seeds `profiles`/`version` on first run and adds `layouts` at v2; non-destructive. `onLoad` backfills any
missing `WarbandeerBarsSettings` keys from `ns.DefaultSettings`.

## Capture / restore model

- **Full-fidelity capture, filtered restore.** The tracker always captures every section
  (`CAPTURE_ALL` in `tracker.lua`) so a stored profile can satisfy any later restore filter.
  `ns.settings.include` only governs which sections a *restore* applies.
- **Restore defaults** to bars + macros + pet bar; bindings & outfits are off so an import doesn't
  silently rewrite keybinds. A consuming UI overrides `include` per call.
- **Store key is `[char][specID]`**, overwriting the previous profile for that slot. Profiles with
  `specID == 0` (no active spec) are never stored.

## Auto-snapshot triggers (`tracker.lua`)

| Trigger | Settle delay |
|---|---|
| `onLogin` (entering world) | 2000 ms |
| `ACTIVE_TALENT_GROUP_CHANGED` (spec swap) | 500 ms |
| `PLAYER_LOGOUT` (also fires on `/reload`) | none |

## Gotchas

- **`C_EditMode.GetLayouts()` index offset:** `info.layouts` contains only *saved* layouts, but
  `info.activeLayout` indexes as if the preset layouts (Modern, Classic) came first —
  `CaptureLayouts` subtracts `#Enum.EditModePresetLayouts` before lookup. An active preset leaves
  `profile.layoutName` nil (presets are default 1-row bars).

- **`ns.Snapshot()` is a no-op during combat or mid-drag.** Macro temp-index resolution in capture
  touches protected APIs, and an in-progress cursor drag would be clobbered. Guarded by
  `InCombatLockdown()` / `GetCursorInfo()`. None of the triggers fire in combat anyway.
- **`ns.Restore` bails in combat** (taint) — it prints a notice and returns.
- **Flyouts restore FIRST** (`RestoreFlyouts` pre-pass): `PickupSpellBookItem` for flyout-type
  spellbook items (e.g. the warlock Summon Demon drawer) silently fails after any other protected
  pickup operation in the same hardware event. Never reorder the restore passes.
- **`PickupSpell` fails for some known spells** (form-specific druid abilities) — restore falls back
  to pickup by spellbook index, and only warns when the spell *is* in the book but still failed.
- **Slots whose content can't be picked up are blanked** (`PickupAction` on the slot), so the result
  matches the profile rather than keeping stale leftovers.
- **Spell overrides are resolved both ways.** Capture stores the *base* spellID
  (`C_Spell.GetOverrideSpell` reverse-mapped); restore re-applies via an override map plus name /
  `FindBaseSpellByID` fallbacks, warning on any spell the character doesn't know.
- **Macros are recreated by name+body match**, not by index — restore reuses an existing matching
  macro or `CreateMacro`s one (account vs character bank inferred from `m.id`), warning if no macro
  slots remain. Macro action slots are placed in a second pass via an id→newId map.
- **Temp/override macro slots** are resolved to their real macro index at capture via a
  `PickupAction`/`PlaceAction` round-trip.
- **Pet bar capture/restore only runs while a pet is active** (`IsPetActive`); tokens are matched by
  name, spells by ID.
- **Two distinct "outfit" concepts — don't conflate them.** (1) `profile.outfits` is a list of
  `C_EquipmentSet` **gear-set names** (the `include.outfits` filter): account-wide data, so it's
  names-only and restore does not rebuild gear sets. (2) A `"outfit"` **action-slot** is a *transmog*
  (Wardrobe) outfit button — a different API (`C_TransmogOutfitInfo`, not `C_EquipmentSet`). It's
  captured/restored like any other slot: store the outfit name (`strindex`) + list position
  (`index`) at capture, resolve name→`outfitID` (position fallback) and `PickupOutfit` at restore.
  Missing this branch previously left transmog outfit buttons uncaptured and **blanked on restore**.
- **Keybindings restore replaces the live binding set** (`SaveBindings(GetCurrentBindingSet())`),
  writing each captured key with its per-command binding context when available. Capture is a
  *full* snapshot (`CaptureBindings` walks every command via `GetNumBindings`/`GetBinding`), so
  restore first **clears any live key not in the profile** (the binding analog of
  `ClearUnusedSlots`) before applying — otherwise the result would be the union of the old live
  bindings and the profile's, leaving stale keys bound (e.g. a live `F5`→`ACTIONBUTTON5` surviving
  a profile that predates it).
