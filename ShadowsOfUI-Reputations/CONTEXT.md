# ShadowsOfUI-Reputations

**Deps:** LibNAddOn, Warbandeer_Characters · **OptionalDeps:** Warbandeer · **SavedVars:** none · **Commands:** `/sreps <factionID|name>` (dev/lookup) · **API:** reads `WarbandeerApi`

Headless addon. Surfaces each character's faction standings warband-wide, in two places: the
in-game Reputation tab (hover a faction) and faction-tied item tooltips. Assignment-form init
(`local ns = LibNAddOn(...)`); no LibNUI, no DB. All data comes from Warbandeer_Characters'
`reputations` broker via `WarbandeerApi`.

## Files

| File | Purpose |
|---|---|
| `core.lua` | Bootstrap + `ns.ColorName` (class colour) + `ns.AppendStandings(tooltip, factionID)` (the shared "Standing across your warband:" block — one class-coloured line per character via `WarbandeerApi:GetFactionStandings`, value **green** when `done`, blue **Paragon** marker; capped at `MAX` 12 + "+N more"). **Account-wide factions** (`FactionData.isAccountWide` — shared across the whole warband) collapse to a single `Warband Wide` line instead of repeating the same standing per character. Also the faction-name index for the item surface: `ns.RebuildFactionIndex` (lowercased name → factionID, union across all tracked characters) + `ns.FactionIDByName(text)` (longest cached name appearing in `text`). `ns.onLogin` rebuilds the index + installs the panel hook. |
| `panel.lua` | `ns.InstallPanelHook` → `hooksecurefunc(ReputationEntryMixin, "OnEnter", …)`: reads `self.elementData.factionID`, appends the block to `GameTooltip`, re-`Show`s it. Installed at file load + retried on login (the mixin is base UI, normally present at load). |
| `tooltip.lua` | `AddTooltipPostCall(Item)` → lowercases the tooltip lines, `ns.FactionIDByName` matches a tracked faction, appends the block (item tooltips auto-show, no re-Show). `/sreps` dev/lookup command. |

## How matching works

- **Panel**: exact — the faction row carries `elementData.factionID`.
- **Item**: heuristic — there's no item→faction API, so a cached faction **name** appearing in
  the tooltip text (rep token's "increases your reputation with X", a tabard's name, …) keys
  the lookup. Locale-consistent (cached names + live tooltip share the client locale); names
  shorter than `MIN_NAME` (5) are ignored as false-positive bait, and the **longest** match
  wins. An item that never names its faction won't trigger the block.

## Gotchas

- **Last-seen data.** Standings refresh while a character is logged in (the broker scans each
  login + on `UPDATE_FACTION`); alts fill in as they're seen. `/wbc missing` flags
  "reputations" for never-seen characters.
- **Panel hook re-Shows the tooltip.** The row's `OnEnter` already built + showed its tooltip;
  appending lines needs a second `GameTooltip:Show()` to resize. Item tooltips don't (the data
  system shows them after post-calls).
- **`GetFactionStandings` is account-wide and sorted** (highest `rank` first) in the data layer,
  so the renderer just walks the list.
- **No `X-Curse-Project-ID` yet** — added when the CurseForge project is created.
