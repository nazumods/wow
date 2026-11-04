# Recycle

**Deps:** LibNAddOn, LibNUI · **SavedVars:** `RecycleDB` (v1, per-character) · **Commands:** `/recycle` (`clear`, `key CTRL|SHIFT|ALT`) · **UI:** LibNUI · **Clients:** Retail + Forever

Auto-sells grey (Poor) items plus manually-marked items whenever a merchant window opens. Single file, assignment form (`local ns = LibNAddOn(...)`).

## Files

| File | Purpose |
|---|---|
| `addon.lua` | Everything: `MigrateDB`, sell logic (`MERCHANT_SHOW` → `sellItems`), modifier+right-click mark toggle, bag-overlay rendering (`ns:refreshMarks`), Baganator junk-plugin integration, settings panel + commands |

## Gotchas

- **What gets sold (`shouldSell`):** any item in `db.itemsToSell[itemID]` (every copy: stackables, and all marks made before per-copy marks), any equippable copy whose `copyKey(hyperlink)` is in `db.copiesToSell` (#1009), plus quality-0 (Poor/grey) items when `settings.sellGrey` is on. Items with no vendor price (price `0`) are skipped. `shouldSell(itemID, quality?, link?)` takes the container-info quality when the caller has it (`sellItems` and `refreshDefaultBags` pass `info.quality`) to avoid a `GetItemInfo` cache miss on a cold login, and the hyperlink (`info.hyperlink`; the Baganator callback passes its `itemLink`) to honour a per-copy mark; the Baganator callback omits the quality and falls back to `GetItemInfo`. Covered by `spec/shouldsell_spec.lua` (`ns.ShouldSell` / `ns.ToggleMark` are exposed for it).
- **Manual marking:** hooks `HandleModifiedItemClick` (not a frame script). The chosen modifier (`settings.modKey`) + **right-click** on a bag item toggles a mark: weapons and armor per COPY in `db.copiesToSell[copyKey]` (`copyKey` = `itemID:itemContext:bonusIDs` from the link, so Normal/Heroic/Mythic copies of one itemID are separate marks — but identical twins share one, i.e. the mark is per VARIANT; an equippable whose link can't be read is NOT marked, never falling back to an all-copies mark; `sellItems` drops a `copiesToSell` key once no copy of it is left in the bags after a complete pass, so a later identical drop isn't sold on a stale mark), everything else per item in `db.itemsToSell[itemID]`; toggling an item that has an old all-copies mark clears that mark; the gate is `IsControlKeyDown`/`IsShiftKeyDown`/`IsAltKeyDown` matched against `GetMouseButtonClicked() == "RightButton"`. The wrapper **returns the stock function's boolean** (`did I handle this click`) — Blizzard callers branch on it (`if HandleModifiedItemClick(...) then return`), so swallowing it would make a handled click fall through to an unintended split/pickup/DressUp.
- **Marks are per-itemID, not per-slot** — every stack of a marked item shows the coin overlay and sells.
- **Overlay rendering** handles both Blizzard bag layouts: `ContainerFrameCombinedBags` when combined, else iterating `ContainerFrameContainer.ContainerFrames`. `BAG_UPDATE` refreshes after a 0.5s debounce.
- **Baganator integration is optional** — `setupBaganator` (on login) registers a junk plugin keyed on `shouldSell` only if `Baganator.API` is present; `refreshMarks` also pokes `RequestItemButtonsRefresh`.
- **Selling uses pickup-and-place** (`PickupContainerItem` → `PickupMerchantItem`), so it only runs while a merchant is open. Sale summary prints gold/silver/copper unless `settings.silent`.
- **Cold-cache sell-price retry:** in `sellItems` a `nil` price (uncached, distinct from a genuine `0`) triggers `C_Item.RequestLoadItemDataByID` and a deferred re-run via `ns:after(300, …)` (not `ns:delay`, which shares the addon's single timer with `BAG_UPDATE`'s `refreshMarks`). Guarded on `MerchantFrame:IsShown()` and capped at `RETRY_BUDGET` (3), which `MERCHANT_SHOW` resets — so a fresh-login first vendor visit still sells everything without leaving uncached greys stranded.

## SavedVariables (`RecycleDB`, per-character)

```lua
{ version = 1,
  settings = { sellGrey = true, silent = false, modKey = "CTRL" },
  itemsToSell = { [itemID] = true },
  copiesToSell = { ["itemID:context:bonusIDs"] = true } }   -- created lazily, no version bump (#1009)
```
`MigrateDB` seeds each missing settings key and `itemsToSell`; non-destructive. `/recycle clear` empties `itemsToSell` and `copiesToSell`.
