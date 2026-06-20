# ShadowsOfUI-Artisan

**Deps:** LibNAddOn, Warbandeer_Characters · **OptionalDeps:** Warbandeer · **SavedVars:** none · **Commands:** `/sartisan [name]` (dev dump) · **API:** reads `WarbandeerApi` + `WarbandeerDB` · **UI:** none (raw WoW frames, no LibNUI)

Adds a currency badge to each crafting profession on the spellbook's professions page
(`ProfessionsBookFrame`), showing the current expansion's artisan crafting currency (the
"Artisan's …" family, e.g. Acuity) for the logged-in character, with an account-wide hover
breakdown. Assignment-form init (`local ns = LibNAddOn(...)`); no LibNUI.

## Files

| File | Purpose |
|---|---|
| `core.lua` | Bootstrap + data. `ns.ARTISAN_CURRENCIES` (parent skillLineID → currencyId, current expansion) and `ns.BuildBreakdown(skillLineID)` → sorted `ArtisanEntry[]`. Manual `/sartisan` dev command. |
| `badge.lua` | `Blizzard_ProfessionsBook` hook: lazily attaches the badge (icon + amount) per profession frame and renders the breakdown tooltip; refreshes on currency change while the page is shown. |

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

- **Attach surface:** `EventUtil.ContinueOnAddOnLoaded("Blizzard_ProfessionsBook", …)` (the
  LoD addon for the spellbook page), then `hooksecurefunc("ProfessionsBookFrame_Update",
  ns.UpdateBadges)`. Blizzard's `FormatProfession` stamps `frame.skillLine` (parent skillLineID)
  on `PrimaryProfession1/2` and `SecondaryProfession1/2/3`; we iterate all five and gate on
  `ARTISAN_CURRENCIES` so secondary/gathering profs show nothing.
- **Badge:** a mouse-enabled `Frame` (`frame.soiArtisanBadge`, 5 frame levels above the
  profession frame) anchored `TOPRIGHT`, holding the currency `iconFileID` texture + amount
  (`BreakUpLargeNumbers`); width grows to cover the text so the whole thing is hoverable. Hidden
  (not destroyed) when the profession has no mapped currency, so a profession swap leaves no
  stale badge.
- **Tooltip** (`onEnter`): header = currency icon + name; one `AddDoubleLine` per `BuildBreakdown`
  entry — class-coloured name (current char tagged `(here)`) + amount.
- **Refresh:** a driver frame registers `CURRENCY_DISPLAY_UPDATE` between the EventRegistry
  `ProfessionsBookFrame.Show`/`.Hide` callbacks; the `ProfessionsBookFrame_Update` hook covers
  profession changes.

## Gotchas

- **`ns.api`/`GetCurrencyInfo` may be cold at file-load** — all reads live inside the hook /
  tooltip closures, never at top level; `BuildBreakdown` guards a missing `ns.api`.
- **Alt amounts are last-seen** — an alt not played since the `artisanCurrency` broker shipped
  reads 0; this is a cache, not a live cross-character query (only the logged-in char's currency
  is live-readable).
- **A wrong/missing currency id fails safe** — `GetCurrencyInfo` returns nil → no badge for
  that profession, rather than erroring.
- **Badge position (`TOPRIGHT -10,-12`) is a first cut** — tune against the live page if it
  collides with the rank text / unlearn button.
