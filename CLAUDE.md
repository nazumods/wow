# WoW AddOn Suite — Claude Instructions

## First Step: Read CONTEXT.md

**At the start of every session, read `CONTEXT.md` in this directory.** It is the top-level index: the dependency graph, a one-line summary per addon, and the global slash command registry. Each addon's full code reference — file maps, class hierarchies, API surfaces, data structures, and constructor options — lives in its own `<addon>/CONTEXT.md` (linked from the root index). Load only the per-addon files relevant to the task; together they eliminate the need to re-read source files.

The `CONTEXT.md` index covers the **suite**. For an unfamiliar **third-party** addon it doesn't cover (e.g. Bagnon/BagBrother, ClassCodex) — typically to design an integration seam against it — prefer an **Explore agent** to answer the specific question ("how does X create frame Y, and what's the stable path to reach it?") over inline Grep + full-file Reads. The agent returns just the conclusion, keeping that addon's large source files out of the main context.

## Searching & Reading Files

Route code search and file reads through the dedicated tools, not the shell: content search → the **Grep tool** (regex alternation `A|B|C`, `glob`/`type` filters, and `path` to scope to any directory — including reference repos like `wow-ui-source` — with clickable results); file discovery → the **Glob tool** (`**/*.lua`); reading a file → the **Read tool**. Reserve the shell for genuine compounds a single tool can't express (a `grep` piped into `sed -n`, or piping `| head -N`/`| tail -N` onto a real command like git/luacheck/busted).

**The `CONTEXT.md` files are the exception to "read a file → Read":** their table rows are single lines that each run to several KB (the DetailView / SummaryColumns / migration rows are the extreme), so a small-looking `Read` line range (`offset`/`limit`) still pulls tens of KB into context — a 45-line window of `Warbandeer/CONTEXT.md` is ~44 KB. To pull one specific row (a file-map entry, an API method, a data-structure block), **Grep it** on a short unique substring (`output_mode: "content"`) instead of reading a line range; that returns just the row(s) you want. Read a contiguous range only when you genuinely need a span of the surrounding prose. This is the read-side companion to the "anchor the `Edit` on a short, unique substring" rule under **Documentation** — the same Grep both locates the row to read and gives you the substring the follow-up `Edit` anchors on.

## Project Overview

WoW Retail addon suite by Nazuraki (Interface 120000+). No build step, no package manager. Testing is done in-game via `/reload`, except WoW-API-free modules which have busted unit tests.

Addons: LibNAddOn, LibNUI, LibNUI_Test, Warbandeer (Characters, main UI, Alias, Collected, Bars), ShadowsOfUI-XP, ShadowsOfUI-GCD, ShadowsOfUI-DMF, HideStanceBar, HideBagBar, CombatOutline, Recycle, BarNonce. The authoritative list is the root `CONTEXT.md` addon index.

## Tooling

Reusable development tooling lives in `Tooling/` (see `Tooling/README.md` for the script index). **Before writing any temporary or one-off script, check `Tooling/` first** — the job may already be solved there (e.g. `make_addon_logo.py` generates addon logos in the identical house style every time). When a scratchpad script proves reusable, promote it into `Tooling/` with a docstring and a README entry. `Tooling/` is not an addon: it ships nothing and is excluded from the release pipeline via `NON_ADDON_DIRS` in `release.sh`.

## Documentation

Each doc has a fixed audience — keep them in sync with code changes:

| Doc | Audience | Content |
|---|---|---|
| Root `README.md` | Anyone landing on the repo | Suite overview + addon table (one row per addon, linking its README) |
| `CONTRIBUTING.md` | Contributors | Style, testing, lint, release process |
| `<addon>/README.md` | **End users** | What it does, commands, settings, dependencies, saved data. Written to be reusable verbatim as the CurseForge page — standalone, no repo-relative links. Exception: library addons (LibNAddOn, LibNUI, Warbandeer_Bars) have developer-facing API READMEs |
| `CONTEXT.md` + `<addon>/CONTEXT.md` | Claude / code reference | File maps, classes, APIs, data structures, gotchas |

Upkeep rules:

- **New addon** → end-user `README.md`, a row in the root `README.md` table, its own `CONTEXT.md`, entries in the root `CONTEXT.md` (dependency graph, addon index, slash registry), and its dir glob in `.luacheckrc` `include_files` (only suite addons are linted — the local AddOns dir also holds untracked third-party addons).
- **Changed slash commands, settings, dependencies, API surface, or DB version** → update the addon's `README.md`, its `CONTEXT.md`, and the root `CONTEXT.md` registry/index in the same change.
- **New/changed public methods or ns fields** → LuaLS annotations are part of the change, not a follow-up.
- Use the `doc:` conventional-commit type for doc-only commits — `.md` changes never trigger a release.
- **Editing a long `CONTEXT.md` row or migration paragraph** → anchor the `Edit` on a short, unique substring inside it, not the whole row. These rows run long and their em-dashes, apostrophes, and inline values (e.g. `1000ms` vs `1s`) drift, so a full-row `old_string` often fails the exact-match; Grep the current text first when unsure.

## Coding Conventions

| Convention | Detail |
|---|---|
| Namespace | Typed import in every file — see **Namespace Imports & Typing** below |
| Class definition | `local Foo = Class(Parent, function(self) ... end, { defaults })` |
| Addon init | `local ns = LibNAddOn(...)` (assignment form; db/commands/etc. from `X-NUI-*` toc fields, settings via `ns:RegisterSettings{...}` at file-load time) |
| DB migration | `MigrateDB()` auto-called by LibNAddOn on version mismatch |
| Event handling | `ns:registerEvent("EVENT", handler)` or define `function ns.EVENT_NAME(self, ...) end` |
| UI widget access | Always via `self._widget`; **never access `_widget` from outside a class** |
| Shared API data | Access via `ns.api.*` (bound from `X-NUI-API` toc field) |
| LuaLS annotations | `---@class`, `---@field`, `---@param`, `---@return` |
| No error handling | WoW API errors surface in-game; no defensive nil-checks on internal invariants |
| No standalone utilities | Everything belongs on a class or the addon namespace |
| Testing | In-game via `/reload` and `/nui test [key]` for UI; busted unit tests in `spec/` for pure-Lua modules (see **Unit Tests** below) |

## Namespace Imports & Typing

Every file imports the addon namespace with a LuaLS annotation so fields link across files.

The setup file (the one that calls `LibNAddOn`):

```lua
---@class Warbandeer_Characters: AddOn
local ns = LibNAddOn(...)
```

All other files:

```lua
---@type Warbandeer_Characters
local ns = select(2, ...)
```

Rules:

- The class name is the addon folder name, with hyphens replaced by underscores (e.g. `ShadowsOfUI_XP`).
- **LibNUI exception**: the class name `LibNUI` belongs to the widget table `ns.ui` (anchored in `LibNUI/globals.lua`); LibNUI's own namespace class is `LibNUI_AddOn`.
- LibNAddOn's own files use `---@class LibNAddOn` on the import instead of `---@type`, since they incrementally define the class.
- Files that **add a field** to `ns` re-open the class instead of importing with `---@type`. Two equivalent forms:
  - **Direct-assignment field** (e.g. a bundled data table) — put `---@class <Addon>` on the `local ns = select(2, ...)` import line itself, and annotate the assignment with `---@type` (e.g. `---@type table<string, string[]>` above `ns.ClassPrimary = {}`). See `ShadowsOfUI-Upgrade/data/*.lua`.
  - **Several fields / methods defined inline** — keep the `---@type` import and re-open the class right before the definitions with a `---@class <Addon>` + `---@field ...` block. See `Warbandeer/views/SummaryColumns.lua`.
- Files that also need the addon name keep it on its own line: `local ADDON_NAME = ...` followed by the annotated `select(2, ...)` import (this includes table-form init files like `CombatOutline/core.lua`).
- Typed widget-table alias where useful: `---@type LibNUI` above `local ui = ns.ui`.

## Naming Conventions

| Pattern | Convention |
|---|---|
| Public methods | `PascalCase` |
| Lifecycle hooks / callbacks | `camelCase` (`onLoad`, `onUpdate`) |
| Constructor init fields | `camelCase` (`cellWidth`, `headerHeight`) |
| Internal fields | `_prefixed` (`_widget`, `_tabs`) |

## Getter/Setter Pattern

```lua
function MyClass:Value(v)
    if v == nil then return self._widget:GetValue() end
    self._widget:SetValue(v)
    return self
end
```

## Git & Commits

Every commit and merge follows a strict discipline: (1) provide the commit message (and any PR/issue body) via `git commit -F <file>` / `--body-file` or multiple `-m` flags, never an inline here-string or `cat <<EOF` heredoc; (2) confirm `git status` shows only the in-scope staged set before committing — nothing else; (3) reach `main` only via a PR-based **squash** merge with all required CI green; (4) after merge, verify a clean tree on an up-to-date `main`. The rules below are the WoW-suite specifics on top of that baseline.

- Follow the [Conventional Commits](https://www.conventionalcommits.org/) spec (`type(scope): summary`, e.g. `feat(detail): show suggested gear upgrade`). Types: `feat`, `fix`, `doc`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert` (note `doc`, not `docs` — see below). Use `doc:` for doc-only changes.
- Keep messages to a short one-liner. Let the code speak for itself — through being simple and clear, or via documentation and comments — rather than explaining it in the commit body.
- Only stage files explicitly in scope for the current task, and never merge a whole branch when only a subset of changes was requested — confirm scope before staging, committing, or merging.

## Versioning

The `## Version:` field in each `.toc` uses the format **`MAJOR.MINOR.PATCH-rREVISION`**, where `MAJOR.MINOR.PATCH` mirrors the WoW client version (e.g. `12.0.5-r0`) and `REVISION` is a zero-based counter that resets each patch cycle. `r0` is the initial release adding support for that client version (at minimum a client version bump in the `.toc`). The `v` prefix is added by the release tooling to tags and titles (e.g. `AddonName-v12.0.5-r0`).

**Do not bump the `-rREVISION` in `.toc` files** when making code changes — the release script bumps it automatically. (Other `.toc` fields, e.g. `X-NUI-DB-VERSION` for a DB migration, are still bumped by hand as part of the change.)

## DB Backwards Compatibility

- DB upgrades must be **non-destructive**: new keys are added, old keys are never removed or repurposed by `MigrateDB`.
- A user must be able to rollback to any earlier revision within the same patch cycle (or a prior cycle) with no data loss or corruption.
- If old keys become stale after an upgrade, expose a **cleanup command** (e.g. `/addon cleanup`) that removes them explicitly. Never run cleanup automatically — only after the user confirms the upgrade is stable.

## File Size

Keep individual files to **200–300 lines maximum**. If a file grows beyond that, split it by responsibility (e.g. separate data, view, and controller concerns into distinct files listed in the `.toc`).

## Unit Tests

WoW-API-free code (currently LibNAddOn's `ns.lua.*` modules) has busted specs in `<addon>/spec/` inside each addon folder. Run the whole suite from the AddOns root:

```
~\.lua51\bin\busted.bat
```

Lint with the same toolchain — the strict `luacheck` CI gate (see below), scoped to the addon dirs you touched:

```
~\.lua51\bin\luacheck.bat <addon-dir> [<addon-dir> ...]
```

- Spec roots are listed in `.busted` at the repo root (`ROOT = {...}`) — add the addon's `spec/` dir there when giving a new addon tests.
- `LibNAddOn/spec/libn.lua` loads LibNAddOn's pure-Lua files into a fresh `ns` with the WoW addon vararg (and stubs `Mixin`); specs call `libn.load()` per test. File paths in loaders are relative to the AddOns root (busted's cwd).
- `spec/` dirs are excluded from the publish pipeline in two places — keep both in sync: the CurseForge zip (`publish.yml` `--exclude "${ADDON}/spec/*"`) and release change-detection (`release.sh` pathspec), so tests are never shipped and test-only commits never trigger a release.
- Spec files are never listed in the `.toc`, so WoW never loads them.
- Specs are linted via the `files["**/spec/**/*.lua"]` override in `.luacheckrc`.
- Spec files must be saved **without a UTF-8 BOM** (Lua 5.1's `loadfile` rejects it).
- CI runs the suite on every PR and push to `main` (`.github/workflows/test.yml`, busted on Lua 5.1). A `luacheck` job runs alongside it and is **strict**: any warning fails the build (the repo lints clean — keep it that way).
- **Keep `.luacheckrc` and `.luarc.json` in sync.** When you add a WoW global (API namespace or function) to `.luacheckrc`'s `read_globals`, add the same entry to `.luarc.json`'s `diagnostics.globals` (the LuaLS/editor config mirrors the same list) — otherwise the editor flags it as undefined even though luacheck passes.

## In-Game Debugging

Use `/dump <expr>` or `/run <lua>` to inspect live data. Output appears in the chat window — can't be copy/pasted and truncates if too long. Use these to check what WoW API calls actually return (e.g. `/run print(C_MajorFactions.GetMajorFactionData(2742))` or `/dump C_DelvesUI.GetDelvesFactionForSeason()`).

## WoW Addon Conventions

- This codebase targets the **Lua 5.1** environment — do not use Lua 5.2+ features (`goto`, etc.).
- Account for WoW 12.0 API changes when using icon/spell APIs (Blizzard renames/repurposes these across client versions).
- The `mcp__wow-api__*` tools (`lookup_api`, `search_api`, etc.) index **namespaced Blizzard API only**. Lua stdlib globals that WoW exposes — `time`, `date`, `bit`, `string`, `math`, `table`, `os`-style calls — are **not** in that index; treat them as `os.*`/LuaJIT and reason from Lua semantics rather than `lookup_api`-ing them (a fuzzy match just returns unrelated `C_*` functions).
- Verify `/wdebug` probes compile and stay under WoW's chat input length limit (255 chars including the prefix).
- Render bars/overlays on the correct frame layer (not `BACKGROUND`) and verify z-order and mouse-grab behavior.
- Creature-display models cannot be dressed — use a `ModelScene` actor for arbitrary races.

## Key Gotchas

- **TableFrame offsetX/offsetY** are computed once at construction based on whether `rowNames`/`colNames` are non-nil. For dynamic tables, pass `rowNames = {}` / `colNames = {}`.
- **SecureButton**: Never call `SetAttribute` during combat (taint).
- **`special = true`**: Registers frame in `_G` and `UISpecialFrames` (Escape closes it). Only for top-level windows.
- **Frame `onUpdate` elapsed**: arrives in **milliseconds** (Frame multiplies WoW's seconds by 1000).
- **`ns.delay(ms, fn)`**: Only one active timer per addon — a new call overwrites the pending one.
- **`rgba(r, g, b, a)`**: r/g/b are 0–255 integers, a is 0–1 float.
