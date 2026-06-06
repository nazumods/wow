# Warbandeer (Main UI)

## TOC
```
Interface: 120001, Dependencies: LibNAddOn, LibNUI, Warbandeer_Characters
SavedVariables: WarbandeerDB (version 2)
X-NUI-COMMANDS: /warband, /wb
X-NUI-COMPARTMENT: Warbandeer_OnAddonCompartmentClick
X-NUI-API: WarbandeerApi, X-NUI-UI: LibNUI
```

## Files

| File | Purpose |
|---|---|
| `init.lua` | Table form init with settings (defaultView dropdown). Defines `ns.views`, `ns.viewOrder` (selector order), class/race arrays, `MigrateDB`, `onLoad` |
| `data.lua` | `ns.data` — `gearTiers`, `IlvlColor()` (wrapped string), `IlvlColorObj()` (ColorMixin), `minorFactions`, `minorFactionMaxStanding`, `factionColors` (`{[id]={r,g,b}}` bar-color overrides for factions the API gives no color for — Delves/Prey/minor factions/Slayer's/Valeera; palette matches the Plumber addon). Midnight entries: Delves→Valeera (2742→2744, friendship rep), Silvermoon Court subfactions (2710→2711-2714). Profession helpers: `EstimateConcentration`, `FindProf`, `GetProfIntent`, `SetProfIntent`, `GetProfToons`, `GetMainCrafter` |
| `theme.lua` | `ns.theme` — "Aetheric Glass" Void-Dark design tokens. `colors` (window/module/hover/track/border/text/muted/gold/orange/green/red) and `fonts` (`fontInfo` {path,size} tuples). Fonts are **bundled** in `media/fonts/`: Hanken Grotesk (headline/title), Geist (body), JetBrains Mono (caps/stat/statBig). No real backdrop blur in WoW → translucent dark surfaces approximate the glassmorphism mockup |
| `media/fonts/` | Bundled OFL/Apache fonts + license files: HankenGrotesk-{SemiBold,Bold}, Geist-Regular, JetBrainsMono-{SemiBold,Bold}. Referenced by `theme.fonts`; not in the `.toc` (loaded by path at runtime) |
| `controls/CharacterTooltip.lua` | `ns.CharacterTooltip` class + `ns.ShowCharacterTooltip`/`ns.HideCharacterTooltip` (richer name/spec/class/realm/level tooltip). Registered on `ns`, NOT `ui` — addon-local controls must not pollute the shared LibNUI global (LibNUI has its own simpler `ui.ShowCharacterTooltip` via `ui.tip`) |
| `controls/StatCard.lua` | `ns.StatCard` — summary tile: caps caption + big mono `amount` (+ optional `sub`), glass-module background. `Amount(text, color?)` setter |
| `controls/FilterDropdown.lua` | `ns.FilterDropdown` — reusable titlebar filter: a labelled `Button` that drops a `Tooltip` menu of `{ key, label, enabled? }` options. Disabled options render greyed/unselectable; picking one updates the button label and fires `onSelect(self, key)`. Shared by views with a dropdown `BuildFilter` (Crafting + Overview expansion pickers). Options: `options`, `selected`, `onSelect`, `width` (96), `menuWidth` (120). `labelFor(key)` resolves an option's display text |
| `controls/LabeledBar.lua` | `ns.LabeledBar` — progress row: name (left) + value (right) + thin bar beneath. Fill is a manually-sized texture over a track (ExpBar pattern, not StatusBar:SetValue). Flat color comes from tinting (`SetVertexColor` with `barColor`/`trackColor`) a white **rounded** texture (`media/bar-rounded.tga`) **nine-sliced** (margin `sliceMargin`==corner radius; `barHeight = 2*sliceMargin` → pill ends at any width). An atlas may be supplied via `barAtlas`/`trackAtlas` instead (skips slicing). Whole row brightens on hover (`highlight` texture + `SetMouseMotionEnabled`); `hoverValue`/`hoverColor` swap the value text on hover (paragon numbers). `Fill(pct)` setter |
| `media/bar-rounded.tga` | 16×16 white rounded-rect (4px radius), nine-sliced as the bar texture in `LabeledBar`. Regenerable; tinted at runtime via vertex color |
| `views/Overview.lua` | Aetheric-Glass overview. Top: 3-card stat strip (Warband Wealth / Playtime / Top Item Level — no M+ rating broker exists yet). Below: three glass-module boxes side by side — **Reputations**, **Achievements**, and `TopAlts` (Top Characters) (beside where the phase-2 detail card will sit), each a box-gap (`GAP*2`) apart. Expansion is chosen via a **titlebar `FilterDropdown`** (`BuildFilter`, options Midnight/WWI from the `EXPANSIONS` table): each expansion builds its own hidden panel once (reps left + achievements right, via `buildTab`), and `selectExpansion(key)` shows the matching panel while resizing the two shared module backgrounds (`_modReps`/`_modAch`, sized to that expansion's section heights) + the view (window refits via `parent:Fit()`). `TopAlts` rows are transparent at rest and brighten (`theme.colors.hover`) on mouse-over via per-row `SetMouseMotionEnabled` + OnEnter/OnLeave. `LabeledBar` rep rows brighten the same way; `Achievements` rows brighten via each cell's `onEnter`/`onLeave` (the captured row's backdrop), making the click-to-open affordance obvious. `FactionBars` renders reputations as `LabeledBar` progress bars (replaces the old `Factions` table). Bar **fill = faction color** (`info.factionFontColor.color`, via `rgbaOf`). `gatherFactions` derives name/value/pct across three subfaction tiers (major renown → friendship rep Valeera → standard C_Reputation standings); `resolveProgress`/`paragonInfo` turn a maxed faction with paragon unlocked into a paragon-progress bar on a **darker-faction-color track** (so paragon reads differently from base rep grey); the value shows green **"paragon"**, swapping to the raw numbers on row hover. `Achievements` table unchanged |
| `views/SummaryColumns.lua` | `SummaryColumn` specs + `SummaryColumnsDelayed()` for DMF. Each column has `getData(toon)` for cells and optional `getFooter(toons)` for the footer cell. Footers: Character → max/levelling tally, Bag → total sub-par bags w/ split tooltip, Played → total playtime, Gold → total gold. Extra columns (Played, Gold) are appended from `views/summaryCol/*.lua` |
| `views/SummaryView.lua` | Two `ClassSummary` TableFrames (Alliance/Horde side-by-side). Footer row built via `TableFrame:setFooter` from each column's `getFooter`; a 1px divider still separates max-level from levelling rows |
| `views/GearView.lua` | `TabFrame` per armor type, 21-col TableFrame per tab |
| `views/DetailView.lua` | Single-character detail: level/race/class/realm/ilvl + per-profession intent editor. `BuildFilter` character-picker dropdown; writes `profIntent` via `ns.data.SetProfIntent` |
| `views/RoleView.lua` | `ClassTable` frames grouped by spec |
| `views/RaceView.lua` | 13-class × 29-race grid |
| `views/Legion.lua` | Hidden artifact appearances + Legion achievements |
| `views/Midnight.lua` | 54 achievement IDs in multi-column grid |
| `views/ProfsView.lua` | Top: best skill per expansion grid. Bottom: per-character detail on click |
| `views/MidnightProfs.lua` | One column per prof, one row per character: Midnight skill + concentration |
| `views/CraftingView.lua` | One row per crafting prof: Crafter (intent-based), Concentration, Learned Recipe %. Expansion-filter dropdown (Midnight wired) |
| `views/PlaytimeView.lua` | Per-character playtime breakdown |
| `views/WeeklyView.lua` | Per-character weekly content tracking |
| `window.lua` | `MainWindow` (TitleFrame), view selector, `ns:Open()`, `ns:view(name)`. Calls `view:BuildFilter(titlebar)` if defined, anchored left of close button |
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
- `self.viewSelector` (Tooltip) — lists all views in `ns.viewOrder` (unlisted views appended, sorted by title), click to switch
- `MainWindow:view(name)` — hides current, shows named, updates title+size
- `ns:Open()` — lazy-creates window on first call
- `ns:view(name)` — `Open()` then `view(name)`

## SavedVariables (`WarbandeerDB`)
```lua
{ version = 2, settings = { defaultView = integer },
  -- per-character, per-profession crafting intent (v2): "main" | "secondary" | "gatherer"
  profIntent = { [charName] = { [skillLineID] = intent } } }
```
`MigrateDB`: v1 seeds `settings.defaultView`; v2 adds `profIntent = {}` (non-destructive).
