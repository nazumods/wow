# bot-ops — context

Design constraints and the things that bit us. Read before changing the crate's shape or the
install contract.

## Why the commands live in `bot_ops::commands`, not at the crate root

`#[tauri::command]` expands to a `#[macro_export]`ed `__cmd__<name>` macro *and* a `pub use` of it
from the defining module. `#[macro_export]` places the macro at the **crate root**, so when the
commands themselves sit at the crate root those two collide:

```
error[E0255]: the name `__cmd__bot_status` is defined multiple times
```

It never showed up before the extraction because the commands used to live in an app's
`mod botops`, one level down. Nesting them in `pub mod commands` restores that. Hosts therefore
register `bot_ops::commands::bot_status`, not `bot_ops::bot_status`.

Do not add a `pub use commands::*;` at the crate root as a convenience — it re-imports the same
macros and reintroduces the collision.

## Why the config env var is a `OnceLock`, not a command argument

The two apps arrived with different override names (`WARBANDEER_OPS_CONFIG`,
`WOW_COMPANION_OPS_CONFIG`), and breaking either would strand an operator's existing setup. The
name is registered once from Rust at startup rather than passed per call, because the frontend
must not get to choose which file the backend reads — that would turn the gate into an arbitrary
file-read primitive.

`BOT_OPS_CONFIG` is checked as a fallback for every host, so an operator running both apps can
keep one `ops.json`.

## Why the module carries its own `@tauri-apps/api`

`ts/index.ts` is imported by `warbandeer-desktop` from **outside** that app's directory. Node
resolution — and therefore both tsc and rollup — walks up from the *importing file*, so it never
reaches `apps/warbandeer-desktop/node_modules`. A `paths` mapping silences tsc but not rollup, and
the build fails with `Rollup failed to resolve import "@tauri-apps/api/core"`.

So the module has its own `package.json` + `node_modules`. The cost is a duplicate copy in the
bundle unless the host sets `resolve.dedupe: ["@tauri-apps/api"]` — do that.

Vendored consumers never hit this: the copy lands inside their own `src/`.

## Why there is no shared UI

Svelte 5 runes in one app, React hooks in the other. A shared component would mean adopting a
third rendering layer in both, for one operator-only screen. The state machine is small; what
actually drifted between the copies was the **field list** and the **wire types**, and those are
shared now. `changedFields()` is here for the same reason — it is the one piece of view logic
with a real correctness trap (the `?? ""` on both sides).

If a third app ever needs the panel, revisit: at three copies a headless controller starts to pay
for itself.

## The whitelist is a mirror, not the authority

`OPS_FIELDS` mirrors the key whitelist in `apps/warbandeer-discord/ops/bot-ops.sh`. That script
runs on the box and is the thing that actually enforces which keys may be written — adding a key
here without adding it there gets a rejection at apply time, not a silent write. Secrets are
absent from both by design.

## Vendoring is one-directional

`nazumods/wow` is the source; `roshne/wow-companion` vendors. Never edit the vendored copy — the
next `npm run vendor:bot-ops` overwrites it, and `--check` will report drift in the meantime.
Changes start here.
