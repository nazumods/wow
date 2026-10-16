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
| `capture.lua` | `ns.Capture(include, accountMacros, charMacros, cursorFree?)` → profile table; per-section capture + spell/flyout override resolution |
| `restore.lua` | `ns.Restore(profile, include, silent?, barFilter?)` — applies a profile, recreating macros on import; flyouts-first pre-pass, spellbook fallbacks, per-bar filter |
| `tracker.lua` | `ns.Snapshot(guardSparse?, cursorFree?)` + `ns.shouldStore` + auto-capture triggers (login / spec change / a 10 s fingerprint check of bars, macro names and icons, and bindings, saving on a change that held for a full check; none at logout); combat- & cursor-guarded. `capture.lua` holds `ns.Fingerprint()` |
| `api.lua` | `WarbandeerBarsApi` methods |
| `commands.lua` | `/wbb` inspection sub-commands (no window — data layer only) |
| `spec/` | busted unit tests (`ns.shouldStore` sparse-capture guard, the WoW-API-free `api.lua` DB methods, the `ns.Capture` slot schema via `bars.loadCapture`'s `setfenv` global stubs, and `ns.Restore`'s petaction/futurespell clear via `bars.loadRestore` + the `bars.actionbars` fake bar, whose `PickupAction`/`PlaceAction` **swap** slot and cursor as they do in game — that swap is what made the clear a round-trip, so a harness modelling pickup as a plain removal wouldn't reproduce it); excluded from zip + release detection |

## WarbandeerBarsApi

```lua
:GetCurrentCharacter()                     → string
:GetCurrentSpecID()                        → number
:GetProfiles(char?)                        → { [specID]=profile }?
:GetProfile(char?, specID?)                → profile?
:ListCharacters()                          → string[]  (sorted)
:GetAllProfiles()                          → profile[] (flat)
:Snapshot()                                → profile?  (capture + store now)
:DeleteProfile(char, specID)               → boolean  (forget one profile; false if the char had no such spec)
:DeleteCharacter(char)                     → boolean  (forget all of a char's profiles; false if none)
:Restore(profile, include?, silent?, barFilter?)
:RestoreProfile(char, specID, include?, silent?, barFilter?) → boolean  (false if no such profile)
:Capture(include?, accountMacros?, charMacros?)  → profile  (no store)
:GetIncludeSettings()                      → include table (live; mutate to change)
```

`char`/`specID`/`include` args default to the current character / spec / per-char settings. `char`
is resolved **case-insensitively** (`resolveChar` — exact hit first, then a case-insensitive scan) so
`/wbb restore lurias` finds the canonically-stored `Lurias`; stored keys stay canonical.
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
  version=3, captured=<time()>,                            -- v2 adds barLayout; v3 adds summonpet species/custom names
  char, realm, class (file token e.g. "MAGE"), classID,
  specID, spec (name), specIcon, level,
  slots    = { { id, type, index? | strindex?, speciesID?, speciesName?, customName? }, ... },  -- action bar slots 1..180
                                                           -- speciesID/speciesName/customName: v3, summonpet only (see below)
  binds    = { { command, key1?, key2? }, ... },
  macros   = { { id, name, icon, body }, ... },
  petslots = { { id, type="token", strindex, tex } | { id, type="spell", index }, ... }, -- tex: token icon (v2, for cross-char preview)
  outfits  = { "Set Name", ... },                          -- equipment-set names only
  bindingSet = <1|2>,                                      -- GetCurrentBindingSet() at capture (1=account, 2=per-character)
  layoutName = <string?>,                                  -- active Edit Mode layout name (set by ns.CaptureLayouts())
  barLayout  = { [bar] = { orientation, numIcons, numRows, enabled }, ... }, -- v2: REAL on-screen geometry
                                                           -- via ns.wow.ReadActionBars() (addon-aware, Bartender/Dominos/ElvUI);
                                                           -- keyed by slot-range bar (floor((slot-1)/12)+1). nil pre-v2 → preview
                                                           -- falls back to the Edit Mode layout. Captured only when include.bars.
}
```

Slot `type` ∈ `spell | item | toy | flyout | companion | summonmount | summonpet | equipmentset | outfit | macro`.
`summonpet` (GUID) and `equipmentset` (set name) use `strindex`; `outfit` (transmog set) carries **both**
its name in `strindex` (identity) and its list position in `index` (fallback); the rest use `index`.

`summonpet` additionally carries `speciesID` + `speciesName` + `customName` (v3, #637). Its `strindex` is an
account-scoped pet **GUID** that nothing outside the client can resolve, so a pet slot read as opaque to an
offline reader (the desktop app's Bars mirror); `speciesID` is the stable external identity and the names are
the display copy (`customName` is user data that exists nowhere else, and is omitted rather than stored as the
`""` the journal reports for an unnamed pet). Every other slot type is either **static game data** resolvable
from generated tables (`spell`/`item`/`toy` → `SpellName`/`ItemSparse`, `summonmount` → `Mount.db2`, `flyout` →
`SpellFlyout`) or **already self-describing** (`macro` carries `name`+`icon` in `profile.macros`; `equipmentset`
and `outfit` carry their name in `strindex`) — so the pet slot was the only gap. Purely additive and filled by
the next snapshot, so there's no `db.version` bump or `MigrateDB` block: older profiles simply lack the fields.
`restore.lua` still keys off `strindex` alone; the new fields are read-only display data.

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
| a change to the bars | a ticker every `CHANGE_CHECK_SECONDS = 10` s compares `ns.Fingerprint()` (see below); a snapshot when it differs from the last stored one AND equals the previous tick's, i.e. 10-20 s after the last change |
| `EDIT_MODE_LAYOUTS_UPDATED` (→ `ns.CaptureLayouts()`) | none |

There is **no logout snapshot**. By `PLAYER_LOGOUT` the client has already emptied the action bars: on Retail on
2026-10-15 a logout snapshot that was made to store (using the last known spec) wrote a profile with 0 action slots over a
101-slot one (observed). Before that it stored nothing because the spec id presumably read 0 and `store()` refuses
`specID == 0` (inferred, not read from the client). `ns.PLAYER_LOGOUT` takes no snapshot; it only disarms `ready`, so a tick
that is still due when the UI starts tearing down captures nothing.
Bar changes are saved by comparing the bars, not by listening to events (`tracker.lua`, `capture.lua`):

- **Why not events (observed, Retail, 2026-10-15, about two minutes, a local test build):** `UPDATE_MACROS` fired 798 times,
  `ACTIONBAR_SLOT_CHANGED` 535, `UPDATE_BINDINGS` 4; a "10 s after the last event" debounce was rescheduled 1,247 times and
  never fired. Something rewrites a macro constantly (RareScanner's `RS_MACRO`, inferred) and buttons redraw constantly (procs,
  forms, the assisted-combat button), so bar events cannot mean "the player changed something". The tracker registers none of them.
- **`ns.Fingerprint()` (`capture.lua`):** a string of every action slot 1..`MAX_BARS` (`GetActionInfo` type and id, except a
  **macro slot, which carries only its macro NAME** via `C_ActionBar.GetActionText`, never the cursor: for a macro that
  currently resolves to a spell, `GetActionInfo`'s id is that SPELL id, which follows form, target and modifier, so reading it
  would read every such change as an edit; found in review from Blizzard's `ActionButton.lua`), every macro's name and icon
  (`GetMacroInfo`, **not its body**), and every bound command's `key1`/`key2`. Absolute slot ids are read, so a shapeshift
  page change does not alter the slots' own contents (inferred from Blizzard's source: a form swap or vehicle sets the main
  bar's action *page* attribute). A plain spell slot's id is read as `GetActionInfo` returns it (base vs override spell id
  not verified).
- **Macro bodies are deliberately not fingerprinted:** a body rewritten every few seconds by another addon would mean a snapshot
  every 10 s. So a body-only macro edit is saved at the next slot / macro-name / icon / binding change or the next login.
- **Store when changed AND steady (`tick`):** `lastStoredPrint` (set at arming from the fingerprint taken after the login
  snapshot, but only if that snapshot actually stored: one skipped in combat or refused as sparse leaves it nil, so the first
  steady tick takes a snapshot, and that first one stays **sparse-guarded** (`guardFirstChange`) so a login capture refused
  because the bars were still unpopulated cannot be stored over the good profile 10 s later; and at every change snapshot)
  and `lastTickPrint`. On a tick: differs from `lastStoredPrint` AND equals `lastTickPrint` -> a cursor-free,
  unguarded `Snapshot(false, true)`; `lastTickPrint` is always updated. A snapshot attempt counts as stored even when it stored
  nothing (no spec yet), so an unwritable profile is not re-captured every 10 s.
- **Skips:** a tick in combat, with a cursor held, or while a vehicle / quest-override / possess / temporary-shapeshift bar is up
  (`C_ActionBar.HasOverrideActionBar`, `HasVehicleActionBar`, `HasTempShapeshiftActionBar`, `IsPossessBarVisible`, each
  guarded) is skipped entirely (it does not advance `lastTickPrint`, so changes made during it still need one steady tick
  after it); nothing before the login snapshot has armed it (`ready`); nothing after `PLAYER_LOGOUT`. A fingerprint that
  cannot be read (an error) skips the tick quietly. Those special bars replace the main bar's page, which lies inside the slot
  range read (pages up to 15 fit in 180 slots; which page each special bar uses is inferred), so without the skip their
  buttons would be stored as the player's bars. A **skyriding mount's** bonus bar is not recognised by those calls (inferred), so
  it can still cost one extra snapshot while mounted that the dismount reverts. The login and spec snapshots had the same
  exposure before this change.
- **A snapshot that throws is not retried** until the bars change again (`lastStoredPrint` is set before the attempt).
- **Cost (not measured; inferred from the loop bounds):** the fingerprint reads 180 slots, up to 150 macros and every binding
  (`GetNumBindings()`, possibly around a thousand on a heavily modded client) per 10 s, plus a snapshot only when something
  changed. One ticker only (`C_Timer.NewTicker`); a second login cancels the first.
- **Unguarded** (`Snapshot(false, true)`): it records a legitimate reduction, the role the logout snapshot used to have. The one
  exception is the first change snapshot after a login snapshot that stored nothing (`guardFirstChange`, above).
- **Cost of having no logout snapshot:** a change made in the last 10-20 s before logout or `/reload` is not saved, and if it was a *reduction*
  (buttons removed) the next login snapshot, being sparse-guarded, refuses the smaller capture, and so does the first change
  snapshot after it (also guarded), so the removal is saved only at the next real change. Additions are accepted by the guard.
- **Pet bar, equipment-set outfits and Edit Mode layouts are captured but are not fingerprint inputs:** they are saved when a
  fingerprinted input changes, or at login or spec change, not on their own.
- **Armed even if the login work throws** (the login timer arms `ready` and the ticker after a `pcall`, then rethrows).
- **Spec change** keeps its own `ns:delay` timer; the ticker is independent of it. A spec swap changes the fingerprint too, so a
  change snapshot follows 10-20 s later (redundant, harmless).

`cursorFree` (`ns.Snapshot(guardSparse, cursorFree)` → `ns.Capture(..., cursorFree)`) never calls
`PickupAction`/`PlaceAction`/`ClearCursor`: picking an action up shows the empty-slot grid, which runs other addons'
action-bar hooks (Bartender4 threw there at logout, #984). A temp macro's index is then the first macro whose name equals
`C_ActionBar.GetActionText(slot)` (`GetMacroIndexByName`; two macros with the same name resolve to the first -- inferred from
the API's documented behaviour, not readable in the Blizzard UI source), else the index the stored profile for this
character and spec had at the same slot when it was a macro (which can be stale if macros were deleted or reordered since
that snapshot), else nil (restore skips a macro slot with no index). Every other snapshot (login, spec change, the
`snapshot` command, `API:Snapshot`) keeps the cursor round-trip.

## Gotchas

- **`C_EditMode.GetLayouts()` index offset:** `info.layouts` contains only *saved* layouts, but
  `info.activeLayout` indexes as if the preset layouts (Modern, Classic) came first —
  `CaptureLayouts` subtracts `#Enum.EditModePresetLayouts` before lookup. An active preset leaves
  `profile.layoutName` nil (presets are default 1-row bars).

- **`ns.Snapshot()` is a no-op during combat or mid-drag.** Macro temp-index resolution in capture
  touches protected APIs, and an in-progress cursor drag would be clobbered. Guarded by
  `InCombatLockdown()` / `GetCursorInfo()`. The login and spec timers can fire in combat, and then take no snapshot (the first steady change check makes up for a skipped login snapshot); the change-check ticker skips a tick in combat or with a cursor held
  (it does not advance its remembered fingerprint), so a change is saved on a later steady tick.
- **Sparse-capture guard (`Snapshot(true)` on the login/spec timers).** The login (`onLogin`, 2 s
  after entering the world) and spec-change (500 ms) snapshots run on a delay and can fire before
  the action bars finish populating — an unguarded store would then overwrite a good profile with a
  half-empty capture. `ns.shouldStore` refuses a *guarded* capture whose `slots` count is below the
  stored profile's. The **change-driven** snapshot is unguarded (a legitimate button removal is still recorded), except the first one
  after a login snapshot that stored nothing (`guardFirstChange`: skipped in combat, or refused because the bars were still
  unpopulated), which stays guarded; the guard is consumed by that first attempt even if it is refused. Same for the public `API:Snapshot()` / `/wbb` snapshot. Covered by `spec/tracker_spec.lua`.
- **`ns.Restore` bails in combat** (taint) — it prints a notice and returns.
- **Flyouts restore FIRST** (`RestoreFlyouts` pre-pass): `PickupSpellBookItem` for flyout-type
  spellbook items (e.g. the warlock Summon Demon drawer) silently fails after any other protected
  pickup operation in the same hardware event. Never reorder the restore passes.
- **`PickupSpell` fails for some known spells** (form-specific druid abilities) — restore falls back
  to pickup by spellbook index, then by spell **name** (`PickupSpellFromBookByName`, for a stored ID
  that no longer matches the book after rank/ID churn but whose name still resolves), and only warns
  when the spell *is* in the book but still failed.
- **Slots whose content can't be picked up are blanked** (`PickupAction` on the slot), so the result
  matches the profile rather than keeping stale leftovers.
- **Spell overrides are resolved both ways.** Capture stores the *base* spellID
  (`C_Spell.GetOverrideSpell` reverse-mapped); restore re-applies via an override map plus name /
  `FindBaseSpellByID` fallbacks, warning on any spell the character doesn't know.
- **Item slots** restore by id, then by link string, then (for toys captured as plain items in older
  profiles) `C_ToyBox.PickupToyBoxItem`. The "Missing item" warning is **gated on the item's data
  being cached** (`C_Item.IsItemDataCachedByID`) — on a cold cache it instead requests the load
  (`RequestLoadItemDataByID`) so a later restore resolves it, rather than warning spuriously.
- **Macros are recreated by name+body match**, not by index — restore reuses an existing matching
  macro or `CreateMacro`s one (account vs character bank inferred from `m.id`), warning if no macro
  slots remain. Macro action slots are placed in a second pass via an id→newId map. Capture keeps the
  icon as a **numeric fileID** when `GetMacroInfo` returns one (only the string/path form is
  normalized to a bare name), so `CreateMacro` gets a valid icon back on restore.
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
- **`petaction` / `futurespell` slots carry nothing re-placeable** (capture stores `{ id, type }`
  and neither type hits an `index`/`strindex` branch), so their wanted state is *empty*: the slot is
  blanked, and a slot that actually lost a button is reported with a `Warn`. That check runs **before**
  the "current state already matches" early-out (which would otherwise leave a pre-existing pet action
  in place) and `return`s before the shared place/blank tail — falling through would `PlaceAction` the
  just-picked-up action straight back into the same slot, the round-trip fixed in #751. User-visible
  consequence: a same-character save→restore now blanks these buttons, where they used to survive.
- **Keybindings restore replaces the binding set the profile was captured under**
  (`SaveBindings(profile.bindingSet or GetCurrentBindingSet())` — 1=account, 2=per-character;
  `SaveBindings` also makes that set active, so an account-set profile lands in the account set even
  if per-character bindings are live now), writing each captured key with its per-command binding
  context when available. Capture is a
  *full* snapshot (`CaptureBindings` walks every command via `GetNumBindings`/`GetBinding`), so
  restore first **clears any live key not in the profile** (the binding analog of
  `ClearUnusedSlots`) before applying — otherwise the result would be the union of the old live
  bindings and the profile's, leaving stale keys bound (e.g. a live `F5`→`ACTIONBUTTON5` surviving
  a profile that predates it).
