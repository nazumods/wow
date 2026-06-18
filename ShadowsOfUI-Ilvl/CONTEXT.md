# ShadowsOfUI-Ilvl

**Deps:** LibNAddOn (Baganator optional) · **SavedVars:** `ShadowsOfUI_IlvlDB` (v1) · **Commands:** `/silvl <itemID|link>` (dev dump) · **UI:** none (no LibNUI)

Overlay addon: draws each gear item's item level + a compact upgrade-track code (`A/V/C/H/M` + rank, e.g. `C2`) onto item buttons. Overlaid on the icon for bags/bank/loot/guild bank/Baganator; per-panel inset (beside the icon, toward centre) or overlay for the character/inspect paperdolls. Assignment-form init (`local ns = LibNAddOn(...)`); Blizzard Settings panel via `ns:RegisterSettings`.

## Files

| File | Purpose |
|---|---|
| `core.lua` | Init, DB defaults + `MigrateDB`, `ns:RegisterSettings` (10 fields), `settingChanged`→`Refresh`, refresher registry (`ns.AddRefresher`/`ns.Refresh`), `/silvl` |
| `render.lua` | `ns.ItemDetails`, lazy FontString attach + apply, `ns.UpdateButton(button, item, inset)` / `ns.CleanButton`, `ns.InsetPositions` |
| `surfaces.lua` | `hooksecurefunc` wiring + per-surface toggle gating + refreshers: character/inspect paperdoll, bags, bank, loot, guild bank |
| `baganator.lua` | One `Baganator.API.RegisterCornerWidget` (upgrade track; Baganator has its own ilvl), gated on `db.baganator` |

## Settings (`ShadowsOfUI_IlvlDB`, v1)

Flat keys, all defaulting on: `bags`, `bank`, `loot`, `guildbank`, `baganator`, `character`, `inspect` (place toggles); `characterInset`, `inspectInset` (inset vs overlay); `minQuality` (dropdown index 1–5 = Poor…Epic, default 3=Uncommon; tags `quality >= minQuality-1`). `MigrateDB` only adds missing keys (non-destructive). Settings register as a subcategory under the shared **Shadows of UI** parent (`parent = "Shadows of UI"` in `RegisterSettings`).

## Behavior

- **`ns.ItemDetails(item)`** — returns `ilvl, quality, track` for a loaded `Item`, or nil when it isn't `minQuality`+ weapon/armor. `track` = `GetItemUpgradeInfo(link).trackString:sub(1,1) .. currentLevel`. `link` is the authoritative container/inventory link for located items (`C_Container.GetContainerItemLink` / `GetInventoryItemLink` via `item:GetItemLocation()`) falling back to `item:GetItemLink()` for loot/guild bank. nil for non-upgradeable gear.
- **`ns.UpdateButton(button, item, inset, big)`** — `item:ContinueOnItemLoad` → lazily attach an overlay `Frame` (one frame level above the button) and the needed FontStrings (`soiIlvl`+`soiTrack` for overlay, `soiInset` for inset), then apply. `big` (paperdoll) bumps the font (inset 14; overlay 15/13 vs bag 13/11). Both modes coexist so a button can switch at runtime; callers `ns.CleanButton` first.
- **Refresh** — each surface registers a refresher via `ns.AddRefresher`; `ns:settingChanged` → `ns.Refresh()` re-tags everything currently shown so a settings change is immediate. Refreshers no-op when their host frame is hidden.
- **Surfaces** (hooked at file-load): character `PaperDollItemSlotButton_Update`; inspect `InspectPaperDollItemSlotButton_Update` (via `EventUtil.ContinueOnAddOnLoaded("Blizzard_InspectUI")`, unit = `InspectFrame.unit or "target"`); bags `ContainerFrameCombinedBags` + each `ContainerFrameContainer.ContainerFrames` `UpdateItems`; bank `BankPanel` `GenerateItemSlotsForSelectedTab`/`RefreshAllItemsForSelectedTab` (gated on `C_Bank.CanUseBank`); loot `LootFrame.ScrollBox` `OnUpdate`→`ForEachFrame`; guild bank `GuildBankFrame:Update` (via `ContinueOnAddOnLoaded("Blizzard_GuildBankUI")`).

## Key tables

| Table | Key → Value | Notes |
|---|---|---|
| `ns.InsetPositions` | slot button name → `{point, relativePoint, x, y, justifyH}` | Character*/Inspect* slots; left column anchors label to the icon's RIGHT, right column to the LEFT, weapons toward centre. Also the "is this a gear slot" gate for the paperdoll hooks |

## Gotchas

- **`ns.db` is nil during file-load** — files run before our `ADDON_LOADED`, so all `db(...)`/`ns.db` reads live inside runtime closures (hooks, refreshers, `ItemDetails`), never at top level. Guards (`ns.db and ...`) cover the first hook fire.
- **Per-surface gate cleans first** — surface update fns `CleanButton` before checking the toggle, so disabling a place (then `Refresh`) visibly clears it; UpdateButton's pre-clean also lets character/inspect swap inset↔overlay live.
- **Track on bag gear needs the authoritative link** — `GetItemUpgradeInfo` accepts only a hyperlink (passing an `ItemLocation` errors), and a freshly-seen bag item's `item:GetItemLink()` can be sparse, so the track comes back blank while the ilvl shows. Fetch the link from the slot instead (`C_Container.GetContainerItemLink` / `GetInventoryItemLink`, resolved via `item:GetItemLocation()`); fall back to `item:GetItemLink()` only for location-less loot/guild-bank items.
- **`ns:Print` (colon)** — `Print` treats a non-`addOn` first arg as a sub-prefix, so the dev command calls `ns:Print(...)`.
- **Equipped-bag buttons share `PaperDollItemSlotButton_Update`** — `CharacterBag*Slot` buttons fire the same hook; the `InsetPositions` membership gate skips them.
- **Baganator widget uses `{corner=...}`, not `default_position`** — current Baganator reads `defaultPosition.corner`/`.priority`; the old SimpleItemLevel `default_position` key leaves the widget registered but never auto-added to a corner (invisible until manually enabled). The onUpdate receives Baganator's `details` (full `itemLink`/`quality`/`itemID`) — use those directly via `ns.TrackFromLink`/`ns.WantGear`, don't rebuild an Item.
- **Baganator refresh is Baganator's** — `ns.Refresh` doesn't touch it; toggling `baganator` applies on Baganator's next redraw. The widget is user-positioned/enabled in Baganator's own settings.
