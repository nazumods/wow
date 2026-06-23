# Warbandeer

**Your whole warband at a glance.** Warbandeer is a multi-view dashboard for all the
characters you play: gear, professions, gold, reputations, playtime, crafting plans,
and more — collected automatically as you log between characters and presented in one
window.

Open it with `/warband` or `/wb`, the minimap button, or the addon-compartment menu at the top of the minimap, and switch views with the icon rail on the left.

The minimap button opens the window on left-click, shows a small menu on right-click, and drags to reposition. Hide or show it any time with `/wb minimap`.

## Views

| View | What it shows |
|---|---|
| Overview | Warband-wide summary: wealth, top alts (with per-raid RF/N/H/M tier-set completion — hover an alt's item level for a per-slot breakdown, or a set cell for its collected/missing pieces; set cells also show wanted-set stars and tier-rank markers, left-click opens the dressing room, Shift-click flags a set as wanted — just like the Collected view, requires Collected), faction progress, achievements |
| Summary | One row per character: level, ilvl, gold, professions |
| Detail | Deep-dive on a single character: gear, a secondary-stats panel (Crit/Haste/Mastery/Versatility, with the spec's best stat highlighted and — with ClassCodex — each rating shown against its recommended target, colour-coded over/at/under), profession crafting intents, each profession's equipped tool/accessories, and a Suggested box of gear upgrades — ready items the character can equip right now, plus active world-quest rewards and buyable faction-quartermaster gear that would upgrade a slot (click to open the map to the quest/vendor, or click a ready upgrade — in the Suggested box or beneath a gear row — to flash it in your open bags/bank) |
| Gear | Equipped item levels piece-by-piece across the warband |
| Roles | Tank/healer/DPS coverage by class |
| Races | Race coverage across your characters |
| Professions | Who has which profession, skill levels and knowledge points |
| Crafting | Profession intents: who is your main crafter, secondary, gatherer |
| Milestones | Achievements that award collectibles (mounts, toys, decor) — spans all expansions |
| Legion | Legion-specific progress: Balance of Power, class halls, mage portals |
| Midnight Professions | Expansion profession progress |
| Playtime | Time played per character and total |
| Bars | Action-bar profile previews (requires Warbandeer_Bars) |
| Collected | Transmog-set collection grid by class and tier, with wanted-set stars and tier-rank markers (requires Collected) |
| Reputations | Faction standings across your whole warband, one page per expansion: each faction shows the highest standing any character reached (and an Alliance/Horde marker for side-locked reps); hover a faction to see every character's standing. Switch expansions with the pulldown or the Up/Down arrow keys, and move between factions with Left/Right |

Every view is also reachable directly, e.g. `/wb gear`, `/wb profs`, `/wb playtime`.

## Settings

Found in the Blizzard settings panel:

- **Default View** — which view opens with the window.
- **Tooltip Side** — show hover tooltips left or right of the window.
- **Summary Columns** — a subpanel of checkboxes to show or hide individual Summary columns (currencies, crests, Great Vault, Mythic+, gold, playtime, and more). The identity columns (character, faction, role, level, item level) are always shown. Changes apply immediately.

## Requirements

- **LibNAddOn** and **LibNUI** (libraries)
- **Warbandeer_Characters** — the data layer that does the actual collecting.
  Warbandeer is only the viewer; without the data layer it has nothing to show.
- *Optional:* **Warbandeer_Bars** for the Bars view.
- *Optional:* **Collected** for the Collected view (it also supplies the expansion badges that label the Reputations view's pages; without it those pages fall back to plain text).
- *Optional:* **ShadowsOfUI-Upgrade** for gear-upgrade markers, missing-enchant + wrong-enchant + empty-socket flags (Summary "Up"/"Ench"/"Gem" columns + Detail notes), and the Detail view's Suggested box. The Summary "Up" column counts how many slots have an available upgrade and is coloured **green** when at least one of them can be equipped right now (at or below the character's level — a warband-bank copy counts, since you can withdraw it), or **gold** when every available upgrade is still gated above the character's level. In the Detail gear list, a piece carrying the *wrong* (non-recommended) enchant shows a yellow "Wrong enchant" note; **right-click that row to accept the enchant on that item** (it asks to confirm, then stops flagging — right-click again to undo). `/wb enchants` lists everything you've accepted and `/wb enchants clear` resets the list.

## Saved data

`WarbandeerDB` (account-wide): window position, settings, and per-character profession
intents. All character data itself lives in Warbandeer_Characters' database.
