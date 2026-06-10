# Warbandeer (Main UI)

**Deps:** LibNAddOn, LibNUI, Warbandeer_Characters · **SavedVars:** `WarbandeerDB` (v3) · **Commands:** `/warband`, `/wb` (+ one per view) · **Reads:** `WarbandeerApi` · **UI:** LibNUI

Main viewer UI. Reads the data layer (`ns.api` ← `WarbandeerApi`) and renders it across a set of views switched from a left icon rail.

## Files

| File | Purpose |
|---|---|
| `init.lua` | Addon init (table form) + settings (`defaultView`, `tooltipSide`). Defines `ns.views`, `ns.viewOrder` (nav order), class/race arrays, `MigrateDB`, `onLoad` |
| `data.lua` | `ns.data` — ilvl/gear-tier color helpers (`IlvlColor`, `IlvlColorObj`), faction color/standing override tables, profession-intent helpers (`GetProfIntent`/`SetProfIntent`, `GetMainCrafter`, `GetProfToons`, `FindProf`, `EstimateConcentration`) |
| `theme.lua` | `ns.theme` — design tokens: `colors` + `fonts` (`{path,size}` tuples) |
| `media/fonts/` | Bundled fonts (Hanken Grotesk, Geist, JetBrains Mono) + licenses; loaded by path, not listed in `.toc` |
| `controls/CharacterTooltip.lua` | `ns.CharacterTooltip` + `ns.ShowCharacterTooltip`/`HideCharacterTooltip`; side-aware anchoring via `ns.TooltipSide()` / `ns.AnchorTip(frame)`. Registered on `ns`, not `ui` |
| `controls/StatCard.lua` | `ns.StatCard` — summary tile (caption + big mono `amount`, optional `sub` + trend `subIcon`). `Amount(text, color?)` |
| `controls/IconStrip.lua` | `ns.IconStrip` — floating left nav rail, one tinted glyph per view; `onSelect(name)`, `SetActive(name)` |
| `controls/FilterDropdown.lua` | `ns.FilterDropdown` — reusable labelled dropdown filter. `options`/`selected`/`onSelect`; `Select(key)` re-points label without firing |
| `controls/LabeledBar.lua` | `ns.LabeledBar` — progress row (name + value + bar beneath). Setters `Fill`/`Label`/`Value`/`BarColor`; optional `onClick`, `hoverValue`/`hoverColor` |
| `media/bar-rounded.tga` | 16×16 white rounded-rect, nine-sliced as the `LabeledBar` bar texture; tinted at runtime |
| `icons/views/*.tga` | White per-view glyphs (+ `logo.tga`) tinted in-game by `IconStrip` |
| `icons/trending_{up,down}.tga` | White up/down trend arrows for the Overview weekly-gold card |
| `icons/*.tga` | White 64×64 glyphs for Summary column headers (`crest_hero`, `crest_myth`, `catalyst`, …), tinted muted in-game |
| `views/Overview.lua` | Stat strip + Reputations / Achievements / Top Characters modules; expansion `BuildFilter`. Rep bars via `FactionBars` (see below); rows click through to Detail |
| `views/SummaryColumns.lua` | `SummaryColumn` specs (`getData`/`getFooter` per column) + `SummaryColumnsDelayed()` (appends the DMF column while the faire is open) |
| `views/summaryCol/*.lua` | One file per Summary column: faction, role, character, level, ilvl, profs, bags, vault, keystone, crests, catalyst, delves, lumber, cofferKey, caches, rested, played, gold |
| `views/SummaryView.lua` | Dual `ClassSummary` tables (Alliance/Horde) toggled by a faction `BuildFilter`; cells drive row hover + click-to-Detail |
| `views/GearView.lua` | Four armor-type tables toggled by `BuildFilter` buttons; per-equipment-slot ilvl + upgrade-track columns |
| `views/DetailView.lua` | Single-character detail: portrait, stat strip, per-profession intent panels, gear list. Character-picker `BuildFilter`; `Select(toon)` switches subject |
| `views/RoleView.lua` | `ClassTable` per class, grouped by spec |
| `views/RaceView.lua` | 13×29 class/race grid (dynamic build), one character per cell; hover + click-to-Detail |
| `views/Legion.lua` | Hidden artifact appearances + Legion achievements |
| `views/Midnight.lua` | Midnight achievement grid |
| `views/ProfsView.lua` | Best-skill-per-expansion grid + per-character detail panel |
| `views/MidnightProfs.lua` | Profs × characters grid: Midnight skill + concentration |
| `views/CraftingView.lua` | Crafting profs: main crafter, concentration, learned-recipe %; expansion `BuildFilter` |
| `views/PlaytimeView.lua` | Per-character playtime breakdown |
| `window.lua` | `MainWindow` (TitleFrame) + `IconStrip` rail; `ns:Open()`, `ns:view(name)`; `Fit()` grows the window down/right |
| `commands.lua` | Registers the base open command + one per view (from `ns.views`) |

## Views

| name | _title | Parent | Key feature | `BuildFilter` |
|---|---|---|---|---|
| `overview` | Overview | Frame | Stat strip, reputations, achievements, top characters | expansion dropdown |
| `summary` | Summary | Frame | Dual ClassSummary tables (Alliance/Horde) | faction toggle |
| `detail` | Detail | Frame | Per-character detail + profession-intent editor | character picker |
| `gear` | Gear | Frame | 4 armor-type tables, per-slot columns | armor-type buttons |
| `roles` | Roles | Frame | ClassTable per class, grouped by spec | — |
| `races` | Races | TableFrame | 13×29 grid, one character per cell | — |
| `profs` | Professions | Frame | Profession skill grid + detail panel | — |
| `crafting` | Crafting | Frame | Main crafter, concentration, recipe % | expansion dropdown |
| `midnight` | Midnight | Frame | Achievement grid | — |
| `legion` | Legion | Frame | Hidden artifacts + achievements | — |
| `playtime` | Playtime | Frame | Per-character playtime | — |
| `midnightprofs` | Midnight Profs | Frame | Profs × characters: skill + concentration | — |

`BuildFilter(parent)` widgets show in the title bar only while that view is active. The two
expansion dropdowns share `ns.FilterDropdown`; the faction toggle, character picker, and
armor-type strip are view-local.

## MainWindow

Subclasses `TitleFrame`; `special=true`, `level=600`.
- `self.iconStrip` — `IconStrip` rail docked just left of the window, one glyph per view in `ns.viewOrder` order (unlisted views appended, sorted by title). Clicking a glyph calls `self:view(name)`.
- `MainWindow:view(name)` — hides current, shows named, updates title+size, calls `iconStrip:SetActive(name)`.
- Window is anchored by a single **TOPLEFT** point (stored in `db.settings.windowPos`) so view changes grow it down/right instead of re-centering. `SavePosition`/`RestorePosition` persist/apply it; titlebar drag saves on release.
- `ns:Open()` lazy-creates the window; `ns:view(name)` = `Open()` then `view(name)`.

## Overview — Factions Widget

`FactionBars` (Frame subclass) stacks one `LabeledBar` per major faction plus optional subfaction
rows; data built by file-local `gatherFactions`. Bar **fill = faction colour**, resolved by
`colorFor(id, apiColor, fallback)`: `ns.data.factionColors[id]` override → API `factionFontColor` →
fallback (subfaction falls back to parent). Maxed factions with paragon unlocked show **paragon
progress on a darker-faction-colour track**; the value reads green **"paragon"**, swapping to raw
`prog / threshold` on row hover (`LabeledBar.hoverValue`).

**Constructor options:** `expansionLevel` (10=TWW, 11=Midnight; passed to `GetMajorFactionIDs`),
`extraFactionIDs` (IDs the API omits, e.g. Silvermoon Court `2710`, Slayer's Duellum `2770`), `width`.

**Subfaction tiers** (tried in order): (1) `GetMajorFactionData` → renown; (2)
`GetFriendshipReputation` with `maxLevel > 1` → friendship rep (e.g. Valeera `2744`); (3)
`C_Reputation.GetFactionDataByID` → standard standing / `minorFactionMaxStanding[parentID]`.

## SavedVariables (`WarbandeerDB`)

```lua
{ version = 3,
  settings = { defaultView = int, tooltipSide = int, windowPos = { x, y } },
  -- per-character, per-profession crafting intent: "main" | "secondary" | "gatherer"
  profIntent = { [charName] = { [skillLineID] = intent } } }
```
`MigrateDB`: v1 seeds `settings.defaultView`; v2 adds `profIntent = {}`; v3 seeds `tooltipSide = 1`
(Left). All migrations are non-destructive. `windowPos` is not migrated — written lazily at runtime.

## Gotchas

- **Decorated table cells must be shallow-copied.** Several `getData` fns return shared table objects (e.g. `faction.lua` → `ns.icons.AllianceLight`); decorating in place chains hover/click wrappers across every row sharing the object and corrupts it globally. SummaryView/GearView/RaceView copy each cell before wrapping.
- **Row hover/click is cell-driven, not row-driven.** Data cells are mouse-interactive for their per-column tooltips, so a mouse-enabled row would steal those events. `decorateRow` chains onto each cell's `onEnter`/`onLeave`/`onClick`.
- **`LabeledBar` frame height comes from the body font size, not `nameLabel:GetHeight()`** — a FontString reports `GetHeight()==0` until laid out a frame later, leaving the frame too short to cover/receive mouse over the bar.
- **`LabeledBar` hover lightens its own fill+track** in addition to the row `highlight` backing, because the opaque bar (a child frame) occludes the highlight overlay.
- **Faction "done" ≠ `IsFactionParagon`.** Paragon caches exist from the start of Midnight factions. Use `renownLevel == maxLevel` (major) / `reaction >= 8` (standard); only consult paragon *after* max. `GetMajorFactionData`/`GetMajorFactionRenownInfo` return nil for Valeera (2744) despite `IsMajorFaction` — use `GetFriendshipReputation`. Some standard reps (e.g. Slayer's 2770) expose a dummy `friendshipFactionID` with `maxLevel == 1` — guard with `maxLevel > 1`.
- **Dynamic tables need explicit final width/height** — `addCol`/`addRow` accumulate only column/row spans, not header offsets (RaceView, RoleView).
- **Icon TGAs are white and tinted in-game**, rasterized from `@material-symbols/svg-400` (32-bit, descriptor 0x08, matching `bar-rounded.tga`) — see the design repo `iconbuild/`. Regenerate there to add view glyphs.
