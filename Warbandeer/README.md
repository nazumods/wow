# Warbandeer

**Your whole warband at a glance.** Warbandeer is a multi-view dashboard for all the
characters you play: gear, professions, gold, reputations, playtime, crafting plans,
and more — collected automatically as you log between characters and presented in one
window.

Open it with `/warband` or `/wb` and switch views with the icon rail on the left.

## Views

| View | What it shows |
|---|---|
| Overview | Warband-wide summary: wealth, top alts (with per-raid RF/N/H/M tier-set completion), faction progress, achievements |
| Summary | One row per character: level, ilvl, gold, professions |
| Detail | Deep-dive on a single character: gear, profession crafting intents, each profession's equipped tool/accessories, and a Suggested box of gear upgrades — ready items the character can equip right now, plus active world-quest rewards and buyable faction-quartermaster gear that would upgrade a slot (click to open the map to the quest/vendor) |
| Gear | Equipped item levels piece-by-piece across the warband |
| Roles | Tank/healer/DPS coverage by class |
| Races | Race coverage across your characters |
| Professions | Who has which profession, skill levels and knowledge points |
| Crafting | Profession intents: who is your main crafter, secondary, gatherer |
| Legion / Midnight | Expansion-specific progress trackers |
| Midnight Professions | Expansion profession progress |
| Playtime | Time played per character and total |
| Bars | Action-bar profile previews (requires Warbandeer_Bars) |
| Collected | Transmog-set collection grid by class and tier (requires Collected) |

Every view is also reachable directly, e.g. `/wb gear`, `/wb profs`, `/wb playtime`.

## Settings

Found in the Blizzard settings panel:

- **Default View** — which view opens with the window.
- **Tooltip Side** — show hover tooltips left or right of the window.

## Requirements

- **LibNAddOn** and **LibNUI** (libraries)
- **Warbandeer_Characters** — the data layer that does the actual collecting.
  Warbandeer is only the viewer; without the data layer it has nothing to show.
- *Optional:* **Warbandeer_Bars** for the Bars view.
- *Optional:* **Collected** for the Collected view.
- *Optional:* **ShadowsOfUI-Upgrade** for gear-upgrade markers and the Detail view's Suggested box.

## Saved data

`WarbandeerDB` (account-wide): window position, settings, and per-character profession
intents. All character data itself lives in Warbandeer_Characters' database.
