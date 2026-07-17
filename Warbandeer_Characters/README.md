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
| `/wbc wmissing` | Same report in a copyable window |
| `/wbc cleanup`, `/wbc clear delves\|dungeons`, `/wbc dump …`, `/wbc wdump …` | Maintenance/developer tools (`wdump` renders any `dump` in a copyable window; bare `wdump` dumps everything) |

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
- Active **world-quest gear rewards** that would upgrade one of your equipped slots are noted
  for each character while it's logged in, so Warbandeer can suggest them later.
- A per-character **item-count index** (everything in your bags, plus full counts for the
  personal/warband/guild banks when opened) is kept so **ShadowsOfUI-WarbandInventory** can
  show account-wide "how many do I have?" totals on item tooltips.
- **Mail** is recorded whenever you open a mailbox (count, attached items + gold, and when
  each piece expires). New, unread mail is also flagged as soon as it arrives — even before
  you open the mailbox — and remembered across reloads, so an envelope shows next to that
  character in the Summary view until the mail is picked up. On login you get a one-line
  warning naming any character whose mail expires within 3 days, and Warbandeer's Summary
  view gains a Mail column.
- **Reputations** are captured each login and whenever they change — every faction's standing
  for each character, so **ShadowsOfUI-Reputations** can show who's Exalted (or still grinding)
  with a faction, on the Reputation tab and on faction-tied item tooltips.
- **Auctions** are recorded when you open the Auction House (active auction count, when each
  expires, and gold tied up), so Warbandeer's Summary view can show — with a live count that
  drops expired ones — which characters have auctions about to lapse.
- **Quests** are captured each login — your active quests and your completed-quest history —
  so **ShadowsOfUI-Quests** can show, on a quest's tooltip, which other characters are on it or
  have already completed it. (The completed history is the largest thing tracked per character.)
- **Playtime** is tracked both as the lifetime `/played` total and **per day** for each character
  (how long you were logged in, by calendar day), so Warbandeer's Playtime view can show Today and
  the last 7 days. Per-day history starts from when this version is first installed and counts only
  time spent logged in (offline time is never added).
- **Titles** are recorded each login (and whenever you earn or change one) — the player titles each
  character has collected, plus its current (featured) title — so Warbandeer's Summary view gains a
  **Titles** column showing each character's current title, with the full title and its earned-title
  count on hover.
- **Weekly profession knowledge** is tracked per character (and cleared each weekly reset) — for each
  profession, which of this week's knowledge-point sources you've collected: the treatise, the weekly
  trainer / Artisan's Consortium quest, treasure knowledge, and gathering knowledge. Warbandeer's
  Midnight Profs view gains a **Know** column (collected / available this week, with a per-profession
  breakdown on hover), so you can see at a glance which characters still have knowledge to pick up.
  This replaces the standalone WeeklyKnowledge addon.
- **Great Vault + weekly lockouts** are tracked per character (and cleared each weekly reset): each
  track's (Raid / Mythic+ / World) reward slots and the item level each would grant, your owned
  keystone and Mythic+ run count, the raid lockouts you're saved to this week, and whether the weekly
  Delver's Bounty is claimed. Warbandeer's **Great Vault** view surfaces the whole warband at a glance.
- **Neighborhood endeavors + house XP** are tracked: which endeavor each character is currently
  feeding (its faction house's crest) shows in a new **Endeavors** column in the Summary view; and the
  two houses' level, favor (lifetime house XP), and current-endeavor progress — all account-wide —
  appear once in the **Overview**, with the House XP each endeavor still lets you earn shown on hover.

## Settings

Found under **Game Menu → Options → AddOns → Warbandeer → Logging**:

- **Enable Combat Log** *(default: off)* — when enabled, turns on the game's combat log,
  writing every combat event to `Logs\WoWCombatLog.txt` so you can analyse fights with
  an outside tool (Warcraft Logs, a parser, a spreadsheet). It also switches on
  **Advanced Combat Logging** (extra detail like positions and item levels) while active.
  Combat logging always starts off when the game launches, so this option re-enables it
  automatically each login. Turn it off to stop logging.

## Dependencies

- **LibNAddOn**
- **LibNUI**

## Saved data

`WarbandeerCharDB` (account-wide): all collected character data.
