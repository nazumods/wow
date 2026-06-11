# WoW AddOn Suite — Code Review (2026-06-11)

Full-depth follow-up review of the entire suite (~16,000 lines of Lua across 16 addons).
Every Lua file was read in full this pass, including the areas sampled last time
(all 12 Warbandeer views + 20 summary columns, all LibNUI widgets, Warbandeer_Collected,
Warbandeer_Bars, LibNUI_Test, and the single-file addons). `Warbandeer_Collected/data/sets.lua`
ID tables were spot-checked for shape, not audited per-ID.

**Status of the 2026-06-10 review:** all 28 findings (H1–H7, M1–M13, L1–L15) verified fixed
in commits #47–#71 and earlier. Busted suite: 49/49 green. Luacheck: 0 warnings in 150 files.

Findings ordered by severity. References are `path:line`.

---

## High

### H1. Warbandeer_Bars restore path lacks the nil-guard capture got
`Warbandeer_Bars/restore.lua:21` (`BuildOverrideMap`) and `:47` (`BuildFlyoutMap`) call
`C_SpellBook.GetSpellBookSkillLineInfo(idx)` and immediately index the result
(`info.numSpellBookItems`). The API is MayReturnNothing — which is exactly why
`capture.lua:16-17` got an `if info then` guard (commit 02e989d). Both restore-side
builders run at the top of every `ns.Restore`, so a nil skill line aborts the entire
restore with a Lua error. Mirror the capture guard.

---

## Medium

### M1. `/wbc stat` does nil arithmetic on every character not yet logged this patch
`Warbandeer_Characters/dump.lua:34` — `pp = pp + t.playtime.byPatch[patch]` with no guard.
`byPatch[patch]` is only written on a character's first `TIME_PLAYED_MSG` of the patch, so
after any client patch the command errors until every alt has logged in. Also `:53` — `ft`
(most-played name) is nil when no character has playtime, breaking the concat. (Bonus: the
command's description string is a copy-paste of "Dump current character data".)

### M2. Stale `toon.specializationActive` field — spec line never renders
DB migration v7 moved the spec to `basic.specialization.active` and nils the old field
(`database.lua:99`), but two display paths still read the dead field, so the spec line
silently never appears:
- `LibNUI/Tooltip.lua:270` — `Tooltip:ShowForCharacter` (and its `ui.ShowCharacterTooltip` wrapper)
- `Warbandeer/views/GearView.lua:66` — name-cell hover tooltip

Use `toon.basic.specialization and toon.basic.specialization.active`. (LibNUI knowing the
WarbandeerApi character shape at all is itself a layering smell — `ShowForCharacter` could
live in Warbandeer.)

### M3. First-session characters crash views via unguarded `equipment.ilvl`
A brand-new character's broker tables exist but are empty until the staggered refresh
queue reaches each field (~100 ms/field). During that window:
- `Warbandeer/views/Overview.lua:259` — TopAlts cell: `ns.IlvlColor(toon.equipment.ilvl)`
  → `IlvlColorObj(nil)` → `nil >= number` comparison error. A fresh alt that is the only
  character of its class breaks the Overview build.
- `Warbandeer/views/summaryCol/ilvl.lua:34` — `WrapTextInColorCode(toon.equipment.ilvl)`
  with nil ilvl errors the Summary row build.
- Same family: `basic.level` comparisons in `SummaryView.lua:49` / `GearView.lua:116`
  constructors run before `level` is populated.

The sorts were fixed (#61) with `ns.ilvlOf`; these display paths need the same guard.

### M4. RaceView keys class columns by localized class name
`Warbandeer/views/RaceView.lua:86` — `lists.find(Classes, t.className)` compares against the
English literals in `Classes`. On a non-English client `colIdx` is nil and `b[colIdx] = ...`
throws "table index is nil", killing the view. Same locale family as the fixed #43; key by
`t.classKey` (e.g. via `ns.wow.ClassByKey`) instead.

### M5. CharacterTooltip crashes for a character with no specialization data yet
`Warbandeer/controls/CharacterTooltip.lua:106` — `toon.basic.specialization.active` is
indexed unguarded (every other consumer guards `specialization`). Hovering a first-session
character's name cell errors.

### M6. Collected LockoutView indexes rows that don't exist after the roster grows
`Warbandeer_Collected/controls/LockoutView.lua:69-74` — the inner TableFrame's `data` is
built once at construction (`GetData`), but `ShowLockoutView` writes
`_view.data.data[i][1]` for the *current* character list. Any character added after the
view was first shown → `data[i]` is nil → error. Rebuild rows from `GetData()` (or append
missing rows) before mutating.

### M7. Equipment and profession-gear item-load countdowns decrement each other
`Warbandeer_Characters/equipment.lua:83-90` and `professions.lua:346-353` both subscribe to
`ITEM_DATA_LOAD_RESULT` and both fire their `RequestLoadItemData` batches from the same
`PLAYER_EQUIPMENT_CHANGED` event. Every load result decrements **both** counters, so each
refresh fires before its own items have all loaded (the per-field cache fallbacks mask it,
but captured data can be one change stale). Tag requests (or count slot-specific results)
per consumer.

### M8. WWIRep quest handler can fire before the field has data, and over-decrements
`Warbandeer_Characters/data/quests.lua:72-80` — `currentValue.missing - 1` errors if
`QUEST_TURNED_IN` fires before the field's first `get()` populated it (login-time turn-ins),
and a re-fired id (or one already true in `currentValue`) drives `missing` negative /
`complete` true early. Guard nil and only decrement when `currentValue[zone]` was falsy.

### M9. `ns.wow.Factions:Get` indexes a `_data` table that is never created
`LibNAddOn/globals/factions.lua:11` — `self._data[id]` with `_data` nowhere initialized;
the first call errors. Currently has **no callers** (Overview rebuilt its own faction
gathering), so it's dead code with a landmine — either add `_data = {}` or delete the
module.

---

## Low

- **L1.** `Recycle/addon.lua:173-175` — every `BAG_UPDATE` schedules an unconditional
  0.5 s full-bag re-mark with no debounce; a loot burst stacks dozens of rescans. Collapse
  to one pending timer (or use `BAG_UPDATE_DELAYED`).
- **L2.** `LibNUI/Button.lua:60-63` — a Button constructed with lowercase `onClick` gets
  `RegisterForClicks("AnyDown", "AnyUp")`, so the script fires twice per click. No current
  caller uses lowercase `onClick` (consumers use `OnClick`/`OnMouseUp`), but CheckButton
  already had to patch this exact trap for itself (`CheckButton.lua:10-13`).
- **L3.** `LibNUI/SecureButton.lua:13-20` — `action.spell`/`action.toy` are stored into
  `self.itemID`, and Button's cooldown path feeds that to `C_Item.GetItemCooldown` — wrong
  API for a spell ID. The toy case is fine; the spell case needs the spell cooldown API.
- **L4.** `LibNAddOn/globals/player.lua:190-211` — `/lib player <method>` invokes
  `Player[args]()` without a receiver; any method written with `self:` (GetHealthPercent,
  GetRewardOptions, isMaxLevel, …) errors. Call `Player[args](Player)`.
- **L5.** `LibNAddOn/globals/player.lua:95-108` — `Profession:GetInfo` reads an 11th return
  (`v`) from `GetProfessionInfo` to compute `isKhazAlgar`; the documented API returns 10
  values, so the flag is likely always false. Verify in-game; nothing currently consumes it.
- **L6.** `LibNAddOn/globals/colors.lua:66` — `rgba` annotation says alpha is 0–255; the
  implementation (and root CLAUDE.md) treat it as 0–1.
- **L7.** `LibNUI/Cell.lua:89-93` — `Cell:update` clears stale onClick/onEnter/onLeave
  scripts only when the *new* data is a table; updating a clickable cell with a plain
  string leaves the previous handlers attached.
- **L8.** `Warbandeer_Collected/controls/InfoTip.lua:61,113` — `ui.ShowInfoTip` /
  `ui.HideInfoTip` register addon-local controls on the shared LibNUI `ui` global, which
  LibNUI/CLAUDE.md explicitly forbids (register on `ns`). `LockoutView` does it correctly.
- **L9.** Pooled-row views (`ProfsView`, `CraftingView`, `MidnightProfs`) grow `tbl.rows`
  but never shrink, and `TableFrame:addRow` permanently grows the frame Height — if the
  visible row count shrinks (profession unlearned, faction toggle), the table keeps dead
  space and stale hidden rows.
- **L10.** `LibNUI/settings/SettingsFrame.lua:16-18` — passing a partial `heading` table
  drops the default `fontObj`/`color` (Class defaults fill shallowly); heading options
  should merge per-key.
- **L11.** `LibNAddOn/settings.lua:70-71` — `addOn.settingsCategory` is overwritten per
  category in the loop; with multiple categories only the last survives.
- **L12.** `Warbandeer_Characters/data/currency.lua:54-68,97-111` — Hero/Myth Dawncrest
  capture weekly `earned`/`capped` but have no `resetOn`, so the red "capped" state lingers
  after reset until the next full refresh of that character.
- **L13.** `Warbandeer_Characters/data/weekly.lua:113` — `hasUnclaimedVault.reset` reads
  `vault.best` and only works because `"hasUnclaimedVault" < "vault"` in the alphabetical
  `fieldOrder` reset pass. Worth an `order` field or a comment pinning the dependency.
- **L14.** `LibNUI/TableFrame.lua:211-243` — `addCol` doesn't honor `padLeft` (the
  constructor does), so dynamically added columns lose that spacing option.
- **L15.** `Warbandeer/views/DetailView.lua:433` — subtitle renders `char.race`, which is
  the race *file token* ("NightElf", "Haranir"), not a display name. CharacterTooltip maps
  through `ALLIANCE_RACES`/`HORDE_RACES`; DetailView could too.
- **L16.** `Warbandeer_Bars/libs/base64.lua:14` — `enc` iterates the byte array with
  `pairs`; array order under `pairs` is an implementation detail. Works under WoW's Lua,
  but `ipairs` costs nothing and removes the assumption (the data is hand-rolled binary).
- **L17.** `BarNonce/addon.lua:16` — comment says "80% opacity", code sets 0.7 (CONTEXT.md
  says 70%). Fix the comment.
- **L18.** `ShadowsOfUI-XP/ExpBar.lua:162-167` — the bar is skipped when already max level
  at load, but a character that *reaches* max level mid-session keeps the (now pointless)
  XP bar until reload.

---

## Notes — looks wrong, isn't

- `Warbandeer_Characters/types.lua` missing from the `.toc` is intentional: it's a
  `---@meta` LuaLS stub, never loaded by WoW.
- `weekly.lua` reset/get `current`-preserving patterns and the broker
  `eventHandler(field, currentValue, ...)` signatures are consistent throughout.
- `serialize.lua`'s signed-int CRC comparison is consistent on both sides (unchanged from
  last review's note).
- `LibNUI_Test/table.lua` calls `t:onLoad()` after construction (so it runs twice); the
  handlers are idempotent and it's test-harness-only.
- Collected `sets.lua` groups without `instance`/`difficulty` (e.g. Blackwing Lair) read
  `locks[nil]` — a safe nil lookup, rendering "no lock", which matches intent.

## Suggested fix order

1. H1 (one-guard fix; restore is the addon's whole point)
2. M2 + M5 (spec-line family), M3 (ilvl guards — reuse `ns.ilvlOf`)
3. M1 (patch-day breakage), M4 (locale), M8 (quest handler guard)
4. M6, M7, M9
5. Ls as touched.
