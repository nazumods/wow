# Warbandeer Discord Bot

Discord bot for the guild channel: WoW timers and announcements.

## Features

- **Darkmoon Faire** — `/dmf` shows when the Faire opens/closes; announces in the channel when it opens (first Sunday of each month, computed in realm-local time with DST handled).
- **Resets** — `/reset` shows the next daily and weekly reset; announces the weekly reset when it happens.
- **Server status** — continuously polls the Blizzard API for your realm's status and announces whenever it goes **down** or comes back **up** — for any outage, not just weekly-reset maintenance. `/status` checks the realm on demand.
- **Release notifications** — polls GitHub and announces new releases. Watches this repo by default, or any list of repos you configure (e.g. ActionBarMaster too).
- **Self-update** — `/update` (admins only) builds the latest code and moves the bot onto it, with nothing outside Discord involved. It verifies the new build before retiring the old one, so a bad build leaves the bot running, and messages you with the build it actually landed on. See [Self-update](#self-update).
- **Transmog import strings** — `/transmog <character> <realm>` returns a `/customset v1 …` string for what a character is wearing, pasteable into `/collected outfit import`. For the characters you *can't* inspect in-game: offline, another realm, or a name someone pasted in chat. Needs the same Blizzard API credentials as realm status. Two caveats it states in every reply: weapon illusions aren't in the profile data, and profile data is a snapshot from the character's **last logout** — so someone online right now reports what they wore last session.
- **Issue reports** — `/report` lets members with a configured role file a GitHub issue (Title + Description via a popup form) straight into the mapped project's repo (`wow`, `abm`), labeled `automated` and noting who filed it. The confirmation posts **in the channel the report was filed from**, carrying the title, the description and the issue link, so the channel can see what's been raised.

All times are posted as Discord timestamps, so everyone sees them in their own timezone.

## Setup

1. **Create the Discord application** at <https://discord.com/developers/applications>: add a **Bot**, copy its **token**, and invite it with this URL (replace `CLIENT_ID` with the application ID):

   ```
   https://discord.com/oauth2/authorize?client_id=CLIENT_ID&scope=bot+applications.commands&permissions=2048
   ```

   (`2048` = Send Messages. No privileged intents are needed.)

2. **Configure**: copy `.env.example` to `.env` and fill it in. `DISCORD_TOKEN` and `ANNOUNCE_CHANNEL_ID` are required (right-click a channel → Copy Channel ID, with Developer Mode enabled). Set `RELEASE_ANNOUNCE_CHANNEL_ID` to post release notifications to their own channel (optional — they go to `ANNOUNCE_CHANNEL_ID` if unset). Set `WATCHED_REPOS` (comma-separated `owner/repo`) to announce releases from more repos than just this one (e.g. `nazumods/wow,roshne/ActionBarMaster`). A watched repo the bot can't see — misspelled, deleted, or private to its `GITHUB_TOKEN` — is skipped with a single warning rather than failing on every poll, and starts announcing on its own if it later becomes visible. Set `GUILD_ID` so slash commands register instantly. For `/status` and server-up announcements, create a client at <https://develop.battle.net> and set `BLIZZARD_CLIENT_ID`, `BLIZZARD_CLIENT_SECRET`, and `WOW_REALM`. To enable `/report`, set `REPORT_ROLE_ID` (the Discord role allowed to file reports) and give `GITHUB_TOKEN` a PAT with **issues:write** on the reportable repos. To run a second **debug/staging** bot in the same server, set `COMMAND_PREFIX` (e.g. `r_`) so its commands register as `/r_dmf`, `/r_reset`, `/r_status` instead of colliding with the live bot's — lowercase only (Discord rule).

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

`/update` (admins only) takes the bot all the way to the new build on its own. Nothing outside the container is involved: no host service, no SSH session, nobody running `--build`.

It works by **starting the replacement before retiring the original**, which is what makes it safe:

1. **Build.** The bot builds a new image through the Docker daemon. It's fully alive for this, so a build failure is reported straight back to you and nothing else happens.
2. **Start alongside.** It creates a second container on the new image. Created by the daemon, that container is a sibling — nothing about its lifetime is tied to the bot's.
3. **Verify.** The new instance has to complete a Discord gateway login to count as working. Until it does it stays in standby: connected, but answering nothing.
4. **Retire.** The verified new instance stops and removes the old container, takes its name, and goes active.

If step 3 doesn't happen, the new container is removed and **the original keeps running** and tells you why. Rollback is the normal case, not a recovery procedure.

Setup — the whole of it is `docker compose up -d`:

1. Set `ADMIN_USER_IDS` to a comma-separated list of Discord user IDs (right-click a user → **Copy User ID**, with Developer Mode on). This is an explicit ID allowlist rather than a role check — roles get reassigned and inherited; the list only changes when you edit `.env`. It fails closed: with none set, `/update` is refused for everyone.
2. Build with `GIT_SHA` as above.
3. Optionally set `AUTO_UPDATE=true` to update as soon as a newer build exists, without waiting for `/update`. **Off by default.**

There is no key to set to enable any of this. The bot discovers its own compose project, volumes, network and container name from its own container through the daemon, so there is nothing to configure and nothing to keep in sync.

**What it costs.** The compose file mounts `/var/run/docker.sock` into the bot. That is root-equivalent access to the host, accepted deliberately: it's the only way `/update` completes with nothing installed outside the container. Two things follow from it, and both belong in the open:

- **Anyone with push access to `BOT_BRANCH` on `GITHUB_REPO` can get root on the box.** The build uses a remote git context, so whatever that branch contains is what gets built and run against the socket — via `/update`, or automatically with `AUTO_UPDATE=true`. The *trigger* is admin-gated; the *content* is gated only by who can push to that branch. Treat push access to it accordingly.
- The container **starts** as root, but only for its entrypoint: the socket's owning group has a host-specific GID (115 here, 999 on stock Debian), so the entrypoint reads the GID off the socket itself, then drops to the `bun` user carrying that one group before the bot runs. No GID to configure, and the long-running process stays non-root — though that is hygiene, not a boundary: whoever holds the socket is root-equivalent regardless.

`GITHUB_REPO` must also be **publicly clonable** — the daemon fetches the build context itself, with no credentials. On a private repo the build fails with an opaque error rather than a hint about auth.

If you don't want any of this, remove the socket mount — the bot detects its absence and falls back to the older behaviour of exiting with code **75** for a supervisor to replace it, which needs one of:

- a manual redeploy with `GIT_SHA=$(git rev-parse HEAD) docker compose up -d --build`, or
- an image-updating supervisor (e.g. Watchtower) against a registry image that CI builds.

Behavior:

- Staleness is "my build doesn't **contain** the newest commit on `BOT_BRANCH` (default `main`) touching `apps/warbandeer-discord`", checked at startup and every 15 minutes when `AUTO_UPDATE=true`, and on demand via `/update`.
- It's a containment question, not an equality one, because `GIT_SHA` is the tip you built from and non-bot commits land on `main` most days — so the sha you built is usually *newer* than the last bot-touching commit, not equal to it. When the two differ the bot asks GitHub's compare endpoint how they relate: if your build is `ahead` of (or identical to) the newest bot commit it's **current**; only `behind` or a diverged side branch counts as stale.
- `BOT_BRANCH` must name a branch that exists on `GITHUB_REPO` — it's queried through the GitHub API, so a branch that only exists on your machine can't be used. Point a staging deploy at its own pushed branch.
- A deploy running **unpushed** commits is recognised rather than mishandled: the compare comes back 404, and self-update reports itself **disabled naming the sha** instead of offering an update it could never deliver. You no longer need to build without `GIT_SHA` to get sane behaviour there.
- If the compare call fails (GitHub down, rate limited), the check falls back to treating a sha mismatch as stale — the pre-existing behaviour — rather than failing startup.
- The overlap is silent. Both containers hold the same `DISCORD_TOKEN`, and Discord delivers every event to both sessions, so the standby registers no commands, no handlers and no scheduler until it has taken over. You won't see doubled replies or doubled announcements.
- The two containers never write `data/state.json` at once: the original stops its scheduler before the replacement starts, and the handoff signal is a separate file with one writer.
- Each build is also tagged with its short sha, and the newest three are kept — so the previous build stays on disk and addressable if you ever need to pin back to it.
- A swap never lands mid-announcement: it waits for the in-flight tick and its `data/state.json` write to finish.
- A second `/update` while a swap is in flight is **refused**, not queued — it would otherwise tear down the in-flight replacement.
- Every wait has an end: if a replacement verifies but then never manages to retire the original (daemon trouble mid-swap), the original reclaims after 3 minutes and reports, rather than sitting quiesced until someone notices.
- Without the daemon socket the bot exits with code **75** instead (distinct from a crash, so a supervisor can tell an update apart from a failure).
- **Once it's back up, it messages whoever ran `/update`** with the build it actually came back on, and which of three things happened:
  - ✅ **updated** — came back on the build it was picking up.
  - ⚠️ **no-op** — came back on the *same* build it left on, i.e. nothing was rebuilt. This is the failure that otherwise looks exactly like success: a container recreated without `--build` comes back happily on the old image and logs a clean startup. (With the socket mounted this shouldn't happen — the bot builds the image itself.)
  - ❓ **unexpected** — came back on some third build, so something else deployed in between.
- That follow-up survives the restart (it's recorded in `data/state.json`, not held in memory), and it tries the original command's reply first, then a DM, then the channel. An expired reply token, closed DMs, or a deleted channel just log — they never hold up or crash startup.
- Only a restart **`/update` asked for** produces a follow-up. An `AUTO_UPDATE` exit, a host reboot, or a plain `docker compose up` stays silent.
- If the bot exits to update and comes back on the same build, it says so once in the log and **stops trying** — a misconfigured deploy produces a warning, not a restart loop. `/update` overrides that suppression.
- Without `GIT_SHA` — or with one the remote has never seen — self-update reports itself disabled rather than guessing, and says which of the two it is.

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
- A filed `/report` is **public in the channel it was filed from** — that's the point of it, so the channel knows what's been raised, but it does mean a report is visible to everyone who can see that channel. `/report` stays role-gated via `REPORT_ROLE_ID`. Only the outcome is public: being refused for a missing role, or for an unconfigured bot, is still shown to you alone. Mentions in a report never ping — an `@everyone` typed into the form renders as text. A description too long for Discord's 2000-character message limit is truncated with a note, and the issue itself always has the full text.

## Files

| File | Responsibility |
|---|---|
| `src/index.ts` | Client login, command registration, interaction routing (commands + `/report` modals) |
| `src/config.ts` | Env config (`.env`); `/report` project→repo map |
| `src/commands.ts` | `/dmf`, `/reset`, `/status`, `/transmog`, `/update`, `/report` handlers |
| `src/wow/transmog.ts` | `/transmog` — equipment → `/customset` import string, realm slugs, reply text |
| `src/wow/blizzard.ts` | Shared Blizzard client-credentials token |
| `src/report.ts` | `/report` — role gate, modal form, files a GitHub issue, announces it in the channel |
| `src/announce.ts` | Scheduler tick: DMF/reset/release announcements, realm watch |
| `src/update.ts` | Self-update: staleness check against the bot's newest commit |
| `src/redeploy.ts` | The swap: builds the new image, starts the replacement, hands over |
| `src/handoff.ts` | Standby/verify/retire protocol shared by both instances |
| `src/docker.ts` | Docker Engine API client over the daemon socket |
| `src/updateReport.ts` | The follow-up after a `/update` restart: which build it came back on |
| `src/restart.ts` | Graceful restart, deferred past in-flight announcements |
| `src/state.ts` | Announcement dedup state (`data/state.json`) |
| `src/wow/dmf.ts` | Darkmoon Faire schedule math (timezone-correct) |
| `src/wow/reset.ts` | Daily/weekly reset math per region |
| `src/wow/realm.ts` | Blizzard OAuth + connected-realm status |
| `src/github.ts` | GitHub API: releases + `/report` issue creation |
