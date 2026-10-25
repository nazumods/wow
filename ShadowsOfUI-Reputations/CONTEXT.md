# ShadowsOfUI-Reputations

**Deps:** LibNAddOn, Warbandeer_Characters · **OptionalDeps:** none · **SavedVars:** none · **Commands:** `/sreps <factionID|name>` (dev/lookup) · **API:** reads `WarbandeerApi` · **Clients:** Retail + Forever

Headless addon. Surfaces each character's faction standings warband-wide, in two places: the
in-game Reputation tab (hover a faction) and faction-tied item tooltips. Assignment-form init
(`local ns = LibNAddOn(...)`); no LibNUI, no DB. All data comes from Warbandeer_Characters'
`reputations` broker via `WarbandeerApi`.

## Files

| File | Purpose |
|---|---|
| `core.lua` | Bootstrap + `ns.AppendStandings(tooltip, factionID)` (the shared "Standing across your warband:" block — one class-coloured line per character (`ns.Colors.className`) via `WarbandeerApi:GetFactionStandings`, value **green** when `done`, blue **Paragon** marker; capped at `MAX` 12 + "+N more"). **Account-wide factions** (`FactionData.isAccountWide` — shared across the whole warband) collapse to a single `Warband Wide` line instead of repeating the same standing per character. Also the faction-name index for the item surface: `ns.RebuildFactionIndex` (lowercased name → factionID, union across all tracked characters) + `ns.FactionIDByName(text)` (longest cached name appearing in `text` — the tooltip direction) + `ns.FactionIDByQuery(query)` (the `/sreps` direction: a typed, possibly **partial**, name as a substring of a cached name — exact wins, else shortest containing name, falling back to `FactionIDByName`). `ns.onLogin` rebuilds the index + installs the panel hook. |
| `changelog.lua` | `ns.changelog` — newest-first `{version, notes}` release history for the in-game **Changelog** viewer (LibNAddOn). **Generated** — `release.sh` prepends each release; not hand-edited |
| `panel.lua` | `ns.InstallPanelHook` → `hooksecurefunc(ReputationEntryMixin, "OnEnter", …)` and, when the mixin has one, `"OnLeave"`. `OnEnter` reads `self.elementData.factionID`: when the row owns `GameTooltip` (Retail), it appends the block and re-`Show`s it. On Forever (`ns.flavor.isForever`; Camelot's `OnEnter` opens no tooltip) it never appends, and for a row that is not selected the addon owns `GameTooltip` itself (`SetOwner(row, "ANCHOR_RIGHT")`, the faction name, then the block; hidden again if there are no standings) and remembers the row. `OnLeave` hides `GameTooltip` only for that remembered row and only while the row still owns it. Installed at file load + retried on login (the mixin is base UI, normally present at load). |
| `spec/` | busted: `reputations.lua` loads `panel.lua` against a fake `GameTooltip` / `ReputationEntryMixin` / `hooksecurefunc` (Retail's `OnEnter` takes the tooltip, Camelot's does not); `panel_spec.lua` drives both clients, a selected row, no standings, and `OnLeave`. |
| `tooltip.lua` | `ns:OnItemTooltip` (LibNAddOn) → lowercases the tooltip lines, `ns.FactionIDByName` matches a tracked faction, appends the block (item tooltips auto-show, no re-Show). Resolution is **memoized per `data.id`** (`false` caches a no-faction result), wiped whenever `ns._factionIndexGen` (bumped at the end of `RebuildFactionIndex`) changes — item tooltips re-fire constantly, so the repeat cost drops to a table lookup. `/sreps` dev/lookup command. |

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
- **Panel hook re-Shows the tooltip.** On Retail the row's `OnEnter` already built + showed its tooltip;
  appending lines needs a second `GameTooltip:Show()` to resize. Item tooltips don't (the data
  system shows them after post-calls).
- **Forever's rows open no tooltip, so the addon opens its own.** Camelot's `ReputationEntryMixin:OnEnter`
  (`Blizzard_UIPanels_Game/Camelot/ReputationFrame.lua`) only shows the bar text and the highlight. The Forever branch
  in `panel.lua` is a deliberate addition (Blizzard shows nothing there), keyed on `ns.flavor.isForever` because it is
  a client UI difference, not a missing game system. Retail behaviour is unchanged. On Forever the
  "row owns `GameTooltip`, append to it" branch is never taken: Blizzard's row opens no tooltip there, so a row that
  owns it is only a leftover (a second `OnEnter` without an `OnLeave`, another addon's tooltip, or, if the real
  `Hide()` keeps the owner (unverified; the spec's fake does), our own hidden one). The addon always `SetOwner`s
  (which clears the lines) and rebuilds, so the block is never appended twice. Sub-header rows
  (`ReputationSubHeaderMixin` copies `OnEnter` at file load, before this hook exists) are not hooked, on either
  client, as before.
- **`GetFactionStandings` is account-wide and sorted** (highest `rank` first) in the data layer,
  so the renderer just walks the list.
- **`X-Curse-Project-ID`** — `1614342`.

**Faction-lookup spec:** `spec/factionid_spec.lua` (loader `reputations.loadCore`) loads the real `core.lua` against a fake warband and covers `FactionIDByName` (longest match, `MIN_NAME` guard, plain-text match), `FactionIDByQuery` (exact, shortest-containing, superset fallback) and `RebuildFactionIndex` (generation bump).
