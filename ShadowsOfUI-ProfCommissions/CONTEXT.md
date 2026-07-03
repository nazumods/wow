# ShadowsOfUI-ProfCommissions

**Deps:** LibNAddOn · **OptionalDeps:** none · **SavedVars:** none · **Commands:** `/sprofcomm` (status), `/sprofcomm size <n>` (dev: live icon-size tuning) · **API:** none · **UI:** none (raw WoW frames, no LibNUI)

Two hooks on the crafter **Crafting Orders** browse list: (1) replaces Blizzard's generic reward
**treasure-chest** icon in the Commission column with the **actual reward item/currency icons**
(each hoverable for its full tooltip); (2) **replaces the text "Reagents" column** with an **"Info"
column** of two status icons — first-craft bonus + reagent provision. Patron (NPC) orders carry
`npcOrderRewards`; other orders have none and render no reward icons. Assignment-form init
(`local ns = LibNAddOn(...)`); no LibNUI, no DB.

## Files

| File | Purpose |
|---|---|
| `core.lua` | Both features: the `hooksecurefunc` on the commission cell mixin (reward-icon pool + rendering); the `ShadowsOfUI_ProfCommissions_InfoCellMixin` + `SetupTable` hook that repurposes the Reagents column; and the `/sprofcomm` command. |
| `column.xml` | The Info column's cell template (`ShadowsOfUI_ProfCommissions_InfoCellTemplate`) — a `passThroughButtons` Frame with two textures (`FirstCraft`, `Reagents`) and OnEnter/OnLeave wired to the mixin. |

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

## `onPopulate(cell, rowData)` (post-hook)

1. `cell.RewardIcon:Hide()` — always suppress the native chest (our post-hook runs after Blizzard's
   `SetShown(hasRewards)`, so we win).
2. Reads `rowData.option.npcOrderRewards` (array of `{ itemLink, count }` **or**
   `{ currencyType, count }` — same shape `ProfessionsCrafterOrderRewardMixin:SetReward` consumes).
3. Lazily grows a **per-cell** icon-button pool (`cell.soiRewardIcons`); reused on row recycle,
   surplus buttons hidden.
4. Anchors the **rightmost** reward next to `TipMoneyDisplayFrame`'s `LEFT` and walks leftward, so
   reward 1 ends up leftmost (matching the tooltip's top-down order).

Each icon button (`acquireIcon`): trimmed icon texture, a 1px quality-coloured `border` texture
(shown only for item rewards above Common), a small `count` fontstring (shown when count > 1), and
`OnEnter`/`OnLeave` scripts. `fillIcon` resolves texture+quality via `C_Item.GetItemInfoInstant` +
`C_Item.GetItemQualityByID` (items) or `C_CurrencyInfo.GetCurrencyInfo` (currency). The tooltip is
`GameTooltip:SetHyperlink(itemLink)` / `SetCurrencyByID(currencyType)`, and hovering also shows the
row's `HighlightTexture` (via `cell:GetParent():GetParent()`), matching the native feel.

`ICON_SIZE` (18) / `ICON_GAP` (3) are module-level; `/sprofcomm size <n>` mutates `ICON_SIZE` live
(applies on the next `Populate`, i.e. a re-sort or reopen).

## Info column (`SetupTable` hook)

`ProfessionsFrame.OrdersPage:SetupTable()` rebuilds the table builder's columns each time it runs
(tab/browse-type change). We post-hook the **instance** (`hooksecurefunc(ProfessionsFrame.OrdersPage,
"SetupTable", …)`) — the page frame already exists at `Blizzard_Professions` load, so hooking the
mixin table would miss it. In the hook, `replaceReagentsColumn` finds the Reagents column by
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
- `Populate(rowData)` — `FirstCraft:SetShown(C_TradeSkillUI.IsRecipeFirstCraft(order.spellID))`;
  `Reagents` atlas by `order.reagentState` — `Capacitance-General-WorkOrderCheckmark` (All, green),
  `NPE_ExclamationPoint` (Some, yellow / None, red-tinted). Both fail safe to hidden on missing data.
- `OnEnter`/`OnLeave` — row `HighlightTexture` + a `GameTooltip` summarising the shown icons
  (first-craft line + the reagent-provision line). `passThroughButtons` keeps the row click alive.

## Gotchas

- **Hook before cells exist** — must hook the mixin table at addon-load, not after the list is
  populated; frames copy the function reference at `Mixin`/`CreateFrame` time.
- **Native chest re-shows every populate** — Blizzard's `Populate` calls `RewardIcon:SetShown(...)`
  each time; the hide must live in the post-hook (runs after), not a one-off.
- **`GetItemQualityByID` is cache-backed** — returns nil for an uncached reward item → no border
  that pass (fails safe); order-reward items are generally cached since they're being displayed.
- **Icon sizing is a first cut** — the Tip column is 160px wide (25px padding each side); money
  takes ~60px, leaving room for ~2–3 icons at 18px. Tune with `/sprofcomm size`.
