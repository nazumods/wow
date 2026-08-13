[**Part of Nazuraki's WoW AddOn Suite**](https://github.com/nazumods/wow) — free & open source on GitHub.

![Warbandeer_Characters](https://raw.githubusercontent.com/nazumods/wow/main/Warbandeer_Characters/logo.png)

# Warbandeer: Characters

**The engine that powers Warbandeer — there's no window.** Every time you log into a character, Warbandeer_Characters quietly scans and stores everything worth knowing: level, spec, professions, gold, currencies, equipped gear and item levels, bags, Great Vault progress, Mythic+ keystones, raid and transmog lockouts, reputations, quests, titles, mail, auctions, playtime, and more. Weekly values reset themselves on schedule.

Install **[Warbandeer](https://github.com/nazumods/wow/tree/main/Warbandeer)** to browse it all in a dashboard, or **[Warbandeer_Collected](https://github.com/nazumods/wow/tree/main/Warbandeer_Collected)** for transmog tracking. Several **Shadows of UI** addons also read this data to add cross-alt lines to tooltips (who can learn a recipe, who's Exalted with a faction, how many of an item your account holds, and more).

- Scanning is spread out (one field per 100 ms) so logins stay smooth.
- Open each profession window once per character for full recipe/knowledge data.
- Other addons can read everything through the `WarbandeerApi` global.

`/characters` or `/wbc` lists and manages stored characters.

## Dependencies

- **LibNAddOn**, **LibNUI** — install automatically.

## Found a bug / Have a suggestion?

Warbandeer_Characters is developed in the open as part of **[Nazuraki's WoW AddOn Suite](https://github.com/nazumods/wow)**. Please report bugs and request features on the **[GitHub issue tracker](https://github.com/nazumods/wow/issues)**.
