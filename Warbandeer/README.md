# Warbandeer

**Your whole warband at a glance.** Warbandeer is a multi-view dashboard for all the
characters you play: gear, professions, gold, reputations, titles, playtime, crafting plans,
and more — collected automatically as you log between characters and presented in one
window.

Open it with `/warband` or `/wb`, the minimap button, or the addon-compartment menu at the top of the minimap, and switch views with the icon rail on the left. **Right-click the logo at the top of that rail** for a menu with Settings and a jump-to-view list (the same menu the minimap button offers).

The minimap button opens the window on left-click and drags to reposition. Right-click it for a menu: hide the button, open Settings, or jump straight to any view. Hide or show it any time with `/wb minimap`. The addon-compartment entry works the same way — left-click opens the window, right-click brings up the Settings + jump-to-view menu.

## Views

| View | What it shows |
|---|---|
| Overview | Warband-wide summary: wealth, top alts (with per-raid RF/N/H/M tier-set completion — hover an alt's item level for a per-slot breakdown, or a set cell for its collected/missing pieces; set cells also show wanted-set stars and tier-rank markers, left-click opens the dressing room, Shift-click flags a set as wanted — just like the Collected view, requires Collected), faction progress, achievements, and the monthly Traveler's Log (Trading Post activity progress + rewards waiting to collect), and — once you own a house — your **Houses**: each faction house's level, favor (its lifetime house XP) and current neighborhood-endeavor progress, with the House XP you can still earn this cycle shown on hover |
| Summary | One row per character: level, ilvl, gold, professions, and the neighborhood endeavor each character is currently feeding (its faction house's crest). A faction control in the title bar switches between your Alliance roster, your Horde roster, or **Both** in one merged warband-wide list (column totals then cover every character) |
| Great Vault | Every character's Great Vault at a glance: how many of the three reward slots on each track (Raid, Dungeons, World) are unlocked — shown as pips, with the exact reward item level per slot on hover — plus your owned keystone and this week's raid lockout (hover for the full list). Uses the same Alliance / Horde / Both faction control as Summary, and marks any character with a reward still waiting to be collected |
| Detail | Deep-dive on a single character: gear, a secondary-stats panel (Crit/Haste/Mastery/Versatility, with the spec's best stat highlighted and — with ClassCodex — each rating shown against its recommended target, colour-coded over/at/under), profession crafting intents, each profession's equipped tool/accessories, and a Suggested box of gear upgrades — ready items the character can equip right now, plus active world-quest rewards and buyable faction-quartermaster gear that would upgrade a slot (click to open the map to the quest/vendor, or click a ready upgrade — in the Suggested box or beneath a gear row — to flash it in your open bags/bank). With **ClassCodex** installed it also shows a **Consumables** box — the spec's recommended flask, combat potion, food, weapon buff and augment rune (hover one for its tooltip); hide any category you don't want from the settings. An **Appearance** box lists the cosmetic glyphs the character has applied — with a spec picker to switch between the character's specs — plus per-character learned class unlocks — for Druids the **Tome of the Wilds** spells (Treant Form, Mount Form, Flap, and the rest), for Hunters the **Tomes & Tames** — special-pet tames (Blood Beasts, Feathermanes, Direhorns, Mechanicals, Gargon, Cloud Serpents, Undead, Dragonkin, Nah'qi, Florafaun) plus utility ability tomes (Aspect of the Chameleon, Fetch) — and, for Druids and Warlocks, the account-wide appearance unlocks (Druid form Marks and travel-form glyphs; Warlock demon Grimoires and the **green fire** unlock, The Codex of Xerrath — which points you to the next step, from the starter tome to the final scenario, until you've earned it). It also lists your **class mounts** and their spec colour tints — the Legion order-hall mounts every class earns (Death Knights ride a single mount that recolours with the active spec) — read from your account-wide collection. Every entry is shown as owned or missing, so you can see at a glance what's still to collect. For **Hunters**, a **Pets** button toggles a panel — docked to the right of the window — listing that character's pets, both its active (Call Pet) pets and its full stable, each with its family, level and specialization (many identical skins of one pet, such as Hati's several appearances, collapse into a single row with a count so a big stable stays readable; hover any row for its full detail), captured the last time the Hunter visited a stable master. Beside it, a **Challenge Tames** panel cross-references your stable against a curated list of rare, hard-to-tame "secret" pets (spirit beasts, the Molten Front challenge tames, and the like), grouped by category and showing at a glance which you've caught (in colour, named as your own pet) and which are still out there (dimmed, with a hint of where to find them). **Warlocks** get the same button as **Demons**, listing each of that character's summoned demons by species and name (Imp, Voidwalker, Felhunter, …) — captured as the Warlock summons each one (there's no stable to read them all at once, so the list fills in over time; hover a demon to see when it was last seen) |
| Gear | Equipped item levels piece-by-piece across the warband |
| Roles | Tank/healer/DPS coverage by class |
| Races | Race coverage across your characters |
| Professions | Who has which profession, skill levels and knowledge points |
| Crafting | Profession intents: who is your main crafter, secondary, gatherer |
| Milestones | Achievements that award collectibles (mounts, toys, decor) — spans all expansions |
| Legion | Legion-specific progress: Balance of Power, class halls, mage portals |
| Midnight Professions | Expansion profession progress |
| Playtime | Time played per character and total |
| Bars | Action-bar profile browser (requires Warbandeer_Bars): filter saved profiles by class and spec, and pick one to preview its bars — every icon and keybind, laid out in each bar's real on-screen orientation (matching your action-bar addon, e.g. Bartender), including stance/class pages set apart with a subtle border. Selecting a profile also opens an **Apply** panel (below the preview) to copy it onto your current character: per-bar toggles (Action Bars 1-8, Class Pages 1-5, and the Bonus / Skyriding / Pet bars) show **gold = included / red = excluded** — click to flip, and hover one to light up the bar it controls in the preview. The Apply button shows how many bars it will write and confirms in-panel once done. Keybindings and outfits are never changed, and applying overwrites the current character's bars |
| Collected | Transmog-set collection grid by class and tier, with wanted-set stars and tier-rank markers (requires Collected) |
| Housing Decor | Account-wide housing decor catalog — every decor with its owned count, category/unowned/wanted filters and a name search, and wanted stars you set with Shift-click (requires Housing Decor) |
| Reputations | Faction standings across your whole warband, one page per expansion: each faction shows the highest standing any character reached (and an Alliance/Horde marker for side-locked reps); hover a faction to see every character's standing. Switch expansions with the pulldown or the Up/Down arrow keys, and move between factions with Left/Right |
| Titles | Every player title in one browsable list — earned by your warband (a title any character has earned, with which ones shown on hover) and the ones still unearned. Filter with the pulldown (All / Earned / Unearned) or the Left/Right arrow keys, move between titles with Up/Down. With the optional **Epithet** addon installed, titles are coloured by rarity, the hover shows each title's source, and an extra **Earnable** / **Unearnable** pair of filters splits the unearned titles into the ones you can still get and the ones you can't |

Every view is also reachable directly, e.g. `/wb gear`, `/wb profs`, `/wb playtime`.

**Keybinding:** a *Toggle Warbandeer window* binding is registered under **Esc → Options → Key Bindings → Warbandeer** — assign it any key (Alt-W recommended). **Tap** it to open/close the window; **hold** it to pop a radial selector under your cursor — aim at a view and release to jump straight to it.

## Settings

Found in the Blizzard settings panel:

- **Default View** — which view opens with the window.
- **Tooltip Side** — show hover tooltips left or right of the window.
- **Hide minimap button** — hide or show the Warbandeer minimap button. Stays in sync with `/wb minimap` and the button's right-click menu; changes apply immediately.
- **Summary Columns** — a subpanel of checkboxes to show or hide individual Summary columns (currencies, crests, Great Vault, Mythic+, gold, playtime, titles, endeavors, and more). The identity columns (character, faction, role, level, item level) are always shown. Changes apply immediately.
- **Great Vault Columns** — a subpanel of checkboxes to show or hide individual Great Vault columns (Raid, Dungeons, World, Key, Raid Lock). The identity columns (character, faction, level) are always shown. Changes apply immediately.
- **Consumables** — a subpanel with a master **Show consumables** checkbox (turn the whole Detail Consumables box off) plus a checkbox per category (flask, combat potion, food, weapon buff, augment rune). Appears only with **ClassCodex** installed (the source of the recommendations). Changes apply immediately.
- **Bar Apply Defaults** — a subpanel of checkboxes setting which bars are pre-checked when the Bars view's Apply panel opens (Action Bars 1-8, Class Pages 1-5, and the Bonus / Skyriding / Pet bars). By default every bar is included except Bonus, Skyriding, and Pet. Changes take effect the next time you open the game.
- **Changelog** — a button that opens Warbandeer's release history (newest first) in a scrollable, copyable window, so you can read what changed without leaving the game.

## Dependencies

- **LibNAddOn**
- **LibNUI**
- **Warbandeer_Characters** — the data layer that does the actual collecting.
  Warbandeer is only the viewer; without the data layer it has nothing to show.
- **Warbandeer_Bars** *(optional)* — for the Bars view.
- **Warbandeer_Collected** *(optional)* — for the Collected view (it also supplies the expansion badges that label the Reputations view's pages; without it those pages fall back to plain text).
- **Warbandeer_HousingDecor** *(optional)* — for the Housing Decor view.
- **ShadowsOfUI-Upgrade** *(optional)* — for gear-upgrade markers, missing-enchant + wrong-enchant + empty-socket flags (Summary "Up"/"Ench"/"Gem" columns + Detail notes), and the Detail view's Suggested box. The Summary "Up" column counts how many slots have an available upgrade and is coloured **green** when at least one of them can be equipped right now (at or below the character's level — a warband-bank copy counts, since you can withdraw it), or **gold** when every available upgrade is still gated above the character's level. In the Detail gear list, a piece carrying the *wrong* (non-recommended) enchant shows a yellow "Wrong enchant" note; **right-click that row to accept the enchant on that item** (it asks to confirm, then stops flagging — right-click again to undo). `/wb enchants` lists everything you've accepted and `/wb enchants clear` resets the list. With **ClassCodex** also installed, the Detail view adds a **Consumables** box (recommended flask/potion/food/weapon-buff/augment-rune for the spec).
- **Epithet** *(optional)* — enriches the Titles view. When installed, its title catalog is read live (nothing is copied or stored) so titles are coloured by rarity, the hover shows each title's source, and the Titles view gains **Earnable** and **Unearnable** filters splitting the unearned titles into what can still be obtained and what can't. Without it, the Titles view still works as an earned/unearned browser.

## Saved data

`WarbandeerDB` (account-wide): window position, settings, and per-character profession
intents. All character data itself lives in Warbandeer_Characters' database.
