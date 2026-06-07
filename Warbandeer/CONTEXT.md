# Warbandeer (Main UI)

## TOC
```
Interface: 120001, Dependencies: LibNAddOn, LibNUI, Warbandeer_Characters
SavedVariables: WarbandeerDB (version 3)
X-NUI-COMMANDS: /warband, /wb
X-NUI-COMPARTMENT: Warbandeer_OnAddonCompartmentClick
X-NUI-API: WarbandeerApi, X-NUI-UI: LibNUI
```

## Files

| File | Purpose |
|---|---|
| `init.lua` | Table form init with settings (defaultView dropdown, tooltipSide dropdown — `ns.TOOLTIP_SIDES` = {Left, Right}, default Left). Defines `ns.views`, `ns.viewOrder` (selector order), class/race arrays, `MigrateDB`, `onLoad` |
| `data.lua` | `ns.data` — `gearTiers`, `IlvlColor()` (wrapped string), `IlvlColorObj()` (ColorMixin), `minorFactions`, `minorFactionMaxStanding`, `factionColors` (`{[id]={r,g,b}}` bar-color overrides for factions the API gives no color for — Delves/Prey/minor factions/Slayer's/Valeera; palette matches the Plumber addon). Midnight entries: Delves→Valeera (2742→2744, friendship rep), Silvermoon Court subfactions (2710→2711-2714). Profession helpers: `EstimateConcentration`, `FindProf`, `GetProfIntent`, `SetProfIntent`, `GetProfToons`, `GetMainCrafter` |
| `theme.lua` | `ns.theme` — "Aetheric Glass" Void-Dark design tokens. `colors` (window/module/hover/track/border/text/muted/gold/orange/green/red) and `fonts` (`fontInfo` {path,size} tuples). Fonts are **bundled** in `media/fonts/`: Hanken Grotesk (headline/title), Geist (body), JetBrains Mono (caps/stat/statBig). No real backdrop blur in WoW → translucent dark surfaces approximate the glassmorphism mockup |
| `media/fonts/` | Bundled OFL/Apache fonts + license files: HankenGrotesk-{SemiBold,Bold}, Geist-Regular, JetBrainsMono-{SemiBold,Bold}. Referenced by `theme.fonts`; not in the `.toc` (loaded by path at runtime) |
| `controls/CharacterTooltip.lua` | `ns.CharacterTooltip` class + `ns.ShowCharacterTooltip`/`ns.HideCharacterTooltip` (richer name/spec/class/realm/level tooltip). Registered on `ns`, NOT `ui` — addon-local controls must not pollute the shared LibNUI global (LibNUI has its own simpler `ui.ShowCharacterTooltip` via `ui.tip`). `ShowCharacterTooltip(toon, parent[, position])` auto-anchors below the hovered cell on the side from `db.settings.tooltipSide` (1=Left→anchor TopRight, extends left; 2=Right→anchor TopLeft, extends right) via file-local `sidePosition`; an explicit `position` table overrides the setting. Also exports `ns.TooltipSide()` (the configured index, default 1) and `ns.AnchorTip(frame)` — the side-aware anchor for the shared `ui.tip` (Left→`ANCHOR_BOTTOMLEFT`, Right→`ANCHOR_BOTTOMRIGHT`), used by the summary-column cell tooltips (ilvl/profs/delves/rested) |
| `controls/StatCard.lua` | `ns.StatCard` — summary tile: caps caption + big mono `amount` (+ optional `sub`), glass-module background. `Amount(text, color?)` setter. Optional `subIcon` (texture path) + `subIconColor` draw a small glyph before the sub-line (e.g. the green/red trend arrow on the weekly gold change) |
| `controls/IconStrip.lua` | `ns.IconStrip` (CleanFrame) — floating left-docked navigation rail; replaces the old titlebar-icon dropdown selector. Brand mark (`logo.tga`) + divider on top, then one tinted glyph button per view (white TGA `icons/views/<name>.tga`, tinted muted→on-surface on hover→gold+left-accent+faint-gold-wash when active). Hover shows the view title via `ui.tip` (`ANCHOR_RIGHT`); click fires `onSelect(name)`. `SetActive(name)` highlights the current view. `clamped=false` so it stays glued to the window. Built from `{name,title}` list in `ns.viewOrder` order |
| `controls/FilterDropdown.lua` | `ns.FilterDropdown` — reusable filter: a labelled `Button` that drops a `Tooltip` menu of `{ key, label, enabled? }` options. Disabled options render greyed/unselectable; picking one updates the button label and fires `onSelect(self, key)`. Shared by views with a dropdown `BuildFilter` (Crafting + Overview expansion pickers) and as the **per-profession intent dropdown** in DetailView. Options: `options`, `selected`, `onSelect`, `width` (96), `menuWidth` (120). `labelFor(key)` resolves an option's display text; `Select(key)` re-points the dropdown (updates label) **without** firing `onSelect` — used when a pooled dropdown is reassigned to a new subject |
| `controls/LabeledBar.lua` | `ns.LabeledBar` — progress row: name (left) + value (right) + thin bar beneath. Fill is a manually-sized texture over a track (ExpBar pattern, not StatusBar:SetValue). Flat color comes from tinting (`SetVertexColor` with `barColor`/`trackColor`) a white **rounded** texture (`media/bar-rounded.tga`) **nine-sliced** (margin `sliceMargin`==corner radius; `barHeight = 2*sliceMargin` → pill ends at any width). An atlas may be supplied via `barAtlas`/`trackAtlas` instead (skips slicing). Whole row brightens on hover: `highlight` is a **rounded** (nine-sliced white `barTexture`) Background backing that wraps the entire row — text *and* bar — with a ~5px margin on every side, tinted in via `SetVertexColor` so the bar reads as enclosed rather than sitting below a band around just the label; **additionally the bar lightens its own fill+track colours** (`lighten()` blends toward white) since the bar (a child frame) occludes `highlight` and a translucent overlay barely registers on the opaque bar. `hoverValue`/`hoverColor` swap the value text on hover (paragon numbers). Optional `onClick(self, button)` enables mouse clicks (`SetMouseClickEnabled`) — e.g. DetailView opens the profession window. **The frame height + bar offset are computed from the body font size (`nameH`), not `nameLabel:Height()`** — a FontString reports `GetHeight()==0` until laid out a frame later, which previously left the frame too short to cover (or receive mouse over) the bar. Setters: `Fill(pct)`, `Label(text)`, `Value(text, color?)` (updates stored `value` so hover-restore is correct), `BarColor(color)` (used to recolor pooled bars on reuse) |
| `media/bar-rounded.tga` | 16×16 white rounded-rect (4px radius), nine-sliced as the bar texture in `LabeledBar`. Regenerable; tinted at runtime via vertex color |
| `icons/views/*.tga` | 64×64 white Material-Symbols glyphs (one per view + `logo.tga`), tinted in-game by `IconStrip`. Rasterized from `@material-symbols/svg-400` via a sharp→TGA node script (32-bit, descriptor 0x08, matches `bar-rounded.tga`) — see the design repo `iconbuild/` |
| `icons/trending_{up,down}.tga` | 64×64 white trend arrows (same pipeline); green/red trend glyph on the Overview weekly-gold StatCard sub-line |
| `views/Overview.lua` | Aetheric-Glass overview. Top: 3-card stat strip (Warband Wealth / Playtime / Top Item Level — no M+ rating broker exists yet). Below: three glass-module boxes side by side — **Reputations**, **Achievements**, and `TopAlts` (Top Characters) (beside where the phase-2 detail card will sit), each a box-gap (`GAP*2`) apart. Expansion is chosen via a **titlebar `FilterDropdown`** (`BuildFilter`, options Midnight/WWI from the `EXPANSIONS` table): each expansion builds its own hidden panel once (reps left + achievements right, via `buildTab`), and `selectExpansion(key)` shows the matching panel while resizing the two shared module backgrounds (`_modReps`/`_modAch`, sized to that expansion's section heights) + the view (window refits via `parent:Fit()`). `TopAlts` rows are transparent at rest and brighten (`theme.colors.hover`) on mouse-over via per-row `SetMouseMotionEnabled` + OnEnter/OnLeave; each row is also click-enabled (`SetMouseClickEnabled` + OnMouseUp) and **clicking a row opens that character in the Detail view** (`MainWindow.views.detail:Select(toon)` then `MainWindow:view("detail")`). The clicked toon is captured per-row via `self._toons` (populated alongside `addRow` in `GetData`). `LabeledBar` rep rows brighten the same way; `Achievements` rows brighten via each cell's `onEnter`/`onLeave` (the captured row's backdrop), making the click-to-open affordance obvious. `FactionBars` renders reputations as `LabeledBar` progress bars (replaces the old `Factions` table). Bar **fill = faction color** (`info.factionFontColor.color`, via `rgbaOf`). `gatherFactions` derives name/value/pct across three subfaction tiers (major renown → friendship rep Valeera → standard C_Reputation standings); `resolveProgress`/`paragonInfo` turn a maxed faction with paragon unlocked into a paragon-progress bar on a **darker-faction-color track** (so paragon reads differently from base rep grey); the value shows green **"paragon"**, swapping to the raw numbers on row hover. `Achievements` table unchanged |
| `views/SummaryColumns.lua` | `SummaryColumn` specs + `SummaryColumnsDelayed()` for DMF. Each column has `getData(toon)` for cells and optional `getFooter(toons)` for the footer cell. Footers: Character → max/levelling tally, Bag → total sub-par bags w/ split tooltip, Played → total playtime, Gold → total gold. Extra columns (Played, Gold) are appended from `views/summaryCol/*.lua` |
| `views/SummaryView.lua` | Aetheric-Glass restyle. Two `ClassSummary` TableFrames (Alliance/Horde) toggled by the `BuildFilter` faction button (one shown at a time; no section header — the toggle makes the faction obvious). The active table sits on a glass-module backdrop (`moduleBg` Texture, resized in `layout()`). View has the void `theme.colors.window` background. `ClassSummary` keeps cols/rows transparent so the module surface shows through: each row gets a 1px `theme.colors.divider` top line, still-levelling characters are dimmed (`backdropColor 0,0,0,0.22`), column headers are muted+uppercased via a shallow-copied `colInfo` (each entry gets `color = theme.colors.muted` and an uppercased `name`; the shared source colInfo is left untouched), and the footer uses `theme.colors.moduleHi`. Footer row built via `TableFrame:setFooter` from each column's `getFooter`. **Row hover + click** is cell-driven (not row-driven — data cells are mouse-interactive for their per-column tooltips, so a mouse-enabled row would steal those events): `decorateRow(cells, i)` (called when building `self.data` in the constructor + `OnBeforeShow`) wraps every cell's `onEnter`/`onLeave`/`onClick` to also brighten the row to `theme.colors.hover` / restore its resting tone / open that character in the Detail view (`w.views.detail:Select(toon)` then `w:view("detail")`), chaining onto any existing handlers so tooltips survive. Each decorated cell is a **shallow copy** of the source data — several `getData` fns return shared table objects (e.g. `faction.lua` → `ns.icons.AllianceLight`), so decorating in place would chain wrappers across every row sharing the object (hovering one highlights many) and corrupt the shared table globally. Plain string cells become `{text=...}`; row + toon resolve live via `self.rows[i]` / `self._toons[i]`. `layout()` sizes the module bg + view to the active table; re-run on toggle and in `OnBeforeShow`. **Faction toggle** (`BuildFilter` + `updateFilter`): a bordered button showing the current faction's icon (`ns.icons.AllianceLight`/`HordeLight`) + name, tinted blue (Alliance) / red (Horde) via `FACTION_COLOR`, with a matching 1px border (faction-colour Texture + dark inset interior). Click flips faction; `updateFilter` re-points icon/name/accent |
| `views/GearView.lua` | `TabFrame` per armor type, 21-col TableFrame per tab |
| `views/DetailView.lua` | Aetheric-Glass single-character detail. **Two columns.** Left: class-icon **portrait** (class-colored border + level badge) beside name (class color) / race+class subtitle / realm; below, a 2-card stat strip (**Item Level** via `ns.IlvlColorObj`, **Playtime** hrs — no per-char M+ rating exists); then a `PROFESSIONS` caps header and one **module panel per flexible profession** (`primary`/`secondary`): prof icon + `LabeledBar` (skill/maxSkill fill) + `FilterDropdown` intent picker. Bar fill is tinted **by intent** (`INTENT_COLOR`: main→orange, secondary→gold, gatherer→green, unset→track) and recolored live on pick. Prof rows are pooled (`_profRow`); reuse updates via `LabeledBar:Label/Value/Fill/BarColor` + `FilterDropdown:Select`. Dropdown `onSelect` writes `profIntent` via `ns.data.SetProfIntent`. The bar's `onClick` calls `C_TradeSkillUI.OpenTradeSkill(row._skillID)` to open that profession's window (no-op for alts you're not logged into). Right column: a `GEAR` module panel listing one **pooled gear row** (`_gearRow`/`_showGear`) per equipped slot in `GEAR_SLOTS` order (mirrors GearView, shirt/tabard skipped) — a left **slot icon** (`transmog-nav-slot-<slot>` atlas via `GEAR_SLOT_ATLAS`; non-transmoggable slots Neck/Finger/Trinket have no such atlas so the icon is hidden but its column width `GEAR_LEAD_W` is still reserved to keep names aligned), then item **name** colored by **rarity** (`rarityColor` parses the color prefix off the stored `item.link` — modern `|cnIQ<n>:` quality-name form via `ITEM_QUALITY_COLORS`, or legacy `|cffRRGGBB` hex; cache-independent), right-aligned **ilvl** (`ns.IlvlColorObj` quality color) + **upgrade-track badge** (`track:sub(1,1)..trackLevel`, e.g. `C6`, gold; blank if untracked) from `char.equipment.slots[slot]`. The **name column autosizes**: each row's `name:StringWidth()` is measured, the max clamped to `GEAR_NAME_MIN..GEAR_NAME_MAX`, then rows/panel/view widths are set to fit (name `Label` uses `wordWrap=false` so it still ellipsizes past the max). `OnBeforeShow` sizes the view to `max(leftColH, rightColH)` and sets its width dynamically. `BuildFilter` = class-colored character-picker dropdown (view-local Button+Tooltip, not FilterDropdown, for per-line class colors + scroll). `Select(toon)` switches the displayed character (used by the picker and by clicking a Top Characters row on the Overview) — updates the picker label, calls `OnBeforeShow`, refits |
| `views/RoleView.lua` | `ClassTable` frames grouped by spec |
| `views/RaceView.lua` | 13-class × 29-race grid |
| `views/Legion.lua` | Hidden artifact appearances + Legion achievements |
| `views/Midnight.lua` | 54 achievement IDs in multi-column grid |
| `views/ProfsView.lua` | Top: best skill per expansion grid. Bottom: per-character detail on click |
| `views/MidnightProfs.lua` | One column per prof, one row per character: Midnight skill + concentration |
| `views/CraftingView.lua` | One row per crafting prof: Crafter (intent-based), Concentration, Learned Recipe %. Expansion-filter dropdown (Midnight wired) |
| `views/PlaytimeView.lua` | Per-character playtime breakdown |
| `views/WeeklyView.lua` | Per-character weekly content tracking |
| `window.lua` | `MainWindow` (TitleFrame), `self.iconStrip` (IconStrip nav rail, replaces the old dropdown), `ns:Open()`, `ns:view(name)`. Calls `view:BuildFilter(titlebar)` if defined, anchored left of close button. `Fit()` re-pins the window's TOPLEFT corner so view switches grow down/right, never re-center |
| `commands.lua` | Registers base `""` (open) + one command per view |

## Views

| name | _title | Parent Class | Key Feature |
|---|---|---|---|
| `overview` | Overview | Frame | TopAlts, Factions, Achievements; `BuildFilter` expansion dropdown |
| `summary` | Summary | Frame | Dual ClassSummary tables (Alliance/Horde) |
| `gear` | Gear | TabFrame | 4 armor-type tabs, 16 equipment slot columns |
| `detail` | Detail | Frame | Per-character detail + profession intent editor; `BuildFilter` character picker |
| `roles` | Roles | Frame | ClassTable per class, grouped by spec |
| `races` | Races | TableFrame | 13×29 grid |
| `legion` | Legion | Frame | Hidden artifacts + achievements |
| `midnight` | Midnight | Frame | Achievement grid |
| `profs` | Professions | Frame | Profession skill grid + detail panel |
| `midnightprofs` | Midnight Profs | Frame | Profs × characters grid: Midnight skill + concentration |
| `crafting` | Crafting | Frame | Crafting profs: main crafter, concentration, learned recipe %; `BuildFilter` expansion dropdown |
| `playtime` | Playtime | Frame | Per-character playtime |
| `weekly` | Weekly | Frame | Per-character weekly content |

Views with a `BuildFilter(parent)` method get a filter widget in the title bar (shown only
while that view is active): `summary` (faction toggle), `crafting` (expansion dropdown),
`overview` (expansion dropdown), `detail` (character picker). The two expansion dropdowns
share the reusable `ns.FilterDropdown` control; the faction toggle and character picker are
view-local.

## Overview — Factions Widget

`FactionBars` (Frame subclass; replaced the old `Factions` TableFrame) stacks one `LabeledBar`
per major faction plus optional subfaction rows. Data is built by the file-local `gatherFactions`
(not a class). Bar **fill colour = the faction colour**, resolved by `colorFor(id, apiColor, fallback)`:
`ns.data.factionColors[id]` override → API `factionFontColor.color` → fallback (a subfaction
falls back to its parent's colour). Maxed
factions with paragon unlocked show **paragon progress on a darker-faction-colour track** instead
of the grey base-rep track (`paragonInfo` + `resolveProgress`). A paragon row's value reads
**"paragon"** in green (like "complete"); hovering the row swaps it to the raw `prog / threshold`
numbers (`LabeledBar.hoverValue`).

**Constructor options (`FactionBars`):**
- `expansionLevel` — passed to `C_MajorFactions.GetMajorFactionIDs()`; `10` = TWW, `11` = Midnight
- `extraFactionIDs` — additional IDs to always include, deduped against the API list (used for Midnight factions not returned by the API: Silvermoon Court `2710`, Slayer's Duellum `2770`)
- `width` — bar/row width

**Subfaction rendering tiers** (tried in order):
1. `C_MajorFactions.GetMajorFactionData(id)` returns `renownLevel` → standard major faction renown display
2. `C_GossipInfo.GetFriendshipReputation(id)` returns `friendshipFactionID > 0` → friendship reputation, shows `currentLevel / maxLevel` from `GetFriendshipReputationRanks` (e.g. Valeera 2744, levels 1–60)
3. Fallback → `C_Reputation.GetFactionDataByID`, shows `currentStanding / minorFactionMaxStanding[parentID]` (e.g. Silvermoon Court subfactions 2711–2714)

**Midnight faction IDs (expansion 11):**
- `GetMajorFactionIDs(11)` returns 7 IDs: 4 zone factions, Delves `2742`, Prey `2764`, Ritual `2792`
- `2710` Silvermoon Court — not in `GetMajorFactionIDs`; added via `extraFactionIDs`. Subfactions: Magisters `2711`, Blood Knights `2712`, Farstriders `2713`, Shades of the Row `2714` (standard rep, max standing 42000)
- `2742` Delves S1 — in `GetMajorFactionIDs`. Subfaction: Valeera `2744` (friendship rep, `GetMajorFactionData` returns nil for 2744)
- `2770` Slayer's Duellum — not in `GetMajorFactionIDs`; added via `extraFactionIDs`

**API pitfalls:**
- `C_MajorFactions.GetMajorFactionData` and `GetMajorFactionRenownInfo` both return nil for Valeera (2744) even though `C_Reputation.IsMajorFaction(2744)` is true. Use `C_GossipInfo.GetFriendshipReputation` instead.
- `C_Reputation.IsFactionParagon` returns true for many in-progress Midnight factions because paragon caches exist from the start. Do NOT use it to determine if a faction is "done" — use `renownLevel == maxLevel` for major factions and `reaction >= 8` for standard reputation subfactions. `gatherFactions` only consults paragon (`IsFactionParagon` + `GetFactionParagonInfo`) **after** a faction is already at max (`resolveProgress`), so the cache-from-start behaviour is harmless. Paragon `currentValue` accumulates past `threshold` (one bag per multiple); show `currentValue % threshold`, and treat `hasRewardPending` with `prog == 0` as a full bar.
- Some standard reputation subfactions (e.g. Slayer's Duellum 2770) have a `friendshipFactionID` but with `maxLevel = 1` (dummy/uninitialized). Guard with `rankInfo.maxLevel > 1` before treating as a real friendship rep.

## MainWindow

Subclasses `TitleFrame`, `special=true`, `level=600`.
- `self.iconStrip` (IconStrip) — floating icon rail docked just left of the window (`TopRight`→window `TopLeft`, -8px). One glyph per view in `ns.viewOrder` order (unlisted views appended, sorted by title). Replaces the removed titlebar-icon dropdown (`viewSelector`). Clicking a glyph calls `self:view(name)`
- `MainWindow:view(name)` — hides current, shows named, updates title+size, calls `iconStrip:SetActive(name)`
- `MainWindow:SavePosition()` / `RestorePosition()` — window is anchored by a single **TOPLEFT** point relative to UIParent (stored in `db.settings.windowPos = {x, y}`) so view changes grow it down/right instead of re-centering. `RestorePosition` (called at end of construction) applies the stored anchor; with none, `SavePosition` freezes the construction-time computed-center into a TOPLEFT anchor and records it. The titlebar drag (`OnMouseUp`) calls `SavePosition` to persist after a move.
- `ns:Open()` — lazy-creates window on first call
- `ns:view(name)` — `Open()` then `view(name)`

## SavedVariables (`WarbandeerDB`)
```lua
{ version = 3, settings = { defaultView = integer, tooltipSide = integer, windowPos = { x = number, y = number } },
  -- per-character, per-profession crafting intent (v2): "main" | "secondary" | "gatherer"
  profIntent = { [charName] = { [skillLineID] = intent } } }
```
`MigrateDB`: v1 seeds `settings.defaultView`; v2 adds `profIntent = {}` (non-destructive); v3 seeds `settings.tooltipSide = 1` (Left). `settings.windowPos` is not migrated — it is written lazily at runtime by `MainWindow:SavePosition` (first window open / drag).
