# ShadowsOfUI-Collectibles

**Deps:** LibNAddOn · **OptionalDeps:** Warbandeer_Characters, ShadowsOfUI-HousingVendor · **SavedVars:** `ShadowsOfUI_CollectiblesDB` (v2) · **Commands:** `/scollect` (`custom`, `itemtest`) · **API:** reads `WarbandeerApi` (`X-NUI-API`) + optional `WarbandeerDB` + optional `HousingDecorApi` (decor owned-state) · **UI:** none (no LibNUI) · **Clients:** Retail + Forever

Icon-tinting addon: colours already-known / still-collectible items on the **Merchant** and
**Auction House** browse list. Replaces the standalone AlreadyKnown addon (re-derived in suite
style — hooks modeled on `ShadowsOfUI-Ilvl`, not copied). Assignment-form init
(`local ns = LibNAddOn(...)`); Blizzard Settings panel via `ns:RegisterSettings`. Guild bank is
**not** supported (12.0 reworked its UI — see Surfaces).

## Files

| File | Purpose |
|---|---|
| `core.lua` | Init, `PRESETS`/`COLOR_OPTIONS` (7 **bold-but-legible** known-item tints — the tint MULTIPLIES the icon texture, so one channel is held at full for an obvious cast while the others stay clear of zero to avoid crushing to black; green is absent, reserved for `UncollectedColor`), `Defaults` (blue default tint `{0.25,0.45,1.00}`, `knownColor=1`), `MigrateDB` (**v2**, non-destructive: v1→v2 moves only a user still on the retired pure-red factory default to soft blue; any chosen preset or `/scollect custom` colour is preserved), refresher registry (`ns.AddRefresher`/`ns.Refresh`), `ns:settingChanged` (applies the colour preset only when the `knownColor` dropdown changed, so a custom colour survives other toggles), `ns.KnownColor()`, `ns.UncollectedColor`, `RegisterSettings` (5 fields), `ns:RegisterChangelog()` (Changelog button), `/scollect` (status / `custom` colour picker / `itemtest`). Loaded **first** so `AddRefresher` exists before `surfaces.lua` runs. |
| `changelog.lua` | `ns.changelog` — newest-first `{version, notes}` release history for the in-game **Changelog** viewer (LibNAddOn). **Generated** — `release.sh` prepends each release; not hand-edited |
| `data.lua` | `ns.QuestItems` (itemID→questID), `ns.SpecialItems` (itemID→`{srcItemID, linkField, expected}`), `ns.ContainerItems` (itemID→contained itemIDs) — collectibles the game doesn't self-flag as known. Typed direct-assignment fields. |
| `detect.lua` | `ns.IsKnown(link)` / `ns.IsCollectible(link)` + positive-only caches (`knownCache`/`collectibleCache`). |
| `preview.lua` + `preview.xml` | Settings **vendor-card preview**, laid out as a left **controls column** (the wrap-arrow tint stepper + the two sliders) beside a right **preview** — under a **"Preview"** header, a **"Not tinted"** control column paired close (`COLUMN_GAP = 175`) with a captioned **"Tinted"** twin column so each item reads as a normal/coloured pair. Three sample merchant cards per column (common/rare/epic) built from the real merchant textures (`UI-EmptySlot` slot, `UI-Merchant-LabelSlots` name plate, icon + `UI-Quickslot2` border, quality-coloured `C_Item.GetItemQualityColor` name, `C_CurrencyInfo.GetCoinTextureString` price). The left column is an **untinted control** (never touched by `updateCard`); the right column (`self.rows`) is its **tinted twin**, tinted **whole-card** exactly like `surfaces.lua` tints the live merchant — name plate + slot at full `ns.KnownColor()`, icon + border at 0.9x, icon-only `SetDesaturation`. This **is** the tint picker — there is no dropdown. A back/next **wrap-arrow** stepper (native `common-dropdown-icon-back`/`-next` atlases) `step`s `db.knownColor` ±1 with wrap-around and calls `ns:settingChanged("knownColor")` (applies the preset rgb + `ns.Refresh()`). Two **debug sliders** (`MinimalSliderWithSteppersTemplate`, 0–1, via a shared `makeSlider`): **saturation** fades the item's own content (icon `SetDesaturation` + name-text luminance fade) but NOT the tint wash, and **icon dim** fades the icon via `SetAlpha` (Blizzard's unusable-item look). Both preview-only — not saved, not applied to real tinting. Registered as the **first settings field** (`{ typ = "element", template = ... }`, via LibNAddOn's `element` field type) so it sits at the top of the panel; `preview.xml` is the `virtual` template (`ShadowsOfUI_Collectibles_TintPreviewMixin`, a required global). The card rides `ns.AddRefresher` so it tracks every colour change. |
| `spec/` | busted unit tests: `detect_spec.lua` (tooltip-load negative-cache gating), `core_spec.lua` (v1→v2 palette migration + preset invariants). Excluded from zip + release detection. |
| `surfaces.lua` | `tintFor(link)` → r,g,b,desat; the two frame hooks (Merchant, Auction House — each gated on its toggle + registered as a refresher); `ns:onLogin` decor pre-cache. |

## Detection (`detect.lua`)

Both predicates take an item hyperlink or `"item:<id>"` string. Results are cached per link for the
session: positives always; negatives only from the expensive tooltip-scanned fallthrough and only
once the tooltip actually loaded. The load signal is the tooltip scan itself (`C_TooltipInfo.GetHyperlink`
returned a populated `data.lines`), **not** a `GetItemInfo` name proxy: the "already known / Teaches you"
line resolves on its own schedule, so gating on the base item name would cache a false negative while the
tooltip is still filling in (permanent for `IsCollectible`, whose negatives are never wiped). One nuance for
`IsKnown`: its recipe (cross-alt) and companion-pet branches derive the answer partly from `GetItemInfo`'s
**name** (an alt-known recipe / name-matched pet), so *those* negatives are additionally gated on the name
having loaded — else an alt-known recipe at the AH (tooltip populated before the name) locks a false "not
known" until a collection-gain event. Known-negatives
are wiped (+ `ns.Refresh()`) on collection-gain events (`NEW_RECIPE_LEARNED`, `NEW_MOUNT_ADDED`,
`NEW_PET_ADDED`, `TOYS_UPDATED`, `TRANSMOG_COLLECTION_SOURCE_ADDED`, `QUEST_TURNED_IN`,
`HOUSING_STORAGE_UPDATED`); collectible-negatives are permanent (an item's type never changes). The cheap
API paths (battlepet/toy/mount/container and quest/special) never negative-cache; quest/special **positives**
are cached (both states are monotonic).

- **`ns.IsKnown(link)`** — owned/known by this account:
  - caged battlepet link → `C_PetJournal.GetNumCollectedInfo(species) > 0` (not known, uncached, if that function is absent — see Forever).
  - `ns.QuestItems` → `C_QuestLog.IsQuestFlaggedCompleted`; `ns.SpecialItems` → source item's link
    field == expected; `ns.ContainerItems` → **all** contents known (recursive `IsKnown`).
  - toy → `PlayerHasToy(itemID)`.
  - mount → `C_MountJournal.GetMountFromItem(itemID)` then `GetMountInfoByID(...)` `isCollected`
    (direct itemID lookup, class-independent — no icon/name guessing).
  - by item class (`C_Item.GetItemInfoInstant`): **Recipe** → `anyAltKnowsRecipe` (cross-alt via
    `ns.api:GetAllCharacters()`, matching the crafted name in `professions.details[skillLineID]
    .recipes[*].learned[].name`; needs `RECIPE_SUBCLASS_TO_SKILL`) **or** a current-char tooltip
    scan; **Misc/CompanionPet** → journal walk (icon+name match) **or** tooltip scan;
    **Housing/Decor** → `HousingDecorApi.EntryFor(link).owned` (**ShadowsOfUI-HousingVendor**'s shared detection, optional dep; the catalog derivation now lives only there)
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
  owned-state (unavailable immediately after login), only when `ns:Supports("housing")`
  (see Forever). `HOUSING_STORAGE_UPDATED` is likewise registered only then.

## WoW: Forever

TOC `## Interface: 120105, 16001`. Facts are from Blizzard's Forever UI source (build 1.60.1.70425,
branch `origin/forever` of `wow-ui-source`) unless marked otherwise; nothing here has been run on the beta yet.

- **Hook targets exist** (inferred: the `.toc` lines below say `mainline`, and camelot is treated as mainline-family because
  other lines pair `mainline` with an explicit `[ExcludeLoadGameType camelot]`; the source never states it). Merchant: `[Family]\MerchantFrame.lua` loads (`Blizzard_UIPanels_Game.toc:110`) and defines
  `MerchantFrame_UpdateMerchantInfo` (`Mainline/MerchantFrame.lua:274`) and `MerchantFrame_UpdateBuybackInfo` (`:532`).
  Auction house: `Blizzard_AuctionHouseUI.toc:9` allows `mainline, cata, mists`; `AuctionHouseFrame.BrowseResultsFrame`
  (`Shared/Blizzard_AuctionHouseFrame.xml:82`) holds `ItemList` (`Shared/Blizzard_AuctionHouseBrowseResultsFrame.xml:6`).
- **Housing is gated by the feature table, not by the API.** `C_HousingCatalog.CreateCatalogSearcher` and
  `HOUSING_STORAGE_UPDATED` are documented on Forever (`HousingCatalogUIDocumentation.lua:11`, `:494`) but Forever has no
  housing (`LibNAddOn/flavor.lua`: `housing` is unsupported on Forever). So `ns:onLogin` skips the searcher and
  `detect.lua` does not register `HOUSING_STORAGE_UPDATED` there. The decor branches in `IsKnown`/`IsCollectible` are
  unchanged: no Housing-class item is expected to reach them on Forever. `core.lua` has no housing/decor setting.
- **Pet and toy calls.** `C_PetJournal.GetNumPets` / `GetPetInfoByIndex` and `PlayerHasToy` / `C_ToyBox.GetToyInfo` are
  absent from the generated API docs, but Blizzard's own Forever-loaded files call them (`Classic/Blizzard_PetCollection.lua:240,257`,
  loaded for camelot per `Blizzard_Collections.toc:28`; the toy box is `[Family]\Blizzard_ToyBox.lua`, `toc:34`, which
  calls both in `Mainline/Blizzard_ToyBox.lua:257,331` and in `Classic/Blizzard_ToyBox.lua:169,242`; which of the two a camelot
  client resolves `[Family]` to was not determined). Their existence on Forever is inferred from those load lists, not checked
  in game, and the addon calls them unguarded.
- **`C_PetJournal.GetNumCollectedInfo` is guarded.** Blizzard calls it only from `Shared/Blizzard_PetBattleUI.lua:1272`;
  whether it exists on Forever is unknown. `ns.IsKnown` treats a `battlepet:` link as not known, and does not cache that,
  while the function is missing (so the link reads as known once it appears).
- Beta probe (2026-10-15): Shift+P opened "Appearances" with only an Items tab; 0 pets.

## Gotchas

- **The Merchant Buy and Buyback tabs share the same `MerchantItem<i>ItemButton` frames**, repainted
  by two different Blizzard functions, so our Buy-tab paint can ride a recycled button onto an
  unrelated bought-back item (#737). Two separate leaks, two separate fixes:
  - `MerchantFrame_UpdateBuybackInfo` resets all four vertex colours in every branch but **never**
    `SetItemButtonDesaturated` — so only the desaturation leaks, and we hook it to clear just that.
    Resetting the colours there too would stomp Blizzard's own red-unusable / grey-empty cues.
  - `ns.AddRefresher` is **tab-gated** (`MerchantFrame.selectedTab == 1`). Ungated, an external
    refresh with the Buyback tab open repainted Buy-tab tints onto buyback rows — all five
    properties, the larger of the two leaks.
  - **Not the shape of `ShadowsOfUI-HousingVendor`'s #592 fix**, despite the same root cause: that
    addon owns the overlay frames it creates, so a blanket `CleanOverlay` is right there. This one
    owns no frames and mutates Blizzard's own button properties. Don't "align" them.
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
