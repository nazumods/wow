# Bot ops helper

`bot-ops.sh` is the **only** privileged surface behind the **Ops** tab — shipped by two apps
(`apps/warbandeer-desktop` here and `roshne/wow-companion`), which share one backend in
[`apps/bot-ops`](../../bot-ops/README.md). Neither app runs docker or edits the bot's `.env`
itself — they SSH to the box and invoke this script, one subcommand at a time. Keeping the
whitelist and the apply logic here (versioned, reviewable) means **bot secrets never leave the
box**.

This script is the **authority** on which keys may be written; `apps/bot-ops`'s `OPS_FIELDS` only
mirrors it for display. Add a key here first — a key added only to the module is rejected at apply
time, not silently written.

## Subcommands

| Command | Does |
|---|---|
| `status` | JSON: container running?, status line, image, last-observed realm status |
| `logs [N]` | Last `N` container log lines (default 200, capped 5000), raw |
| `restart` | Restart the bot process in place (`docker compose restart`) — no env reload |
| `rebuild` | Pull the checkout, then `up -d --build` with a fresh `GIT_SHA` — the bot comes back on **new code**. JSON with before/after sha |
| `env-get` | JSON of the **non-secret** editable env keys and their current values |
| `env-set` | Read `KEY=VALUE` lines from **stdin**, validate, back up `.env`, apply real changes, then `up -d --force-recreate` to load them |

Run directly on the box to test:

```sh
bash ~/repos/wow-debug/apps/warbandeer-discord/ops/bot-ops.sh status
echo "RELEASE_ANNOUNCE_CHANNEL_ID=1529152068055728330" | bash .../bot-ops.sh env-set
```

## Editable keys (whitelist)

`ANNOUNCE_CHANNEL_ID`, `RELEASE_ANNOUNCE_CHANNEL_ID`, `GUILD_ID`, `REPORT_ROLE_ID`,
`ADMIN_USER_IDS`, `WOW_REALM`, `WOW_REGION`, `WATCHED_REPOS`, `DMF_TIMEZONE`, `AUTO_UPDATE`,
`REDEPLOY_SUPERVISOR`, `BOT_BRANCH`, `COMMAND_PREFIX`. Each is validated against a format regex; an
empty value clears the key back to its documented default.

**Secrets are intentionally absent** — `DISCORD_TOKEN`, `BLIZZARD_CLIENT_ID`,
`BLIZZARD_CLIENT_SECRET`, `GITHUB_TOKEN`, `CLOUDFLARE_TUNNEL_TOKEN`. `env-get` never reads them
out and `env-set` refuses to write them. Edit those by hand with `nano` on the box.

## Safety notes

- **Compose project + container come from `BOT_OPS_PROJECT` / `BOT_OPS_CONTAINER`** (a panel passes
  them per selected bot), defaulting to the debug bot's `warbandeer-discord-debug` /
  `warbandeer-discord`. The project must be passed with `-p` because it is *not* set in a
  non-interactive SSH shell's environment (a bare `docker compose` would default to the directory
  name and miss the running container); both are validated to a safe charset before use.
- **`env-set` rebuilds `.env` line-by-line** (no `sed`), so a value can never inject into the
  file, and comment/blank/secret lines are preserved verbatim. A timestamped `.env.bak.<stamp>`
  is written before any change; a no-op (new value equals current) does nothing and does **not**
  restart the bot.
- Applying an env change **recreates the container** (brief restart) because env vars are frozen
  at container start; a plain `restart` would not reload them.
- **`rebuild`'s pull is best-effort, not fatal.** `--ff-only` fails by design on a checkout
  carrying local commits — the debug bot's exact shape (a worktree on `local` with unpushed work) —
  and refusing to build there would make the subcommand useless on the deploy that most needs it.
  A failed pull is reported as `pulled: false` with its log, and the tree is rebuilt as it stands.
  `GIT_SHA` comes from the resulting `HEAD`, so the bot's own follow-up still names the true build.

## Redeploy on exit 76

`/update` can only ask to be replaced — the bot has no host access, and mounting the docker socket
into the container would hand it root-equivalent control of the box. So a stale build exits **76**
("rebuild me") and `bot-redeploy-watch.sh` is the host half that turns that into `bot-ops.sh
rebuild`. Without it installed, `/update` still works exactly as it did before: the container
respawns on the same image and the bot's follow-up reports the no-op honestly — and `/update`
says up front that no supervisor is configured (set `REDEPLOY_SUPERVISOR=true` once it is).

The watcher reads the **Docker event stream**, because `restart: unless-stopped` respawns the
container on any exit code without ever showing that code to a parent process — the event stream
is the only place it's observable from the host.

**The respawn races the rebuild, by design.** Docker brings the old image straight back up, then
the rebuild recreates the container on the new one seconds later, so an update bounces the bot
twice. That's the cost of keeping `unless-stopped`, and it's the right trade: if the watcher is
dead or absent, the bot still comes back.

Install (one unit per bot — two bots means two copies under distinct names):

```sh
sudo cp ops/bot-redeploy-watch.service /etc/systemd/system/
sudoedit /etc/systemd/system/bot-redeploy-watch.service   # User, paths, BOT_OPS_* for this target
sudo systemctl daemon-reload
sudo systemctl enable --now bot-redeploy-watch
journalctl -u bot-redeploy-watch -f
```

Then set `REDEPLOY_SUPERVISOR=true` in the bot's `.env` (it's on the editable whitelist, so the Ops
panel can do it) so `/update` stops warning that nothing will rebuild the image.

## Enabling a panel + choosing a bot (debug/prod)

The Ops tab is hidden unless an `ops.json` is present — in the app's config dir
(`%APPDATA%\com.nazuraki.warbandeer\ops.json` for **warbandeer-desktop**;
`%APPDATA%\com.roshne.wowcompanion\ops.json` for **wow-companion**), or at the path in the app's
config env var (`WARBANDEER_OPS_CONFIG` / `WOW_COMPANION_OPS_CONFIG`).

**Multi-target format** — list the bots you manage; the panel shows a target (debug/prod) switch:

```json
{
  "targets": [
    {
      "name": "debug",
      "ssh": "roshne@192.168.7.48",
      "remoteDir": "~/repos/wow-debug/apps/warbandeer-discord",
      "project": "warbandeer-discord-debug",
      "container": "warbandeer-discord"
    },
    {
      "name": "prod",
      "ssh": "nazu@your-prod-host",
      "remoteDir": "~/path/to/apps/warbandeer-discord",
      "project": "warbandeer-discord",
      "container": "warbandeer-discord"
    }
  ]
}
```

Per target: `name` (the switch label), `ssh` (SSH destination), `remoteDir` (the bot dir on that
host holding `.env` + `ops/bot-ops.sh`), and the compose `project` / `container` (optional; default
to the debug bot's `warbandeer-discord-debug` / `warbandeer-discord`). The panel runs
`ssh <ssh> "BOT_OPS_PROJECT=<project> BOT_OPS_CONTAINER=<container> bash <remoteDir>/ops/bot-ops.sh …"`,
reusing your existing key — so key-based SSH to that host (as a user in the `docker` group, no sudo)
must already work.

The old single-bot shape still works: `{ "ssh": "...", "remoteDir": "..." }` is read as one `debug`
target. Shipped builds without an `ops.json` never show the tab.

### Breadcrumbs for prod (nazu)

The `prod` entry above is a **placeholder** — in the shipped setup only the `debug` target is live
(it's on roshne's box; nazu's prod runs on a separate deployment). To manage your own prod bot:

1. Add a target with **your** prod host's `ssh` + `remoteDir`, set `project` to prod's compose
   project (the plain `warbandeer-discord` if you didn't start it with `-p …-debug`) and `container`
   to its `container_name`.
2. Make sure **this helper is deployed at that host** as `<remoteDir>/ops/bot-ops.sh` — it ships in
   the repo, so a `git pull` on the prod host puts it there — and that key-based SSH to the host
   works.

Nothing else is bot-specific: the helper reads its `.env` + `docker-compose.yml` from `remoteDir` and
acts on the compose `project` you pass. Secrets are still never read or written (whitelist only).
