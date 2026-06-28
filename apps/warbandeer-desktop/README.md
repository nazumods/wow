# Warbandeer Desktop

A small [Tauri](https://v2.tauri.app/) companion app that reads the **Warbandeer**
addon's SavedVariables and your WoW combat logs from disk, and renders them outside
the game. The first view is a desktop mirror of the addon's **Overview**.

- **Backend (Rust):** loads `Warbandeer_Characters.lua` by executing it in an embedded
  Lua 5.1 VM ([`mlua`](https://crates.io/crates/mlua), vendored) and deserializing the
  `WarbandeerCharDB` global — the same dialect WoW uses, so the data round-trips exactly.
  Also lists/parses `Logs/WoWCombatLog*.txt`.
- **Frontend (Svelte 5 + Vite + TS):** the "void-dark" theme, ilvl/class colors, stat
  strip, reputation bars and Top Characters table mirrored from `Warbandeer/views/`.

## What's shown

| Overview section | Source | Status |
|---|---|---|
| Stat strip — warband wealth (+weekly), playtime (+this patch), top ilvl | `WarbandeerCharDB.warband` + per-char `currency`/`playtime`/`equipment` | ✅ exact |
| Reputations | per-char `reputations.factions` — best standing per faction, account-wide | ✅ (offline analogue of the live rep bars) |
| Top Characters | top char per class by level/ilvl | ✅ (raid set-completion columns: planned, needs the Collected DB) |
| Achievements | not persisted to SavedVariables | ⛔ placeholder (needs live game state) |
| Combat logs | `Logs/WoWCombatLog*.txt` | ✅ list + lightweight CLEU summary (encounters, top damage) |

## Data location

The backend auto-detects the `_retail_` folder (it walks up from the app, which lives
under `…/_retail_/Interface/AddOns/apps/`, and falls back to the default install path).
Override with the `WOW_DIR` environment variable if your install is elsewhere.

## Develop

```sh
cd apps/warbandeer-desktop
npm install
npm run tauri dev # launches the desktop app with HMR
```

Useful checks without launching the window:

```sh
npm run check                       # Svelte + TypeScript typecheck
npm run build                       # frontend production build
cargo check --manifest-path src-tauri/Cargo.toml
```

> `mlua`'s vendored Lua compiles from C, so a C toolchain (MSVC on Windows) must be
> available — the same one Rust already uses to link.

## Build the portable app

```sh
npm run tauri build
```

`bundle.active` is `false` in `src-tauri/tauri.conf.json`, so this produces a single
**portable** executable at `src-tauri/target/release/*.exe` (no NSIS/MSI installer).
Copy that exe anywhere and run it — it needs the Evergreen WebView2 runtime, which
ships with Windows 10/11.

### Icons

The design source `icons/source.png` is committed, and the generated icon set under
`src-tauri/icons/` (also committed, rarely changes) is derived from it. To change the
app icon, replace `icons/source.png` and run `npm run icon` (regenerates the set via
the Tauri CLI). `npm run icon:source` regenerates the bundled placeholder mark from
`scripts/gen-icon.mjs`.

## Releases (CI)

`.github/workflows/app-release.yml` builds the portable Windows exe and publishes a
GitHub release whenever the app's source changes on `main` (doc-only changes are
ignored). The release is tagged `app-warbandeer-desktop-v<version>` and the exe is
attached as `Warbandeer-v<version>-portable.exe`, where `<version>` comes from
`src-tauri/tauri.conf.json`. Bump that `version` (and keep `package.json` +
`src-tauri/Cargo.toml` in sync) to cut a new release; pushes that don't change the
version refresh the current release's asset. App tags use the `app-` prefix so the
addon CurseForge publisher skips them.
