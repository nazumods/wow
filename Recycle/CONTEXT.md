# Recycle

**Deps:** LibNAddOn, LibNUI · **SavedVars:** `RecycleDB` (v1, per-character) · **Commands:** `/recycle` (`clear`, `key CTRL|SHIFT|ALT`) · **UI:** LibNUI

Auto-sells grey (Poor) items plus manually-marked items whenever a merchant window opens. Single file, assignment form (`local ns = LibNAddOn(...)`).

## Files

| File | Purpose |
|---|---|
| `addon.lua` | Everything: `MigrateDB`, sell logic (`MERCHANT_SHOW` → `sellItems`), modifier+right-click mark toggle, bag-overlay rendering (`ns:refreshMarks`), Baganator junk-plugin integration, settings panel + commands |

## Gotchas

- **What gets sold (`shouldSell`):** any item in `db.itemsToSell[itemID]`, plus quality-0 (Poor/grey) items when `settings.sellGrey` is on. Items with no vendor price (price `0`) are skipped. `shouldSell(itemID, quality?)` takes the container-info quality when the caller has it (`sellItems` and `refreshDefaultBags` pass `info.quality`) to avoid a `GetItemInfo` cache miss on a cold login; the Baganator junk-plugin callback omits it and falls back to `GetItemInfo`.
- **Manual marking:** hooks `HandleModifiedItemClick` (not a frame script). The chosen modifier (`settings.modKey`) + **right-click** on a bag item toggles `db.itemsToSell[itemID]`; the gate is `IsControlKeyDown`/`IsShiftKeyDown`/`IsAltKeyDown` matched against `GetMouseButtonClicked() == "RightButton"`.
- **Marks are per-itemID, not per-slot** — every stack of a marked item shows the coin overlay and sells.
- **Overlay rendering** handles both Blizzard bag layouts: `ContainerFrameCombinedBags` when combined, else iterating `ContainerFrameContainer.ContainerFrames`. `BAG_UPDATE` refreshes after a 0.5s debounce.
- **Baganator integration is optional** — `setupBaganator` (on login) registers a junk plugin keyed on `shouldSell` only if `Baganator.API` is present; `refreshMarks` also pokes `RequestItemButtonsRefresh`.
- **Selling uses pickup-and-place** (`PickupContainerItem` → `PickupMerchantItem`), so it only runs while a merchant is open. Sale summary prints gold/silver/copper unless `settings.silent`.
- **Cold-cache sell-price retry:** in `sellItems` a `nil` price (uncached, distinct from a genuine `0`) triggers `C_Item.RequestLoadItemDataByID` and a deferred re-run via `ns:after(300, …)` (not `ns:delay`, which shares the addon's single timer with `BAG_UPDATE`'s `refreshMarks`). Guarded on `MerchantFrame:IsShown()` and capped at `RETRY_BUDGET` (3), which `MERCHANT_SHOW` resets — so a fresh-login first vendor visit still sells everything without leaving uncached greys stranded.

## SavedVariables (`RecycleDB`, per-character)

```lua
{ version = 1,
  settings = { sellGrey = true, silent = false, modKey = "CTRL" },
  itemsToSell = { [itemID] = true } }
```
`MigrateDB` seeds each missing settings key and `itemsToSell`; non-destructive. `/recycle clear` empties `itemsToSell`.
