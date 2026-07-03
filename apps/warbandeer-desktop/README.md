# Warbandeer Desktop

A small [Tauri](https://v2.tauri.app/) companion app that reads the **Warbandeer**
addon's SavedVariables and your WoW combat logs from disk, and renders them outside
the game. The first view is a desktop mirror of the addon's **Overview**.

- **Backend (Rust):** loads `Warbandeer_Characters.lua` by executing it in an embedded
  Lua 5.1 VM ([`mlua`](https://crates.io/crates/mlua), vendored) and deserializing the
  `WarbandeerCharDB` global — the same dialect WoW uses, so the data round-trips exactly.
  Also lists/parses `Logs/WoWCombatLog*.txt`, and reads/writes `character-list-order.txt`.
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
| Character Sort | `WTF/Account/<name>/character-list-order.txt` | ✅ reorder the character-select list (see below) |

## Character Sort

Reorders your WoW account's character-select list — alphabetically, by level, class, or
profession — without the in-game drag-and-drop. This folds in what used to be the
standalone **WarbandeerCharacterSort** app (now retired — see its archived repo).

WoW addons have no access to the character-select (glue) screen and no filesystem API
beyond SavedVariables, so reordering means editing `character-list-order.txt` directly —
only possible from an external tool, and only while **WoW is closed** (the client reads
that file once, at the character-select screen).

How it works: WoW writes `character-list-order.txt` — one line per character, an opaque
`<realmID>-<lowGUID>` fragment and a sort position, no names. Warbandeer_Characters (DB
v30+) stamps each character's full GUID into its own SavedVariables every login. The
**Sort** tab cross-references the two by GUID to resolve every row to an actual
character; unresolved rows (a character Warbandeer hasn't seen since v30) are kept, not
dropped, and can still be repositioned manually.

Usage: pick an account, click a sort button (or use the ^/v buttons to fine-tune
manually), then **Save to WoW** — this makes a timestamped backup of
`character-list-order.txt` in the same folder before overwriting it. Restart WoW (or
return to character select) to see the new order. If anything looks wrong, restore the
backup file from the account folder.

Dual-crafting characters (two crafting professions, no gathering) have no automatic
sort priority between them — the **Profession** sort mode asks which one leads via a
dialog; the answer is remembered (per-character, in the app's local storage) and can be
revisited later with **Prof choices…**.

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
cargo test --manifest-path src-tauri/Cargo.toml
```

`.github/workflows/app-test.yml` runs all four on every PR/push touching this app.

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
