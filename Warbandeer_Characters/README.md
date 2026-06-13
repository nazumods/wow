# Warbandeer_Characters

The **data layer** of the Warbandeer suite. Each time you log into a character it
quietly scans and stores everything worth knowing: level, spec, professions, gold,
currencies, equipped gear and item levels, bags, Great Vault progress, Mythic+
keystones, raid/transmog lockouts, achievements, and playtime. Weekly values reset
themselves on schedule.

There is **no window** — this addon only collects. Install **Warbandeer** to browse
the data, or **Warbandeer_Collected** for transmog tracking. Other addons can read the
data through the `WarbandeerApi` global.

## Commands

`/characters` or `/wbc`:

| Command | What it does |
|---|---|
| `/wbc` or `/wbc list` | List all stored characters |
| `/wbc delete <name>` | Remove a character from the database |
| `/wbc refresh` | Re-scan the current character now |
| `/wbc stat` | Warband-wide playtime/class statistics |
| `/wbc missing [me]` | Report characters/fields with incomplete data |
| `/wbc wmissing` | Same report in a copyable window (with a titlebar font-size picker) |
| `/wbc cleanup`, `/wbc dump …` | Maintenance/developer tools |

## Notes

- Scanning is spread out (one field per 100 ms) so logins stay smooth.
- Learned recipes and profession specialization points are captured when you **open
  the profession window** — open each profession once per character for full data.
- Warband bank gold is tracked account-wide, with a weekly wealth history.
- Profession gear sitting in a **bank** — the warband bank, any character's bank, or a
  guild bank — is noted whenever you open it, so Warbandeer can tell you when an empty
  profession slot could be filled from one of your banks.
- Equippable gear in your **bags** and in the **warband / personal banks** is also recorded
  (whenever those are open).

## Requirements

**LibNAddOn** and **LibNUI**.

## Saved data

`WarbandeerCharDB` (account-wide): all collected character data.
