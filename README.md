# Nazuraki's WoW AddOn Suite

A monorepo of World of Warcraft (Retail) addons by Nazuraki. The suite is built on two
shared libraries — **LibNAddOn** (addon bootstrapping) and **LibNUI** (OOP UI widgets) —
with the **Warbandeer** family providing warband-wide character tracking, plus the
**Shadows of UI** custom-UI tweaks and a handful of small quality-of-life addons.

Each addon folder has its own `README.md` with end-user documentation.

## Addons

Every addon builds on **LibNAddOn** (except the two raw-API tweaks, HideBagBar and BarNonce),
and UI addons additionally need **LibNUI**. In the tables below, the **Requires** column lists
each addon's hard dependencies — it won't load without them — and **Optional** lists addons that
unlock extra functionality when they're also installed. Each addon's own README repeats this in a
**Dependencies** section.

### Libraries

| Addon | Requires | Optional | Description |
|---|---|---|---|
| [LibNAddOn](LibNAddOn/README.md) | — | — | Bootstrapping library: addon init, events, saved-variable DB, settings panels, slash commands, Lua utilities. Required by almost everything below. |
| [LibNUI](LibNUI/README.md) | LibNAddOn | — | OOP UI widget library wrapping Blizzard frames (windows, tables, tabs, buttons, themes). |
| [LibNUI-ModelViewer](LibNUI-ModelViewer/README.md) | LibNAddOn + LibNUI | — | 3D model-viewer widget (`ui.Model`) extracted from LibNUI; only addons that show a character/transmog viewer need it. |
| [LibNUI_Test](LibNUI_Test/README.md) | LibNUI | — | Load-on-demand visual test gallery for LibNUI (`/nui test`). Developers only. |

### Warbandeer

| Addon | Requires | Optional | Description |
|---|---|---|---|
| [Warbandeer_Characters](Warbandeer_Characters/README.md) | LibNAddOn + LibNUI | — | Data layer: scans and stores every character you log into (gear, professions, gold, currencies, lockouts, playtime…). No UI. |
| [Warbandeer](Warbandeer/README.md) | LibNAddOn + LibNUI + Warbandeer_Characters | Warbandeer_Bars, Warbandeer_Collected, Warbandeer_Decor, ShadowsOfUI-Upgrade | The main viewer UI (`/wb`): 18 views over your whole warband (16 without the optional Collected and Decor addons). |
| [Warbandeer_Collected](Warbandeer_Collected/README.md) | LibNAddOn + LibNUI + LibNUI-ModelViewer + Warbandeer_Characters | — | Transmog set collection tracker (`/collected`) with wanted flags and S–F tier ranking. |
| [Warbandeer_Decor](Warbandeer_Decor/README.md) | LibNAddOn + LibNUI | — | Account-wide housing decor collection tracker (`/housingdecor`) with owned counts, filters, and wanted flags. |
| [Warbandeer_Bars](Warbandeer_Bars/README.md) | LibNAddOn | — | Headless action-bar/keybind/macro profile layer, per character + spec. |
| [Warbandeer_Alias](Warbandeer_Alias/README.md) | LibNAddOn + LibNUI | — | Prefixes your guild chat messages with an alias so guildmates recognize your alts. |

### Custom UI

| Addon | Requires | Optional | Description |
|---|---|---|---|
| [ShadowsOfUI-XP](ShadowsOfUI-XP/README.md) | LibNAddOn + LibNUI | — | Minimal full-width XP bar at the bottom of the screen (below max level only). |
| [ShadowsOfUI-GCD](ShadowsOfUI-GCD/README.md) | LibNAddOn + LibNUI | — | Slim global-cooldown sweep bar between your resource bars. |
| [ShadowsOfUI-Castbar](ShadowsOfUI-Castbar/README.md) | LibNAddOn + LibNUI | — | Three minimal, Edit Mode-placed cast bars for your target, focus target, and yourself (icon, name, time; non-interruptible casts greyed). Player bar off by default. |
| [ShadowsOfUI-DMF](ShadowsOfUI-DMF/README.md) | LibNAddOn | — | Darkmoon Faire helper: auto-buys profession quest mats and guides you between quest givers. |
| [ShadowsOfUI-Ilvl](ShadowsOfUI-Ilvl/README.md) | LibNAddOn | Baganator, Bagnon | Item level + upgrade-track badge on gear icons (bags, bank, loot, Baganator, Bagnon); inset beside each slot on the character/inspect panels. Per-place toggles. |
| [ShadowsOfUI-Known](ShadowsOfUI-Known/README.md) | LibNAddOn + Warbandeer_Characters | Warbandeer | Recipe tooltips: which alts can still learn or already know a recipe, plus which guildmates can craft it. |
| [ShadowsOfUI-Upgrade](ShadowsOfUI-Upgrade/README.md) | LibNAddOn + Warbandeer_Characters | Warbandeer, ClassCodex | Finds warband gear upgrades (bags/bank/warband bank) and shows them on item tooltips and in Warbandeer — what to keep vs sell. |
| [ShadowsOfUI-Artisan](ShadowsOfUI-Artisan/README.md) | LibNAddOn + Warbandeer_Characters | Warbandeer | Shows each profession's crafting currency (Artisan's … Moxie) — beside the Concentration readout in the crafting window and on the spellbook's Professions page — plus an account-wide hover breakdown. |
| [ShadowsOfUI-Inventory](ShadowsOfUI-Inventory/README.md) | LibNAddOn + Warbandeer_Characters | — | Adds a "Warband Inventory" block to item tooltips: how many of an item each character holds (bags + bank), plus the warband and guild banks. Hold Shift to hide. |
| [ShadowsOfUI-Reputations](ShadowsOfUI-Reputations/README.md) | LibNAddOn + Warbandeer_Characters | — | Shows every character's standing with a faction — on the Reputation tab and on faction-tied item tooltips (which alt to mail that rep token to). |
| [ShadowsOfUI-Quests](ShadowsOfUI-Quests/README.md) | LibNAddOn + Warbandeer_Characters | — | Adds a cross-alt "Also on this quest / Completed by" block to quest-log tooltips, so you can see which character still needs a quest. |
| [ShadowsOfUI-Delves](ShadowsOfUI-Delves/README.md) | LibNAddOn + LibNUI + Warbandeer_Characters | — | Times your delve runs and shows your average completion time (at Tier 11 once max level) on each delve's map entrance pin. |
| [ShadowsOfUI-Compartment](ShadowsOfUI-Compartment/README.md) | LibNAddOn + LibNUI | — | Makes the minimap's addon-compartment button movable (ALT+drag) and swaps its count for a clean icon. |
| [ShadowsOfUI-Collectibles](ShadowsOfUI-Collectibles/README.md) | LibNAddOn | Warbandeer_Characters, ShadowsOfUI-HousingVendor | Tints already-known and still-collectible items (recipes, toys, mounts, pets, decor…) on vendors and the Auction House — recipes checked across your whole warband. |
| [ShadowsOfUI-HousingVendor](ShadowsOfUI-HousingVendor/README.md) | LibNAddOn | Bagnon, Warbandeer_Decor | Overlays housing-decor icons at vendors with your in-storage owned count and a star on decor that grants a first-time House XP bonus you haven't collected yet. |
| [ShadowsOfUI-ProfCommissions](ShadowsOfUI-ProfCommissions/README.md) | LibNAddOn | — | Enhances the Crafting Orders list: shows each order's actual reward icons in place of the generic chest, and replaces the Reagents text column with at-a-glance first-craft + reagent-provision icons. |
| [ShadowsOfUI-QuestXP](ShadowsOfUI-QuestXP/README.md) | LibNAddOn | — | Shows what percentage of a level a quest's XP reward is worth, next to the XP reward in the quest log's reward pane. |
| [ShadowsOfUI-PostOffice](ShadowsOfUI-PostOffice/README.md) | LibNAddOn + LibNUI | Warbandeer_Characters | Headless mailbox helper: coin-collected reports, trade blocking, coin auto-subject, modifier-click shortcuts, Forward / copy-mail buttons on open letters, a recipient menu + autocomplete on the To: field, trade-goods quick-attach buttons, and inbox tools (per-letter return/delete icons, select checkboxes with batch open/return). |

### Quality of life

| Addon | Requires | Optional | Description |
|---|---|---|---|
| [Recycle](Recycle/README.md) | LibNAddOn + LibNUI | Baganator | Auto-sells grey items and anything you mark, whenever you visit a merchant. |
| [HideStanceBar](HideStanceBar/README.md) | LibNAddOn + LibNUI | — | Hides the stance bar, with a per-class toggle. |
| [HideBagBar](HideBagBar/README.md) | None (raw WoW API) | — | Hides the backpack and bag slot buttons. |
| [CombatOutline](CombatOutline/README.md) | LibNAddOn | — | Enables the character outline rendering mode only while in combat. |
| [MouselookToggle](MouselookToggle/README.md) | LibNAddOn | — | Toggle mouselook (steer the camera without holding right-click) with a configurable keybind. |
| [BarNonce](BarNonce/README.md) | None (raw WoW API) | — | Removes padding and dims Action Bars 1–2 to 70% opacity. |

## Installation

Released addons are published to CurseForge (per-addon — see each README). To install
from source, copy (or symlink) the addon folder into your
`World of Warcraft/_retail_/Interface/AddOns/` directory. Mind the dependencies listed
in each addon's README/.toc — most addons need LibNAddOn, and UI addons also need LibNUI.

## Contributing

Development setup, code style, testing, and release process are documented in
[CONTRIBUTING.md](CONTRIBUTING.md).
