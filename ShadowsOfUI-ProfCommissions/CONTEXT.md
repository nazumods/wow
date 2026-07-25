# ShadowsOfUI-ProfCommissions

**Deps:** LibNAddOn · **OptionalDeps:** none · **SavedVars:** none · **Commands:** `/sprofcomm` (status), `/sprofcomm size <n>` (dev: live icon-size tuning), `/sprofcomm reserve <n>` (dev: live money-zone tuning), `/sprofcomm glow <n>` (dev: live rare-glow quality threshold), `/sprofcomm rewards` (dev: dump every reward drawn this session + its resolved quality) · **API:** none · **UI:** none (raw WoW frames, no LibNUI)

Two hooks on the crafter **Crafting Orders** browse list: (1) replaces Blizzard's generic reward
**treasure-chest** icon in the Commission column with the **actual reward item/currency icons**
(each hoverable for its full tooltip, and **gold-glowing** at Epic quality or better); (2) **replaces the text "Reagents" column** with an **"Info"
column** of two status icons — first-craft bonus + reagent provision. Patron (NPC) orders carry
`npcOrderRewards`; other orders have none and render no reward icons. Assignment-form init
(`local ns = LibNAddOn(...)`); no LibNUI, no DB.

## Files

| File | Purpose |
|---|---|
| `core.lua` | Bootstrap only: `LibNAddOn(...)`, the shared `ns.tuning` knob table (`iconSize` / `iconGap` / `moneyReserve` / `glowQuality`), the `ContinueOnAddOnLoaded` installer that `hooksecurefunc`s both features, and the `/sprofcomm` command. |
| `rewards.lua` | Feature 1 — the reward-icon pool, `fillIcon` / `applyQuality` / `requestQuality` (quality border + gold rare glow), `ns.PopulateRewardIcons` (the commission-cell post-hook), and `ns.DumpRewards`. |
| `infocolumn.lua` | Feature 2 — `ShadowsOfUI_ProfCommissions_InfoCellMixin` and `ns.ReplaceReagentsColumn` (the `SetupTable` post-hook that repurposes the Reagents column). |
| `changelog.lua` | `ns.changelog` — newest-first `{version, notes}` release history for the in-game **Changelog** viewer (LibNAddOn). **Generated** — `release.sh` prepends each release; not hand-edited |
| `column.xml` | The Info column's cell template (`ShadowsOfUI_ProfCommissions_InfoCellTemplate`) — a `passThroughButtons` Frame with two textures (`FirstCraft`, `Reagents`) and OnEnter/OnLeave wired to the mixin. |
| `media/unresolved.tga` | Red ⊗ marker (a copy of LibNUI's `unresolved.tga`; this addon has no LibNUI dep) drawn on `FirstCraft` when the recipe is unlearned. |

## How it hooks

Blizzard's `ProfessionsCrafterTableCellCommissionMixin:Populate(rowData)` (defined in
`Blizzard_ProfessionsTemplates`, a dependency of the load-on-demand `Blizzard_Professions`)
renders the Tip/Commission cell: a `TipMoneyDisplayFrame` (right-anchored) plus a `RewardIcon`
(atlas `ui_icon_chest_npcreward`) shown when `rowData.option.npcOrderRewards` is non-empty, with a
hover tooltip listing the rewards.

We `EventUtil.ContinueOnAddOnLoaded("Blizzard_Professions", …)` then
`hooksecurefunc(ProfessionsCrafterTableCellCommissionMixin, "Populate", onPopulate)`. Hooking the
shared **mixin table** before any cell frame is created means every cell (created lazily by the
table builder on first browse) picks up the wrapped method — cells `Mixin` the current table
values at `CreateFrame` time. The same mixin backs the Tip/MaxTip/AvgTip columns; only orders with
`npcOrderRewards` render icons, so the aggregate public-order columns are unaffected.

## `ns.PopulateRewardIcons(cell, rowData)` (post-hook)

1. `cell.RewardIcon:Hide()` — always suppress the native chest (our post-hook runs after Blizzard's
   `SetShown(hasRewards)`, so we win).
2. Reads `rowData.option.npcOrderRewards` (array of `{ itemLink, count }` **or**
   `{ currencyType, count }` — same shape `ProfessionsCrafterOrderRewardMixin:SetReward` consumes).
3. Lazily grows a **per-cell** icon-button pool (`cell.soiRewardIcons`); reused on row recycle,
   surplus buttons hidden.
4. Anchors the **rightmost** reward next to `TipMoneyDisplayFrame`'s `LEFT` and walks leftward, so
   reward 1 ends up leftmost (matching the tooltip's top-down order).

Each icon button (`acquireIcon`): trimmed icon texture, a `glow` texture (see below), a 1px
quality-coloured `border` texture (shown only for item rewards above Common), a small `count`
fontstring (shown when count > 1), and `OnEnter`/`OnLeave` scripts. `fillIcon` resolves
texture+quality via `C_Item.GetItemInfoInstant` + `C_Item.GetItemQualityByID` (items) or
`C_CurrencyInfo.GetCurrencyInfo` (currency), then hands quality to `applyQuality` (border + glow).
The tooltip is `GameTooltip:SetHyperlink(itemLink)` / `SetCurrencyByID(currencyType)`, and hovering
also shows the row's `HighlightTexture` (via `cell:GetParent():GetParent()`), matching the native
feel.

The tunables live on **`ns.tuning`** (`core.lua`), not as per-file locals, so the slash command can
mutate them across files: `iconSize` (18) / `iconGap` (3) / `moneyReserve` (80) / `glowQuality`
(`Enum.ItemQuality.Epic`). The **rightmost** reward pins its right edge to `TipMoneyDisplayFrame`'s
**right** edge minus `moneyReserve` (a fixed money zone), not to the money's *left* edge — the left
edge shifts with the amount's digit count, so pinning there left the reward column ragged across
rows; the fixed reserve keeps it aligned. `/sprofcomm size|reserve|glow <n>` mutate the matching
field live, applying on the next **full populate** — reopen the Crafting Orders window; a header
re-sort reuses the cells already drawn and leaves the old values on screen.

## Rare-reward glow

**Criteria: quality ≥ `Enum.ItemQuality.Epic` (4), items and currency alike.** Currency rewards do
carry a real item-quality value — `C_CurrencyInfo.GetCurrencyInfo().quality` is what Blizzard's own
`ProfessionsCrafterOrderRewardTooltipMixin:SetReward` colours currency names with — so one threshold
covers both kinds and no curated ID list is needed. **Epic** is the floor because every Patron order
pays the profession's *Artisan `<Prof>`'s Moxie* currency at **Rare** (3); glowing on Rare would glow
every row. The reward that prompted this (#692), *Artisan's Consortium Gold Star*, is item **246450**
at **Epic** — an item, not a currency as the issue assumed.

The glow is `bags-glow-white` (Blizzard's new-item glow art) with `SetBlendMode("ADD")`,
vertex-coloured WoW gold `(1, 0.82, 0)`, spreading `GLOW_PAD` (4px) past each edge — and it sits on
**`BACKGROUND`, behind the icon**. That layer is the whole trick: `bags-glow-white` is a *filled*
square, not a ring, so drawn on top it washes an 18px icon into an unreadable gold block (verified
in-game — it rendered as a hard gold box). Behind, the opaque icon masks the filled middle and only
the soft falloff shows, giving a halo around a legible icon. `iconGap` is 4 to match `GLOW_PAD`, so
two adjacent rare rewards' haloes meet without overlapping. Created **hidden**, per the suite rule
that icon overlays must not leak a first paint. It is **static**, not pulsed: these rows recycle
constantly, so there is no animation lifecycle to leave stuck on a recycled icon.

`requestQuality` covers the cache miss: `C_Item.GetItemQualityByID` is cache-backed, so a reward item
the client has never seen resolves to `nil` and would render with neither border nor glow.
`Item:CreateFromItemLink(link):ContinueOnItemLoad(...)` re-runs `applyQuality` when the data lands,
re-checking `icon.itemLink == link` first — rows recycle their icons while the request is in flight.

`ns.DumpRewards` (`/sprofcomm rewards`) prints every distinct reward drawn this session from the
module-level `seen` map (keyed by itemLink / currencyType, holding the reward entry itself so quality
is re-resolved at dump time), each with its kind, name, resolved quality and whether it glows.

## Info column (`SetupTable` hook)

`ProfessionsFrame.OrdersPage:SetupTable()` rebuilds the table builder's columns each time it runs
(tab/browse-type change). We post-hook the **instance** (`hooksecurefunc(ProfessionsFrame.OrdersPage,
"SetupTable", …)`) — the page frame already exists at `Blizzard_Professions` load, so hooking the
mixin table would miss it. In the hook, `ns.ReplaceReagentsColumn` finds the Reagents column by
`col.headerFrame.sortOrder == ProfessionsSortOrder.Reagents` (present only on the per-order **Flat**
list — the aggregated bucketed view has no Reagents column, so the lookup returns nil and the hook
no-ops), then:

1. `column:Reset()` — release the old text cells **through their own pool** (must precede the pool
   swap, or `Arrange`'s later `Reset` would release them through the new pool → corruption).
2. `column:ConstructCells("FRAME", "…InfoCellTemplate", page)` — swap the cell pool to our template.
3. `column.headerFrame:SetText("Info")` — relabel (the header keeps its `sortOrder`, so the column
   still **sorts by reagent state**).
4. `tb:Arrange()` — rebuild every row's cells with the new pool.

Reusing the Reagents column keeps its slot, 90px width, position, and sort. `SetupTable` calls
`Reset()` + re-adds Blizzard's Reagents column each rebuild, so the post-hook re-applies the swap
every time (a momentary "Reagents"/text state is overwritten before paint).

`ShadowsOfUI_ProfCommissions_InfoCellMixin` (`CreateFromMixins(TableBuilderCellMixin)`):
- `Populate(rowData)` — the `FirstCraft` texture is tri-state (tracked on `self._firstCraftState`):
  **unlearned** recipe (`not GetRecipeInfo(spellID)` or `not .learned`, mirroring Blizzard's own
  claim gate) → the red ⊗ `media/unresolved.tga` marker (`SetTexture`); else **first craft**
  (`IsRecipeFirstCraft`) → the `Professions_Icon_FirstTimeCraft` book (`SetAtlas`); else hidden. The
  unlearned check wins so a first-craft bonus you can't claim yet isn't dangled. `Reagents` atlas by
  `order.reagentState` — `Capacitance-General-WorkOrderCheckmark` (All, green), `NPE_ExclamationPoint`
  (Some, yellow / None, red-tinted). All fail safe to hidden on missing data.
- `OnEnter`/`OnLeave` — row `HighlightTexture` + a `GameTooltip` summarising the shown icons
  (first-craft line + the reagent-provision line). `passThroughButtons` keeps the row click alive.

## Gotchas

- **Hook before cells exist** — must hook the mixin table at addon-load, not after the list is
  populated; frames copy the function reference at `Mixin`/`CreateFrame` time.
- **`ContinueOnAddOnLoaded` can fire synchronously** — when `Blizzard_Professions` is already loaded
  it calls the callback *inline*, which for `core.lua` means during its own main chunk, before
  `rewards.lua` / `infocolumn.lua` have defined `ns.PopulateRewardIcons` / `ns.ReplaceReagentsColumn`.
  Both hooks therefore go through a **closure** that resolves the `ns` field at call time; passing
  the field directly raises `Usage: hooksecurefunc(...)` on login. Also keeps the installer immune
  to `.toc` reordering.
- **A header re-sort does not repopulate** — it reuses cells already drawn, so a live `/sprofcomm`
  retune (and any other populate-time change) only shows after the Crafting Orders window is
  **reopened**. Worth knowing when verifying in-game: re-sorting reads back stale paint.
- **Native chest re-shows every populate** — Blizzard's `Populate` calls `RewardIcon:SetShown(...)`
  each time; the hide must live in the post-hook (runs after), not a one-off.
- **`GetItemQualityByID` is cache-backed** — returns nil for an uncached reward item, which would
  drop *both* the border and the glow. `requestQuality` re-decorates asynchronously; its callback
  **must** re-check `icon.itemLink`, because the icon may have been recycled onto another row.
- **Currency quality is real** — `GetCurrencyInfo().quality` is a genuine `Enum.ItemQuality` value,
  not a placeholder. The glow uses it; the **border** deliberately still doesn't (items-only, #360).
- **Icon sizing is a first cut** — the Tip column is 160px wide (25px padding each side); money
  takes ~60px, leaving room for ~2–3 icons at 18px. Tune with `/sprofcomm size`.
