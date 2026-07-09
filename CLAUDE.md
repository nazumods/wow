# WoW AddOn Suite — Claude Instructions

## Environment

This is a Windows environment. Prefer PowerShell for file/text operations (e.g. `\r\n` conversion, here-strings). Do **not** run PowerShell here-string syntax through the Bash tool — the `@` literal leaks into the output. Keep each shell's idioms in its own tool: don't mix Unix syntax into the PowerShell tool, and don't mix PowerShell syntax into the Bash tool.

`zip` is **not** available in the Bash/MSYS environment. For packaging, use PowerShell `Compress-Archive` (or let the release tooling handle it) rather than a `zip` command.

Route code search through the **Grep tool**, not Bash `grep`/`rg`. It handles multi-pattern searches via regex alternation (`A|B|C`), scopes to any directory with `path` (including reference repos like `wow-ui-source`), and filters with `glob`/`type` — so a scoped, multi-pattern search is one Grep call, and the results come back as clickable file links. Reserve Bash for genuine compounds a single tool can't express (grep piped into `sed -n`/`find`, or grep alongside a heredoc). Same for `find`→Glob and `cat`/`head`/`tail`-as-read→Read (piping `| head -N`/`| tail -N` onto a real command like git/luacheck/busted is fine).

## First Step: Read CONTEXT.md

**At the start of every session, read `CONTEXT.md` in this directory.** It is the top-level index: the dependency graph, a one-line summary per addon, and the global slash command registry. Each addon's full code reference — file maps, class hierarchies, API surfaces, data structures, and constructor options — lives in its own `<addon>/CONTEXT.md` (linked from the root index). Load only the per-addon files relevant to the task; together they eliminate the need to re-read source files.

The `CONTEXT.md` index covers the **suite**. For an unfamiliar **third-party** addon it doesn't cover (e.g. Bagnon/BagBrother, ClassCodex) — typically to design an integration seam against it — prefer an **Explore agent** to answer the specific question ("how does X create frame Y, and what's the stable path to reach it?") over inline Grep + full-file Reads. The agent returns just the conclusion, keeping that addon's large source files out of the main context.

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

**The `git-commit-safety` skill is the standing discipline for every commit and merge in every session** — invoke/apply it whenever you are about to `git add`, `git commit`, or merge (the `/pr` skill automates the same rules for a full branch → PR → merge ship). Its four non-negotiables: (1) write the commit message to a temp file and use `git commit -F` (or multiple `-m` flags), never an inline here-string; (2) print `git status` and confirm the staged set matches the user's stated scope **exactly** before staging — nothing else, and never another session's in-progress files; (3) reach `main` only via a PR-based **squash** merge with all required CI green; (4) after merge, verify a clean tree on an up-to-date `main`. The rules below are the WoW-suite specifics that sit on top of that baseline.

- Follow the [Conventional Commits](https://www.conventionalcommits.org/) spec (`type(scope): summary`, e.g. `feat(detail): show suggested gear upgrade`). Types: `feat`, `fix`, `doc`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert` (note `doc`, not `docs` — see below). Use `doc:` for doc-only changes.
- Keep messages to a short one-liner. Let the code speak for itself — through being simple and clear, or via documentation and comments — rather than explaining it in the commit body.
- Write commit messages with multiple `-m` flags or a temp file (`git commit -F`) — **never** bash/PowerShell here-strings, which reliably mangle messages in this environment.
- Only stage files explicitly in scope for the current task. Never stage another session's in-progress work, and never merge a whole branch when only a subset of changes was requested — confirm scope before staging, committing, or merging.

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
