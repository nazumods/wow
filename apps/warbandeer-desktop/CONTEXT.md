# apps/warbandeer-desktop

> **Purpose:** Tauri 2 + Svelte 5 desktop companion (not an addon — lives under `apps/`, excluded from the addon release pipeline). The Rust backend loads `Warbandeer_Characters.lua` SavedVariables by executing it in an embedded Lua 5.1 VM (`mlua`, vendored) and deserializing the `WarbandeerCharDB` global, lists/summarizes `Logs/WoWCombatLog*.txt`, and reads/writes `character-list-order.txt` (character-select reordering, ported from the retired standalone WarbandeerCharacterSort WPF app). The frontend mirrors the Warbandeer addon's Overview view in the "void-dark" theme. Three tabs: **Overview**, **Logs**, **Sort**.

## Files

| File | Purpose |
|---|---|
| **Rust backend (`src-tauri/`)** | |
| `src/lib.rs` | Tauri builder — registers the 8 commands (see command surface) |
| `src/main.rs` | Thin entry point calling `lib.rs::run()` |
| `src/wow.rs` | Locate `_retail_` (override/`WOW_DIR` → exe/cwd ancestor with `WTF/Account` → default install path); find SavedVariables per account; list accounts with an order file |
| `src/savedvars.rs` | `load_char_db(path)` — exec the file in a fresh `mlua` Lua 5.1 VM, deserialize global `WarbandeerCharDB` via `LuaSerdeExt` |
| `src/model.rs` | Typed **subset** of `WarbandeerCharDB` (serde, unknown fields ignored): warband gold/week, per-char basic/spec/professions/equipment/currency/playtime/reputations/guid |
| `src/overview.rs` | `get_overview` — computes the Overview payload (stat strip, best-standing-per-faction reps, top char per class); mirrors `Warbandeer/views/Overview.lua` + `overview/TopAlts.lua` + `FactionBars.lua`. Has an end-to-end test against the live install (skips if none) |
| `src/combatlog.rs` | `list_combat_logs` (newest first) + `summarize_combat_log` — streaming CLEU parse: unique `ENCOUNTER_START` names, damage-by-source top 10 |
| `src/charorder.rs` | Parse/resolve/save `character-list-order.txt` + the remembered-order file; timestamped backups; extensive unit tests |
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
- **Clippy is a hard gate** (`-D warnings` in `app-test.yml`), matching the suite's strict-luacheck policy.
