# Nazuraki's WoW AddOn Suite

A monorepo of World of Warcraft (Retail) addons by Nazuraki. The suite is built on two
shared libraries — **LibNAddOn** (addon bootstrapping) and **LibNUI** (OOP UI widgets) —
with the **Warbandeer** family providing warband-wide character tracking, plus the
**Shadows of UI** custom-UI tweaks and a handful of small quality-of-life addons.

Each addon folder has its own `README.md` with end-user documentation.

## Addons

### Libraries

| Addon | Description |
|---|---|
| [LibNAddOn](LibNAddOn/README.md) | Bootstrapping library: addon init, events, saved-variable DB, settings panels, slash commands, Lua utilities. Required by almost everything below. |
| [LibNUI](LibNUI/README.md) | OOP UI widget library wrapping Blizzard frames (windows, tables, tabs, buttons, themes). |
| [LibNUI_Test](LibNUI_Test/README.md) | Load-on-demand visual test gallery for LibNUI (`/nui test`). Developers only. |

### Warbandeer

| Addon | Description |
|---|---|
| [Warbandeer_Characters](Warbandeer_Characters/README.md) | Data layer: scans and stores every character you log into (gear, professions, gold, currencies, lockouts, playtime…). No UI. |
| [Warbandeer](Warbandeer/README.md) | The main viewer UI (`/wb`): 13 views over your whole warband. |
| [Warbandeer_Collected](Warbandeer_Collected/README.md) | Transmog set collection tracker (`/collected`) with wanted flags and S–F tier ranking. |
| [Warbandeer_Bars](Warbandeer_Bars/README.md) | Headless action-bar/keybind/macro profile layer, per character + spec. |
| [Warbandeer_Alias](Warbandeer_Alias/README.md) | Prefixes your guild chat messages with an alias so guildmates recognize your alts. |

### Custom UI

| Addon | Description |
|---|---|
| [ShadowsOfUI-XP](ShadowsOfUI-XP/README.md) | Minimal full-width XP bar at the bottom of the screen (below max level only). |
| [ShadowsOfUI-GCD](ShadowsOfUI-GCD/README.md) | Slim global-cooldown sweep bar between your resource bars. |
| [ShadowsOfUI-Castbar](ShadowsOfUI-Castbar/README.md) | Three minimal, Edit Mode-placed cast bars for your target, focus target, and yourself (icon, name, time; non-interruptible casts greyed). Player bar off by default. |
| [ShadowsOfUI-DMF](ShadowsOfUI-DMF/README.md) | Darkmoon Faire helper: auto-buys profession quest mats and guides you between quest givers. |
| [ShadowsOfUI-Ilvl](ShadowsOfUI-Ilvl/README.md) | Item level + upgrade-track badge on gear icons (bags, bank, loot, Baganator, Bagnon); inset beside each slot on the character/inspect panels. Per-place toggles. |
| [ShadowsOfUI-Known](ShadowsOfUI-Known/README.md) | Adds a "Learnable by:" line to recipe tooltips, listing the alts that can still learn it. |
| [ShadowsOfUI-Upgrade](ShadowsOfUI-Upgrade/README.md) | Finds warband gear upgrades (bags/bank/warband bank) and shows them on item tooltips and in Warbandeer — what to keep vs sell. |
| [ShadowsOfUI-Artisan](ShadowsOfUI-Artisan/README.md) | Shows each profession's crafting currency (Artisan's … Moxie) — beside the Concentration readout in the crafting window and on the spellbook's Professions page — plus an account-wide hover breakdown. |
| [ShadowsOfUI-WarbandInventory](ShadowsOfUI-WarbandInventory/README.md) | Adds a "Warband Inventory" block to item tooltips: how many of an item each character holds (bags + bank), plus the warband and guild banks. Hold Shift to hide. |
| [ShadowsOfUI-Reputations](ShadowsOfUI-Reputations/README.md) | Shows every character's standing with a faction — on the Reputation tab and on faction-tied item tooltips (which alt to mail that rep token to). |
| [ShadowsOfUI-Quests](ShadowsOfUI-Quests/README.md) | Adds a cross-alt "Also on this quest / Completed by" block to quest-log tooltips, so you can see which character still needs a quest. |
| [ShadowsOfUI-Delves](ShadowsOfUI-Delves/README.md) | Times your delve runs and shows your average completion time (at Tier 11 once max level) on each delve's map entrance pin. |
| [ShadowsOfUI-Compartment](ShadowsOfUI-Compartment/README.md) | Makes the minimap's addon-compartment button movable (ALT+drag) and swaps its count for a clean icon. |
| [ShadowsOfUI-Collectibles](ShadowsOfUI-Collectibles/README.md) | Tints already-known and still-collectible items (recipes, toys, mounts, pets, decor…) on vendors and the Auction House — recipes checked across your whole warband. |
| [ShadowsOfUI-ProfCommissions](ShadowsOfUI-ProfCommissions/README.md) | Enhances the Crafting Orders list: shows each order's actual reward icons in place of the generic chest, and replaces the Reagents text column with at-a-glance first-craft + reagent-provision icons. |
| [ShadowsOfUI-QuestXP](ShadowsOfUI-QuestXP/README.md) | Shows what percentage of a level a quest's XP reward is worth, next to the XP reward in the quest log's reward pane. |
| [ShadowsOfUI-PostOffice](ShadowsOfUI-PostOffice/README.md) | Headless mailbox helper: coin-collected reports, trade blocking, coin auto-subject, modifier-click shortcuts, Forward / copy-mail buttons on open letters, a recipient menu + autocomplete on the To: field, trade-goods quick-attach buttons, and per-letter return/delete icons in the inbox. |

### Quality of life

| Addon | Description |
|---|---|
| [Recycle](Recycle/README.md) | Auto-sells grey items and anything you mark, whenever you visit a merchant. |
| [HideStanceBar](HideStanceBar/README.md) | Hides the stance bar, with a per-class toggle. |
| [HideBagBar](HideBagBar/README.md) | Hides the backpack and bag slot buttons. |
| [CombatOutline](CombatOutline/README.md) | Enables the character outline rendering mode only while in combat. |
| [MouselookToggle](MouselookToggle/README.md) | Toggle mouselook (steer the camera without holding right-click) with a configurable keybind. |
| [BarNonce](BarNonce/README.md) | Removes padding and dims Action Bars 1–2 to 70% opacity. |

## Installation

Released addons are published to CurseForge (per-addon — see each README). To install
from source, copy (or symlink) the addon folder into your
`World of Warcraft/_retail_/Interface/AddOns/` directory. Mind the dependencies listed
in each addon's README/.toc — most addons need LibNAddOn, and UI addons also need LibNUI.

## Contributing

Development setup, code style, testing, and release process are documented in
[CONTRIBUTING.md](CONTRIBUTING.md).
