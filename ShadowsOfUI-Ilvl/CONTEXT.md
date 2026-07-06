# ShadowsOfUI-Ilvl

**Deps:** LibNAddOn (Baganator + Bagnon/Bagnonium optional) · **SavedVars:** `ShadowsOfUI_IlvlDB` (v3) · **Commands:** `/silvl <itemID|link>` (dev dump) · **UI:** none (no LibNUI)

Overlay addon: draws each gear item's item level + a compact upgrade-track code (`A/V/C/H/M` + rank, e.g. `C2`) onto item buttons. Overlaid on the icon for bags/bank/loot/guild bank/Baganator/Bagnon; per-panel inset (beside the icon, toward centre) or overlay for the character/inspect paperdolls. Assignment-form init (`local ns = LibNAddOn(...)`); Blizzard Settings panel via `ns:RegisterSettings`.

## Files

| File | Purpose |
|---|---|
| `core.lua` | Init, DB defaults + `MigrateDB`, `ns:RegisterSettings` (12 fields), `settingChanged`→`Refresh`, refresher registry (`ns.AddRefresher`/`ns.Refresh`), `/silvl` |
| `render.lua` | `ns.ItemDetails`, lazy FontString attach + apply, `ns.UpdateButton(button, item, inset)` / `ns.CleanButton`, `ns.SetAvgIlvl(parent, ilvl)`, `ns.InsetPositions` |
| `surfaces.lua` | `hooksecurefunc` wiring + per-surface toggle gating + refreshers: character/inspect paperdoll (incl. inspect average ilvl), bags, bank, loot, guild bank |
| `baganator.lua` | One `Baganator.API.RegisterCornerWidget` (upgrade track; Baganator has its own ilvl), gated on `db.baganator` |
| `bagnon.lua` | Chains the Wildpants `Item.UpdateSecondary` on each front-end global (`Bagnon`/`Bagnonium`) to overlay ilvl+track; gated on `db.bagnon`. Refresher = `<frontend>.Frames:Update()` |

## Settings (`ShadowsOfUI_IlvlDB`, v3)

Flat keys, all defaulting on: `bags`, `bank`, `loot`, `guildbank`, `baganator`, `bagnon`, `character`, `inspect` (place toggles); `characterInset`, `inspectInset` (inset vs overlay); `inspectAvg` (average ilvl atop the inspect model); `minQuality` (dropdown index 1–5 = Poor…Epic, default 3=Uncommon; tags `quality >= minQuality-1`). `MigrateDB` only adds missing keys (non-destructive); v2 added `bagnon`, v3 added `inspectAvg`. Settings register as a subcategory under the shared **Shadows of UI** parent (`parent = "Shadows of UI"` in `RegisterSettings`).

## Behavior

- **`ns.ItemDetails(item)`** — returns `ilvl, quality, track` for a loaded `Item`, or nil when it isn't `minQuality`+ weapon/armor. `track` = `GetItemUpgradeInfo(link).trackString:sub(1,1) .. currentLevel`. `link` is the authoritative container/inventory link for located items (`C_Container.GetContainerItemLink` / `GetInventoryItemLink` via `item:GetItemLocation()`) falling back to `item:GetItemLink()` for loot/guild bank. nil for non-upgradeable gear.
- **`ns.UpdateButton(button, item, inset, big)`** — `item:ContinueOnItemLoad` → lazily attach an overlay `Frame` (one frame level above the button) and the needed FontStrings (`soiIlvl`+`soiTrack` for overlay, `soiInset` for inset), then apply. `big` (paperdoll) bumps the font (inset 14; overlay 15/13 vs bag 13/11). Both modes coexist so a button can switch at runtime; callers `ns.CleanButton` first. Each button carries a monotonic `soiToken` bumped by both `UpdateButton` and `CleanButton`; the `ContinueOnItemLoad` callback captures it and no-ops if it changed, so during rapid bag churn a late callback for an old item can't repaint over a newer (or cleared) state.
- **Refresh** — each surface registers a refresher via `ns.AddRefresher`; `ns:settingChanged` → `ns.Refresh()` re-tags everything currently shown so a settings change is immediate. Refreshers no-op when their host frame is hidden.
- **Surfaces** (hooked at file-load): character `PaperDollItemSlotButton_Update`; inspect `InspectPaperDollItemSlotButton_Update` (via `EventUtil.ContinueOnAddOnLoaded("Blizzard_InspectUI")`, unit = `InspectFrame.unit or "target"`) — the same block also shows the average ilvl (`ns.SetAvgIlvl(InspectModelFrame, C_PaperDollInfo.GetInspectItemLevel(unit))`, gated on `inspectAvg`), refreshed on `INSPECT_READY` (data streams in async) and by the inspect refresher; bags `ContainerFrameCombinedBags` + each `ContainerFrameContainer.ContainerFrames` `UpdateItems`; bank `BankPanel` `GenerateItemSlotsForSelectedTab`/`RefreshAllItemsForSelectedTab` (gated on `C_Bank.CanUseBank`); loot `LootFrame.ScrollBox` `OnUpdate`→`ForEachFrame`; guild bank `GuildBankFrame:Update` (via `ContinueOnAddOnLoaded("Blizzard_GuildBankUI")`).
- **Bagnon** (`bagnon.lua`, via `ContinueOnAddOnLoaded("Bagnon")` / `"Bagnonium"`): chains `<frontend>.Item.UpdateSecondary` — the `nop` "backwards support" hook `Item:Update` runs at the end of every refresh, with `self.info` (`itemID`/`hyperlink`/`quality`). Build the overlay item from `info.hyperlink`. Hooking the *base* `Item` reaches the bag-slot `ContainerItem` subclass (its `UpdateSecondary` Super-calls the base). Refresher calls `<frontend>.Frames:Update()` (fires `UPDATE_ALL`→ re-Layout → re-runs the hook).

## Key tables

| Table | Key → Value | Notes |
|---|---|---|
| `ns.InsetPositions` | slot button name → `{point, relativePoint, x, y, justifyH}` | Character*/Inspect* slots; left column anchors label to the icon's RIGHT, right column to the LEFT. Weapons (bottom centre) follow the same convention vertically centred — main hand left, off hand right — so they drop below the wrist / trinket-2 labels instead of overlapping. Also the "is this a gear slot" gate for the paperdoll hooks |

## Gotchas

- **`ns.db` is nil during file-load** — files run before our `ADDON_LOADED`, so all `db(...)`/`ns.db` reads live inside runtime closures (hooks, refreshers, `ItemDetails`), never at top level. Guards (`ns.db and ...`) cover the first hook fire.
- **Per-surface gate cleans first** — surface update fns `CleanButton` before checking the toggle, so disabling a place (then `Refresh`) visibly clears it; UpdateButton's pre-clean also lets character/inspect swap inset↔overlay live.
- **Track on bag gear needs the authoritative link** — `GetItemUpgradeInfo` accepts only a hyperlink (passing an `ItemLocation` errors), and a freshly-seen bag item's `item:GetItemLink()` can be sparse, so the track comes back blank while the ilvl shows. Fetch the link from the slot instead (`C_Container.GetContainerItemLink` / `GetInventoryItemLink`, resolved via `item:GetItemLocation()`); fall back to `item:GetItemLink()` only for location-less loot/guild-bank items.
- **`ns:Print` (colon)** — `Print` treats a non-`addOn` first arg as a sub-prefix, so the dev command calls `ns:Print(...)`.
- **Equipped-bag buttons share `PaperDollItemSlotButton_Update`** — `CharacterBag*Slot` buttons fire the same hook; the `InsetPositions` membership gate skips them.
- **Baganator widget uses `{corner=...}`, not `default_position`** — current Baganator reads `defaultPosition.corner`/`.priority`; the old SimpleItemLevel `default_position` key leaves the widget registered but never auto-added to a corner (invisible until manually enabled). The onUpdate receives Baganator's `details` (full `itemLink`/`quality`/`itemID`) — use those directly via `ns.TrackFromLink`/`ns.WantGear`, don't rebuild an Item.
- **Baganator refresh is Baganator's** — `ns.Refresh` doesn't touch it; toggling `baganator` applies on Baganator's next redraw. The widget is user-positioned/enabled in Baganator's own settings.
- **There is no `_G.BagBrother`** — BagBrother's own `.toc` loads *no* files; it's a shared-source container that front-ends `<Include>` into *their own* namespace (Bagnon's `main.xml` → `..\..\BagBrother\core\core.xml`). So `WildAddon:NewAddon` runs with `ADDON = "Bagnon"` and the classes/Frames land on `_G.Bagnon` (and `_G.Bagnonium` for that front-end), each a separate copy. `bagnon.lua` therefore hooks every known front-end global via `_G[name]`, not `BagBrother`. (`IsAddOnLoaded("BagBrother")` is still true — it just defines no global.)
- **Wildpants Mixin-copies methods onto each button** — `Item:Bind` does `Mixin(button, __bindList)` (the class's method list, cached on first bind) "for secure frames", so a button's `UpdateSecondary` is a *copy*, not a metatable lookup. We must override the class method **before the first button is bound**; `ContinueOnAddOnLoaded(<frontend>)` fires at the front-end's ADDON_LOADED (startup), before the bag frames + buttons are first built, so the override is captured. The bag button (`ContainerItem`) overrides `UpdateSecondary` and `self:Super(Item):UpdateSecondary()` — a live class lookup — so chaining the *base* `Item` reaches it. Chain the original (`nop`) rather than replacing, to coexist with other extensions.
- **Don't shadow the `Item` global in `bagnon.lua`** — `<frontend>.Item` is the *button class*; we still need the Blizzard `Item` mixin factory (`Item:CreateFromItemLink`) to build the overlay item. The hook receives the button as `addon.Item.UpdateSecondary(button)`, keeping the global `Item` free.
