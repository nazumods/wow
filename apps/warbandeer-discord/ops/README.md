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

- **Compose project is hardcoded** (`-p warbandeer-discord-debug`): it is *not* set in a
  non-interactive SSH shell's environment, so a bare `docker compose` would default to the
  directory name and fail to see the running container.
- **`env-set` rebuilds `.env` line-by-line** (no `sed`), so a value can never inject into the
  file, and comment/blank/secret lines are preserved verbatim. A timestamped `.env.bak.<stamp>`
  is written before any change; a no-op (new value equals current) does nothing and does **not**
  restart the bot.
- Applying an env change **recreates the container** (brief restart) because env vars are frozen
  at container start; a plain `restart` would not reload them.

## Enabling the desktop Ops tab

The tab is hidden unless an `ops.json` is present. Create it in the desktop app's config dir
(`%APPDATA%\com.nazuraki.warbandeer\ops.json` on Windows), or point `WARBANDEER_OPS_CONFIG` at a
file elsewhere:

```json
{
  "ssh": "roshne@192.168.7.48",
  "remoteDir": "~/repos/wow-debug/apps/warbandeer-discord"
}
```

`remoteDir` is the bot dir on the box holding `.env` and `ops/bot-ops.sh` (this dir). The app
runs `ssh <ssh> "bash <remoteDir>/ops/bot-ops.sh …"`, reusing your existing key — so key-based
SSH to the box, as user `roshne` (in the `docker` group, no sudo), must already work. Shipped
builds without an `ops.json` never show the tab.
