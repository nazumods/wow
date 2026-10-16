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
| `tracker.lua` | `ns.Snapshot(guardSparse?, cursorFree?)` + `ns.shouldStore` + auto-capture triggers (login / spec change / bar, macro and binding changes; none at logout); combat- & cursor-guarded |
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
| `ACTIONBAR_SLOT_CHANGED`, `UPDATE_MACROS`, `UPDATE_BINDINGS` | 10000 ms after the **last** event (`CHANGE_SETTLE_MS`; `ns:debounce("change", ...)`, its own keyed timer; every event restarts the wait) |
| `EDIT_MODE_LAYOUTS_UPDATED` (→ `ns.CaptureLayouts()`) | none |

There is **no logout snapshot**. By `PLAYER_LOGOUT` the client has already emptied the action bars: on Retail on
2026-10-15 a logout snapshot that was made to store (using the last known spec) wrote a profile with 0 action slots over a
101-slot one (observed). Before that it stored nothing because the spec id presumably read 0 and `store()` refuses
`specID == 0` (inferred, not read from the client). `ns.PLAYER_LOGOUT` takes no snapshot; it only disarms `ready`, so a change
timer still pending when the UI starts tearing down captures nothing.
Bar changes are saved as they happen instead (`tracker.lua`):

- **Armed only after the login snapshot** has run (`ready`): before it the bars are still populating, which is why the login
  snapshot is sparse-guarded. Change events earlier are ignored.
- **No self-trigger.** While a cursor-path capture runs (login snapshot, `snapshot` command, `API:Snapshot`) a `capturing` flag
  makes the handlers ignore events. The change snapshot itself is `cursorFree`, which picks nothing up, so it fires no
  action-bar event and cannot loop. (If the client delivers a cursor-path capture's events after it returns, one extra
  cursor-free snapshot results; it cannot loop.)
- **Unguarded** (`Snapshot(false, true)`): it records a legitimate reduction, the role the logout snapshot used to have.
- **Combat:** a snapshot that comes due in combat sets `pendingChange` and runs on `PLAYER_REGEN_ENABLED`. One that comes due
  while the cursor holds something (`Snapshot` skips then) is re-armed for another quiet period.
- **Cost of having no logout snapshot:** a change made in the last 10 s before logout or `/reload` is not saved (the pending timer is
  dropped), and if it was a *reduction* (buttons removed) the next login snapshot, being sparse-guarded, refuses the smaller
  capture, so the removal is saved only at the next change event. Additions are accepted by that guard.
- **Armed even if the login work throws** (the login timer arms `ready` after a `pcall`, then rethrows).
- **Spec change** keeps its own `ns:delay` timer; a bar change uses `ns:debounce`'s keyed timer, so neither cancels the other.

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
  `InCombatLockdown()` / `GetCursorInfo()`. The login and spec timers don't fire in combat; a change-driven snapshot that does come
  due in combat is held (`pendingChange`) and run on `PLAYER_REGEN_ENABLED`.
- **Sparse-capture guard (`Snapshot(true)` on the login/spec timers).** The login (`onLogin`, 2 s
  after entering the world) and spec-change (500 ms) snapshots run on a delay and can fire before
  the action bars finish populating — an unguarded store would then overwrite a good profile with a
  half-empty capture. `ns.shouldStore` refuses a *guarded* capture whose `slots` count is below the
  stored profile's. The **change-driven** snapshot is unguarded (it only runs after the login snapshot, so the bars are populated; a
  legitimate button removal is still recorded). Same for the public `API:Snapshot()` / `/wbb` snapshot. Covered by `spec/tracker_spec.lua`.
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
