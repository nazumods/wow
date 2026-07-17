# warbandeer-discord — Code Context

> **Purpose:** Discord bot (Bun + TypeScript, discord.js v14) for the guild channel:
> DMF open/close + reset timers (`/dmf`, `/reset`), weekly-reset announcement with a
> post-reset realm-up watch via the Blizzard API (`/status`), GitHub release
> announcements for this repo, and a `/report` command that files GitHub issues from Discord.
> Not an addon — lives in `apps/`, excluded from the release pipeline.

## File Map

| File | Responsibility |
|---|---|
| `src/index.ts` | Client login (Guilds intent only), slash-command registration (guild if `GUILD_ID`, else global), starts the scheduler; routes interactions — chat commands → `handleCommand`, `/report` modal submits → `handleReportModal` |
| `src/config.ts` | Env config from `.env` — pure `resolveConfig(env)` (exported for tests) + the `config` singleton resolved from `process.env`; throws at import time on missing required vars or an invalid `COMMAND_PREFIX`. Also the `/report` project→repo map (`REPORT_PROJECTS` + `repoForProject`) and `reportRoleId` |
| `src/commands.ts` | `/dmf`, `/reset`, `/status`, `/report` command builders + dispatch; `cmd(name)` builds every command under `config.commandPrefix`, `bareName()` strips it back off on dispatch; Discord `<t:…>` timestamp helpers |
| `src/report.ts` | `/report` flow: role gate (reads roles from the interaction — no Members intent), Title/Description modal, then `createIssue` in the mapped repo labeled `automated`; `reportBody` footer names the reporter (plain username, no mention) |
| `src/announce.ts` | 60 s tick scheduler: DMF-open + weekly-reset announcements, realm-up watch, release polling; routes per `AnnounceKind` via `channelFor()` — releases → `RELEASE_ANNOUNCE_CHANNEL_ID` (falls back to `ANNOUNCE_CHANNEL_ID`), everything else → `ANNOUNCE_CHANNEL_ID` |
| `src/config.test.ts` | bun tests for `resolveConfig` (release-channel fallback, required-var, region, `COMMAND_PREFIX`, `REPORT_ROLE_ID`) + report helpers (`repoForProject`, `reportBody`) |
| `src/commands.test.ts` | bun tests for `bareName()`: strips the prefix, no-op when unset, passes an unprefixed name through unmangled |
| `src/state.ts` | Announcement dedup state, persisted to `data/state.json` (gitignored) |
| `src/wow/dmf.ts` | DMF schedule math: first Sunday of month 00:01 in `config.dmfTimezone`, one week; IANA-timezone-correct (two-pass DST conversion) |
| `src/wow/reset.ts` | Daily/weekly reset math (fixed UTC: us = Tue 15:00, eu = Wed 04:00) |
| `src/wow/realm.ts` | Blizzard client-credentials OAuth + connected-realm status search (`UP`/`DOWN`) |
| `src/github.ts` | GitHub API client: releases (drafts filtered) + `createIssue` / idempotent `ensureLabel` for `/report` (both need `GITHUB_TOKEN` with issues:write) |
| `Dockerfile` | `oven/bun:1-slim` (Debian — Intl IANA timezones), prod-only install, non-root `bun` user, `VOLUME /app/data` |
| `docker-compose.yml` | `docker compose up -d --build`: `env_file: .env`, named volume `state` → `/app/data`, `restart: unless-stopped` |

## Behavior

- **Dedup keys** in `BotState`: `dmfAnnouncedFor` (`"YYYY-M"`), `weeklyAnnouncedFor` /
  `serversUpAnnouncedFor` (reset ISO), `seenReleaseIds` (capped at 100). Restarts never re-announce.
- **Realm watch** arms at the weekly reset (only if Blizzard creds + `WOW_REALM` configured),
  polls each tick, announces recovery only after actually observing `DOWN`, gives up after 3 h.
- **Release polling** follows the repo's daily release cron (14:00 UTC, `.github/workflows/release.yml`):
  polls every 5 min inside a 90-min window from 14:00 UTC, plus once at startup to catch
  anything published while the bot was offline. First-ever poll seeds `seenReleaseIds` silently.

## Gotchas

- **`/report`** (`src/report.ts`) is disabled unless BOTH `REPORT_ROLE_ID` and `GITHUB_TOKEN`
  are set (it replies "not configured" otherwise). `project` is a fixed choices list, so an
  unknown project can't reach the handler; the modal `customId` (`report:<project>`) carries the
  selection to the submit handler. `ensureLabel` treats HTTP 422 (label already exists) as success,
  so `/report` never fails on a missing `automated` label — it creates it on first use. Role check
  reads `member.roles` from the interaction payload (cached manager **or** raw `string[]`), so no
  privileged Members intent is needed.
- `config.ts` reads env at import time (the `config` singleton) — tests/scripts must set
  `DISCORD_TOKEN` and `ANNOUNCE_CHANNEL_ID` **before** importing any module that imports it
  (see `config.test.ts`: env vars + dynamic import). Config *logic* is testable without env
  games via the pure `resolveConfig(env)`.
- DMF "first Sunday" is realm-**local** (e.g. EU window starts Saturday 22:01/23:01 UTC).
- Weekly-reset detection compares `now` against `lastWeeklyReset()` within a 10-min window —
  the tick cadence must stay well under that window.
- `COMMAND_PREFIX` (empty by default) namespaces every slash-command name so a second
  debug/staging bot can share a server without command collisions (`r_` → `/r_dmf`). It must be
  lowercase (Discord rejects uppercase names); `resolveConfig` validates and throws otherwise.
  A second bot is its own Discord application/token with its own state volume — and since
  `index.ts`'s `rest.put` fully replaces an application's command set, switching the prefix and
  restarting removes the old names automatically.
- **Build every command with `cmd(name)`, never a bare `new SlashCommandBuilder().setName("foo")`.**
  A hand-written name registers outside the namespace, and dispatch then has to cope with it:
  `bareName()` only strips the prefix when the name actually starts with it. An earlier
  unconditional `slice(prefix.length)` turned an unprefixed `update` into `date`, matching no
  case — the command appeared in Discord and silently did nothing. `cmd()` makes that
  unrepresentable; `bareName()`'s tolerance is the backstop.
- Run `bun run check` (tsc) and `bun test` after changes — CI runs both on every PR/push
  touching this app (`.github/workflows/discord-bot-test.yml`, path-scoped). No lint beyond tsc.
