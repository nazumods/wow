# Warbandeer_Collected

**Deps:** LibNAddOn, LibNUI, Warbandeer_Characters · **SavedVars:** `WarbandeerCollectedDB` (v2) · **Commands:** `/collected`, `/collect` (no-arg opens the window; `scan` subcommand) · **Reads:** `WarbandeerApi` · **UI:** LibNUI · **Compartment:** `WarbandeerCollected_OnAddonCompartmentClick` · **Exposes:** `WarbandeerCollectedApi` (read-only data bridge for Warbandeer's `collected` view)

Transmog set collection tracker. Renders a class × instance-set grid showing, per character, how many appearances of each tier/dungeon set remain uncollected, plus per-character instance lockouts.

## Files

| File | Purpose |
|---|---|
| `init.lua` | Assignment-form init (`local ns = LibNAddOn(...)`); `MigrateDB` seeds `db.sets`/`collected`/`total`, sets `version = 2` |
| `commands.lua` | empty command (`/collected` with no args) → `ns:Open()`; `scan` subcommand — rebuilds `db.sets`/`collected`/`total` from `C_TransmogSets` APIs, refreshes the open window |
| `data/sets.lua` | `ns.Sets` (set-group array) + `ns.Releases` (expansion names, Vanilla→Midnight) |
| `api.lua` | Creates the global `WarbandeerCollectedApi` — read-only bridge so sibling addons (Warbandeer) can render the collection without depending on this addon's UI. Exposes `.Sets`/`.Releases` and `Counts()`, `IsScanned()`, `GroupStatus(groupId)`, `SetStatus(groupId, setId)` reading account-wide `ns.db`, plus `ShowInfoTip(group, set, parent, position)` / `HideInfoTip()` (lazy forwarders to `ns.ShowInfoTip`/`HideInfoTip`) so consumers render the identical per-slot source tooltip |
| `DataView.lua` | `ns.DataView` (TableFrame subclass) — lock + name + 13 class columns; cell value = uncollected count, tinted by a 10-shade red→green gradient; name click opens `LockoutView` |
| `controls/InfoTip.lua` | `ns.InfoTip` (CleanFrame) + `ui.ShowInfoTip(group, set, parent, pos)` / `ui.HideInfoTip()` — per-slot source list for a hovered set |
| `controls/LockoutView.lua` | `ns.LockoutView` (CleanFrame) + `ns.ShowLockoutView(grpIdx, parent, pos)` / `ns.HideLockoutView()` — character list, locked toons red and sorted first |
| `window.lua` | `MainWindow` (TitleFrame, `special`, `level=580`): DataView + ScrollFrame + `Sets: x / y` counter; `ns:Open()`, `ns:CompartmentClick(btn)` |

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
</content>
</invoke>
