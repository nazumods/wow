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
| `env-get` | JSON of the **non-secret** editable env keys and their current values |
| `env-set` | Read `KEY=VALUE` lines from **stdin**, validate, back up `.env`, apply real changes, then `up -d --force-recreate` to load them |
| `migrate` | **One-time.** Move `.env` + `docker-compose.yml` out of the checkout into the config dir, repoint the build context, recreate, and delete the checkout's `.env` |

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
  file, and comment/blank/secret lines are preserved verbatim. A timestamped backup is written
  before any change; a no-op (new value equals current) does nothing and does **not** restart the
  bot.
- **Backups land beside `.env`**, as `.env.bak.<stamp>` (`0600`), wherever `.env` itself lives. Once
  the config dir is outside the checkout there is nothing to hide the backup from — and relocating
  the backup while leaving the actual secret file behind was never the fix. The path is returned in
  `env-set`'s JSON so the panels show where it went.
- Applying an env change **recreates the container** (brief restart) because env vars are frozen
  at container start; a plain `restart` would not reload them.

## Where running config lives

`.env` and `docker-compose.yml` belong in the **config dir** —
`WARBANDEER_DISCORD_CONFIG_DIR`, default `/opt/warbandeer-discord/<project>` — not in the checkout.
The path must be **absolute**, so a relative value can't quietly resolve back into the checkout from
whatever cwd a non-interactive SSH call lands in.

**They move together, and the script enforces it.** Compose resolves `env_file: .env` relative to
*the compose file*, not the working directory — and `docker compose --env-file` does not change that
(it controls variable interpolation, a different mechanism). Splitting the pair would silently feed
the bot a different `.env` than the one `env-set` edits, so a config dir holding one without the
other is a hard error.

A checkout that still holds `.env` keeps working: the script falls back to it and prints a one-line
notice on **stderr** (never stdout, which is a JSON contract the panels parse). That is a
compatibility path for un-migrated hosts and for running from source — not a second supported mode.
`status` reports `configDir` and `migrated` so you can see which is in play.

### Migrating a deployment

Once, when you decide to — nothing relocates itself at startup, because silently moving a file full
of live tokens is a bad surprise and would be wrong in a dev checkout where config legitimately
belongs. Creating the directory is the only step needing root:

```sh
sudo install -d -o "$USER" -g "$USER" -m 700 /opt/warbandeer-discord/warbandeer-discord-debug
bash ~/repos/wow-debug/apps/warbandeer-discord/ops/bot-ops.sh migrate
```

`migrate` copies both files, repoints `build: context:` at the checkout (there is no published image
to reference yet), validates the result with `docker compose config` **before** touching the running
container, recreates it, and only then deletes the checkout's `.env`. If the recreate fails, nothing
is removed.

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
