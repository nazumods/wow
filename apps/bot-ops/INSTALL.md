# Installing bot-ops into a Tauri app

Two halves, wired independently. Both are needed for a working panel.

## 1. Rust — the commands

**In this repo** (`apps/*`), a path dependency:

```toml
# src-tauri/Cargo.toml
[dependencies]
bot-ops = { path = "../../bot-ops/rust" }
```

**In another repo**, vendor the `rust/` directory (see [Vendoring](#vendoring)) and point the path
dependency at the vendored copy.

Then register the commands. Note the `commands::` segment — it is load-bearing:

```rust
pub fn run() {
    bot_ops::set_config_env_var("MY_APP_OPS_CONFIG"); // optional; BOT_OPS_CONFIG always works

    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            bot_ops::commands::ops_config,
            bot_ops::commands::bot_status,
            bot_ops::commands::bot_logs,
            bot_ops::commands::bot_restart,
            bot_ops::commands::bot_env_get,
            bot_ops::commands::bot_env_set,
            // ...the app's own commands
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

`set_config_env_var` is only needed to keep an app's pre-existing override name working. Call it
once, before any command runs; later calls are ignored so the app can't be re-pointed mid-run.

## 2. TypeScript — the API

**Out-of-tree** (same repo, different directory): alias it, and dedupe the Tauri API so the
module's own copy isn't bundled alongside the app's.

```ts
// vite.config.ts
resolve: {
  alias: { "@bot-ops": fileURLToPath(new URL("../bot-ops/ts/index.ts", import.meta.url)) },
  dedupe: ["@tauri-apps/api"],
},
server: { fs: { allow: [".."] } },  // dev server must be allowed to serve above the app root
```

```jsonc
// tsconfig.json
"baseUrl": ".",
"paths": { "@bot-ops": ["../bot-ops/ts/index.ts"] },
"include": ["src/**/*.ts", "../bot-ops/ts/*.ts"]
```

Run `npm install` in `apps/bot-ops` once — the module resolves `@tauri-apps/api` from its own
`node_modules`, which is what lets it typecheck standalone.

**Vendored**: the copy lands inside the app's own `src/`, so none of the above applies — import it
by relative path and let normal resolution find the app's `@tauri-apps/api`.

## 3. The panel

Not provided — write it in whatever framework the app uses. Import the pieces that must not
diverge:

```ts
import {
  opsConfig, botStatus, botLogs, botRestart, botEnvGet, botEnvSet,
  changedFields, OPS_FIELDS,
  type OpsTargetInfo, type BotStatus, type EnvSetResult,
} from "@bot-ops";
```

Gate rendering on `opsConfig()`: `null` means ops mode is off and the tab must stay hidden. Use
`changedFields(env, draft)` for the dirty set rather than re-deriving it — a missing `?? ""` on
either side makes an untouched blank field look dirty.

Existing panels to copy from:

- `apps/warbandeer-desktop/src/lib/components/BotOps.svelte`
- `wow-companion/src/components/BotOps.tsx`

## Vendoring

For an app in another repo, mirror what `wow-companion` does: a script that fetches
`apps/bot-ops/{rust,ts}` from `nazumods/wow` at development time, writes it under a `vendor/`
directory with a `VENDORED.md` and a recorded source commit, and commits the result. A `--check`
mode that reports drift without writing lets a scheduled watch flag staleness.

Fetch at development time and commit the result — the build must never touch the network. See
`wow-companion/scripts/vendor-bot-ops.mjs`.
