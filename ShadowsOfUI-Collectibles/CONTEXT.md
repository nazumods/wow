# ShadowsOfUI-Collectibles

**Deps:** LibNAddOn · **OptionalDeps:** Warbandeer_Characters · **SavedVars:** `ShadowsOfUI_CollectiblesDB` (v1) · **Commands:** `/scollect` (`custom`, `itemtest`) · **API:** reads `WarbandeerApi` (`X-NUI-API`) + optional `WarbandeerDB` · **UI:** none (no LibNUI)

Icon-tinting addon: colours already-known / still-collectible items on the **Merchant** and
**Auction House** browse list. Replaces the standalone AlreadyKnown addon (re-derived in suite
style — hooks modeled on `ShadowsOfUI-Ilvl`, not copied). Assignment-form init
(`local ns = LibNAddOn(...)`); Blizzard Settings panel via `ns:RegisterSettings`. Guild bank is
**not** supported (12.0 reworked its UI — see Surfaces).

## Files

| File | Purpose |
|---|---|
| `core.lua` | Init, `Defaults` + `MigrateDB` (non-destructive), refresher registry (`ns.AddRefresher`/`ns.Refresh`), `ns:settingChanged` (applies the colour preset only when the `knownColor` dropdown changed, so a custom colour survives other toggles), `ns.KnownColor()`, `ns.UncollectedColor`, `RegisterSettings` (5 fields), `/scollect` (status / `custom` colour picker / `itemtest`). Loaded **first** so `AddRefresher` exists before `surfaces.lua` runs. |
| `data.lua` | `ns.QuestItems` (itemID→questID), `ns.SpecialItems` (itemID→`{srcItemID, linkField, expected}`), `ns.ContainerItems` (itemID→contained itemIDs) — collectibles the game doesn't self-flag as known. Typed direct-assignment fields. |
| `detect.lua` | `ns.IsKnown(link)` / `ns.IsCollectible(link)` + positive-only caches (`knownCache`/`collectibleCache`). |
| `surfaces.lua` | `tintFor(link)` → r,g,b,desat; the two frame hooks (Merchant, Auction House — each gated on its toggle + registered as a refresher); `ns:onLogin` decor pre-cache. |

## Detection (`detect.lua`)

Both predicates take an item hyperlink or `"item:<id>"` string. Results are cached per link for the
session: positives always; negatives only from the expensive tooltip-scanned fallthrough and only
once the item's data is loaded (`GetItemInfo` name present — an incomplete tooltip reads as a false
negative). Known-negatives are wiped (+ `ns.Refresh()`) on collection-gain events
(`NEW_RECIPE_LEARNED`, `NEW_MOUNT_ADDED`, `NEW_PET_ADDED`, `TOYS_UPDATED`,
`TRANSMOG_COLLECTION_SOURCE_ADDED`, `QUEST_TURNED_IN`, `HOUSING_STORAGE_UPDATED`);
collectible-negatives are permanent (an item's type never changes). The cheap API paths
(battlepet/quest/special/container/toy/mount) never negative-cache.

- **`ns.IsKnown(link)`** — owned/known by this account:
  - caged battlepet link → `C_PetJournal.GetNumCollectedInfo(species) > 0`.
  - `ns.QuestItems` → `C_QuestLog.IsQuestFlaggedCompleted`; `ns.SpecialItems` → source item's link
    field == expected; `ns.ContainerItems` → **all** contents known (recursive `IsKnown`).
  - toy → `PlayerHasToy(itemID)`.
  - mount → `C_MountJournal.GetMountFromItem(itemID)` then `GetMountInfoByID(...)` `isCollected`
    (direct itemID lookup, class-independent — no icon/name guessing).
  - by item class (`C_Item.GetItemInfoInstant`): **Recipe** → `anyAltKnowsRecipe` (cross-alt via
    `ns.api:GetAllCharacters()`, matching the crafted name in `professions.details[skillLineID]
    .recipes[*].learned[].name`; needs `RECIPE_SUBCLASS_TO_SKILL`) **or** a current-char tooltip
    scan; **Misc/CompanionPet** → journal walk (icon+name match) **or** tooltip scan;
    **Housing/Decor** → `C_HousingCatalog.GetCatalogEntryInfoByItem(link, true)` owned-stack subtype
    **or** the tooltip's "Total Owned:" count.
  - fallback: `scanTooltipKnown` (`C_TooltipInfo.GetHyperlink`) — `ITEM_SPELL_KNOWN`, the
    `ITEM_PET_KNOWN` pattern, or the decor "Total Owned:" line (`HOUSING_DECOR_OWNED_COUNT_FORMAT`,
    read even when the housing catalog hasn't cached the item).
- **`ns.IsCollectible(link)`** — a recognized collectible *type*, owned or not (drives the green
  tint; owned ones are caught first by `IsKnown`): battlepet link, tracked quest/special/container
  item, Recipe class, mount (`GetMountFromItem`), Misc/CompanionPet, Housing/Decor,
  `C_ToyBox.GetToyInfo`, or a "Teaches you" tooltip hit. **Transmog/cosmetic appearances are
  intentionally out of scope** (tinting every owned appearance was too noisy).

## Surfaces (`surfaces.lua`)

`tintFor(link)`: known → `ns.KnownColor()` (+ `db.monochrome` desaturate); else, when
`db.markUncollected` and `IsCollectible`, the green `ns.UncollectedColor`; else nil (leave alone).
Each surface cleans/resets to white when there's no tint and registers a refresher so a settings
change re-tints what's on screen (pattern from `ShadowsOfUI-Ilvl/surfaces.lua`).

- **Merchant** — `hooksecurefunc("MerchantFrame_UpdateMerchantInfo")`; `MERCHANT_ITEMS_PER_PAGE`
  buttons, `GetMerchantItemLink`, `SetItemButton*VertexColor` / `SetItemButtonDesaturated`.
- **Auction House** — `EventUtil.ContinueOnAddOnLoaded("Blizzard_AuctionHouseUI")` → hook
  `AuctionHouseFrame.BrowseResultsFrame.ItemList.ScrollBox` `Update`; per row `rowData.itemKey`
  (dummy `82800` → battlepet link from `battlePetSpeciesID`), tint `SelectedHighlight` + `cells[2]`.
- **Guild bank** — **not supported.** 12.0 reworked the guild bank: `GuildBankFrame.Columns[*]
  .Buttons[*]` are now a hidden, data-only structure (an occupied button's `.icon` reports
  `IsShown() == true` but `IsVisible() == false`, and isn't among the button's own regions), so
  tinting them paints nothing visible. `GetGuildBankItemLink`/`GetCurrentGuildBankTab` still work
  (data layer), so the detection is fine — only the visible frame is unknown. Revisit by locating
  and hooking the new visible guild-bank frame. (`ShadowsOfUI-Ilvl`'s guild-bank overlay is likely
  stale for the same reason.)
- **Login** — `ns:onLogin` calls `C_HousingCatalog.CreateCatalogSearcher()` to prime decor
  owned-state (unavailable immediately after login).

## Gotchas

- **`X and f()` truncates multiple returns to one.** `local r,g,b,desat = link and tintFor(link)`
  silently drops g/b/desat — always guard with `if link then r,g,b,desat = tintFor(link) end`.
- **Recipe knowledge is name-matched + capture-gated.** A profession never opened on an alt has no
  learned capture, so a recipe it knows may still read as collectible. The cross-alt walk uses
  captured recipe *names* (same caveat as `ShadowsOfUI-Known`'s Learnable surface).
- **`ns.db` is nil at file-load** — hooks/refreshers read it at runtime (guarded via `db(key)`).
- **`settingChanged` reapplies the preset only for `key == "knownColor"`** so `/scollect custom`
  survives toggling other options.
- **"Teaches you" is enUS-specific** — the collectible tooltip fallback for non-class-typed learn
  items is locale-dependent (class-typed collectibles are locale-safe).
- **Known-negatives depend on the event list** — a cached "not known" only flips via one of the
  collection-gain events registered in `detect.lua`; a knowledge source with no covering event would
  read stale until `/reload`. Positives are forever (something known never becomes unknown);
  an item that becomes known mid-session is caught by the event wipe + `ns.Refresh()`.
