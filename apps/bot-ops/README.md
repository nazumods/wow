# bot-ops

Shared module behind the operator-only **Bot Ops** panel — the screen that shows a
`warbandeer-discord` bot's container status, tails its logs, restarts it, and edits its non-secret
env keys.

Maintained here, consumed by two apps:

| App | Repo | How it consumes this module |
|---|---|---|
| `warbandeer-desktop` | `nazumods/wow` (this repo) | directly — cargo `path` dep + the `@bot-ops` vite alias |
| `wow-companion` | `roshne/wow-companion` | vendored — `npm run vendor:bot-ops` |

See [INSTALL.md](INSTALL.md) to wire it into a third app, and [CONTEXT.md](CONTEXT.md) for the
design constraints and gotchas.

## Layout

```
apps/bot-ops/
  rust/          # `bot-ops` crate — the six #[tauri::command]s and the SSH plumbing
    src/lib.rs
  ts/            # framework-agnostic frontend: wire types, OPS_FIELDS, typed invoke wrappers
    index.ts
```

There is no UI here on purpose — see [PURPOSE.md](PURPOSE.md).

## What it does not contain

The privileged work happens in a `bot-ops.sh` deployed on the box, which is the authority on what
may be read or written. This module only **calls** it over SSH: it never runs docker and never
edits the bot's `.env` itself, so bot secrets never traverse the wire. The `OPS_FIELDS` whitelist in
`ts/index.ts` mirrors that script's whitelist — when a key is added there, add it here too.

**Two `bot-ops.sh` copies exist, and they've drifted** — this module has to stay compatible with
both since it's shared:

- `apps/warbandeer-discord/ops/bot-ops.sh`, here in this repo — what `warbandeer-desktop`'s targets
  talk to. Still on the older contract: no `BOT_OPS_CONFIG_DIR`/`BOT_OPS_COMPOSE_FILE`, script
  found at `<remoteDir>/ops/bot-ops.sh`, whitelist key `GUILD_ID`.
- [`roshne/rackbops-discord-bot`'s `ops/bot-ops.sh`](https://github.com/roshne/rackbops-discord-bot/blob/main/ops/bot-ops.sh)
  — what the debug bot **instance** itself runs, confirmed cut over off `nazumods/wow` per
  `roshne/rackbops-discord-bot#2`'s closing comment (closed 2026-09-01: *"rackbops-discord-bot-debug
  has been running cleanly on nucbox since the cutover"*). Requires `BOT_OPS_CONFIG_DIR`/
  `BOT_OPS_COMPOSE_FILE`, deploys the script to a fixed shared path independent of any one
  instance's directory, whitelist key `DISCORD_SERVER_ID` (the same setting, renamed).
  `wow-companion`'s own `ops.json` has **not** been updated to point its `debug` target at this
  yet — this crate's fields exist so it *can* be, but that's a separate operator step, tracked
  (along with an open question on whether to finish the desktop tab at all vs. retire it in favor
  of a small web admin panel that fork also shipped) in
  [roshne/wow-companion#197](https://github.com/roshne/wow-companion/issues/197). **Note for a
  future reader:** #197's own *body* still reads "hasn't happened yet" — that text predates the
  cutover and was never refreshed; trust `rackbops-discord-bot#2`'s closing comment (dated after
  #197 was last touched) over #197's stale body on this specific point.

`OpsTarget`'s `configDir`/`composeFile`/`scriptPath` (all three, or none — see `parse_config`) opt
a target into the newer contract; `OPS_FIELDS` lists both `DISCORD_SERVER_ID` and `GUILD_ID` so
either script's whitelist is satisfiable. Adding a key that only one of the two scripts accepts is
fine — a save sends only the fields you actually changed, so touching one target never risks
sending a key the other target's script would reject.

## Operator gate

Every command resolves an operator-supplied `ops.json`. When it is absent, `opsConfig()` resolves
`null` and the host app hides the tab — which is why shipped builds stay dormant for end users. The
path is the first of:

1. the app-specific env var the host registered via `bot_ops::set_config_env_var(...)`
2. `BOT_OPS_CONFIG` — honoured by every host, so one file can serve several installed apps
3. `<app config dir>/ops.json`

```jsonc
{
  "targets": [
    // Older contract (e.g. nazumods/wow's own bot) — configDir/composeFile/scriptPath omitted.
    { "name": "debug", "ssh": "me@box", "remoteDir": "~/warbandeer-discord-debug" },
    {
      "name": "prod",
      "ssh": "me@box",
      "remoteDir": "~/warbandeer-discord",
      "project": "warbandeer-discord",
      "container": "warbandeer-discord"
    },
    // Newer contract (e.g. rackbops-discord-bot's install.sh layout) — all three set together.
    {
      "name": "rackbops-debug",
      "ssh": "me@box",
      "remoteDir": "/opt/rackbops-discord-bot/bin",
      "project": "rackbops-discord-bot-debug",
      "container": "rackbops-discord-bot-debug",
      "configDir": "/opt/rackbops-discord-bot/debug",
      "composeFile": "/opt/stacks/rackbops-discord-bot-debug/docker-compose.yml",
      "scriptPath": "/opt/rackbops-discord-bot/bin/bot-ops.sh"
    }
  ]
}
```

`project`/`container` default to the debug bot's and are validated to `[A-Za-z0-9._-]` — they are
interpolated into the remote docker command. The legacy flat `{ "ssh", "remoteDir" }` shape is
still accepted and read as a single `debug` target. `configDir`/`composeFile`/`scriptPath` are
optional but must be set together (all three or none) — a partial set is rejected at parse time.
When set, `scriptPath` is used verbatim as the remote script path instead of deriving
`<remoteDir>/ops/bot-ops.sh`, and `configDir`/`composeFile` are sent as `BOT_OPS_CONFIG_DIR`/
`BOT_OPS_COMPOSE_FILE`. `remoteDir` is still required even then (`name`/`ssh`/`remoteDir` are the
three fields every target needs), but once `scriptPath` is set it's not actually used for
anything — the `"rackbops-debug"` example above sets it to `remoteDir`'s closest real equivalent
(the directory `bot-ops.sh` itself lives in) so the value isn't misleading, not because it does
anything.

## Checks

```bash
cd rust && cargo test
```

```bash
npm install && npm run check
```

The module carries its own `@tauri-apps/api` because it must resolve standalone — host apps that
import it out-of-tree should `dedupe` that package so it isn't bundled twice.
