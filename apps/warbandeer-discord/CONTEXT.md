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
| `src/config.ts` | Env config from `.env` — pure `resolveConfig(env)` (exported for tests) + the `config` singleton resolved from `process.env`; throws at import time on missing required vars |
| `src/commands.ts` | `/dmf`, `/reset`, `/status`, `/update` handlers; `isAdmin()` allowlist gate; Discord `<t:…>` timestamp helpers |
| `src/announce.ts` | 60 s tick scheduler: DMF-open + weekly-reset announcements, realm-up watch, release polling; routes per `AnnounceKind` via `channelFor()` — releases → `RELEASE_ANNOUNCE_CHANNEL_ID` (falls back to `ANNOUNCE_CHANNEL_ID`), everything else → `ANNOUNCE_CHANNEL_ID` |
| `src/config.test.ts` | bun tests for `resolveConfig`: release-channel fallback, required-var and region validation, self-update vars |
| `src/update.ts` | Self-update: pure `decideUpdate()` + `sameSha()`, `fetchLatestBotSha()` (newest `main` commit touching `apps/warbandeer-discord`), stateful `checkForUpdate(force)` |
| `src/update.test.ts` | bun tests for `decideUpdate`/`sameSha`: staleness, short-sha prefixes, anti-loop suppression, `force` |
| `src/restart.ts` | Ref-counted critical section + `requestRestart()`; exits `RESTART_EXIT_CODE` (75); `setExitFn`/`resetForTest` for tests |
| `src/restart.test.ts` | bun tests: immediate vs deferred exit, nesting, exit-once, release-on-throw |
| `src/commands.test.ts` | bun tests for `isAdmin`: allowlist hit/miss, fails closed, whole-id match |
| `src/state.ts` | Announcement dedup state, persisted to `data/state.json` (gitignored) |
| `src/wow/dmf.ts` | DMF schedule math: first Sunday of month 00:01 in `config.dmfTimezone`, one week; IANA-timezone-correct (two-pass DST conversion) |
| `src/wow/reset.ts` | Daily/weekly reset math (fixed UTC: us = Tue 15:00, eu = Wed 04:00) |
| `src/wow/realm.ts` | Blizzard client-credentials OAuth + connected-realm status search (`UP`/`DOWN`) |
| `src/github.ts` | GitHub releases API client (drafts filtered out) |
| `Dockerfile` | `oven/bun:1-slim` (Debian — Intl IANA timezones), prod-only install, non-root `bun` user, `VOLUME /app/data`, `ARG/ENV GIT_SHA` |
| `docker-compose.yml` | `GIT_SHA=$(git rev-parse HEAD) docker compose up -d --build`: `env_file: .env`, `GIT_SHA` build arg, named volume `state` → `/app/data`, `restart: unless-stopped` |

## Behavior

- **Dedup keys** in `BotState`: `dmfAnnouncedFor` (`"YYYY-M"`), `weeklyAnnouncedFor` /
  `serversUpAnnouncedFor` (reset ISO), `seenReleaseIds` (capped at 100). Restarts never re-announce.
- **Realm watch** arms at the weekly reset (only if Blizzard creds + `WOW_REALM` configured),
  polls each tick, announces recovery only after actually observing `DOWN`, gives up after 3 h.
- **Release polling** follows the repo's daily release cron (14:00 UTC, `.github/workflows/release.yml`):
  polls every 5 min inside a 90-min window from 14:00 UTC, plus once at startup to catch
  anything published while the bot was offline. First-ever poll seeds `seenReleaseIds` silently.
- **Self-update** compares baked-in `GIT_SHA` against the newest `main` commit touching the bot's
  dir (flat 15-min cadence + startup, only when `AUTO_UPDATE=true`; `/update` checks on demand
  with `force`). Stale → persist `attemptedUpdateToSha`, then exit 75 for the orchestrator to
  respawn. `/update` is gated on the `ADMIN_USER_IDS` allowlist and fails closed when empty.

## Gotchas

- `config.ts` reads env at import time (the `config` singleton) — tests/scripts must set
  `DISCORD_TOKEN` and `ANNOUNCE_CHANNEL_ID` **before** importing any module that imports it
  (see `config.test.ts`: env vars + dynamic import). Config *logic* is testable without env
  games via the pure `resolveConfig(env)`.
- DMF "first Sunday" is realm-**local** (e.g. EU window starts Saturday 22:01/23:01 UTC).
- Weekly-reset detection compares `now` against `lastWeeklyReset()` within a 10-min window —
  the tick cadence must stay well under that window.
- **A clean exit is not an update.** `restart: unless-stopped` respawns the *same image*, so
  self-update only does something if the respawn supplies rebuilt code (manual `--build`, or a
  registry image + Watchtower-style updater). The `attemptedUpdateToSha` marker exists precisely
  because the naive version exit-loops forever against a non-cooperating orchestrator: once the
  bot has exited for a sha and come back unchanged, it warns instead of exiting again.
- `requestRestart()` exits **immediately** when no critical section is open — anything that must
  survive the exit (a Discord reply, a state write) has to run inside `withCritical()`. The
  `/update` handler wraps its `checkForUpdate` for exactly this reason; without it the process
  dies before `editReply` lands.
- Run `bun run check` (tsc) and `bun test` after changes — CI runs both on every PR/push
  touching this app (`.github/workflows/discord-bot-test.yml`, path-scoped). No lint beyond tsc.
- Every `*.test.ts` that reaches the `config` singleton (directly or transitively — `update.ts`
  and `commands.ts` both do) must prime `DISCORD_TOKEN`/`ANNOUNCE_CHANNEL_ID` and use a dynamic
  `await import()`, or it throws when run **standalone**. A full-suite `bun test` can mask this:
  `config.test.ts` sorts first and primes the env for everyone. Check with `bun test src/<f>.test.ts`.
