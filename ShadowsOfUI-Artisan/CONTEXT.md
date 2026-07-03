# ShadowsOfUI-Artisan

**Deps:** LibNAddOn, Warbandeer_Characters · **OptionalDeps:** Warbandeer · **SavedVars:** none · **Commands:** `/sartisan [name]` (dev dump) · **API:** reads `WarbandeerApi` + `WarbandeerDB` · **UI:** none (raw WoW frames, no LibNUI)

Adds a currency badge — the current expansion's artisan crafting currency (Midnight's
per-profession "Artisan's … Moxie") for the logged-in character, with an account-wide hover
breakdown — on **three surfaces**: the crafting window (`ProfessionsFrame.CraftingPage`, beside
Blizzard's Concentration readout), the crafting-window **Crafting Orders tab**
(`ProfessionsFrame.OrdersPage`, top-left header slot), and the spellbook professions page
(`ProfessionsBookFrame`, under each profession's spell-button labels). Assignment-form init
(`local ns = LibNAddOn(...)`); no LibNUI.

## Files

| File | Purpose |
|---|---|
| `core.lua` | Bootstrap + data. `ns.ARTISAN_CURRENCIES` (parent skillLineID → currencyId, current expansion) and `ns.BuildBreakdown(skillLineID)` → sorted `ArtisanEntry[]`. Manual `/sartisan` dev command. |
| `badge.lua` | Shared `makeBadge`/`applyBadge`/`onEnter` + three surfaces: `ns.UpdateBadge` (crafting window, one badge by the concentration readout), `ns.UpdateOrderBadge` (Crafting Orders tab, one badge in the top-left header) and `ns.UpdateBookBadges` (spellbook page, one badge per profession under its spell label). All refresh on profession switch + currency change while shown. |

## `ns.ARTISAN_CURRENCIES`

`{ [parentSkillLineID] = currencyId }` for the **current expansion only**. In Midnight the
currency is the **per-profession** "Artisan's … Moxie" family (3256–3266) — unlike the older
single-shared Mettle/Acuity model, **every** profession has its own, **including the gathering
professions** (Herbalism 182, Mining 186, Skinning 393). Only the secondary slots
(Cooking/Fishing/Archaeology) have none. **Duplicated** in
`Warbandeer_Characters/data/artisancurrency.lua` (the broker that caches it for alts); keep the
two tables in sync, and **replace both each expansion**. (IDs cross-checked against the
SavedInstances addon's currency module.)

## `ns.BuildBreakdown(skillLineID)`

Returns `nil` when the skill line has no mapped currency. Otherwise walks
`WarbandeerApi:GetAllCharacters()`, keeps toons whose `basic.professions` has a slot with
`skillID == skillLineID`, and emits an `ArtisanEntry { name, classKey, quantity, rank,
isCurrent }`. The logged-in character (`isCurrent`) uses the **live** `GetCurrencyInfo(currencyId)
.quantity`; alts read the cached `toon.artisanCurrency.data[skillLineID].quantity` (nil → 0).
`rank` is the intent rank from `WarbandeerDB.profIntent[name][skillLineID]` (main 1, secondary 2,
else 3). Sorted by `rank ↑`, `quantity ↓`, `name ↑`.

## Rendering (`badge.lua`)

Shared helpers: `makeBadge(parent, levelOffset)` builds a mouse-enabled `Frame` (currency
`iconFileID` texture + amount `FontString`); `applyBadge(badge, skillLineID, currencyId)` sets the
icon/amount (`BreakUpLargeNumbers`), grows the width to cover the text, stamps `skillLineID`/
`currencyId` for the tooltip, and hides+returns false when the currency has no mapped id / isn't
known yet; `onEnter` renders the breakdown tooltip (header = currency icon + name; one
`AddDoubleLine` per `BuildBreakdown` entry — class-coloured name, current char tagged `(here)`).

- **Crafting window** (`ns.UpdateBadge`): `ContinueOnAddOnLoaded("Blizzard_Professions")` →
  `hooksecurefunc(ProfessionsFrame.CraftingPage, "Refresh", …)`, which fires on open + every
  profession switch with the shown `professionInfo`; key off `professionInfo.parentProfessionID`
  (parent skill line, e.g. Enchanting 333), falling back to `professionID`. One badge
  (`ns.craftBadge`) anchored `LEFT` of `page.ConcentrationDisplay`'s `RIGHT` when shown, else the
  page `TOPLEFT (120,-35)` (the concentration slot).
- **Crafting Orders tab** (`ns.UpdateOrderBadge`): same `ContinueOnAddOnLoaded("Blizzard_Professions")`
  block hooks `ProfessionsFrame.OrdersPage`'s `Refresh` (`ProfessionsCraftingOrderPageMixin`), which
  Blizzard calls for **every** page on each `ProfessionsMixin:Refresh`, so the shared `ns.currentSkill`
  is set from the same `professionInfo`. One badge (`ns.orderBadge`) at `OrdersPage TOPLEFT (120,-35)`
  (both pages `setAllPoints` the frame, so this matches the crafting badge's slot on screen). The
  **OrderView** — shown after an order is selected — has its own `ConcentrationDisplay` anchored to
  that *exact* slot; while it's shown the badge sits `LEFT` of its `RIGHT` (+16) instead, so both read
  cleanly, reverting to the slot on the browse list. Re-anchored via `ConcentrationDisplay`
  `OnShow`/`OnHide` hooks; its own driver frame registers `CURRENCY_DISPLAY_UPDATE` only while the
  Orders page is shown.
- **Spellbook page** (`ns.UpdateBookBadges`): `ContinueOnAddOnLoaded("Blizzard_ProfessionsBook")`
  → `hooksecurefunc("ProfessionsBookFrame_Update", …)`. Iterates `PrimaryProfession1/2` +
  `SecondaryProfession1/2/3`, reads `frame.skillLine` (stamped by Blizzard's `FormatProfession`),
  one badge per frame (`frame.soiArtisanBadge`) anchored under the lowest shown spell button's
  `spellString` label; gated on `ARTISAN_CURRENCIES` so Cooking/Fishing/Archaeology show nothing.
- **Refresh:** each surface has a driver frame registering `CURRENCY_DISPLAY_UPDATE` only while
  its window is shown (crafting via `ProfessionsFrame` `OnShow`/`OnHide`; book via the EventRegistry
  `ProfessionsBookFrame.Show`/`.Hide` callbacks). The respective `Refresh`/`_Update` hook covers
  profession changes.

## Gotchas

- **`ns.api`/`GetCurrencyInfo` may be cold at file-load** — all reads live inside the hook /
  tooltip closures, never at top level; `BuildBreakdown` guards a missing `ns.api`.
- **Alt amounts are last-seen** — an alt not played since the `artisanCurrency` broker shipped
  reads 0; this is a cache, not a live cross-character query (only the logged-in char's currency
  is live-readable).
- **A wrong/missing currency id fails safe** — `GetCurrencyInfo` returns nil → no badge for
  that profession, rather than erroring.
- **Badge positions are first cuts** — crafting window: `LEFT` of ConcentrationDisplay +18 (move
  below it if it collides with the skill/rank bar); spellbook page: under the lowest spell-button
  `spellString` (offset 0,-3). Tune against the live frames.
