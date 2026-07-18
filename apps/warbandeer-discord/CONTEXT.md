# warbandeer-discord — Code Context

> **Purpose:** Discord bot (Bun + TypeScript, discord.js v14) for the guild channel:
> DMF open/close + reset timers (`/dmf`, `/reset`), weekly-reset announcement, a
> continuous realm up/down watch via the Blizzard API (`/status`), GitHub release
> announcements for this repo, and a `/report` command that files GitHub issues from Discord.
> Not an addon — lives in `apps/`, excluded from the release pipeline.

## File Map

| File | Responsibility |
|---|---|
| `src/index.ts` | Client login (Guilds intent only), slash-command registration (guild if `GUILD_ID`, else global), starts the scheduler; routes interactions — chat commands → `handleCommand`, `/report` modal submits → `handleReportModal` |
| `src/config.ts` | Env config from `.env` — pure `resolveConfig(env)` (exported for tests) + the `config` singleton resolved from `process.env`; throws at import time on missing required vars or an invalid `COMMAND_PREFIX`. Also the `/report` project→repo map (`REPORT_PROJECTS` + `repoForProject`) + `reportRoleId`, and the self-update config (`gitSha`, `botBranch`, `autoUpdate`, `adminUserIds`) |
| `src/commands.ts` | `/dmf`, `/reset`, `/status`, `/update`, `/report` command builders + dispatch; `cmd(name)` builds every command under `config.commandPrefix`, `bareName()` strips it back off on dispatch; `isAdmin()` allowlist gate for `/update`; Discord `<t:…>` timestamp helpers |
| `src/report.ts` | `/report` flow: role gate (reads roles from the interaction — no Members intent), Title/Description modal, then `createIssue` in the mapped repo labeled `automated`; `reportBody` footer names the reporter (plain username, no mention) |
| `src/announce.ts` | 60 s tick scheduler: DMF-open + weekly-reset announcements, continuous realm up/down watch (`checkRealm`, polls every `REALM_POLL_GAP_MS` = 2 min whenever `realmWatchConfigured()`), release polling; routes per `AnnounceKind` via `channelFor()` — releases → `RELEASE_ANNOUNCE_CHANNEL_ID` (falls back to `ANNOUNCE_CHANNEL_ID`), everything else → `ANNOUNCE_CHANNEL_ID` |
| `src/config.test.ts` | bun tests for `resolveConfig` (release-channel fallback, required-var, region, `COMMAND_PREFIX`, `REPORT_ROLE_ID`, self-update vars) + report helpers (`repoForProject`, `reportBody`) |
| `src/commands.test.ts` | bun tests for `isAdmin` (allowlist hit/miss, fails closed, whole-id match) + `bareName()` (strips the prefix, no-op when unset, passes an unprefixed name through unmangled) |
| `src/update.ts` | Self-update: pure `decideUpdate()` + `sameSha()`, `fetchLatestBotSha()` (newest `config.botBranch` commit touching `apps/warbandeer-discord`), stateful `checkForUpdate(force)` |
| `src/update.test.ts` | bun tests for `decideUpdate`/`sameSha`: staleness, short-sha prefixes, anti-loop suppression, `force` |
| `src/restart.ts` | Ref-counted critical section + `requestRestart()`; exits `RESTART_EXIT_CODE` (75); `setExitFn`/`resetForTest` for tests |
| `src/restart.test.ts` | bun tests: immediate vs deferred exit, nesting, exit-once, release-on-throw |
| `src/state.ts` | Announcement dedup state, persisted to `data/state.json` (gitignored) |
| `src/wow/dmf.ts` | DMF schedule math: first Sunday of month 00:01 in `config.dmfTimezone`, one week; IANA-timezone-correct (two-pass DST conversion) |
| `src/wow/reset.ts` | Daily/weekly reset math (fixed UTC: us = Tue 15:00, eu = Wed 04:00) |
| `src/wow/realm.ts` | Blizzard client-credentials OAuth + connected-realm status search (`UP`/`DOWN`); pure `decideRealmTransition(prev, next)` → `"up"`/`"down"`/`null` (first observation seeds silently) |
| `src/wow/realm.test.ts` | bun tests for `decideRealmTransition`: seed-silent first observation, no-change, UP→DOWN, DOWN→UP |
| `src/github.ts` | GitHub API client: releases (drafts filtered) + `createIssue` / idempotent `ensureLabel` for `/report` (both need `GITHUB_TOKEN` with issues:write) |
| `Dockerfile` | `oven/bun:1-slim` (Debian — Intl IANA timezones), prod-only install, non-root `bun` user, `VOLUME /app/data`, `ARG/ENV GIT_SHA` |
| `docker-compose.yml` | `GIT_SHA=$(git rev-parse HEAD) docker compose up -d --build`: `env_file: .env`, `GIT_SHA` build arg, named volume `state` → `/app/data`, `restart: unless-stopped`. Opt-in `cloudflared` sidecar (`profiles: [tunnel]`, needs `CLOUDFLARE_TUNNEL_TOKEN`) for exposing a future local API without inbound firewall ports |

## Behavior

- **Dedup keys** in `BotState`: `dmfAnnouncedFor` (`"YYYY-M"`), `weeklyAnnouncedFor` (reset ISO),
  `realmStatus` (last observed `UP`/`DOWN`), `seenReleaseIds` (capped at 100). Restarts never re-announce.
- **Realm watch** runs continuously whenever Blizzard creds + `WOW_REALM` are configured (not tied
  to the weekly reset): polls every `REALM_POLL_GAP_MS` (2 min) and announces every UP↔DOWN
  transition. `state.realmStatus` persists the last reading, so the first observation seeds silently
  (no phantom transition on a fresh install or restart) and restarts never re-announce. A Blizzard
  API error is logged and skipped — it never masquerades as a `DOWN`.
- **Release polling** follows the repo's daily release cron (14:00 UTC, `.github/workflows/release.yml`):
  polls every 5 min inside a 90-min window from 14:00 UTC, plus once at startup to catch
  anything published while the bot was offline. First-ever poll seeds `seenReleaseIds` silently.
- **Self-update** compares baked-in `GIT_SHA` against the newest `BOT_BRANCH` (default `main`)
  commit touching the bot's dir (flat 15-min cadence + startup, only when `AUTO_UPDATE=true`;
  `/update` checks on demand with `force`). Stale → persist `attemptedUpdateToSha`, then exit 75
  for the orchestrator to respawn. `/update` is gated on the `ADMIN_USER_IDS` allowlist and fails
  closed when empty.

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
- **A clean exit is not an update.** `restart: unless-stopped` respawns the *same image*, so
  self-update only does something if the respawn supplies rebuilt code (manual `--build`, or a
  registry image + Watchtower-style updater). The `attemptedUpdateToSha` marker exists precisely
  because the naive version exit-loops forever against a non-cooperating orchestrator: once the
  bot has exited for a sha and come back unchanged, it warns instead of exiting again.
- **`BOT_BRANCH` is queried through the GitHub API, so it must exist on the remote.** A deploy
  running a local-only branch (e.g. an unpushed integration branch that merges several PRs)
  can't point at it — and since such a branch never equals any remote branch's tip, self-update
  there reports a permanent update it can never deliver. Build those **without `GIT_SHA`** so
  self-update disables itself honestly instead.
- `requestRestart()` exits **immediately** when no critical section is open — anything that must
  survive the exit (a Discord reply, a state write) has to run inside `withCritical()`. The
  `/update` handler wraps its `checkForUpdate` for exactly this reason; without it the process
  dies before `editReply` lands.
- Run `bun run check` (tsc) and `bun test` after changes — CI runs both on every PR/push
  touching this app (`.github/workflows/discord-bot-test.yml`, path-scoped). No lint beyond tsc.
- **`cloudflared` currently has nothing to route to** — the bot exposes no HTTP port yet
  (that's the desktop-app API work, tracked separately). It's pure plumbing for now: an
  opt-in sidecar (`--profile tunnel`) that joins the bot's Compose network, so a future
  local server is reachable at `http://bot:<port>` once one exists and a public hostname
  is mapped to it in the Cloudflare dashboard. The bot process itself never reads
  `CLOUDFLARE_TUNNEL_TOKEN` — only the sidecar container does.
- Every `*.test.ts` that reaches the `config` singleton (directly or transitively — `update.ts`
  and `commands.ts` both do) must prime `DISCORD_TOKEN`/`ANNOUNCE_CHANNEL_ID` and use a dynamic
  `await import()`, or it throws when run **standalone**. A full-suite `bun test` can mask this:
  `config.test.ts` sorts first and primes the env for everyone. Check with `bun test src/<f>.test.ts`.
