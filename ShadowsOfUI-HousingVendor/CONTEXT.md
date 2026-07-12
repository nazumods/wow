# ShadowsOfUI-HousingVendor

**Deps:** LibNAddOn · **OptionalDeps:** none (Bagnon/Bagnonium detected at runtime) · **SavedVars:** `ShadowsOfUI_HousingVendorDB` (v2) · **Commands:** `/shvendor` (status), `/shvendor itemtest` (dev: dump decor info for the cursor item) · **API:** populates `HousingDecorApi` (`X-NUI-API`) · **UI:** none (raw WoW frames, no LibNUI)

Overlays housing-decor icons with owned/stored counts and a first-acquisition-bonus marker on the **Merchant** window and on **bags / bank / Bagnon** — the suite's native replacement for the at-vendor decor overlays in Ludius Plus / Plumber / RiddleCompass / Decor Vendor (see #463; bags/bank + shared detection added in #464). Standalone (no Warbandeer dep). Assignment-form init (`local ns = LibNAddOn(...)`); Blizzard Settings panel via `ns:RegisterSettings`. Complements **ShadowsOfUI-Collectibles**, which *tints* owned/collectible decor (and other collectible types) at the merchant/AH — the two are additive (tint = owned; this = how many + bonus) and Collectibles now reads this addon's decor detection (see API below). The owned-check indicator is off by default to avoid double-signalling ownership for Collectibles users.

## Files

| File | Purpose |
|---|---|
| `core.lua` | Init, `Defaults` + non-destructive `MigrateDB` (v2), refresher registry (`ns.AddRefresher`/`ns.Refresh`), `ns:settingChanged` (→ `Refresh`), `RegisterSettings` (3 indicator + 3 surface toggles), `ns:RegisterChangelog`, `ns:onLogin` catalog prime, the `HOUSING_STORAGE_UPDATED` cache-wipe + all-surface `Refresh`, `/shvendor` (status / `itemtest`). |
| `changelog.lua` | `ns.changelog` — newest-first `{version, notes}` for the in-game **Changelog** viewer. **Generated** — `release.sh` prepends each release; not hand-edited. |
| `decor.lua` | `ns.NormalizeEntry(entry)` (pure count/bonus derivation, unit-tested) + `ns.DecorEntryFor(link)` (class gate + catalog lookup + session cache) + `ns.WipeDecorCache()`. Exposes `DecorEntryFor` as `ns.api.EntryFor` (see API). |
| `overlay.lua` | The shared per-button overlay: `ns.EnsureOverlay` / `ns.CleanOverlay` / `ns.ApplyOverlay(button, d)` — the lazy overlay frame + the three indicators, honouring the toggles. Used by every surface. |
| `surfaces.lua` | Merchant "Buy" tab: the `MerchantFrame_UpdateMerchantInfo` hook + refresher. |
| `bags.lua` | Blizzard bags (`ContainerFrame` `UpdateItems`) + bank (`BankPanel`, gated on `C_Bank.CanUseBank`) surfaces + refreshers, via `C_Container.GetContainerItemLink`. |
| `bagnon.lua` | Bagnon / Bagnonium surface: chains `<frontend>.Item.UpdateSecondary` (`ContinueOnAddOnLoaded`), gated on `db.bagnon`; refresher = `<frontend>.Frames:Update()`. |
| `spec/` | busted specs (`hvendor.lua` loader + `decor_spec.lua`) for `NormalizeEntry`/`DecorEntryFor` + the `ns.api.EntryFor` wiring; excluded from zip + release detection. |

## API (`HousingDecorApi`, `decor.lua`)

`decor.lua` ends with `if ns.api then ns.api.EntryFor = ns.DecorEntryFor end`, publishing the normalized decor lookup as the suite's **single decor-detection source**. `HousingDecorApi.EntryFor(link)` → an `HVDecorInfo?` (`owned`/`stored`/`total`/`bonus`/`bonusAvailable`) or nil (not decor / catalog not resolved yet). **ShadowsOfUI-Collectibles** reads `.owned` from it (guarded: HousingVendor is an optional dep, and when absent Collectibles' own tooltip "Total Owned:" scan covers owned decor). The guard also keeps the busted loader — which seeds an empty `ns.api` — valid.

## Data (`decor.lua`)

One synchronous call drives everything: `C_HousingCatalog.GetCatalogEntryInfoByItem(link, true)` → a `HousingCatalogEntryInfo`. `ns.NormalizeEntry` mirrors `Blizzard_HousingCatalogUtil`:

- `stored` = `totalNumStored + remainingRedeemable` (on hand / placeable — `GetEntryNumStored`)
- `total` = `stored + totalNumPlaced` (owned anywhere — `GetEntryTotalOwned`)
- `owned` = `total > 0`
- `bonus` = `firstAcquisitionBonus` (House XP for first-time acquisition)
- `bonusAvailable` = `bonus > 0 and total == 0` — gated to **unowned** decor so a not-yet-zeroed bonus field can't dangle an already-claimed bonus.

`ns.DecorEntryFor` gates on item class via `C_Item.GetItemInfoInstant` (`Enum.ItemClass.Housing` / `Enum.ItemHousingSubclass.Decor` — synchronous, itemID-only, never a false negative), then caches per link: a `false` entry ("not decor") is permanent; a resolved decor entry is cached until `WipeDecorCache`. A decor item the catalog **can't resolve yet** (right after login, before the catalog primes) is deliberately **not** cached, so it retries.

## Overlay (`overlay.lua`)

The overlay is a `Frame` one level above each item button (`button.shvOverlay`), built lazily and reused. Three indicators, each in a corner clear of the icon's own stack-count number (bottom-right). Shared by **every** surface via `ns.EnsureOverlay` / `ns.CleanOverlay` / `ns.ApplyOverlay(button, d)`:

- **count** — `NUMBER_FONT` (Arial Narrow) FontString, **bottom-left**; the `stored` number (white; dim grey when `stored == 0` but owned). Gated on `db.countBadge`.
- **star** — Texture atlas `auctionhouse-icon-favorite` (the gold favourite star the AH/profession windows use), **top-left**; shown when `bonusAvailable`. Gated on `db.bonusBadge`.
- **check** — Texture `Interface\RaidFrame\ReadyCheck-Ready` (green check), **top-left**; shown when `owned`. Gated on `db.ownedCheck` (default off).

The star and check share the top-left corner: `bonusAvailable` requires `total == 0` (unowned) and `owned` requires `total > 0`, so they are mutually exclusive and never both show. Top-right is deliberately left free for other addons' unowned-item markers. Decor is never gear, so the overlay never collides with **ShadowsOfUI-Ilvl**'s (whose labels sit top-right / bottom-left on gear only).

## Surfaces (`surfaces.lua`, `bags.lua`, `bagnon.lua`)

Every surface cleans then repaints its buttons, calling `ns.DecorEntryFor(link)` + `ns.ApplyOverlay`, and registers an `ns.AddRefresher` so a settings change re-renders what's on screen. The decor lookup is fully synchronous (container link + class gate + catalog query all resolve at once), so — unlike Ilvl — no `ContinueOnItemLoad` / stale-callback token is needed.

- **Merchant** (`surfaces.lua`) — `hooksecurefunc("MerchantFrame_UpdateMerchantInfo")` (runs after Blizzard repaints from scratch); all `MERCHANT_ITEMS_PER_PAGE` buttons (`_G["MerchantItem"..i.."ItemButton"]`, `GetMerchantItemLink((page-1)*perPage + i)`). **Buy tab only** (decor is bought, not bought-back). Always on (no toggle).
- **Bags** (`bags.lua`) — `ContainerFrameCombinedBags` + each `ContainerFrameContainer.ContainerFrames`, `UpdateItems` hook; `C_Container.GetContainerItemLink(bag, slot)`. Gated on `db.bags`.
- **Bank** (`bags.lua`) — `BankPanel` `GenerateItemSlotsForSelectedTab` / `RefreshAllItemsForSelectedTab`, gated on `db.bank and C_Bank.CanUseBank(...)`; link via bank-tab id + container slot id.
- **Bagnon / Bagnonium** (`bagnon.lua`) — chains `<frontend>.Item.UpdateSecondary` via `EventUtil.ContinueOnAddOnLoaded`, using `button.info.hyperlink`; gated on `db.bagnon`. Refresher = `<frontend>.Frames:Update()`. Same Wildpants rationale as `ShadowsOfUI-Ilvl/bagnon.lua`.

`ns:onLogin` calls `C_HousingCatalog.CreateCatalogSearcher()` to prime owned-state (unavailable immediately after login). `HOUSING_STORAGE_UPDATED` (in `core.lua`) wipes the shared cache and calls `ns.Refresh()` — repainting **every** visible surface (each refresher no-ops when its frame is hidden), not just the merchant.

## Gotchas

- **Glyph-free indicators.** The star is the `auctionhouse-icon-favorite` atlas (a widely-used, stable gold star that reads cleanly at ~14px); the check is the `ReadyCheck-Ready` `.blp` file texture; the count is digits. All avoid ★/✓ glyphs (not in every font). Note the individual raid-target-icon *files* (`UI-RaidTargetingIcon_N`) exist only for chat `|T…|t` markup — `SetTexture` on them fails to a broken-texture fallback, so the star uses the favourite **atlas**, not that path.
- **`ns.db` is nil at file-load** — the surface reads it at runtime via `db(key)`; overlays build lazily on first paint.
- **Owned but `stored == 0`** is a real state (every copy placed) — the count badge shows a dimmed `0`, not nothing, so "owned, none to place" stays legible.
- **Catalog primes late.** Owned counts are empty for a moment after login; the login searcher + `HOUSING_STORAGE_UPDATED` refresh cover it, and unresolved decor is left uncached so it fills in rather than sticking blank.
- **Shared cache, one wipe.** `DecorEntryFor`'s cache is the single copy the merchant, bag, bank, Bagnon surfaces *and* Collectibles (via `HousingDecorApi`) all read; the `core.lua` `HOUSING_STORAGE_UPDATED` handler wipes it once and `ns.Refresh()`es everything.
