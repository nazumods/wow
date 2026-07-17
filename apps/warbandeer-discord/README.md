# Warbandeer Discord Bot

Discord bot for the guild channel: WoW timers and announcements.

## Features

- **Darkmoon Faire** — `/dmf` shows when the Faire opens/closes; announces in the channel when it opens (first Sunday of each month, computed in realm-local time with DST handled).
- **Resets** — `/reset` shows the next daily and weekly reset; announces the weekly reset when it happens.
- **Server-up watch** — after the weekly reset, polls the Blizzard API for your realm's status; if the realm goes down for maintenance, announces when it comes back up. `/status` checks the realm on demand.
- **Release notifications** — polls GitHub and announces new releases of the addon suite.
- **Self-update** — `/update` (admins only) restarts the bot onto the latest build, so code changes don't need someone on the box. See [Self-update](#self-update).

All times are posted as Discord timestamps, so everyone sees them in their own timezone.

## Setup

1. **Create the Discord application** at <https://discord.com/developers/applications>: add a **Bot**, copy its **token**, and invite it with this URL (replace `CLIENT_ID` with the application ID):

   ```
   https://discord.com/oauth2/authorize?client_id=CLIENT_ID&scope=bot+applications.commands&permissions=2048
   ```

   (`2048` = Send Messages. No privileged intents are needed.)

2. **Configure**: copy `.env.example` to `.env` and fill it in. `DISCORD_TOKEN` and `ANNOUNCE_CHANNEL_ID` are required (right-click a channel → Copy Channel ID, with Developer Mode enabled). Set `RELEASE_ANNOUNCE_CHANNEL_ID` to post release notifications to their own channel (optional — they go to `ANNOUNCE_CHANNEL_ID` if unset). Set `GUILD_ID` so slash commands register instantly. For `/status` and server-up announcements, create a client at <https://develop.battle.net> and set `BLIZZARD_CLIENT_ID`, `BLIZZARD_CLIENT_SECRET`, and `WOW_REALM`.

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

- Staleness is "the newest commit on `main` touching `apps/warbandeer-discord` isn't my `GIT_SHA`", checked at startup and every 15 minutes when `AUTO_UPDATE=true`, and on demand via `/update`.
- The bot exits with code **75** (distinct from a crash, so a supervisor can tell an update apart from a failure).
- A restart never lands mid-announcement: it waits for the in-flight tick and its `data/state.json` write to finish.
- If the bot exits to update and comes back on the same build, it says so once in the log and **stops trying** — a misconfigured deploy produces a warning, not a restart loop. `/update` overrides that suppression.
- Without `GIT_SHA`, self-update reports itself disabled rather than guessing.

## Behavior notes

- Announcement state persists in `data/state.json`, so restarts never repeat an announcement.
- The first release poll seeds silently (no backlog spam); only releases published after that are announced.
- The server-up watch only reports recovery if it actually observed the realm **down** after reset — quiet weeks with no maintenance produce no message. It gives up after 3 hours.
- Releases publish from a daily cron at 14:00 UTC, so GitHub is only polled in a 90-minute window after that (every 5 minutes), plus once at startup to catch anything published while the bot was offline.

## Files

| File | Responsibility |
|---|---|
| `src/index.ts` | Client login, slash-command registration, wiring |
| `src/config.ts` | Env config (`.env`) |
| `src/commands.ts` | `/dmf`, `/reset`, `/status`, `/update` handlers |
| `src/announce.ts` | Scheduler tick: DMF/reset/release announcements, realm watch |
| `src/update.ts` | Self-update: staleness check against the bot's newest commit |
| `src/restart.ts` | Graceful restart, deferred past in-flight announcements |
| `src/state.ts` | Announcement dedup state (`data/state.json`) |
| `src/wow/dmf.ts` | Darkmoon Faire schedule math (timezone-correct) |
| `src/wow/reset.ts` | Daily/weekly reset math per region |
| `src/wow/realm.ts` | Blizzard OAuth + connected-realm status |
| `src/github.ts` | GitHub releases API client |
