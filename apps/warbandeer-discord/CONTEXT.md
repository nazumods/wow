# warbandeer-discord — Code Context

> **Purpose:** Discord bot (Bun + TypeScript, discord.js v14) for the guild channel:
> DMF open/close + reset timers (`/dmf`, `/reset`), weekly-reset announcement with a
> post-reset realm-up watch via the Blizzard API (`/status`), and GitHub release
> announcements for this repo. Not an addon — lives in `apps/`, excluded from the
> release pipeline.

## File Map

| File | Responsibility |
|---|---|
| `src/index.ts` | Client login (Guilds intent only), slash-command registration (guild if `GUILD_ID`, else global), starts the scheduler |
| `src/config.ts` | Env config from `.env` — exports the `config` singleton; throws at import time on missing required vars |
| `src/commands.ts` | `/dmf`, `/reset`, `/status` handlers; Discord `<t:…>` timestamp helpers |
| `src/announce.ts` | 60 s tick scheduler: DMF-open + weekly-reset announcements, realm-up watch, release polling; posts to `ANNOUNCE_CHANNEL_ID` |
| `src/state.ts` | Announcement dedup state, persisted to `data/state.json` (gitignored) |
| `src/wow/dmf.ts` | DMF schedule math: first Sunday of month 00:01 in `config.dmfTimezone`, one week; IANA-timezone-correct (two-pass DST conversion) |
| `src/wow/reset.ts` | Daily/weekly reset math (fixed UTC: us = Tue 15:00, eu = Wed 04:00) |
| `src/wow/realm.ts` | Blizzard client-credentials OAuth + connected-realm status search (`UP`/`DOWN`) |
| `src/github.ts` | GitHub releases API client (drafts filtered out) |

## Behavior

- **Dedup keys** in `BotState`: `dmfAnnouncedFor` (`"YYYY-M"`), `weeklyAnnouncedFor` /
  `serversUpAnnouncedFor` (reset ISO), `seenReleaseIds` (capped at 100). Restarts never re-announce.
- **Realm watch** arms at the weekly reset (only if Blizzard creds + `WOW_REALM` configured),
  polls each tick, announces recovery only after actually observing `DOWN`, gives up after 3 h.
- **Release polling** follows the repo's daily release cron (14:00 UTC, `.github/workflows/release.yml`):
  polls every 5 min inside a 90-min window from 14:00 UTC, plus once at startup to catch
  anything published while the bot was offline. First-ever poll seeds `seenReleaseIds` silently.

## Gotchas

- `config.ts` reads env at import time — tests/scripts must set `DISCORD_TOKEN` and
  `ANNOUNCE_CHANNEL_ID` **before** importing any module that imports it.
- DMF "first Sunday" is realm-**local** (e.g. EU window starts Saturday 22:01/23:01 UTC).
- Weekly-reset detection compares `now` against `lastWeeklyReset()` within a 10-min window —
  the tick cadence must stay well under that window.
- Run `bun run check` (tsc) after changes; there is no lint/CI for `apps/` TypeScript.
