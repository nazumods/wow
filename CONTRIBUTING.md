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

Symlink an addon into the beta installation:

```
cd _beta_\Interface\Addons
mklink /D HideBagBar ..\..\..\_retail_\Interface\AddOns\HideBagBar
```
