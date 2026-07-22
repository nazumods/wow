# apps/warbandeer-desktop

> **Purpose:** Tauri 2 + Svelte 5 desktop companion (not an addon — lives under `apps/`, excluded from the addon release pipeline). The Rust backend loads `Warbandeer_Characters.lua` SavedVariables by executing it in an embedded Lua 5.1 VM (`mlua`, vendored) and deserializing the `WarbandeerCharDB` global, lists/summarizes `Logs/WoWCombatLog*.txt`, and reads/writes `character-list-order.txt` (character-select reordering, ported from the retired standalone WarbandeerCharacterSort WPF app). The frontend mirrors the Warbandeer addon's Overview view in the "void-dark" theme. Tabs: **Overview**, **Logs**, **Sort**, and an operator-only **Ops** tab (hidden unless `ops.json` is present) that drives the `warbandeer-discord` bot on the box over SSH.

## Files

| File | Purpose |
|---|---|
| **Rust backend (`src-tauri/`)** | |
| `src/lib.rs` | Tauri builder — registers the 14 commands (see command surface) |
| `src/main.rs` | Thin entry point calling `lib.rs::run()` |
| `src/wow.rs` | Locate `_retail_` (override/`WOW_DIR` → exe/cwd ancestor with `WTF/Account` → default install path); find SavedVariables per account; list accounts with an order file |
| `src/savedvars.rs` | `load_char_db(path)` — exec the file in a fresh `mlua` Lua 5.1 VM, deserialize global `WarbandeerCharDB` via `LuaSerdeExt` |
| `src/model.rs` | Typed **subset** of `WarbandeerCharDB` (serde, unknown fields ignored): warband gold/week, per-char basic/spec/professions/equipment/currency/playtime/reputations/guid |
| `src/overview.rs` | `get_overview` — computes the Overview payload (stat strip, best-standing-per-faction reps, top char per class); mirrors `Warbandeer/views/Overview.lua` + `overview/TopAlts.lua` + `FactionBars.lua`. Has an end-to-end test against the live install (skips if none) |
| `src/combatlog.rs` | `list_combat_logs` (newest first) + `summarize_combat_log` — streaming CLEU parse: unique `ENCOUNTER_START` names, damage-by-source top 10 |
| `src/charorder.rs` | Parse/resolve/save `character-list-order.txt` + the remembered-order file; timestamped backups; extensive unit tests |
| `src/staticdata.rs` | Offline lookup layer — `data/static-data.json` embedded via `include_str!`, parsed once into a `OnceLock`. `currency(id)` resolves a currency id to name / icon name / cap / quality. Generated data, never hand-edited |
| `src/botops.rs` | Operator-only: `ops_config` gate + `bot_status`/`bot_logs`/`bot_restart`/`bot_env_get`/`bot_env_set`, all shelling `ssh` to the box's `apps/warbandeer-discord/ops/bot-ops.sh` (the only privileged surface). **Multi-target**: `ops.json` lists bots (debug/prod, each ssh/remoteDir + compose project/container); every command takes a `target` index and passes `BOT_OPS_PROJECT`/`BOT_OPS_CONTAINER`. Legacy flat `{ssh,remoteDir}` = one `debug` target. Config from the app config dir or `WARBANDEER_OPS_CONFIG`; absent ⇒ `ops_config` returns `None` and the tab stays hidden. Unit tests for multi/flat parse, injection-reject + payload deser |
| **Svelte frontend (`src/`)** | |
| `main.ts`, `App.svelte` | Mount; titlebar (version via `getVersion()`, account), tab switch, load/refresh, error state |
| `lib/api.ts` | Thin typed `invoke()` wrappers, one per Rust command |
| `lib/types.ts` | TS mirrors of the Rust serde structs — **kept in sync by hand** with `overview.rs`/`combatlog.rs`/`charorder.rs` |
| `lib/theme.ts` | WoW class colors by `classKey` + ilvl tier colors (mirrors addon `data.lua` gearTiers) |
| `lib/format.ts` | Gold/hours/bytes formatting matching the addon (`en-US` thousands separators) |
| `lib/sort.ts` | Pure sort engine for the Sort tab: `SortMode`, `applySort`, `applyLocked`, gap-rank math (`assignPositions`/`gapRanksFromOrder`), remembered profession-primary choices (localStorage) |
| `lib/components/Overview.svelte` | 3-column mirror of the addon Overview (StatCard × 3 + FactionBars + Achievements + TopCharacters) |
| `lib/components/CombatLogPanel.svelte` | Log file list + on-demand summary |
| `lib/components/CharacterSort.svelte` | Sort tab controller (751 lines, the big one): account picker, sort/lock/gap state, drag-and-drop, Save to WoW / Remember this order |
| `lib/components/ProfessionChoiceDialog.svelte` | Modal asking which of two crafting professions leads (dual-crafter ambiguity) |
| `lib/components/Achievements.svelte` | Placeholder — achievements aren't in SavedVariables |
| `lib/components/BotOps.svelte` | Operator-only Ops tab: a target (debug/prod) selector when >1 bot, status bar (running/realm), restart (confirmed), an env form over the non-secret whitelist (dirty-tracked, apply → recreate, confirmed), and a log tail. `App.svelte` renders it before the WoW-data gate so it works with no install |
| **Generated data** | |
| `src-tauri/data/static-data.json` | **Generated** currency lookup bundle (~220 KB, 1,490 rows) from wago.tools `CurrencyTypes` + the `interface/icons/` listfile. Records its source build, carries no timestamp (so an unchanged build regenerates byte-identically) |
| `tools/update-static-data.ps1` | The generator — pins a wago build, asserts the DB2 schema, resolves `InventoryIconFileID` → icon name, guards row floor / deletion % / icon-resolution %. `-Check` is the staleness gate, `-CacheDir` avoids refetching the ~2 MB listfile |
| `tools/UPDATING.md` | Regeneration workflow, guard rationale, and the release-trigger warning |
| `../../.github/workflows/update-static-data.yml` | **Weekly** refresh → PR only when the data changed; runs `cargo test --lib staticdata` against the fresh asset. Never auto-merged (see Gotchas) |
| **Build & release** | |
| `vite.config.ts`, `svelte.config.js`, `tsconfig*.json` | Vite on fixed port 1420 (`strictPort`), `src-tauri/` excluded from watch |
| `src-tauri/tauri.conf.json` | `productName` "Warbandeer", **`version` = release source of truth**, `bundle.active: false` (portable exe only) |
| `src-tauri/Cargo.toml` | mlua `lua51`+`vendored`+`serialize`; size-optimized release profile |
| `scripts/gen-icon.mjs` | Regenerates the placeholder `icons/source.png` (`npm run icon:source`); `npm run icon` derives `src-tauri/icons/` from it |
| `../../.github/workflows/app-test.yml` | PR/push gate: `svelte-check`, frontend build, `cargo test`, `cargo check`, clippy (`-D warnings`) — windows-latest |
| `../../.github/workflows/app-release.yml` | Release on push to `main` touching the app (md-only ignored): builds portable exe, GitHub release tagged `app-warbandeer-desktop-v<version>` with asset `Warbandeer-v<version>-portable.exe` |

## Data flow

`WTF/Account/<acct>/SavedVariables/Warbandeer_Characters.lua` → `wow::find_retail_dir` + `find_saved_var` → `savedvars::load_char_db` (mlua exec + serde) → typed `model::CharDb` → command builds a serde-`camelCase` payload → frontend `lib/api.ts` `invoke()` → Svelte 5 `$state` in `App.svelte` / `CharacterSort.svelte` (no store library — plain runes). `App.svelte` fetches Overview + log list once on mount (`$effect`) and on the ⟳ button; the Sort tab loads lazily per account.

## Tauri command surface

All commands take an optional `wowDir` override (frontend always passes `null` today; `WOW_DIR` env var works too). Errors are `Result<_, String>` — surfaced verbatim in the UI.

| Command | Returns | Notes |
|---|---|---|
| `get_overview` | `Overview` | Picks the account whose SavedVariables file is most recently modified |
| `list_combat_logs` | `CombatLogFile[]` | Missing `Logs/` dir → empty list, not an error |
| `summarize_combat_log(path)` | `CombatLogSummary` | Streams the file; no full damage-meter math |
| `list_order_accounts` | `string[]` | Accounts that have a `character-list-order.txt` |
| `get_character_order(account)` | `CharacterOrderPayload` | Order file cross-referenced to Warbandeer chars by GUID; missing SavedVariables ⇒ all rows unresolved, still `Ok` |
| `save_character_order(account, ordered)` | backup path | Backs up first (see Gotchas), then writes CRLF `Version: 2` file |
| `get_remembered_order(account)` | `OrderLine[] \| null` | `null` = nothing remembered yet |
| `remember_character_order(account, ordered)` | `()` | Overwrites `character-list-order - Memory.txt` in the account dir, no backup (intended) |

Static-data commands — no `wowDir`, no disk access; they read the embedded bundle, so they work with no WoW install at all:

| Command | Returns | Notes |
|---|---|---|
| `get_currency_meta(id)` | `CurrencyMeta \| null` | From the embedded bundle, not SavedVariables; `null` for an id the bundle doesn't know |
| `static_data_build` | `string` | Client build the embedded bundle came from — surfaces a stale bundle in diagnostics |

Operator-only ops commands (no `wowDir`; each takes the selected `target` index and shells `ssh <ssh> "BOT_OPS_PROJECT=<p> BOT_OPS_CONTAINER=<c> bash <remoteDir>/ops/bot-ops.sh …"`, see `../warbandeer-discord/ops/README.md`):

| Command | Returns | Notes |
|---|---|---|
| `ops_config` | `OpsTargetInfo[] \| null` | The gate + switch options — `null` (no `ops.json`) ⇒ tab hidden; else the list of bots. A malformed config errors so a typo is visible |
| `bot_status(target)` | `BotStatus` | running / status line / image / last realm status (parsed from the helper's JSON) |
| `bot_logs(target, lines?)` | `string` | Container log tail (default 200, capped 5000) |
| `bot_restart(target)` | `string` | In-place restart, no env reload |
| `bot_env_get(target)` | `Record<string,string>` | Current values of the non-secret editable keys only |
| `bot_env_set(target, changes)` | `EnvSetResult` | Whitelisted `.env` edit on the box → backup + `--force-recreate`; a no-op skips the restart |

## Character Sort model

- The order file is `Version: 2` header + `{flag} {realmID}-{lowGUID} {position}` lines — no names. Resolution builds `"Player-" + realmGuid` and matches `WarbandeerCharDB.characters[name].guid` (stamped every login since **DB v30**). Unresolved rows get sentinel `class_id == 0`, are kept (never dropped), always sort to the end, and can only be moved manually.
- `position` is a sort key, not an index: deleted characters leave real numeric gaps. Positions are round-tripped **verbatim** — the frontend does all numbering via `assignPositions(characters, gaps)`; a `null` slot is simply an omitted number (a deliberately vacant slot).
- Locking: `lockedGuids` pins characters in place (`applyLocked` sorts around them); `lockedGapRanks` ⊆ `gaps` are empty slots that survive a sort. Gap "ranks" = how many characters precede the blank, not array indices.
- Dual-crafting characters (two crafting, no gathering profession) have no automatic priority — `ProfessionChoiceDialog` asks, the answer is stored in **localStorage** (`warbandeer-desktop:profession-primary:v1`, keyed by realmGuid) and invalidated when the profession pair changes.
- "Remember this order" snapshots the current gap-aware numbering to the memory file; the **Remembered Order** sort restores it (new characters append at the end; remembered gaps come back locked).

## Release & versioning

Version lives in **three places kept in sync by hand**: `src-tauri/tauri.conf.json` (what CI reads and `getVersion()` shows), `package.json`, `src-tauri/Cargo.toml`. There is **no auto-bump** (unlike addon `.toc` revisions) — bumping the version is part of the change; a push without a bump refreshes the existing release's exe. Tags are `app-*`-prefixed so the addon CurseForge publisher (`publish.yml`) skips them.

## Gotchas

- **Every numeric in `model.rs` is `f64`** — WoW's Lua 5.1 has no integer type, so saved numbers must deserialize as doubles (serde's float visitor accepts integers too); typed as `i64` they'd fail with "invalid type". Casts to `i64` happen at the payload edge.
- **Rust structs ↔ `lib/types.ts` sync is manual.** Payloads are `#[serde(rename_all = "camelCase")]`; a field added on one side silently arrives as `undefined` on the other — no codegen, no runtime check.
- **Multi-account behavior differs by tab**: Overview auto-picks the account with the newest `Warbandeer_Characters.lua`; the Sort tab lists all accounts that have an order file and lets the user choose.
- **`_retail_` auto-detection relies on the repo location** — the exe/cwd ancestor walk works in dev precisely because the app lives under `…/_retail_/Interface/AddOns/apps/`. A portable exe run elsewhere falls back to the default install path or needs `WOW_DIR`.
- **Order-file writes are CRLF** and keep the `Version: 2` header; the leading `flag` column is opaque (always `"0"` so far) and round-tripped verbatim.
- **Backups land OUTSIDE the WTF tree** in `C:\Temp\WarbandeerCharacterSort\` (`character-list-order.<account>.backup-<timestamp>.txt`); `save` refuses to overwrite an existing same-name backup (two saves within one second) rather than silently clobbering it.
- **Saving the order only takes effect while WoW is closed** — the client reads `character-list-order.txt` once at the character-select screen and rewrites it on exit.
- **English-client assumption** in `sort.ts`: gathering professions are matched by English name (`Herbalism`/`Mining`/`Skinning`), same as the backend's role tokens.
- **Rep bar `pct` is relative, not absolute**: capped/paragon = full; in-progress bars are `rank / max shown in-progress rank` — a comparison between the shown bars, not real standing progress.
- **CLEU parsing conventions** (`combatlog.rs`): timestamp and payload split on two spaces; the damage amount is the 10th-from-last field (fixed damage suffix), source name is field 3.
- **Overview's Rust test hits the live install** (`real_data_pipeline`) — it exercises the real SavedVariables when present and skips cleanly on CI.
- **`bundle.active: false`** — `npm run tauri build` emits only the portable `src-tauri/target/release/*.exe`; enabling bundling would break `app-release.yml`'s `ls …/*.exe` staging assumption.
- **mlua is vendored C** — building needs the MSVC toolchain Rust already links with; first builds are slow.
- **A static-data refresh must carry a version bump.** `data/static-data.json` lives under `apps/warbandeer-desktop/**`, which is `app-release.yml`'s trigger path, and it's embedded with `include_str!` so a data change really does need a new exe. Releases are immutable, so merging a refresh PR without bumping the version fails the release build. That's why `update-static-data.yml` is weekly, PR-only, and never auto-merged.
- **The static-data bundle carries no generation timestamp** — only its source build. Adding one would make every scheduled run produce a diff, so the weekly refresh would open an empty-diff PR forever. The generator also normalises to LF, because CI regenerates on ubuntu while humans regenerate on Windows.
- **Most currencies legitimately have no icon.** ~916 of 1,490 `CurrencyTypes` rows carry `InventoryIconFileID = 0`, so `CurrencyMeta.icon` is `None` for them — that's DB2, not a broken join. The generator counts those separately from ids that *had* a FileDataID and still missed the listfile; only the latter is a signal, and only that one is threshold-guarded.
- **Clippy is a hard gate** (`-D warnings` in `app-test.yml`), matching the suite's strict-luacheck policy.
- **Ops tab is operator-only and dormant by default** — no `ops.json` ⇒ `ops_config` returns `None` ⇒ the tab never renders, so shipped builds are inert for end users. The privileged work lives entirely in the box's `ops/bot-ops.sh`; the Rust side only shells `ssh` with fixed subcommand names + validated numbers (env changes go over stdin), so **bot secrets never traverse the wire** and the whitelist is enforced on the box, not in the app.
