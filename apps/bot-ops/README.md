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

The privileged work happens in `apps/warbandeer-discord/ops/bot-ops.sh`, which is deployed on the
box and is the authority on what may be read or written. This module only **calls** it over SSH:
it never runs docker and never edits the bot's `.env` itself, so bot secrets never traverse the
wire. The `OPS_FIELDS` whitelist in `ts/index.ts` mirrors that script's whitelist — when a key is
added there, add it here too.

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
    { "name": "debug", "ssh": "me@box", "remoteDir": "~/warbandeer-discord-debug" },
    {
      "name": "prod",
      "ssh": "me@box",
      "remoteDir": "~/warbandeer-discord",
      "project": "warbandeer-discord",
      "container": "warbandeer-discord"
    }
  ]
}
```

`project`/`container` default to the debug bot's and are validated to `[A-Za-z0-9._-]` — they are
interpolated into the remote docker command. The legacy flat `{ "ssh", "remoteDir" }` shape is
still accepted and read as a single `debug` target.

## Checks

```bash
cd rust && cargo test
```

```bash
npm install && npm run check
```

The module carries its own `@tauri-apps/api` because it must resolve standalone — host apps that
import it out-of-tree should `dedupe` that package so it isn't bundled twice.
