# Warbandeer (Main UI)

**Deps:** LibNAddOn, LibNUI, Warbandeer_Characters · **OptionalDeps:** Warbandeer_Bars (`bars` view), Warbandeer_Collected (`collected` view), ShadowsOfUI-Upgrade (gear-upgrade markers) · **SavedVars:** `WarbandeerDB` (v3) · **Commands:** `/warband`, `/wb` (+ one per view) · **Reads:** `WarbandeerApi`, `WarbandeerBarsApi`, `WarbandeerCollectedApi`, `ShadowsOfUI_UpgradeApi` · **UI:** LibNUI

Main viewer UI. Reads the data layer (`ns.api` ← `WarbandeerApi`) and renders it across a set of views switched from a left icon rail.

## Files

| File | Purpose |
|---|---|
| `init.lua` | Addon init (assignment form) + `ns:RegisterSettings` (`defaultView`, `tooltipSide`). Defines `ns.views`, `ns.viewOrder` (nav order), class/race arrays, `MigrateDB`, `onLoad` |
| `data.lua` | `ns.data` — ilvl/gear-tier color helpers (`IlvlColor`, `IlvlColorObj`), faction color/standing override tables, profession-intent helpers (`GetProfIntent`/`SetProfIntent`, `GetMainCrafter`, `GetProfToons`, `FindProf`, `EstimateConcentration`) |
| `theme.lua` | `ns.theme` — a LibNUI `ui.Theme` ("void-dark"): `colors` + `fonts` (`{path,size}` tuples). Passed on MainWindow, so every widget in the window inherits it; `window`/`border`/`divider`/`text`/`muted`/`header` and fonts `title`/`body` override the LibNUI dark defaults, the rest (`module`, `hover`, `gold`, …) are Warbandeer-specific tokens |
| `media/fonts/` | Bundled fonts (Hanken Grotesk, Geist, JetBrains Mono) + licenses; loaded by path, not listed in `.toc` |
| `controls/CharacterTooltip.lua` | `ns.CharacterTooltip` + `ns.ShowCharacterTooltip`/`HideCharacterTooltip`; side-aware anchoring via `ns.TooltipSide()` / `ns.AnchorTip(frame)`. Registered on `ns`, not `ui` |
| `controls/ItemTooltip.lua` | `ns.ShowItemTooltip(frame, link)` / `ns.HideItemTooltip()` — shared private `WarbandeerItemTooltip` (GameTooltipTemplate) reskinned (`styleTooltip` → flat black + theme border via `NineSlice`) that `:SetHyperlink`s an item link; no auto-comparison. Used by Detail + Gear gear cells; anchor side per `ns.TooltipSide()` |
| `controls/StatCard.lua` | `ns.StatCard` — summary tile (caption + big mono `amount`, optional `sub` + trend `subIcon`). `Amount(text, color?)` |
| `controls/IconStrip.lua` | `ns.IconStrip` — floating left nav rail, one tinted glyph per view; `onSelect(name)`, `SetActive(name)` |
| `controls/UpgradeMark.lua` | `ns.UpgradeMark(charName, slot)` → cell-text ▲ glyph (green held / gold better-in-warband) and `ns.UpgradeTip(charName, slot)` → hover line, both via `ShadowsOfUI_UpgradeApi` (OptionalDep); no-op "" / nil when that addon is absent |
| `controls/FilterDropdown.lua` | `ns.FilterDropdown` — reusable labelled dropdown filter. `options`/`selected`/`onSelect`; `Select(key)` re-points label without firing |
| `controls/LabeledBar.lua` | `ns.LabeledBar` — progress row (name + value + bar beneath). Setters `Fill`/`Label`/`Value`/`BarColor`; optional `onClick`, `hoverValue`/`hoverColor` |
| `media/bar-rounded.tga` | 16×16 white rounded-rect, nine-sliced as the `LabeledBar` bar texture; tinted at runtime |
| `icons/views/*.tga` | White per-view glyphs (+ `logo.tga`) tinted in-game by `IconStrip` |
| `icons/trending_{up,down}.tga` | White up/down trend arrows for the Overview weekly-gold card |
| `icons/*.tga` | White 64×64 glyphs for Summary column headers (`crest_hero`, `crest_myth`, `catalyst`, …), tinted muted in-game |
| `views/Overview.lua` | Stat strip + Reputations / Achievements / Top Characters modules; expansion `BuildFilter`. Rep bars via `FactionBars` (see below); rows click through to Detail |
| `views/SummaryColumns.lua` | `SummaryColumn` specs (`getData`/`getFooter` per column) + `SummaryColumnsDelayed()` (appends the DMF column while the faire is open) |
| `views/summaryCol/*.lua` | One file per Summary column: faction, role, character, level, ilvl, upgrades, profs, bags, vault, keystone, crests, catalyst, voidcore, delves, lumber, cofferKey, caches, rested, played, gold. `upgrades.lua` (the "Up" count column) early-returns unless `ShadowsOfUI_UpgradeApi` exists, so its column is only registered when ShadowsOfUI-Upgrade is loaded |
| `views/SummaryView.lua` | Dual `ClassSummary` tables (Alliance/Horde) toggled by a faction `BuildFilter`; cells drive row hover + click-to-Detail |
| `views/GearView.lua` | Four armor-type tables toggled by `BuildFilter` buttons; per-equipment-slot ilvl + upgrade-track columns. Each slot cell hovers to the shared item tooltip (`ns.ShowItemTooltip`) and appends `ns.UpgradeMark(toon.name, slot)` (the ▲ available-upgrade glyph) |
| `views/DetailView.lua` | Single-character detail: portrait, stat strip, per-profession intent panels (each followed by that profession's equipped tool/accessory list), equipped-gear list. Gear + prof-gear rows highlight and show the shared item tooltip on hover (`attachItemTip` → row `hover` tint + `ns.ShowItemTooltip(frame, item.link)`; see `controls/ItemTooltip.lua`); equipped-gear rows append `ns.UpgradeMark` to the item name. Character-picker `BuildFilter`; `Select(toon)` switches subject; `OnNavigate()` resets to the logged-in character |
| `views/RoleView.lua` | `ClassTable` per class, grouped by spec |
| `views/RaceView.lua` | 13×29 class/race grid (dynamic build), one character per cell; hover + click-to-Detail |
| `views/Legion.lua` | Hidden artifact appearances + Legion achievements |
| `views/Midnight.lua` | Midnight achievement grid |
| `views/ProfsView.lua` | Best-skill-per-expansion grid + per-character detail panel |
| `views/MidnightProfs.lua` | Profs × characters grid: Midnight skill + concentration |
| `views/CraftingView.lua` | Crafting profs: main crafter, concentration, learned-recipe %; expansion `BuildFilter` |
| `views/PlaytimeView.lua` | Per-character playtime breakdown |
| `views/BarsView.lua` | Action-bar profile browser (class/spec filters + result list); needs `WarbandeerBarsApi` (OptionalDep) |
| `views/BarsPreview.lua` | `ns.BarsPreviewFrame` — companion box docked right of the window rendering a profile's bars (icons, keybinds, Edit Mode layout) |
| `views/BarsApply.lua` | `ns.BarsApplyFrame` — companion box below the main window: per-bar muted/red toggles (1-8 / C1-C5 / Bonus, Sky, Pet) + Apply button → `WarbandeerBarsApi:Restore` with a `barFilter` |
| `views/CollectedView.lua` | Transmog-set collection grid (class × set-group, red→green uncollected counts + green checks) backed by `WarbandeerCollectedApi` (OptionalDep); local `Grid` TableFrame inside a capped `ScrollFrame`, cell hover → the shared per-slot source InfoTip via `WarbandeerCollectedApi:ShowInfoTip`/`HideInfoTip` (same tooltip as `/collected`, including its **Preview model** button → the shared 3D dressing room — inherited for free since the InfoTip is one shared singleton), anchored on the configured side via `tipPosition` (`ns.TooltipSide()`); `BuildFilter` titlebar toggle flips row order (oldest/newest first, in-place re-sort via `grid._reverse`). No lockout columns/panel — those stay in Collected's own window |
| `window.lua` | `MainWindow` (TitleFrame) + `IconStrip` rail; `ns:Open()`, `ns:view(name)`; `Fit()` grows the window down/right |
| `commands.lua` | Registers the base open command + one per view (from `ns.views`) |

## Views

| name | _title | Parent | Key feature | `BuildFilter` |
|---|---|---|---|---|
| `overview` | Overview | Frame | Stat strip, reputations, achievements, top characters | expansion dropdown |
| `summary` | Summary | Frame | Dual ClassSummary tables (Alliance/Horde) | faction toggle |
| `detail` | Detail | Frame | Per-character detail + profession-intent editor + per-profession gear list | character picker |
| `gear` | Gear | Frame | 4 armor-type tables, per-slot columns | armor-type buttons |
| `roles` | Roles | Frame | ClassTable per class, grouped by spec | — |
| `races` | Races | TableFrame | 13×29 grid, one character per cell | — |
| `profs` | Professions | Frame | Profession skill grid + detail panel | — |
| `crafting` | Crafting | Frame | Main crafter, concentration, recipe % | expansion dropdown |
| `midnight` | Midnight | Frame | Achievement grid | — |
| `legion` | Legion | Frame | Hidden artifacts + achievements | — |
| `playtime` | Playtime | Frame | Per-character playtime | — |
| `midnightprofs` | Midnight Profs | Frame | Profs × characters: skill + concentration | — |
| `bars` | Bars | Frame | Bar-profile browser + docked preview & apply panels | — (view-local dropdowns) |
| `collected` | Collected | Frame | Transmog-set collection grid (class × set-group) backed by `WarbandeerCollectedApi` | raid-order toggle (oldest/newest first) |

`BuildFilter(parent)` widgets show in the title bar only while that view is active. The two
expansion dropdowns share `ns.FilterDropdown`; the faction toggle, character picker, and
armor-type strip are view-local.

## MainWindow

Subclasses `TitleFrame`; `special=true`, `level=600`, `theme = ns.theme` (inherited by all window widgets; table headers default to the theme's muted `header` token, so views no longer set header colors explicitly).
- **Views are constructed lazily**: `MainWindow:getView(name)` builds a view (and wires its `BuildFilter`) on first navigation; only the default view is built when the window opens. The nav rail therefore reads **class-level** metadata — every view class sets `name`, `_title` (and optionally `_iconRotation`) as class fields after `Class(...)`, not (only) in defaults. Row-click cross-navigation must go through `w:getView("detail")`, never `w.views.detail` (may not exist yet).
- `self.iconStrip` — `IconStrip` rail docked just left of the window, one glyph per view in `ns.viewOrder` order (unlisted views appended, sorted by title). Clicking a glyph calls the view's `OnNavigate()` (if defined) then `self:view(name)`.
- `MainWindow:view(name)` — hides current, shows named (building it if needed), updates title+size, calls `iconStrip:SetActive(name)`.
- Window is anchored by a single **TOPLEFT** point (stored in `db.settings.windowPos`) so view changes grow it down/right instead of re-centering. `SavePosition`/`RestorePosition` persist/apply it; titlebar drag saves on release.
- `ns:Open()` lazy-creates the window; `ns:view(name)` = `Open()` then `OnNavigate()` (if the view defines it) then `view(name)`. Both the icon rail and slash commands count as *direct navigation* and fire `OnNavigate`; row-click paths (`w:getView("detail"):Select(toon)` + `w:view("detail")`) call `MainWindow:view` directly and skip it, so the clicked character stays selected.

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

- **Cold-session FontString rasterization glitch.** On the first UI load of a client session (not after `/reload`), cell FontStrings in the Overview's two TableFrames can render blank even though text/size/visibility/font all report correct via the API. A same-params `SetFont`/`SetText` is a client no-op and does NOT heal it; only a *real* font change does. Fix: `healCellFonts` in `Overview.lua` swaps each cell label's font away (FrizQT) and back one tick after construction (`ns:after`). The `/wb cells [heal]` diagnostic in `commands.lua` can probe/heal live if it recurs elsewhere.

- **Don't pass `ns.theme` to free-floating CleanFrames** (e.g. `CharacterTooltip`, parented to UIParent). The theme's `window` token is **alpha 0** — views layer it over the MainWindow surface — so a standalone frame using it as its CleanFrame background turns transparent. MainWindow itself keeps an explicit opaque `background` for the same reason.
- **Decorated table cells must be shallow-copied.** Several `getData` fns return shared table objects (e.g. `faction.lua` → `ns.icons.AllianceLight`); decorating in place chains hover/click wrappers across every row sharing the object and corrupts it globally. SummaryView/GearView/RaceView copy each cell before wrapping.
- **Row hover/click is cell-driven, not row-driven.** Data cells are mouse-interactive for their per-column tooltips, so a mouse-enabled row would steal those events. `decorateRow` chains onto each cell's `onEnter`/`onLeave`/`onClick`.
- **`LabeledBar` frame height comes from the body font size, not `nameLabel:GetHeight()`** — a FontString reports `GetHeight()==0` until laid out a frame later, leaving the frame too short to cover/receive mouse over the bar.
- **`LabeledBar` hover lightens its own fill+track** in addition to the row `highlight` backing, because the opaque bar (a child frame) occludes the highlight overlay.
- **Faction "done" ≠ `IsFactionParagon`.** Paragon caches exist from the start of Midnight factions. Use `renownLevel == maxLevel` (major) / `reaction >= 8` (standard); only consult paragon *after* max. `GetMajorFactionData`/`GetMajorFactionRenownInfo` return nil for Valeera (2744) despite `IsMajorFaction` — use `GetFriendshipReputation`. Some standard reps (e.g. Slayer's 2770) expose a dummy `friendshipFactionID` with `maxLevel == 1` — guard with `maxLevel > 1`.
- **Dynamic tables need explicit final width/height** — `addCol`/`addRow` accumulate only column/row spans, not header offsets (RaceView, RoleView).
- **Icon TGAs are white and tinted in-game**, rasterized from `@material-symbols/svg-400` (32-bit, descriptor 0x08, matching `bar-rounded.tga`) — see the design repo `iconbuild/`. Regenerate there to add view glyphs.
