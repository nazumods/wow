# ShadowsOfUI-Delves

**Deps:** LibNAddOn, LibNUI, Warbandeer_Characters · **SavedVars:** none · **Commands:** `/sdelves` (dev/calibration) · **UI:** LibNUI (shared copy window for `/sdelves`) · **API:** reads `WarbandeerApi`

Headless tooltip addon. Appends the current character's average delve completion time — and, for
leveling characters, average XP earned + XP/hr — to a delve's **map entrance-pin** tooltip.
Assignment-form init (`local ns = LibNAddOn(...)`); no DB.
LibNUI is bound (`X-NUI-UI: LibNUI`) only so the `/sdelves` dev commands can render into the shared
copyable window (`ui.ToggleCopyWindow`) instead of chat. All run-time data is tracked + stored by **Warbandeer_Characters**
(`data/delvetimes.lua`) and read here via `WarbandeerApi:GetDelveStats`. Pairs with
ShadowsOfUI-Quests/-Reputations (same data-layer-consumer shape).

## Files

| File | Purpose |
|---|---|
| `core.lua` | Bootstrap (`local ui = ns.ui`) + `ns.AssumedTier()` (T11 = `MAX_TIER` at the level cap via `ns.wow.Player:isMaxLevel()`, else nil → all-tiers fallback) + `ns.FormatDuration(sec)` (alias of the shared `ns.lua.strings.duration`, `m:ss`) + `/sdelves` (no arg: dump live delve state for tier/name calibration; `dump`: `GetDelveStats` for the delve you're in — includes `avgXp`/`xpCount` when recorded). Both render into the shared **copy window** (`ui.ToggleCopyWindow`) so the output can be pasted; only the short "not in a delve"/"no runs" guards stay `ns.Print`. |
| `changelog.lua` | `ns.changelog` — newest-first `{version, notes}` release history for the in-game **Changelog** viewer (LibNAddOn). **Generated** — `release.sh` prepends each release; not hand-edited |
| `tooltip.lua` | `hooksecurefunc(DelveEntrancePinMixin, "OnMouseEnter", …)` (installed via `EventUtil.ContinueOnAddOnLoaded("Blizzard_SharedMapDataProviders")` — the mixin is in a **LoadOnDemand** package, nil at login) → gate the pin to delves via `C_AreaPoiInfo.GetDelvesForMap(mapID)`, then `appendDelveTime`: pull the current character's entry from `WarbandeerApi:GetDelveStats(poiName, ns.AssumedTier())` and add a line (`Avg completion (T11): m:ss · N runs`, or `(all tiers)` for the aggregate, or a muted `No timed runs yet`), then re-`Show`. For **leveling** characters (gated on `not ns.wow.Player:isMaxLevel()` — an explicit cap gate that drops stale leveling XP left in the rolling window on a freshly-capped char — and a non-nil `avgXp`) it adds a second `Avg XP: <BreakUpLargeNumbers> · <AbbreviateNumbers> XP/hr` line, where XP/hr = `avgXp ÷ avg × 3600`. Shift hides both. |

## How it hooks

Delve entrance pins build their tooltip in `DelveEntrancePinMixin:OnMouseEnter` (a copy-based
`AreaPOIPinMixin:CreateSubPin`). We hook **that** mixin — not the `AreaPOIPinMixin` base:
`CreateSubPin`/`CreateFromMixins` *copy* the parent's methods into the sub-pin table, so the pins
call the copy and a base-mixin hook never fires for them. The mixin lives in
`Blizzard_SharedMapDataProviders`, a **LoadOnDemand** package that only loads with the World Map
(after us), so at login the global is nil — we defer the hook with
`EventUtil.ContinueOnAddOnLoaded("Blizzard_SharedMapDataProviders", …)` (which runs immediately if
it's already loaded). In the hook we read the pin's `areaPoiID` + owning map and only act when the
POI is in `GetDelvesForMap(mapID)` (defensive — the delve mixin is already delve-only), then append
our line and re-`Show` so `GameTooltip` resizes around it — same append idiom as ShadowsOfUI-Quests.

## Gotchas

- **Calibrate-in-game spots** (each has a safe fallback; `/sdelves` surfaces the live values):
  the **tier readout** lives in the data layer (`Warbandeer_Characters/data/delvetimes.lua`'s
  `readTier`) and falls back to the unknown bucket (still counted in the aggregate); the **POI
  name ↔ scenario name** match relies on `ns.NormalizeDelveKey` (extend it if a delve's pin name
  and in-delve name differ by more than a leading article); the **pin mixin** hook targets
  `DelveEntrancePinMixin` (deferred until its LoadOnDemand package loads) and is guarded, so a
  client/mixin-name change just disables the line instead of erroring.
- **No data ≠ broken.** A delve with no completed runs shows `No timed runs yet`; the average
  only appears after the current character finishes that delve at least once.
- **No `X-Curse-Project-ID` yet** — added when the CurseForge project is created.
