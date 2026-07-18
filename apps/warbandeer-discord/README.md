# Warbandeer Discord Bot

Discord bot for the guild channel: WoW timers and announcements.

## Features

- **Darkmoon Faire** — `/dmf` shows when the Faire opens/closes; announces in the channel when it opens (first Sunday of each month, computed in realm-local time with DST handled).
- **Resets** — `/reset` shows the next daily and weekly reset; announces the weekly reset when it happens.
- **Server status** — continuously polls the Blizzard API for your realm's status and announces whenever it goes **down** or comes back **up** — for any outage, not just weekly-reset maintenance. `/status` checks the realm on demand.
- **Release notifications** — polls GitHub and announces new releases. Watches this repo by default, or any list of repos you configure (e.g. ActionBarMaster too).
- **Self-update** — `/update` (admins only) restarts the bot onto the latest build, so code changes don't need someone on the box. See [Self-update](#self-update).
- **Issue reports** — `/report` lets members with a configured role file a GitHub issue (Title + Description via a popup form) straight into the mapped project's repo (`wow`, `abm`), labeled `automated` and noting who filed it.

All times are posted as Discord timestamps, so everyone sees them in their own timezone.

## Setup

1. **Create the Discord application** at <https://discord.com/developers/applications>: add a **Bot**, copy its **token**, and invite it with this URL (replace `CLIENT_ID` with the application ID):

   ```
   https://discord.com/oauth2/authorize?client_id=CLIENT_ID&scope=bot+applications.commands&permissions=2048
   ```

   (`2048` = Send Messages. No privileged intents are needed.)

2. **Configure**: copy `.env.example` to `.env` and fill it in. `DISCORD_TOKEN` and `ANNOUNCE_CHANNEL_ID` are required (right-click a channel → Copy Channel ID, with Developer Mode enabled). Set `RELEASE_ANNOUNCE_CHANNEL_ID` to post release notifications to their own channel (optional — they go to `ANNOUNCE_CHANNEL_ID` if unset). Set `WATCHED_REPOS` (comma-separated `owner/repo`) to announce releases from more repos than just this one (e.g. `nazumods/wow,roshne/ActionBarMaster`). Set `GUILD_ID` so slash commands register instantly. For `/status` and server-up announcements, create a client at <https://develop.battle.net> and set `BLIZZARD_CLIENT_ID`, `BLIZZARD_CLIENT_SECRET`, and `WOW_REALM`. To enable `/report`, set `REPORT_ROLE_ID` (the Discord role allowed to file reports) and give `GITHUB_TOKEN` a PAT with **issues:write** on the reportable repos. To run a second **debug/staging** bot in the same server, set `COMMAND_PREFIX` (e.g. `r_`) so its commands register as `/r_dmf`, `/r_reset`, `/r_status` instead of colliding with the live bot's — lowercase only (Discord rule).

3. **Run** ([Bun](https://bun.sh) required):

   ```
   bun install
   bun start
   ```

   `bun run dev` restarts on file changes; `bun run check` typechecks.

   Or with **Docker** (reads the same `.env`; state persists in a named volume):

   ```
   GIT_SHA=$(git rev-parse HEAD) docker compose up -d --build
   ```

   `GIT_SHA` bakes the current commit into the image so the bot can tell when it's running stale code. It's optional — without it everything works except self-update.

## Self-update

The bot can't rewrite its own code: it restarts, and **whatever supervises it is responsible for bringing up the new build**. `/update` is an admin-triggered *"stop, so you can be replaced"*, not a `git pull`.

That distinction matters, because `restart: unless-stopped` on its own **will not update anything** — Docker respawns the same container from the same image, so the bot comes back on the identical code. For self-update to actually do something, the respawn has to supply a rebuilt image. Either:

- redeploy manually with `GIT_SHA=$(git rev-parse HEAD) docker compose up -d --build` (in which case `/update` is unnecessary — the rebuild already restarts it), or
- run an image-updating supervisor (e.g. Watchtower) against a registry image that CI builds.

Setup:

1. Set `ADMIN_USER_IDS` to a comma-separated list of Discord user IDs (right-click a user → **Copy User ID**, with Developer Mode on). This is an explicit ID allowlist rather than a role check — roles get reassigned and inherited; the list only changes when you edit `.env`. It fails closed: with none set, `/update` is refused for everyone.
2. Build with `GIT_SHA` as above.
3. Optionally set `AUTO_UPDATE=true` to exit as soon as a newer build exists, without waiting for `/update`. **Off by default** — it's only useful with a supervisor that supplies new code.

Behavior:

- Staleness is "the newest commit on `BOT_BRANCH` (default `main`) touching `apps/warbandeer-discord` isn't my `GIT_SHA`", checked at startup and every 15 minutes when `AUTO_UPDATE=true`, and on demand via `/update`.
- `BOT_BRANCH` must name a branch that exists on `GITHUB_REPO` — it's queried through the GitHub API, so a branch that only exists on your machine can't be used. Point a staging deploy at its own pushed branch. A deploy running something unpushed should build **without** `GIT_SHA` instead, so self-update reports itself disabled rather than reporting a permanent, undeliverable update.
- The bot exits with code **75** (distinct from a crash, so a supervisor can tell an update apart from a failure).
- A restart never lands mid-announcement: it waits for the in-flight tick and its `data/state.json` write to finish.
- If the bot exits to update and comes back on the same build, it says so once in the log and **stops trying** — a misconfigured deploy produces a warning, not a restart loop. `/update` overrides that suppression.
- Without `GIT_SHA`, self-update reports itself disabled rather than guessing.

## Cloudflare Tunnel

An opt-in sidecar for exposing a future local API (e.g. for the desktop app) to the internet without opening any inbound firewall ports. It's currently just plumbing — the bot has no HTTP server yet — but sets up the tunnel ahead of that work.

1. In the [Cloudflare Zero Trust dashboard](https://one.dash.cloudflare.com/), go to **Networks → Tunnels**, create a tunnel, choose the **Docker** connector, and copy the token it gives you.
2. Set `CLOUDFLARE_TUNNEL_TOKEN` in `.env`.
3. Start it alongside the bot:

   ```
   GIT_SHA=$(git rev-parse HEAD) docker compose --profile tunnel up -d --build
   ```

   Without `--profile tunnel`, the sidecar doesn't start — a normal `docker compose up` is unaffected and doesn't need the token.

Once the bot exposes a local port, map a public hostname to it (`http://bot:<port>`) in the tunnel's **Public Hostname** settings in the dashboard.

## Behavior notes

- Announcement state persists in `data/state.json`, so restarts never repeat an announcement.
- Each watched repo's first release poll seeds silently (no backlog spam); only releases published after that are announced, and each repo tracks what it's seen independently.
- The server status watch runs continuously (whenever `WOW_REALM` + Blizzard credentials are set), polling every 2 minutes and announcing each up/down transition once. The first reading after a start seeds silently, so a fresh install or restart never posts a phantom up/down.
- Releases publish from a daily cron at 14:00 UTC, so GitHub is only polled in a 90-minute window after that (every 5 minutes), plus once at startup to catch anything published while the bot was offline.
- `COMMAND_PREFIX` lets a second (debug) instance run in the same server: it prefixes every slash-command name (e.g. `r_` → `/r_status`). A second instance needs its own Discord application/token and its own state volume.

## Files

| File | Responsibility |
|---|---|
| `src/index.ts` | Client login, command registration, interaction routing (commands + `/report` modals) |
| `src/config.ts` | Env config (`.env`); `/report` project→repo map |
| `src/commands.ts` | `/dmf`, `/reset`, `/status`, `/update`, `/report` handlers |
| `src/report.ts` | `/report` — role gate, modal form, files a GitHub issue |
| `src/announce.ts` | Scheduler tick: DMF/reset/release announcements, realm watch |
| `src/update.ts` | Self-update: staleness check against the bot's newest commit |
| `src/restart.ts` | Graceful restart, deferred past in-flight announcements |
| `src/state.ts` | Announcement dedup state (`data/state.json`) |
| `src/wow/dmf.ts` | Darkmoon Faire schedule math (timezone-correct) |
| `src/wow/reset.ts` | Daily/weekly reset math per region |
| `src/wow/realm.ts` | Blizzard OAuth + connected-realm status |
| `src/github.ts` | GitHub API: releases + `/report` issue creation |
