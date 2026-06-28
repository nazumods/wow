# ShadowsOfUI-Delves

**Deps:** LibNAddOn, Warbandeer_Characters · **SavedVars:** none · **Commands:** `/sdelves` (dev/calibration) · **UI:** none (no LibNUI) · **API:** reads `WarbandeerApi`

Headless tooltip addon. Appends the current character's average delve completion time to a
delve's **map entrance-pin** tooltip. Assignment-form init (`local ns = LibNAddOn(...)`); no
LibNUI, no DB. All run-time data is tracked + stored by **Warbandeer_Characters**
(`data/delvetimes.lua`) and read here via `WarbandeerApi:GetDelveStats`. Pairs with
ShadowsOfUI-Quests/-Reputations (same data-layer-consumer shape).

## Files

| File | Purpose |
|---|---|
| `core.lua` | Bootstrap + `ns.AssumedTier()` (T11 = `MAX_TIER` at the level cap via `ns.wow.Player:isMaxLevel()`, else nil → all-tiers fallback) + `ns.FormatDuration(sec)` (`m:ss`) + `/sdelves` (no arg: dump live delve state for tier/name calibration; `dump`: print `GetDelveStats` for the delve you're in). |
| `tooltip.lua` | `hooksecurefunc(AreaPOIPinMixin, "OnMouseEnter", …)` → gate the pin to delves via `C_AreaPoiInfo.GetDelvesForMap(mapID)`, then `appendDelveTime`: pull the current character's entry from `WarbandeerApi:GetDelveStats(poiName, ns.AssumedTier())` and add a line (`Avg completion (T11): m:ss · N runs`, or `(all tiers)` for the aggregate, or a muted `No timed runs yet`), then re-`Show`. Shift hides it. |

## How it hooks

Delve entrance pins build their tooltip in `AreaPOIPinMixin:OnMouseEnter`; we hook it, read the
pin's `areaPoiID` + owning map, and only act when the POI is in `GetDelvesForMap(mapID)` (so
non-delve pins are untouched). We append our line and re-`Show` so `GameTooltip` resizes around
it — same idiom as ShadowsOfUI-Quests.

## Gotchas

- **Calibrate-in-game spots** (each has a safe fallback; `/sdelves` surfaces the live values):
  the **tier readout** lives in the data layer (`Warbandeer_Characters/data/delvetimes.lua`'s
  `readTier`) and falls back to the unknown bucket (still counted in the aggregate); the **POI
  name ↔ scenario name** match relies on `ns.NormalizeDelveKey` (extend it if a delve's pin name
  and in-delve name differ by more than a leading article); the **pin mixin** hook is guarded, so
  a client/mixin-name change just disables the line instead of erroring.
- **No data ≠ broken.** A delve with no completed runs shows `No timed runs yet`; the average
  only appears after the current character finishes that delve at least once.
- **No `X-Curse-Project-ID` yet** — added when the CurseForge project is created.
