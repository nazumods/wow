# Warbandeer_Collected

**Deps:** LibNAddOn, LibNUI, Warbandeer_Characters · **SavedVars:** `WarbandeerCollectedDB` (v2) · **Commands:** `/collected`, `/collect` (no-arg opens the window; `scan` subcommand) · **Reads:** `WarbandeerApi` · **UI:** LibNUI · **Compartment:** `WarbandeerCollected_OnAddonCompartmentClick` · **Exposes:** `WarbandeerCollectedApi` (read-only data bridge for Warbandeer's `collected` view)

Transmog set collection tracker. Renders a class × instance-set grid showing, per character, how many appearances of each tier/dungeon set remain uncollected, plus per-character instance lockouts.

## Files

| File | Purpose |
|---|---|
| `init.lua` | Assignment-form init (`local ns = LibNAddOn(...)`); `MigrateDB` seeds `db.sets`/`collected`/`total`, sets `version = 2` |
| `commands.lua` | empty command (`/collected` with no args) → `ns:Open()`; `scan` subcommand — rebuilds `db.sets`/`collected`/`total` from `C_TransmogSets` APIs, refreshes the open window |
| `data/sets.lua` | `ns.Sets` (set-group array) + `ns.Releases` (expansion names, Vanilla→Midnight) |
| `data/models.lua` | `ns.RaceModels` (`[raceID][sex]=creatureDisplayID`, an **enhancement** that unlocks exact gender selection per race — seeded from Blizzard's Allied Races UI, hand-maintained, verify in-game) + `ns.PlayableRaces()` (ordered `{id,name,file}` list for the selector, skipping ids absent on this client) |
| `api.lua` | Creates the global `WarbandeerCollectedApi` — read-only bridge so sibling addons (Warbandeer) can render the collection without depending on this addon's UI. Exposes `.Sets`/`.Releases` and `Counts()`, `IsScanned()`, `GroupStatus(groupId)`, `SetStatus(groupId, setId)` reading account-wide `ns.db`, plus `ShowInfoTip`/`HideInfoTip` and `ShowDressingRoom(group, set)`/`HideDressingRoom()` (lazy forwarders) so consumers render the identical tooltip + 3D preview window |
| `DataView.lua` | `ns.DataView` (TableFrame subclass) — lock + name + 13 class columns; cell value = uncollected count, tinted by a 10-shade red→green gradient; name click opens `LockoutView`. `ToggleOrder()` flips row order oldest/newest-first (`_reverse`), tracking display vs `ns.Sets` source index so lockout selection stays correct |
| `controls/InfoTip.lua` | `ns.InfoTip` (CleanFrame) + `ns.ShowInfoTip(group, set, parent, pos)` / `ns.HideInfoTip()` — per-slot source list for a hovered set. **Hover-persistent**: mouse-enabled, with a **Preview model** button; `HideInfoTip` defers (cancelable `C_Timer`) and the tip stays open while `MouseIsOver` it, so the cursor can travel onto the button. Tracks the current group/set for the button. Item names load async, so a render with blank rows requests the items (`C_Item.RequestLoadItemDataByID`) and re-renders (capped retries) until they resolve |
| `controls/LockoutView.lua` | `ns.LockoutView` (CleanFrame) + `ns.ShowLockoutView(grpIdx, parent, pos)` / `ns.HideLockoutView()` — character list, locked toons red and sorted first |
| `controls/DressingRoom.lua` | `ns.DressingRoom` (TitleFrame, `special`, `strata=HIGH`) + `ns.ShowDressingRoom(group, set)` / `ns.HideDressingRoom()` — persistent 3D preview: a `ui.Model` flanked by paper-doll equipment-slot columns (Head/Shoulder/Back/Chest/Wrist left, Hands/Waist/Legs/Feet right; each column centered independently, `UpdateSlots` fills each with the set piece's icon + green/red status border + an in-game `GameTooltip` on hover, capped icon-load retry; slots the set doesn't use show the shared `ui.media.unresolved` marker), plus an Undress toggle (`SetUndressed` — bare body for race id), a gender toggle, and a wrapped race-icon selector (defaults to the logged-in char). `Dress()` uses a `ns.RaceModels` creature display ID when one exists (exact race+gender), else renders the race via `Model:Unit("player", raceID)` (textured, gender follows the char), then `TryOn`s every `C_TransmogSets.GetAllSourceIDs(set.id)` source |
| `window.lua` | `MainWindow` (TitleFrame, `special`, `level=580`): DataView + ScrollFrame + `Sets: x / y` counter + a raid-order toggle button in the title bar (left of close; calls `DataView:ToggleOrder`, border goes gold when newest-first); `ns:Open()`, `ns:CompartmentClick(btn)` |

## Data Model (`ns.Sets`)

```lua
{ id, name, release, instance, difficulty, minLevel?,
  sets = { { id, name, classId }, ... } }  -- one entry per class set; id is the base set id
```
`release` indexes `ns.Releases`; `instance`/`difficulty` key into a character's `instances.locks` (from the data layer) for lockout display.

## SavedVariables (`WarbandeerCollectedDB`)

```lua
{ version = 2, collected = int, total = int,
  sets = { [groupId] = { [setId] = true | { collected, parts, total } } } }
```
- `true` = base set fully collected; otherwise a partial record (`parts` is the raw `GetSetPrimaryAppearances` array).
- `MigrateDB` is non-destructive: only ensures missing top-level keys exist.

## Scan Logic (`/collected scan`)

Resets the three DB keys, then for each group → each set with an `id`:
- `C_TransmogSets.IsBaseSetCollected(id)` true → store `true`, bump `collected`.
- else → `GetSetPrimaryAppearances(id)`, count `p.collected`, store `{ collected, parts, total }`.

`total` accumulates `#grp.sets`. After scanning, refreshes `ns.window.counter` and `ns.window.data`.

## Gotchas

- **Grid cells show *uncollected* count, not collected** — `text = total - collected`, and the gradient shade is keyed by the *collected* fraction (`floor(collected/total*10)`), so a low number on a green cell means nearly done.
- **InfoTip slot order is fixed** — it walks slots `{1,3,5,6,7,8,9,10}` (Head, Shoulder, Chest, Waist, Legs, Feet, Wrist, Hands), matching `GetSourcesForSlot` against the set's primary `appearanceID`s; collected sources green, missing red.
- **Lockout state lives in the data layer**, not here — read via `api.GetAllCharacters()` → `toon.instances.locks[group.instance][group.difficulty]`.
- **`ns:CompartmentClick`**: right-click runs the scan, any other click opens the window.
- **DataView auto-sizes the name column** at construction from the widest row label, then grows `rowArea`/self to match.
- **Arbitrary races need a `ModelScene` actor, not a bare `DressUpModel`.** `SetCustomRace` was removed, and `DressUpModel:SetDisplayInfo` renders non-player races untextured (white). The `ui.Model` widget borrows dressup scene 596 and skins its actor via `SetModelByCreatureDisplayID` (exact race+gender, needs a display ID) or `SetModelByUnit("player", …, customRaceID)` (any race, textured, gender = the char's). `ns.RaceModels` only supplies the former; it is hand-maintained and unverified beyond the Allied Races ids — verify in-game.
- **InfoTip hide is deferred, not immediate.** Cell `onLeave` arms a cancelable `C_Timer` that only hides once `MouseIsOver` the tip is false; a re-entered cell (`ShowInfoTip`) cancels it. This is what lets the **Preview** button be clickable. The tip is now mouse-enabled, so it can capture clicks over any grid cells it overlaps.
</content>
</invoke>
