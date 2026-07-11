# ShadowsOfUI-HousingVendor

**Deps:** LibNAddOn · **OptionalDeps:** none · **SavedVars:** `ShadowsOfUI_HousingVendorDB` (v1) · **Commands:** `/shvendor` (status), `/shvendor itemtest` (dev: dump decor info for the cursor item) · **API:** none · **UI:** none (raw WoW frames, no LibNUI)

Overlays housing-decor icons in the **Merchant** window with owned/stored counts and a first-acquisition-bonus marker — the suite's native replacement for the at-vendor decor overlays in Ludius Plus / Plumber / RiddleCompass / Decor Vendor (see #463). Standalone (no Warbandeer dep). Assignment-form init (`local ns = LibNAddOn(...)`); Blizzard Settings panel via `ns:RegisterSettings`. Complements **ShadowsOfUI-Collectibles**, which *tints* owned/collectible decor (and other collectible types) at the same window — the two are additive (tint = owned; this = how many + bonus). The owned-check indicator is off by default to avoid double-signalling ownership for Collectibles users.

## Files

| File | Purpose |
|---|---|
| `core.lua` | Init, `Defaults` + non-destructive `MigrateDB`, refresher registry (`ns.AddRefresher`/`ns.Refresh`), `ns:settingChanged` (→ `Refresh`), `RegisterSettings` (3 indicator toggles), `ns:RegisterChangelog`, `ns:onLogin` catalog prime, `/shvendor` (status / `itemtest`). |
| `changelog.lua` | `ns.changelog` — newest-first `{version, notes}` for the in-game **Changelog** viewer. **Generated** — `release.sh` prepends each release; not hand-edited. |
| `decor.lua` | `ns.NormalizeEntry(entry)` (pure count/bonus derivation, unit-tested) + `ns.DecorEntryFor(link)` (class gate + catalog lookup + session cache) + `ns.WipeDecorCache()`. |
| `surfaces.lua` | Per-button overlay frame + indicators, the `MerchantFrame_UpdateMerchantInfo` hook, the refresher, and the `HOUSING_STORAGE_UPDATED` cache-wipe + repaint. |
| `spec/` | busted specs (`hvendor.lua` loader + `decor_spec.lua`) for `NormalizeEntry`/`DecorEntryFor`; excluded from zip + release detection. |

## Data (`decor.lua`)

One synchronous call drives everything: `C_HousingCatalog.GetCatalogEntryInfoByItem(link, true)` → a `HousingCatalogEntryInfo`. `ns.NormalizeEntry` mirrors `Blizzard_HousingCatalogUtil`:

- `stored` = `totalNumStored + remainingRedeemable` (on hand / placeable — `GetEntryNumStored`)
- `total` = `stored + totalNumPlaced` (owned anywhere — `GetEntryTotalOwned`)
- `owned` = `total > 0`
- `bonus` = `firstAcquisitionBonus` (House XP for first-time acquisition)
- `bonusAvailable` = `bonus > 0 and total == 0` — gated to **unowned** decor so a not-yet-zeroed bonus field can't dangle an already-claimed bonus.

`ns.DecorEntryFor` gates on item class via `C_Item.GetItemInfoInstant` (`Enum.ItemClass.Housing` / `Enum.ItemHousingSubclass.Decor` — synchronous, itemID-only, never a false negative), then caches per link: a `false` entry ("not decor") is permanent; a resolved decor entry is cached until `WipeDecorCache`. A decor item the catalog **can't resolve yet** (right after login, before the catalog primes) is deliberately **not** cached, so it retries.

## Surfaces (`surfaces.lua`)

Overlay is a `Frame` one level above each merchant item button, built lazily and reused. Three indicators, each in a corner clear of Blizzard's own stack-count number (bottom-right):

- **count** — `NUMBER_FONT` (Arial Narrow) FontString, **bottom-left**; the `stored` number (white; dim grey when `stored == 0` but owned). Gated on `db.countBadge`.
- **star** — Texture `Interface\TargetingFrame\UI-RaidTargetingIcon_1` (yellow star), **top-right**; shown when `bonusAvailable`. Gated on `db.bonusBadge`.
- **check** — Texture `Interface\RaidFrame\ReadyCheck-Ready` (green check), **top-left**; shown when `owned`. Gated on `db.ownedCheck` (default off).

`updateMerchant` cleans then repaints all `MERCHANT_ITEMS_PER_PAGE` buttons (`_G["MerchantItem"..i.."ItemButton"]`, `GetMerchantItemLink((page-1)*perPage + i)`). Installed via `hooksecurefunc("MerchantFrame_UpdateMerchantInfo", …)` (runs after Blizzard repaints from scratch) + registered as a refresher (settings change re-renders the open window). `HOUSING_STORAGE_UPDATED` wipes the cache and repaints. `ns:onLogin` calls `C_HousingCatalog.CreateCatalogSearcher()` to prime owned-state (unavailable immediately after login).

## Gotchas

- **File-stable, glyph-free indicators.** The star/check are `.blp` file textures (`UI-RaidTargetingIcon_1`, `ReadyCheck-Ready`) present in every client — chosen over atlas names (which Blizzard churns across patches) and over ★/✓ glyphs (not in every font). Count uses digits only.
- **`ns.db` is nil at file-load** — the surface reads it at runtime via `db(key)`; overlays build lazily on first paint.
- **Owned but `stored == 0`** is a real state (every copy placed) — the count badge shows a dimmed `0`, not nothing, so "owned, none to place" stays legible.
- **Catalog primes late.** Owned counts are empty for a moment after login; the login searcher + `HOUSING_STORAGE_UPDATED` refresh cover it, and unresolved decor is left uncached so it fills in rather than sticking blank.
- **Buy tab only.** Only `MerchantFrame_UpdateMerchantInfo` (the Buy tab) is hooked; the Buyback tab isn't decorated (decor is bought, not bought-back).
