# Bot ops helper

`bot-ops.sh` is the **only** privileged surface behind the Warbandeer Desktop app's **Ops**
tab. The desktop app never runs docker or edits the bot's `.env` itself — it SSHes to the box
and invokes this script, one subcommand at a time. Keeping the whitelist and the apply logic
here (versioned, reviewable) means **bot secrets never leave the box**.

## Subcommands

| Command | Does |
|---|---|
| `status` | JSON: container running?, status line, image, last-observed realm status |
| `logs [N]` | Last `N` container log lines (default 200, capped 5000), raw |
| `restart` | Restart the bot process in place (`docker compose restart`) — no env reload |
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
`BOT_BRANCH`, `COMMAND_PREFIX`. Each is validated against a format regex; an empty value clears
the key back to its documented default.

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
