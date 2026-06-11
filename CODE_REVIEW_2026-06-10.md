# WoW AddOn Suite — Code Review (2026-06-10)

Full-codebase review of the Nazuraki addon suite (~15,500 lines of Lua across 16 addons).
Reviewed at full depth: LibNAddOn, LibNUI, Warbandeer_Characters, Warbandeer_Bars, and the
single-file addons; Warbandeer and Warbandeer_Collected were reviewed via their core
infrastructure and a sample of views. `Warbandeer_Collected/data/sets.lua` ID tables and the
vendored libs (base64, crc32) were not audited line-by-line.

Findings are ordered by severity. File references are `path:line`.

---

## High — likely user-visible bugs

### H1. Numeric IDs stringified by `sets.Set` / `sets.values` — quest event handlers never fire
`LibNAddOn/lua/sets.lua:13` and `:26` convert numeric values to strings (`v = v..""`) before
using them as set keys. But the event handlers that consume these sets look up **numeric**
quest IDs from event args:

- `Warbandeer_Characters/data/weekly.lua:54` — `preMidnight` eventHandler: `self.ids[questId]`
  with numeric `questId` vs string keys from `Set{87308,91795}` → never matches.
- `Warbandeer_Characters/data/weekly.lua:86` — `caches` eventHandler: same mismatch.
- `Warbandeer_Characters/data/quests.lua:73` — `WWIRep` eventHandler: `ids = Values(...)`
  (sets.values) → same mismatch.

Additionally `quests.lua:47` builds `ids = Set{q=86204}` — `sets.Set` iterates with `ipairs`,
so a map-style argument produces an **empty set**; the `UndermineStoryMode` handler can never
match either.

Net effect: all of these "live update on quest turn-in" paths are dead; the data only
refreshes via the login/refresh `get()` pass. Fix direction: stop stringifying numbers in
`sets.Set`/`sets.values` (check for other consumers relying on string keys first), or
`tostring()` the IDs at lookup.

### H2. `unregisterEvent(name, handler)` never removes the handler
`LibNAddOn/eventListener.lua:48` — the lookup loop iterates the wrong table:

```lua
for i,h in ipairs(self._eventHandlers) do   -- should be self._eventHandlers[name]
```

`_eventHandlers` is keyed by event name (no array part), so `ipairs` yields nothing, `idx`
stays nil, and the targeted handler is silently left registered. The follow-up
`getn(...) == 0` check then also misbehaves. Unregistering *all* handlers (nil handler) works.

### H3. Horde Haranir characters classified as Alliance
`Warbandeer_Characters/data/races.lua:72-73`:

```lua
raceIdToFactionIndex[86] = {15, true}
raceIdToFactionIndex[87] = {15, true}   -- every other pair is one true / one false
```

One of the 86/87 pair should be `{15, false}`. A Horde Haranir gets `isAlliance = true` baked
into its character record at first init (and it persists — `initialize()` only writes these
fields for new characters).

### H4. "Default View" setting can select a view the window can't open
`Warbandeer/init.lua:7` offers 7 options (`..., "Professions"`), but
`Warbandeer/window.lua:8` maps only 6 (`viewIdx = {"overview", "races", "summary", "gear",
"detail", "roles"}`). With Default View = Professions, the constructor never sets `_view`, and
`ns:Open()` (`window.lua:149`) crashes on `self.MainWindow._view:Show()`. The two lists also
encode the same ordering twice — derive one from the other.

### H5. Warbandeer's duplicated race tables have drifted from Warbandeer_Characters
`Warbandeer/init.lua:75-149` duplicates `ALLIANCE_RACES` / `HORDE_RACES` /
`raceIdToFactionIndex` from `Warbandeer_Characters/data/races.lua` — but without the Haranir
entries (raceIds 86/87, "Haranir" race name, faction index 15). Any code path resolving a
Haranir through Warbandeer's copy gets `unpack(nil)` or a missing grid slot (RaceView sizes
off these lists). The API already exposes `WarbandeerApi.ALLIANCE_RACES` etc. — consume those
instead of duplicating.

### H6. Leftover debug print spams chat on every quest turn-in
`Warbandeer_Characters/data/quests.lua:107-110`:

```lua
function ns:QUEST_TURNED_IN(questId)
  ns.Print("quest turned in " .. questId)
end
ns:registerEvent("QUEST_TURNED_IN")
```

Every quest turn-in prints to chat for all users. Remove (or gate behind a debug flag).

### H7. `Cell:Texture()` re-collapses `atlasSize = false` to `true`
`LibNUI/Cell.lua:30`:

```lua
self.texture:Atlas(data.atlas, data.atlasSize ~= nil and data.atlasSize or true)
```

When `atlasSize` is `false`, this evaluates to `true` — the exact and/or trap that
`LibNUI/Texture.lua:9-15` documents and branches around. Cells that are *updated* (re-sorts,
refreshes) silently regain native atlas sizing; cells created fresh do not. Use the explicit
nil-check branch like the Texture constructor.

---

## Medium — real defects, narrower blast radius

### M1. `Class` runs a parent's class-level `onLoad` twice for subclasses
`LibNAddOn/lua/class.lua:20-31` — when constructing a subclass, `parent:new(o)` already runs
the parent's `c.onLoad` (line 28), then the child's `new` runs `parent.onLoad(o)` again
(line 27). Example: every `DataView`/`ClassSummary` construction executes `TableFrame:onLoad`
(→ `update()` + `Autosize()`) twice. It currently only costs wasted work because the handlers
happen to be idempotent, but it's a footgun for any non-idempotent onLoad.

### M2. `TableFrame:set` corrupts row order when growing the cells array
`LibNUI/TableFrame.lua:202-206` — the fill loop starts at `#self.cells` (an index that already
exists), so `insert(self.cells, i, {})` shifts the existing last row up. Should start at
`#self.cells + 1`.

### M3. Button cooldown text: no seconds format, stale display, suspect API
`LibNUI/Button.lua:27-35` — `formatCooldown(t)` returns `nil` for `t <= 60`, and
`Label:Text(nil)` is a *getter* (no-op), so the label freezes at the last minute-formatted
value. The `m..':'..(t - m*60)` branch also renders fractional seconds ("1:23.4567").
Separately, `Button.lua:7` localizes global `GetItemCooldown`, which moved to
`C_Container.GetItemCooldown` in Retail, and `OnMouseUp` compares `enable == 1` where the C_
API returns a boolean — verify in-game; the cooldown path may simply error.

### M4. `/wbc delete` decrements the character count even when nothing was deleted
`Warbandeer_Characters/database.lua:23-27` — no existence check before
`numCharacters = numCharacters - 1`; a typo'd name (it's also case-sensitive, no realm
handling) corrupts the count permanently.

### M5. One shared delay timer drops concurrent broker updates
`Warbandeer_Characters/broker.lua:21-30` — all `eventDelay` fields share a single
`eventListener` frame; a second delayed event overwrites the first frame's `OnUpdate` before
it fires, silently dropping that field's update. Same hazard with `ns.delay`: the refresh
queue (`main.lua:23,41`) runs on the addon-wide timer, so any other `ns:delay` call mid-queue
kills the rest of the refresh pass. (The one-timer limitation is documented for `ns.delay`,
but the broker frame multiplexes *many* fields over one timer.)

### M6. `weeklies.caches` event handler does nil arithmetic on first fire
`Warbandeer_Characters/data/weekly.lua:87` — `self:set(currentValue + 1)` errors if the event
fires before the field's first `get()` populated it. Latent today because of H1; will surface
once H1 is fixed.

### M7. Equipment refresh request count is hardcoded
`Warbandeer_Characters/data/equipment.lua:57` — `ns.requests = 16`, but only slots with links
issue `RequestLoadItemData`. With empty slots the countdown in `ITEM_DATA_LOAD_RESULT` relies
on unrelated item-load events to ever reach zero. Count the actual requests issued (as the
professions gear handler at `professions.lua:336` correctly does).

### M8. `lists.map` silently substitutes the original value when the transform returns nil
`LibNAddOn/lua/lists.lua:44` — `insert(r, f and f(v, k) or v)`: a transform returning
`nil`/`false` inserts the untransformed value. `Warbandeer_Collected/DataView.lua:65-79`
already depends on this accident (unscanned sets pass the raw set table through as cell
data). Surprising semantics; at minimum document it, ideally make nil mean "skip" explicitly.

### M9. `CheckButton` click handling fights the native toggle — **fixed**
`LibNUI/CheckButton.lua:19-25` — `OnToggle(checked)` then `Checked(not checked)` reverses the
post-click state, layered on a Button base that registers `"AnyDown", "AnyUp"` (two click
firings). The double-negation appears to compensate for the double-fire; it works by accident
and breaks if the click registration changes. Worth simplifying to a single registered click.
**Update 2026-06-11:** the surviving flaw after the up-only simplification was that the
class OnClick hook fires from OnMouseUp — *before* the widget auto-toggles — so `OnToggle`
received the **inverted** (pre-toggle) state. Surfaced in ActionBarMaster as a barFilter
that filtered out everything after "Uncheck All"; also affected `ToggleSetting` persistence
suite-wide. Fixed by firing OnToggle from a real OnClick script (post-toggle).

### M10. `StatusBar:SetValue` horizontal textured branch is an empty stub
`LibNUI/StatusBar.lua:82-85` — the HORIZONTAL branch is `if dx > 0 then --[[nothing]] end`;
horizontal status bars with a texture table never update their fill. Also `p = 1 - (v/(m-n))`
ignores the min offset (`should be (v-n)/(m-n)`), and `SetColorFill` (`:31`, `:73`) is worth
verifying as a real StatusBar widget method on current Retail.

### M11. Recycle can sell more than the 12-item buyback window
`Recycle/addon.lua:55-74` — `sellItems()` sells every matching item at `MERCHANT_SHOW` with no
cap or confirmation. The merchant buyback page holds 12 items; a bad mark/grey day means
irrecoverable losses. Consider capping at 12 per visit or batching.

### M12. `classKey` derived from the localized class name
`Warbandeer_Characters/database.lua:107` — `classKey = gsub(className, " ", "")` uses
`GetClassInfo` (localized). On a non-English client, `classKey` won't match `data.DeathKnight`
(artifacts.lua), `ns.wow.Armor.byClass`, `ns.Colors[classKey]`, etc. Use the class file token
(`select(2, UnitClass("player"))`, already captured as `classId`/file elsewhere) as the key.

### M13. Roster sorts compare `equipment.ilvl` unguarded
`Warbandeer/views/SummaryView.lua:78` and `Warbandeer/views/Overview.lua:238,246` — two
same-level characters where one hasn't had an equipment pass yet (fresh alt) → comparison with
nil errors. Other code paths guard (`toon.equipment and toon.equipment.ilvl`); the sorts
should too.

---

## Low — polish, robustness, conventions

- **L1.** `LibNAddOn/lua/strings.lua:24` — `split` builds a character class from the raw
  token: any Lua-pattern magic char (`-`, `%`, `^`...) breaks or alters matching, and a
  multi-char token splits on *each* char. Fine for current callers; document or escape.
- **L2.** `LibNAddOn/lua/lists.lua:32-36` — `generate` with `start > 1` produces a sparse
  table (`insert(r, i, ...)` beyond `#r+1`); `fold`'s doc ("each of size n") doesn't match the
  round-robin implementation.
- **L3.** `LibNAddOn/api.lua:15,21` — mixed `ns:Print(...)` / `ns.Print(...)` calling
  conventions only work because `Print` self-detects its receiver; pick one.
- **L4.** `LibNAddOn/database.lua:28` — `version ~= self.db.version` compares the `.toc`
  metadata **string** against whatever type `MigrateDB` stores; a numeric `db.version` means
  migration runs every login. (HideStanceBar's `MigrateDB` never sets `db.version` at all —
  same effect, `HideStanceBar/addon.lua:5-10`.)
- **L5.** `LibNAddOn/slashCommands.lua:27-41` — `registerCommand(cmd, subcmd, ...)` installs
  the *first subcommand's* handler as the base-command handler (fallthrough for unknown
  subcommands runs an arbitrary handler). Intentional-looking but surprising; worth a comment
  or an explicit default handler.
- **L6.** `LibNUI/Frame.lua:142-155` — `Frame:delay` shares the `OnUpdate` slot with
  `startUpdates`/`onUpdate` animation; calling delay on an animating frame silently kills the
  animation.
- **L7.** `LibNUI/AutoWidget.lua:7-11` — the `onClick` branch builds a bare Button, ignoring
  label/texture options; `update()` (`:38`) is an empty stub despite the class comment
  promising reconfiguration.
- **L8.** `Warbandeer_Characters/data/artifacts.lua:33-44` — Evoker returns a flat
  `{goal, progress}` where the declared shape is a map keyed by `wq/dungeon/kills`; the
  `/wbc dump artifact` command also errors for classes with no `data[classKey]` (Evoker).
- **L9.** `Warbandeer_Characters/main.lua:29-31` — `refreshQueue` assumes a non-empty queue
  (`remove(queue, 1)` then index nil entry); harmless today, will error if brokers register no
  fields or the queue is drained by a colliding delay (see M5).
- **L10.** `Warbandeer_Bars/capture.lua:10-34` vs `restore.lua:16-39` — `BuildSpellOverrides`'
  comment says it maps override→base, but the spell branch maps base→override
  (`map[spellId] = GetOverrideSpell(spellId)`), while the flyout branch maps override→base
  (`map[ovr] = sid`). Capture and restore build the *same* map yet label it as opposite
  directions. Behavior mostly survives via the name/`FindBaseSpellByID` fallbacks at restore
  time, but the captured IDs are inconsistent — straighten the direction in both.
- **L11.** `Warbandeer_Characters/data/playtime.lua:29` — `RequestTimePlayed()` at login
  triggers the default UI's "Total time played" chat message every session; consider
  suppressing around the call.
- **L12.** `CombatOutline/core.lua:18-21` — leaving combat hardcodes `OutlineEngineMode 0`,
  stomping a user's chosen value (the TODO in the file acknowledges this).
- **L13.** `Warbandeer/views/SummaryColumns.lua:129-146` — if the calendar isn't loaded when
  the first (Alliance) table builds but is for the second, only one table gets the real DMF
  column; the other gets a blank auto-added column from `update()`. Self-heals on later
  builds; worth a re-check on `OnBeforeShow`.
- **L14.** `LibNAddOn/globals/player.lua:111-123` — `Player:GetProfessions()` caches forever;
  learning/dropping a profession mid-session serves stale data to the basic broker.
- **L15.** Docs: root `CONTEXT.md` addon index/dependency graph is missing **ShadowsOfUI-GCD**
  and **BarNonce** (both exist in the repo with no CONTEXT entry). Also
  `Warbandeer_Collected/data/sets.lua` is 2,346 lines against the suite's 200-300 line
  convention — being a pure data table makes it tolerable, but it could split per release.

---

## Notes on things that look wrong but aren't

- `weekly.lua` `get = function(_, _, current)` signatures are correct: brokers call
  `field:get(toon, currentValue)`, so the second underscore is `toon`.
- `serialize.lua`'s signed-int CRC comparison is consistent on both sides of the equality, so
  the bit-library sign quirks cancel out.
- `Theme`/`Region` theme inheritance and the TableFrame `offsetX/offsetY` constraints match
  their documented gotchas.

## Suggested fix order

1. H1 + M6 (one change in sets.lua unlocks all the dead event handlers; fix the nil-arith at
   the same time)
2. H3 + H5 (Haranir faction data, deduplicate race tables through WarbandeerApi)
3. H4 (default-view crash), H6 (chat spam), H7 (one-line cell fix)
4. H2, M2, M3 (LibNUI/LibNAddOn library fixes)
5. The rest as touched.
