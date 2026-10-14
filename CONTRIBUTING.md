# Contributing

This repo lives directly in a WoW installation's `Interface/AddOns/` directory; only
Nazuraki's own addons are tracked (third-party addons sitting alongside them are
ignored). There is no build step and no package manager.

For a code-level map of the suite, start at [CONTEXT.md](CONTEXT.md) (the index) and
each addon's `<addon>/CONTEXT.md`. Coding conventions are specified in detail in
[CLAUDE.md](CLAUDE.md) — the highlights below.

## Code style

- 2-space indent.
- OOP via `Class(Parent, constructorFn, defaults)` from LibNAddOn; everything belongs
  on a class or the addon namespace — no standalone utility functions.
- Public methods `PascalCase`; lifecycle hooks/callbacks `camelCase` (`onLoad`,
  `onUpdate`); constructor option fields `camelCase`; internal fields `_prefixed`.
- Getter/setter methods are combined: no argument reads, an argument writes and
  returns `self` for chaining.
- LuaLS annotations (`---@class`, `---@field`, `---@param`, `---@return`) on all
  classes and public methods.
- WoW runs **Lua 5.1** — no `goto`, no `//`, no bitwise operators, no `table.unpack`.
- Files stay within ~200–300 lines; split by responsibility beyond that.

## Namespace imports

Every file declares the addon namespace with a typed import so the Lua language server
can link fields across files.

The setup file (the one that calls `LibNAddOn`):

```lua
---@class MyAddOn: AddOn
local ns = LibNAddOn(...)
```

Every other file:

```lua
---@type MyAddOn
local ns = select(2, ...)
```

The class name is the addon folder name with hyphens replaced by underscores. If a file
also needs the addon name, keep it on its own line (`local ADDON_NAME = ...`) above the
annotated import.

## Dependencies

Each addon declares its dependencies in its `.toc`:

- `## Dependencies:` — addons that must load first; the addon won't load without them.
  Almost everything lists `LibNAddOn`; addons with a UI also list `LibNUI`; addons that
  read warband data also list `Warbandeer_Characters`. The two raw-WoW-API tweaks
  (HideBagBar, BarNonce) declare none.
- `## OptionalDeps:` — addons that aren't required but, when installed, are loaded first so
  integration hooks resolve (e.g. `Warbandeer`, `ClassCodex`). Some optional integrations
  (Baganator, Bagnon) are detected at runtime instead and aren't listed in the `.toc`.

Keep the docs in step with the `.toc`. Every addon `README.md` carries a **`## Dependencies`**
section — required libs/addons as bold bullets, optional ones marked
`*(optional)* — what it unlocks` — and the root [README.md](README.md) addon tables carry
**Requires** / **Optional** columns. When an addon's dependencies change, update the `.toc`,
that addon's README section, and the root README columns in the same change.

## Testing

- **In-game**: `/reload` after changes; `/nui test [key]` opens LibNUI's visual test
  gallery. `/dump <expr>` and `/run <lua>` for live inspection.
- **Unit tests**: WoW-API-free modules have [busted](https://lunarmodules.github.io/busted/)
  specs in `<addon>/spec/`. Run the whole suite from the repo root:
  `~\.lua51\bin\busted.bat`. Spec roots are registered in `.busted`.
- **Lint**: `luacheck` (config in `.luacheckrc`). CI is strict — any warning fails the
  build, and the repo lints clean. Keep it that way.
- CI runs busted + luacheck on every PR and push to `main`
  (`.github/workflows/test.yml`).

### Setting up the Lua toolchain

Neither tool ships with the repo, and a machine without them can't run the gate CI
enforces — write the code, then find out on the PR. Set one of these up before your
first change.

**Linux / WSL2 — do this if you can.** Everything is packaged, and neither Windows
gotcha below applies:

```sh
sudo apt install build-essential lua5.1 liblua5.1-0-dev luarocks
sudo luarocks --lua-version=5.1 install busted
sudo luarocks --lua-version=5.1 install luacheck
```

Under WSL2 the repo is reachable at `/mnt/r/repos/wow` (adjust for your drive), and
`git config --global --add safe.directory "*"` avoids a dubious-ownership error on
Windows-hosted checkouts. Run `busted` and `luacheck .` from the repo root. In-game
`/reload` testing stays on Windows regardless — WSL only covers the test/lint half.

**Windows native.** Install a private Lua 5.1 + LuaRocks under `~\.lua51` with
[hererocks](https://github.com/luarocks/hererocks) (needs Python and a MinGW-w64 **UCRT**
GCC — both available via `winget`):

```
py -m pip install hererocks
py -m hererocks %USERPROFILE%\.lua51 -l 5.1 -r latest
%USERPROFILE%\.lua51\bin\luarocks install busted
%USERPROFILE%\.lua51\bin\luarocks install luacheck
```

Two failures are likely, and both have cost a session before:

1. **`couldn't run install.bat /?`** — hererocks passes a relative path that breaks on
   modern Python for Windows. Patch its `site-packages\hererocks.py` to call
   `os.path.abspath("install.bat")`.
2. **`The specified module could not be found`** when a rock's DLL loads (e.g.
   `require 'lfs'`, or busted failing to start). LuaRocks' MinGW config defaults to
   `MSVCRT = 'MSVCR80'`, which links against a CRT that isn't there. Set
   `MSVCRT = 'ucrt'` in `~\.lua51\luarocks\config-5.1.lua`, then rebuild the affected
   rocks from source: `luarocks build luafilesystem luasystem lua-term`. To confirm a
   DLL's linkage: `objdump -p <dll> | findstr "DLL Name"`.

The binaries are **not** added to `PATH`, and the `.bat` wrappers aren't runnable from
Git Bash — invoke them by full path from PowerShell:

```
& "$env:USERPROFILE\.lua51\bin\busted.bat"
& "$env:USERPROFILE\.lua51\bin\luacheck.bat" <addon-dir> [<addon-dir> ...]
```

Reference versions from a known-good install: Lua 5.1.5, LuaRocks 3.8.0, busted 2.3.0,
luacheck 1.2.0.

## Versioning & releases

- `## Version:` in each `.toc` is `MAJOR.MINOR.PATCH-rREVISION`, where
  `MAJOR.MINOR.PATCH` mirrors the WoW client version. **Never bump `-rREVISION` by
  hand** — the release workflow (`.github/scripts/release.sh`) detects changed addons,
  bumps the revision, tags `AddonName-vX.Y.Z-rN`, and creates GitHub releases with a
  changelog generated from conventional-commit messages.
- **In-game changelog (opt-in).** If an addon ships a `changelog.lua` (a newest-first
  `ns.changelog = {{version, notes}}` list) and calls `ns:RegisterChangelog()`, `release.sh`
  prepends each release's generated notes to that file so a **Changelog** button in the
  addon's Settings shows the history in-game. The script only touches `changelog.lua` when it
  already exists (opt-in by presence) and never lets a `changelog.lua` change trigger a
  release. See LibNAddOn's README.
- Publishing a GitHub release triggers `.github/workflows/publish.yml`, which zips the
  addon folder (excluding `spec/`) and uploads it to CurseForge for addons that have an
  `X-Curse-Project-ID` in their `.toc`.
- Doc-only (`.md`) and test-only (`spec/`) commits never trigger a release.

## Database compatibility

- Saved-variable migrations (`MigrateDB`, versioned via `X-NUI-DB-VERSION` in the
  `.toc`) must be **non-destructive**: add new keys, never remove or repurpose old
  ones. Users must be able to roll back to an earlier revision without data loss.
- Stale keys are removed only by an explicit user-invoked cleanup command, never
  automatically.

## Testing against the beta client

Symlink an addon into the beta installation. The Forever beta lives in `_classic_beta_`
(its `.flavor.info` says `wow_classic_beta`), not `_beta_`:

```
cd _classic_beta_\Interface\Addons
mklink /D HideBagBar ..\..\..\_retail_\Interface\AddOns\HideBagBar
```

## Writing for several clients (Retail + Forever)

One addon folder serves both clients. The detection helper and the feature table live in
LibNAddOn (`LibNAddOn/flavor.lua`); every addon gets them from `LibNAddOn(...)`.

- **One TOC, comma-delimited Interface**: `## Interface: 120105, 16001`. An addon that is ported to
  Forever also carries `## X-Game: [Game]` and `## X-Family: [Family]`, added in the same commit as
  `16001` (that commit releases the addon anyway). The helper reads LibNAddOn's own `X-Game`, so the
  lines in another addon's TOC are not what it reads.
- **Detect with the helper, never with `GetBuildInfo()`**: `ns.flavor.isForever` /
  `ns.flavor.isRetail`, and `ns:Supports("housing")` for a feature. Build-number ranges drift;
  the helper checks `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT`, then LibNAddOn's `X-Game` metadata
  (`Camelot` or `Forever`), and falls back to Retail. `/lib flavor` in-game prints what it found.
- **On Forever, an API existing is not a feature test.** The client is Mainline-family and, as
  observed on the beta, exposes `C_Housing`, `C_NeighborhoodInitiative`, `C_WeeklyRewards` and
  `C_PerksProgram` with no server system behind them, so `if C_Housing then` is true there and wrong. A game system Forever lacks
  goes in the `UNSUPPORTED` feature table in `LibNAddOn/flavor.lua` (anything not listed exists
  everywhere), and addon code asks `ns:Supports(feature)`. The table is the one place a gap is recorded.
- **Gate at registration.** A file for a missing system returns at its top
  (`if not ns:Supports("housing") then return end`), so its broker, view, command and events never
  register, rather than every call site checking.
- **Guard a genuinely missing global function by existence** (`if not GetSpecialization then return end`):
  those functions really are absent on Forever, unlike the systems above. Return nothing, or a "no
  data" value the caller already handles.
- **Forever-only files** go in the TOC file list with inline directives:
  `ForeverOnly.lua [AllowLoadGameType camelot] [ExcludeLoadGameType standard, classic]`. The paired
  exclude is there because, per the wiki's TOC format page, an allow list none of whose names the
  client recognises still passes.
- **Specs run as either flavor**: `libn.load({ flavor = "forever" })` (see `LibNAddOn/spec/libn.lua`)
  loads LibNAddOn as the Forever client would; `libn.load()` loads it as Retail.
