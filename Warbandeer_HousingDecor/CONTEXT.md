# Warbandeer_HousingDecor

**Deps:** LibNAddOn, LibNUI · **OptionalDeps:** none · **SavedVars:** `WarbandeerHousingDecorDB` (v1) · **Commands:** `/housingdecor`, `/wbdecor` (`""` open, `scan`, `wanted`) — `/decor` is deliberately avoided (a common third-party decor-vendor addon owns it) · **API:** publishes `WarbandeerHousingDecorApi` (hardcoded in `api.lua`, not `X-NUI-API`) · **UI:** LibNUI (`X-NUI-UI`)

A standalone **housing decor collection tracker**, modelled on the *packaging* of Warbandeer_Collected (sibling addon + published API bridge + embedded view/tab in Warbandeer) but with a **single-axis, account-wide** body instead of the class×set matrix. Decor collection is warband-level (`totalNumStored`/`totalNumPlaced` are account counts; houses belong to the warband), so there is **no per-character axis and no `Warbandeer_Characters` dependency** — the whole scan runs off `C_HousingCatalog` on whatever character is logged in. The catalog is fully enumerable from the client (`CreateCatalogSearcher():GetAllSearchItems()`), so there is **no static DB** (unlike Collected's generated `data/` + tooling) — the entry list is rebuilt live each session and never persisted; only the wanted flags + a header count are saved.

Warbandeer embeds the same list as an optional **`decor`** view (`Warbandeer/views/HousingDecorView.lua`), gated on the `WarbandeerHousingDecorApi.List` global; `/wb decor` opens it. The two grids share the account-wide wanted DB and cross-refresh via `OnRatingsChanged`/`OnScanned`.

## Files

| File | Purpose |
|---|---|
| `init.lua` | `local ns = LibNAddOn(...)` + non-destructive `MigrateDB` (v1): `wanted` (`[recordID]=true`), cached `collected`/`total` counts, `windowPos`. |
| `commands.lua` | `/housingdecor` / `/wbdecor` (`""` open, `scan`, `wanted` list). |
| `catalog.lua` | **Pure, busted-specced:** `ns.NormalizeEntry(entry)` (owned/bonus count derivation) + `ns.DedupeVariants(variants)` (searcher variant descriptors → unique decor `recordID`s, filtered to `Enum.HousingCatalogEntryType.Decor`, first-seen order). WoW-API-free. |
| `ratings.lua` | The **wanted** model keyed by `recordID`: `IsWanted`/`SetWanted`/`ToggleWanted`/`WantedCount`, `WantedIcon` (`PetJournal-FavoritesIcon`), and the `OnRatingsChanged`/`NotifyRatingsChanged` listener registry. No S–F rank / per-race (decor has no race axis). |
| `api.lua` | Publishes `_G.WarbandeerHousingDecorApi`: `Counts`/`IsScanned`/`Entries`/`WantedCount`, `OnScanned`, wanted read+write + `OnRatingsChanged`, `ShowInfoTip`/`HideInfoTip` forwarders. `.List` (the grid class) is attached later by `list.lua`. |
| `scan.lua` | Stateful catalog layer: holds the searcher (`ns._searcher`), `ns:Scan()` (enumerate → dedupe → `GetCatalogEntryInfoByRecordID` → normalize → build `ns._entries` + the `ns._categoryName`/`ns._subcategoryName` maps + counts → refresh window → fire `_scanned`), `ns:onLogin` prime, and the debounced re-scan on `HOUSING_STORAGE_UPDATED`/`HOUSING_STORAGE_ENTRY_UPDATED`/`NEW_HOUSING_ITEM_ACQUIRED`. Guards `C_HousingCatalog` presence (no-ops pre-housing). |
| `controls/InfoTip.lua` | Shared decor hover tooltip on the game's `GameTooltip` (`ns.ShowInfoTip`/`HideInfoTip`/`RefreshInfoTip`): name (quality-colored), owned breakdown (stored/placed) or "Not collected", first-acquisition bonus, wrapped source text, shift-click hint. Owner-anchored (`SetOwner(row, "ANCHOR_RIGHT")`) so it stays on-screen off a full-width row and costs nothing to lay out during scroll. |
| `list.lua` | `HousingDecorList = Class(Frame)` — a **windowed** one-row-per-decor list (LibNUI's `VirtualList` builds a frame per item, too many for the ~1800-entry catalog). Owns a `ScrollFrame` whose child is sized to `#_shown * ROW_H` (a zero-size bottom spacer pins that content extent so the scrollbar spans everything), plus a recycled pool of ~viewport-worth of rows repositioned/repopulated by `_window()` on every scroll/resize. Each row is a **Button** (mouse-motion enabled, so hover fires) — `createRow`/`updateRow` (quality-ringed icon, name, owned count, bonus star, wanted star). `GetItems` (filter+sort over `ns._entries`), `Render`/`Refresh`, `VisibleCounts`, row interaction (hover→InfoTip, shift-click→`ToggleWanted`). Attaches itself to `WarbandeerHousingDecorApi.List` + `ns.List`. `STRIP_H`. |
| `filters.lua` | Re-opens `HousingDecorList` with the filter setters (`ToggleUncollected`/`ToggleWantedOnly`/`SetSearch`/`_applyCategoryKey`), `CategoryOptions` (hierarchical category→subcategory menu), and `BuildFilterStrip` (Unowned + Wanted toggles + Category `FilterDropdown` + search `EditBox`). |
| `window.lua` | Standalone `DecorWindow = Class(TitleFrame)`: filter strip + counter band + the `HousingDecorList` (fixed-size window; the list scrolls internally). `void-dark`→`dark` theme fallback, `RefreshCounter`/`RefreshWanted`/`Refresh`, `ns:Open`, `ns:CompartmentClick`, and the `OnRatingsChanged` live-refresh. |
| `spec/` | busted specs (`loader.lua` harness + `housingdecor_spec.lua`) for `NormalizeEntry`, `DedupeVariants`, and the wanted model; excluded from zip + release detection. |

## API (`WarbandeerHousingDecorApi`, `api.lua`)

Mirrors `WarbandeerCollectedApi`. A plain global table published as the last line of `api.lua`; `list.lua` then hangs the embeddable grid class on `.List`.

- `API:Counts()` → `collected, total` (from the last scan) · `API:IsScanned()` → `#ns._entries > 0` (this session) · `API:Entries()` → the live `HousingDecorEntry[]` · `API:WantedCount()`.
- `API:OnScanned(fn)` — fired after each `ns:Scan()` rebuilds the snapshot.
- `API:IsWanted`/`SetWanted`/`ToggleWanted` + `API:OnRatingsChanged(fn)` — the account-wide wanted DB, mutated through one place so both grids stay in sync.
- `API:ShowInfoTip(entry, parent, position)` / `API:HideInfoTip()` — lazy forwarders to `ns.ShowInfoTip`/`HideInfoTip`.
- `API.List` — the `HousingDecorList` grid class; build with `embedded = true` to reuse it in a host view. `API.WantedIcon` — the wanted-star atlas.

## Data (`scan.lua`, `catalog.lua`)

The searcher is the only enumeration source: `ns._searcher:GetAllSearchItems()` returns per-**variant** descriptors (`{ entryType, recordID }`; dye variants share a `recordID`), which `ns.DedupeVariants` collapses to unique decor `recordID`s. Each resolves via `C_HousingCatalog.GetCatalogEntryInfoByRecordID(Enum.HousingCatalogEntryType.Decor, recordID, true)` → a `HousingCatalogEntryInfo`, normalized by `ns.NormalizeEntry` (identical to HousingVendor's):

- `stored` = `totalNumStored + remainingRedeemable` (on hand) · `total` = `stored + totalNumPlaced` (owned anywhere) · `owned` = `total > 0`.
- `bonus` = `firstAcquisitionBonus` (House XP) · `bonusAvailable` = `bonus > 0 and total == 0` (unowned only).

A `HousingDecorEntry` also carries `name`, `iconTexture`/`iconAtlas`, `quality`, `categoryIDs`/`subcategoryIDs`, and `sourceText`. `recordID` is the stable key (the analog of Collected's `setId`). Category/subcategory localized names are cached into `ns._categoryName`/`ns._subcategoryName` during the scan (successful resolutions only, retried on miss) for the filter dropdown.

## UI (`list.lua`, `filters.lua`, `window.lua`)

The body is a **windowed** list over a LibNUI `ScrollFrame` (only the visible rows + a small buffer are live, recycled on scroll), *not* a TableFrame matrix and *not* the non-windowed `VirtualList`. `GetItems` filters `ns._entries` by category/subcategory (mutually-exclusive fields driven by one hierarchical dropdown) + unowned + wanted + name search, sorted alphabetically; `Render` sizes the scroll child and `_window` repaints the visible slice. Filter changes route through `Render` → `onFilterChanged` (host counter). Shift-click a row → `ns:ToggleWanted` → `NotifyRatingsChanged` → each host's `OnRatingsChanged` listener re-renders its list + tally (so a second open list cross-updates). The standalone window is fixed-size (the list scrolls internally); the embedded Warbandeer view sizes itself and the window `Fit()`s to it.

## Gotchas

- **Account-wide, not per-character.** There is deliberately no per-alt axis: every character queries the same `C_HousingCatalog` counts. `IsScanned`/counts reflect the current session's live scan (`#ns._entries`), not a persisted snapshot.
- **Entry list is never persisted.** Only `wanted` + cached counts + `windowPos` are saved; the catalog is re-enumerated every session, so it can't go stale. This is the intended divergence from Collected (which persists `db.sets`).
- **Must `RunSearch()` to populate.** The searcher's result set is empty until a search runs — `GetCatalogSearchResults()` (not `GetAllSearchItems()`) returns entries only after `RunSearch()`, which arrives asynchronously via the `SetResultsUpdatedCallback`. `ns:onLogin` creates the searcher and kicks `RunSearch()`; the `HOUSING_*` events re-run it (mirrors Blizzard's `HousingDashboardCatalog`). The scan is debounced via `ns:delay` (one pending timer); the embedded view shows an empty-state message until `IsScanned`.
- **Icon is a fileID OR an atlas.** Decor entries set exactly one of `iconTexture` / `iconAtlas`; `updateRow` branches (`row._icon:Atlas(...)` vs `:Texture(...)`), falling back to the `INV_Misc_QuestionMark` fileID.
- **Bonus vs wanted star.** Both are gold stars but never conflict on meaning: the bonus star (`auctionhouse-icon-favorite`, on the icon's top-left) only shows on **unowned** decor with a claimable bonus; the wanted star (`PetJournal-FavoritesIcon`, right edge) is orthogonal. The InfoTip spells both out.
- **Construction-time `Render`.** `HousingDecorList`'s ctor calls `Render`, which fires `onFilterChanged` before the host's counter Label exists — so `RefreshCounter` guards on `self.counter`.
- **Windowed list needs the spacer + a Button row.** The scroll range derives from the scroll child's content extent, so with only the pooled rows live you'd be unable to scroll past them — the zero-size bottom spacer pins the extent to `#_shown * ROW_H`. And each row must be a `type = "Button"` frame with `SetMouseMotionEnabled(true)` for `OnEnter`/hover to fire; a child `ui.Button` captures clicks but not motion (that was the "no tooltips" bug).
- **Hover tooltip is `GameTooltip`, not a custom frame.** A custom panel anchored off a full-width row's right edge lands off the window; `GameTooltip:SetOwner(row, "ANCHOR_RIGHT")` auto-stays on-screen and avoids per-hover layout cost during scroll.
