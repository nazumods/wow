# Warbandeer Discord Bot

Discord bot for the guild channel: WoW timers and announcements.

## Features

- **Darkmoon Faire** — `/dmf` shows when the Faire opens/closes; announces in the channel when it opens (first Sunday of each month, computed in realm-local time with DST handled).
- **Resets** — `/reset` shows the next daily and weekly reset; announces the weekly reset when it happens.
- **Server-up watch** — after the weekly reset, polls the Blizzard API for your realm's status; if the realm goes down for maintenance, announces when it comes back up. `/status` checks the realm on demand.
- **Release notifications** — polls GitHub and announces new releases of the addon suite.

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
   docker compose up -d --build
   ```

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
| `src/commands.ts` | `/dmf`, `/reset`, `/status` handlers |
| `src/announce.ts` | Scheduler tick: DMF/reset/release announcements, realm watch |
| `src/state.ts` | Announcement dedup state (`data/state.json`) |
| `src/wow/dmf.ts` | Darkmoon Faire schedule math (timezone-correct) |
| `src/wow/reset.ts` | Daily/weekly reset math per region |
| `src/wow/realm.ts` | Blizzard OAuth + connected-realm status |
| `src/github.ts` | GitHub releases API client |
