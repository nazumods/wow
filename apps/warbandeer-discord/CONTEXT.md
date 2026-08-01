# warbandeer-discord — Code Context

> **Purpose:** Discord bot (Bun + TypeScript, discord.js v14) for the guild channel:
> DMF open/close + reset timers (`/dmf`, `/reset`), weekly-reset announcement, a
> continuous realm up/down watch via the Blizzard API (`/status`), GitHub release
> announcements for this repo, and a `/report` command that files GitHub issues from Discord.
> Not an addon — lives in `apps/`, excluded from the release pipeline.

## File Map

| File | Responsibility |
|---|---|
| `src/index.ts` | Client login (Guilds intent only), then `activate()` — slash-command registration (guild if `GUILD_ID`, else global), the interaction routes (chat commands → `handleCommand`, `/report` modal submits → `handleReportModal`), the scheduler, and `reportUpdateOutcome()` fired un-awaited (an owed `/update` follow-up must not delay startup). Under `bootMode() === "standby"` (#879) it logs in and attaches **none** of that until `takeOver()` has retired the original — both instances hold the same token and Discord delivers events to both sessions, so a standby with handlers would double every reply. A standby that never reaches `ClientReady` inside `VERIFY_DEADLINE_MS` writes a `failed` marker and exits 1, so the original gets a reason rather than a timeout |
| `src/config.ts` | Env config from `.env` — pure `resolveConfig(env)` (exported for tests) + the `config` singleton resolved from `process.env`; throws at import time on missing required vars or an invalid `COMMAND_PREFIX`. Also the `/report` project→repo map (`REPORT_PROJECTS` + `repoForProject`) + `reportRoleId`, the release-watch list (`watchedRepos` from `WATCHED_REPOS`, comma-separated `owner/repo`, defaulting to `[githubRepo]` — distinct from `githubRepo`, which anchors self-update), and the self-update config (`gitSha`, `botBranch`, `autoUpdate`, `adminUserIds`) |
| `src/commands.ts` | `/dmf`, `/reset`, `/status`, `/update`, `/report` command builders + dispatch; `cmd(name)` builds every command under `config.commandPrefix`, `bareName()` strips it back off on dispatch; `isAdmin()` allowlist gate for `/update`; `updateReply(decision, latestSha, { runningSha, reason, redeploy })` (exported for tests) renders the `/update` acknowledgement — a `redeploy` result present at all means the swap **failed**, since a successful one never returns to reply (the replacement retires this process and delivers the ✅ itself) — the running sha is a **parameter, not a `config` read**, because config resolves env at import time and is one singleton for the whole bun test process, so a formatter reading it is only testable by winning a race with whichever test file imports config first; dispatch passes the interaction's user/channel/application/token to `checkForUpdate` as the follow-up requester; Discord `<t:…>` timestamp helpers |
| `src/report.ts` | `/report` flow: role gate (reads roles from the interaction — no Members intent), Title/Description modal, then `createIssue` in the mapped repo labeled `automated`; `reportBody` footer names the reporter (plain username, no mention); pure `reportAnnouncement()` renders the channel-visible confirmation (reporter, `repo#N` + url, title, description clamped to Discord's 2000-char cap with a truncation note) |
| `src/announce.ts` | 60 s tick scheduler: DMF-open + weekly-reset announcements, continuous realm up/down watch (`checkRealm`, polls every `REALM_POLL_GAP_MS` = 2 min whenever `realmWatchConfigured()`), release polling (`checkReleases` loops `config.watchedRepos`, isolating each repo's failure via a per-repo try/catch so one bad repo can't starve the others; a repo `fetchReleases` reports unreachable is skipped without touching its seen-id list — so it seeds silently if it returns — and warns only on the edge, via the module-level `releaseReachability` log); routes per `AnnounceKind` via `channelFor()` — releases → `RELEASE_ANNOUNCE_CHANNEL_ID` (falls back to `ANNOUNCE_CHANNEL_ID`), everything else → `ANNOUNCE_CHANNEL_ID` |
| `src/config.test.ts` | bun tests for `resolveConfig` (release-channel fallback, required-var, region, `COMMAND_PREFIX`, `REPORT_ROLE_ID`, `WATCHED_REPOS` parse/default, self-update vars) + report helpers (`repoForProject`, `reportBody`, `reportAnnouncement` — content, no-truncation-when-it-fits, the 2000-char clamp, and the boundary either side of it) |
| `src/github.test.ts` | bun tests for pure `decideReleaseAnnouncements`: silent seed on never-polled, unseen-only oldest-first, no-op when nothing new, first release of a zero-release repo. Plus `fetchReleases` against a stubbed `globalThis.fetch` (payload mapping, draft filter, tag fallback, `null` on 404, `[]` on a releaseless repo, throws on 401/403/429/5xx) and `createReachabilityLog` (once per standing failure, silent when healthy, recovery, per-repo independence) |
| `src/state.test.ts` | bun tests for pure `normalizeSeenReleaseIds`: legacy-array migration under the default repo, empty array → `{}`, keyed map/`undefined` pass-through |
| `src/commands.test.ts` | bun tests for `isAdmin` (allowlist hit/miss, fails closed, whole-id match) + `bareName()` (strips the prefix, no-op when unset, passes an unprefixed name through unmangled) + `updateReply()` (names the target build; no longer asks the reader to check whether it changed; both `disabled` reasons — a missing `GIT_SHA` vs. an unpublished one, which is named) |
| `src/update.ts` | Self-update: pure `decideUpdate()` + `sameSha()`, `fetchLatestBotSha()` (newest `config.botBranch` commit touching `apps/warbandeer-discord`), `fetchShaRelation()` (the `ShaRelation` ancestry answer from `GET /compare/{latest}...{running}`; 404 → `unpublished`, any other failure → `unknown`, never throws), stateful `checkForUpdate({ force, requester })` answering `busy` while a handoff is in flight (guard before any state write — see the gotcha), returning a `DisabledReason` when it disables — and, on `restart`, routing through `applyUpdate()`: a self-contained `redeploy()` when the daemon socket is mounted, else the original exit-75 fallback so a deployment on an older compose file keeps working. A failed redeploy clears `attemptedUpdateToSha` + `pendingUpdateReport` again, since the restart never happened — leaving them would owe a follow-up for nothing and let the anti-loop guard suppress the next genuine attempt; pure `buildUpdateReport()` returns the `PendingUpdateReport` to persist across the restart, or `undefined` when there's no requester (which is what keeps an `AUTO_UPDATE` exit silent) |
| `src/update.test.ts` | bun tests for `decideUpdate`/`sameSha`: staleness, short-sha prefixes, anti-loop suppression, `force`; the ancestry matrix (`ahead`/`identical` → current, `behind`/`diverged` → restart, `unpublished` → disabled and outranking both suppression and `force`, `unknown` → pre-#871 fallback, equality shortcut winning before any relation is read); `fetchShaRelation` against a stubbed `fetch` (each status, 404, 500, a rejected fetch, an unrecognised status, and the `latest...running` argument order); plus `buildUpdateReport` (records requester + both shas; no requester → no report) |
| `src/updateReport.ts` | The follow-up owed after a `/update`-initiated restart. Pure `decideUpdateOutcome()` (`updated`/`noop`/`unexpected`/`unknown` by comparing the running `GIT_SHA` against the report's `toSha`/`fromSha`), `updateOutcomeMessage()`, `tokenUsable()` (15-min interaction-token window), `reportTooOld()` (24 h); `deliverUpdateReport()` walks interaction follow-up → DM → channel with injected deliverers, logging and falling through on each failure; `reportUpdateOutcome(client)` is the boot entry point |
| `src/updateReport.test.ts` | bun tests for the four outcomes (incl. short-sha tolerance and a missing `GIT_SHA`), per-outcome message content, the token/staleness windows, and the delivery fallback order — including "every route fails" resolving to `none` rather than throwing |
| `src/restart.ts` | Ref-counted critical section + `requestRestart()`; exits `RESTART_EXIT_CODE` (75); `setExitFn`/`resetForTest` for tests. Also `beginHandoff()`/`endHandoff()`/`handoffActive()` (#879): quiesce for a handoff — `restartPending()` goes true so the scheduler stops writing `state.json` while the replacement shares that volume, but the process deliberately does **not** exit, because it is the only thing that can remove a replacement that fails to verify |
| `src/restart.test.ts` | bun tests: immediate vs deferred exit, nesting, exit-once, release-on-throw; handoff quiesce-without-exit, resume, idempotent resume, and that a handoff neither masks nor is masked by a genuine pending restart |
| `src/docker.ts` | Minimal Docker Engine API client over `/var/run/docker.sock` via Bun's `fetch(url, { unix })` — no dependency. Unversioned paths so it tracks the daemon's own API version. `inspectSelf()` (hostname first, `parseContainerId()` off `/proc/self/mountinfo` as the fallback for a pinned `hostname:`), `buildImage()` (remote git context — the daemon fetches the source, so the image needs no git or tar), create/start/stop/remove/rename, image list/remove, `daemonReachable()`. Pure `parseBuildOutput()` because `/build` answers **200 even when the build failed**, with the error buried in the JSONL stream |
| `src/docker.test.ts` | bun tests for `parseContainerId` (both mountinfo layouts, short-id rejection) and `parseBuildOutput` (the 200-with-an-error case, `errorDetail.message` preference, non-JSON noise), plus stubbed-`fetch` daemon calls: ping, build query construction (remote + both tags + build-arg), and 304/404 on stop/remove being success rather than errors |
| `src/handoff.ts` | The handoff contract, kept free of I/O so it tests as pure logic: `bootMode(env)` (presence of `HANDOFF_FROM` *is* the standby instruction), the marker file in the shared volume (its own file, never `state.json` — one writer, one reader), `decideHandoffOutcome()` → `ready`/`failed`/`timeout`/`waiting` (plus `stalled`, decided not by it but by outliving `RETIREMENT_DEADLINE_MS` — see the gotcha), deadlines, `handoffFailureMessage()`. The marker is read before the container state on purpose: a replacement that signalled `ready` is already stopping the original, so what it *said* must outrank how it currently looks |
| `src/handoff.test.ts` | bun tests for `bootMode` (incl. an empty `HANDOFF_FROM` staying normal), the full `decideHandoffOutcome` matrix, the three ready-marker-wins races (mid-stop, already gone, expired deadline), and `handoffFailureMessage` always saying the current build is still running |
| `src/redeploy.ts` | The swap itself. `redeploy(sha)`: quiesce → build (`buildRemote()` = `…/wow.git#<branch>:apps/warbandeer-discord`, tagged `:latest` + `:<sha7>`) → prune → create + start the replacement → poll until `decideHandoffOutcome()` settles; **returns only on failure**, since a successful handoff kills this process mid-await — observing `ready` starts a bounded wait for that death, and outliving it demotes the outcome to `stalled` (reclaim + report) rather than quiescing forever. Pure `buildCreateSpec()` derives the replacement entirely from the original's own inspect (compose labels replicated, mounts re-bound, `User` carried over, `GIT_SHA` **dropped** so the new image's baked sha wins), `imageTags()`, `selectImagesToPrune()` (sha-shaped tags of this repo only — `:latest` and hand-named rollback targets are never candidates), `replacementName()`. `retireOriginal()` is the replacement's side: stop + **remove** (an exited container would be respawned on its old image by `restart: unless-stopped`) then take the canonical name |
| `src/redeploy.test.ts` | bun tests for naming, `buildRemote`, `imageTags`, `selectImagesToPrune` (keep-newest-N oldest-first, the never-prune set, untagged images), and `buildCreateSpec` — label replication, `HANDOFF_FROM` injection with no stacking, the `GIT_SHA` drop, both binds, `User`, restart-policy default, network |
| `src/state.ts` | Announcement dedup state, persisted to `data/state.json` (gitignored). `seenReleaseIds` is keyed per `owner/repo`; pure `normalizeSeenReleaseIds()` migrates the legacy global array (single-repo era) under `config.githubRepo` on load; `saveState` caps each repo's list at 100. `attemptedUpdateToSha` guards the self-update exit loop; `pendingUpdateReport` (`PendingUpdateReport`: `fromSha`, `toSha`, `userId`, `channelId?`, `applicationId?`, `interactionToken?`, `requestedAt`) is the `/update` follow-up owed on next boot — purely additive, so an old `state.json` simply lacks the key |
| `src/wow/dmf.ts` | DMF schedule math: first Sunday of month 00:01 in `config.dmfTimezone`, one week; IANA-timezone-correct (two-pass DST conversion) |
| `src/wow/reset.ts` | Daily/weekly reset math (fixed UTC: us = Tue 15:00, eu = Wed 04:00) |
| `src/wow/blizzard.ts` | Shared Blizzard API access: the client-credentials token, cached until a minute before expiry. Client creds cover everything the bot reads — Game Data (realm status) and public character profiles — so there is no per-user OAuth or account link. Lifted out of `realm.ts` once `/transmog` became a second caller; it was never realm-specific |
| `src/wow/realm.ts` | Connected-realm status search (`UP`/`DOWN`); pure `decideRealmTransition(prev, next)` → `"up"`/`"down"`/`null` (first observation seeds silently). Token comes from `blizzard.ts`. `realmExists(slug)` answers "is this a realm in the configured region", used by `/transmog` to separate a bad realm from a bad character — the character endpoint returns the *same* 404 for both (verified live), so asking separately is the only way to tell. **Fails open**: an outage or rate limit reports `true`, because "we couldn't ask" must never render as "your realm is wrong" |
| `src/wow/realm.test.ts` | bun tests for `decideRealmTransition`: seed-silent first observation, no-change, UP→DOWN, DOWN→UP |
| `src/wow/transmog.ts` | `/transmog` — a `/customset v1 …` import string for a character you can't inspect in-game (#820, the fallback #819's in-game path can't reach). `buildCustomSet(equipment)` is pure: it maps each equipped item's `transmog.item_modified_appearance_id` / `second_item_modified_appearance_id` (already source ids — no translation) onto the 17-value wire layout, **mirroring `Warbandeer_Collected/outfitcodec.lua` exactly**, since that decoder rejects any count but 17. Also pure: `realmSlug()` and `formatTransmogReply()`. `fetchTransmog()` is the only impure part. **Two values are always 0 by design** — the payload carries no visual-enchant field (illusions) and omits `transmog` entirely for an untransmogged slot; both are named in the reply rather than shipped silently. **A secondary that merely echoes its primary encodes 0**: the REST payload repeats the primary appearance when a slot has no distinct secondary, where the in-game producer emits 0 — and 0 is what this format means by "none", so normalising is what keeps the two producers emitting the same string for the same look. **`bare` (equipped, not transmogged) and `empty` (nothing equipped) are tracked separately** — only `bare` leaves the look incomplete; an empty off hand is just a two-hander, and reporting that as a gap tells the user their look is broken when it isn't. **The slot-type vocabulary (`HEAD`/`SHIRT`/`HANDS`/`MAIN_HAND`…) is the one thing not verified against a captured response**, so an unrecognised type is collected and surfaced in the reply instead of silently encoding 0 |
| `src/wow/transmog.test.ts` | bun tests: wire order and the fixed 17-value count, absent-transmog → 0 + reported bare, illusions always 0, a secondary not bleeding into the next slot, non-transmoggable slots ignored vs unknown ones surfaced; `realmSlug` (spaces, apostrophes, accents, already-a-slug); `formatTransmogReply` (code + import target, slot labels, caveats always present, all-zero special case) |
| `src/github.ts` | GitHub API client: `fetchReleases(repo)` (drafts filtered; returns `null` on a 404 — the repo is missing or invisible to `GITHUB_TOKEN`, which GitHub reports identically — while 401/403/429/5xx still throw, and a releaseless repo is a plain `[]`) + `createReachabilityLog()` (edge-triggered per-repo tracker: `observe(repo, reachable)` → `"lost"` / `"recovered"` / `null`, in-memory so a restart re-reports once) + pure `decideReleaseAnnouncements(releases, seen)` (seed-silently on `seen===undefined`, else announce unseen oldest-first) + `createIssue` / idempotent `ensureLabel` for `/report` (both need `GITHUB_TOKEN` with issues:write) |
| `Dockerfile` | `oven/bun:1-slim` (Debian — Intl IANA timezones), prod-only install, non-root `bun` user, `VOLUME /app/data`, `ARG/ENV GIT_SHA`, `ENTRYPOINT entrypoint.sh` |
| `entrypoint.sh` | Root→`bun` drop when compose starts the container as root: joins the socket's group by reading its GID off the socket (`setpriv --groups`), execs the CMD; a plain exec under `USER bun` |
| `docker-compose.yml` | `GIT_SHA=$(git rev-parse HEAD) docker compose up -d --build`: `env_file: .env`, `GIT_SHA` build arg, named volume `state` → `/app/data`, `restart: unless-stopped`. Opt-in `cloudflared` sidecar (`profiles: [tunnel]`, needs `CLOUDFLARE_TUNNEL_TOKEN`) for exposing a future local API without inbound firewall ports |
| `ops/bot-ops.sh` + `ops/README.md` | Operator admin surface for the desktop app's **Ops** tab (`apps/warbandeer-desktop`): whitelisted `status`/`logs`/`restart`/`env-get`/`env-set` over docker+`.env`, invoked over SSH. Secrets are never read/written (whitelist excludes them); env-set backs up then `-p warbandeer-discord-debug up -d --force-recreate`. The only privileged surface — the desktop app just SSHes to it |

## Behavior

- **Dedup keys** in `BotState`: `dmfAnnouncedFor` (`"YYYY-M"`), `weeklyAnnouncedFor` (reset ISO),
  `realmStatus` (last observed `UP`/`DOWN`), `seenReleaseIds` (`Record<owner/repo, number[]>`, each
  capped at 100). Restarts never re-announce.
- **Realm watch** runs continuously whenever Blizzard creds + `WOW_REALM` are configured (not tied
  to the weekly reset): polls every `REALM_POLL_GAP_MS` (2 min) and announces every UP↔DOWN
  transition. `state.realmStatus` persists the last reading, so the first observation seeds silently
  (no phantom transition on a fresh install or restart) and restarts never re-announce. A Blizzard
  API error is logged and skipped — it never masquerades as a `DOWN`.
- **Release polling** follows the repo's daily release cron (14:00 UTC, `.github/workflows/release.yml`):
  polls every 5 min inside a 90-min window from 14:00 UTC, plus once at startup to catch
  anything published while the bot was offline. Each repo in `config.watchedRepos` is polled
  independently; a repo's first-ever poll (its key absent from `seenReleaseIds`) seeds silently.
- **Self-update** asks whether the baked-in `GIT_SHA` **contains** the newest `BOT_BRANCH` (default
  `main`) commit touching the bot's dir (flat 15-min cadence + startup, only when `AUTO_UPDATE=true`;
  `/update` checks on demand with `force`). Stale → persist `attemptedUpdateToSha`, then exit 75
  for the orchestrator to respawn. `/update` is gated on the `ADMIN_USER_IDS` allowlist and fails
  closed when empty.
- **Update follow-up** closes the loop `/update` used to leave open: the command also persists a
  `pendingUpdateReport` (requester + both shas), and the next boot messages that requester with
  the build it actually came back on — `updated` / `noop` / `unexpected` named explicitly, since
  the no-op is otherwise indistinguishable from success. Only a `/update`-initiated restart leaves
  a report, so `AUTO_UPDATE` exits and host reboots stay silent.

## Gotchas

- **The redeploy order is inverted on purpose (#879), and the reason is a kernel boundary.** Every
  "shut down, then have something bring the replacement up" variant dies on the same thing: a
  detached process (`setsid`, double fork, `Bun.spawn({ detached: true })`) leaves its *parent*, not
  the container's **PID namespace** or **cgroup**, and per `pid_namespaces(7)` the kernel `SIGKILL`s
  every process in a namespace when its PID 1 exits. `init: true` doesn't help either — tini exits
  with its main child. Starting the replacement *first* means there is no window to survive, so
  nothing has to. Don't "simplify" this back into an exit-then-respawn.
- **The old container is removed, never just stopped.** Under `restart: unless-stopped` an exited
  container is respawned **on its old image** — the original #868 failure, and now with two bots
  live. An explicit `docker stop` is exempt from that policy, which is why retirement is a daemon
  call rather than a process exit.
- **`GIT_SHA` is stripped from the replacement's copied env** (`buildCreateSpec`). Docker's
  `Config.Env` merges the image's baked ENV with the container's own, so copying it verbatim pins
  the *old* sha onto the new container and overrides the new image's — a bot that updated correctly
  would then report its own update as a ⚠️ no-op.
- **A plain `compose up -d` after a swap recreates the container — expected, not a bug.** The
  replacement copies the original's labels verbatim, including `com.docker.compose.config-hash`,
  which embeds the `GIT_SHA` build-arg environment of whatever `up` created the original — so
  compose sees a stale hash and recreates. Benign, verified on the box: compose recognises the
  replacement as its own service (no second bot — the trap the labels exist to prevent), and the
  recreate reuses `:latest`, which *is* the self-deployed build, so no rollback. Don't "fix" it by
  computing a fresh hash — a wrong guess would make compose orphan the service and start a second
  container, the far worse failure.
- **The standby attaches nothing** until it has taken over: both instances hold the same
  `DISCORD_TOKEN` and Discord delivers every event to **both** gateway sessions, so a standby that
  registered handlers would double every command reply for the length of the overlap.
- **The handoff marker is its own file, not `state.json`.** One writer (the replacement), one
  reader (the original). `decideHandoffOutcome` reads it *before* the container state because a
  replacement that signalled `ready` is already stopping the original, so it can be caught mid-stop
  and would otherwise be misread as one that died.
- **`bot-ops.sh env-set` must never gain `--build`.** It recreates without building so it reuses
  the `<project>-bot:latest` tag a self-update just wrote; adding `--build` would rebuild from
  whatever the box's checkout is on, silently rolling the bot back on every settings edit.
- **The bot container *starts* as root but *runs* as `bun`** (`user: "0:0"` in
  `docker-compose.yml` + `entrypoint.sh`). The daemon socket is mode 0660 `root:docker` and the
  docker GID differs per host (115 on the box, 999 on a stock Debian) — naming one would be the
  operator-supplied config #879 rules out — so the entrypoint reads the GID off the socket
  itself (`stat -c %g`), then `setpriv`s to `bun` carrying that one supplementary group. Hygiene,
  not a boundary: the socket mount is already root-equivalent either way. Under the image's own
  `USER bun` (no socket, older compose file) it execs the CMD untouched. State written by a
  pre-drop root-run deployment stays root-owned — a one-time `chown -R bun:bun` on the host's
  `data/`, not something the entrypoint redoes every start.
- **`ready` is a promise of a stop, not the stop itself.** The replacement writes the marker
  *before* retiring the original, so a `retireOriginal` that dies in between would leave the
  original quiesced forever — seen `ready`, stopped counting, waiting to be killed. Two guards
  close that: the original bounds the wait for its own death (`RETIREMENT_DEADLINE_MS`, outcome
  `stalled` — reclaim, remove the replacement, report "check the daemon socket"), and past the
  `stopContainer` point of no return `retireOriginal` degrades instead of throwing, because the
  original is dead by then and a rejecting `ClientReady` would strand *both* containers.
- **A second `/update` mid-swap answers `busy`** — the guard sits at the top of
  `checkForUpdate`, before any state write or network call, because interaction handling does
  not quiesce during a handoff (only the scheduler does) and `/update`'s `force: true` bypasses
  the anti-loop suppression: unguarded, it would overwrite the in-flight attempt's
  `pendingUpdateReport` and then force-remove its replacement.
- **`/report`** (`src/report.ts`) is disabled unless BOTH `REPORT_ROLE_ID` and `GITHUB_TOKEN`
  are set (it replies "not configured" otherwise). `project` is a fixed choices list, so an
  unknown project can't reach the handler; the modal `customId` (`report:<project>`) carries the
  selection to the submit handler. `ensureLabel` treats HTTP 422 (label already exists) as success,
  so `/report` never fails on a missing `automated` label — it creates it on first use. Role check
  reads `member.roles` from the interaction payload (cached manager **or** raw `string[]`), so no
  privileged Members intent is needed.
- **A `/report` outcome is public; its refusals are not (#870).** The modal submit defers
  **without** `MessageFlags.Ephemeral`, so the filed-issue confirmation (and the failure that
  replaces it) lands in the channel the report came from — the transparency is the feature, and the
  confirmation *is* the announcement, so there's no second message and no channel config. The three
  pre-flight refusals stay ephemeral on purpose: an unconfigured bot, a missing role, and an unknown
  project are the reporter's own business, not something the channel needs. Two consequences of
  going public: the send passes `allowedMentions: { parse: [] }`, because the description is
  now untrusted free text in a public message and an `@everyone` typed into the modal would
  otherwise fire; and the message is clamped to 2000 chars by `reportAnnouncement`, since the
  modal's Description field is unbounded and Discord rejects an over-long send outright.
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
- **Staleness is ancestry, not sha equality (#871).** `GIT_SHA` is baked as `git rev-parse HEAD` —
  the tip the image was built from — which is only occasionally the last commit to touch
  `apps/warbandeer-discord`, because non-bot commits land on `main` most days. Asking "is my sha
  *the* newest bot commit" therefore called a correct deploy stale as its **normal** state: one
  wasted exit-75 per deploy under `AUTO_UPDATE`, and every `/update` (always `force`) overriding
  the suppression to waste another. `decideUpdate` takes a `ShaRelation` from
  `fetchShaRelation()` (`GET /compare/{latest}...{running}`) instead: `identical`/`ahead` →
  `current`, `behind`/`diverged` → `restart`. It's only fetched when the shas differ, so the
  common path still costs one request.
- **`BOT_BRANCH` is queried through the GitHub API, so it must exist on the remote.** A deploy
  running a local-only branch (e.g. an unpushed integration branch that merges several PRs) can't
  point at it. The *running sha* being unpushed is handled, though: the compare 404s, which is its
  own `ShaRelation` (`unpublished`) and resolves to `disabled` naming the sha — so such a deploy
  can keep `GIT_SHA` baked, where it previously had to be built without one. `unknown` (any other
  compare failure) deliberately falls back to the pre-#871 "mismatch = stale", so a GitHub outage
  degrades the check rather than failing startup.
- **`reportUpdateOutcome()` clears and saves `pendingUpdateReport` *before* it tries to deliver.**
  Delivery is the part that can fail — an expired token, closed DMs, a deleted channel — and a
  report left in place after a failed send would re-fire on every subsequent boot. Losing one
  follow-up beats wedging the marker. For the same reason `index.ts` calls it **after**
  `startScheduler` and doesn't await it: an owed follow-up must never delay or crash startup.
- **The interaction follow-up posts unauthenticated via raw `REST.post(Routes.webhook(...), { auth: false })`,
  not `WebhookClient`** — the webhook route is authenticated by the interaction token itself, and
  discord.js's `WebhookClient.send` typing can't set the ephemeral flag, which the follow-up needs
  to match the ephemeral `/update` reply it continues. **Measured on the box's debug bot (#681):
  the token does survive the restart** — the follow-up lands ephemerally in the original command's
  thread, so DM and channel are true fallbacks rather than the load-bearing path.
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
