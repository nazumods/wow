# Updating the static data bundle

`apps/warbandeer-desktop/src-tauri/data/static-data.json` is **generated** — never hand-edit
it. It is the suite's offline lookup layer: constant client data that SavedVariables only
store ids for.

Current contents: **currencies** (the full `CurrencyTypes` table) and **achievements**
(`Achievement`, filtered to the ids Warbandeer's views track).

**Why the generator and its output live apart.** The bundle sits with the desktop app
because that app compiles it in with `include_str!`. The generator sits in `Tooling/` for
two reasons: it serves more than one consumer (`wow-companion` consumes the published
release), and everything under `apps/warbandeer-desktop/` is in `app-release.yml`'s trigger
path — a generator edit compiles into nothing, so it must not cut a desktop release.

## Why it exists

WoW saves ids, not the constants behind them — a currency *amount* keyed by id, an
achievement's completed bit keyed by id. The name, icon, cap and points live in DB2, which
the in-game addon reads through live API calls — but the desktop app ships as a single
portable exe with no network access, so it has nothing to resolve those ids against. This
bundle is that lookup table, generated in CI from [wago.tools](https://wago.tools) and
embedded in the exe with `include_str!`.

## What earns a place in the bundle

The rule is **what the addon doesn't already persist** — not everything DB2 offers.

[#639](https://github.com/nazumods/wow/issues/639) originally proposed bundling nine tables
as an alternative to persisting display metadata into `WarbandeerCharDB`, and left one
question open: whether the desktop app would gain Blizzard REST credentials and converge with
`wow-companion`, or stay offline and credential-free. **It stays offline.** #631–#637 all
shipped as addon-side persistence, so the addon owns character state *and* the display
metadata attached to it, and the bundle covers only the residue:

| Table | Why it's here |
|---|---|
| `CurrencyTypes` | No Blizzard REST equivalent exists at all — the Game Data API has no currency endpoint — so it is wago-sourced regardless of credentials. Shipped whole (220 KB); filtering would couple the generator to view internals for no gain. |
| `Achievement` | `Warbandeer_Characters/data/achievements.lua` deliberately snapshots only `completed` + `wasEarnedByMe`, leaving name/points/icon to be looked up rather than duplicated into every save. Filtered to the tracked ids — see below. |

Deliberately **absent**, because the addon persists them itself: the title catalog (#721),
keystone/mastery/currency display metadata (#722), appearance-unlock and class-mount state
(#724), pet species (#726), reputation thresholds (#702), and item names in the gear caches
(#635). Bundling those would ship a second, staler copy of data the app already reads.

Adding a table later means extending the generator, not reworking it — but the bar is that
same rule: the addon must have no way to persist it, or a good reason not to.

## Why the achievement extract is filtered

`Achievement.db2` is 13,810 rows / 2.0 MB; the ids Warbandeer's views actually track are 93
of them, so the extract is a few KB rather than ~800 KB.

The filter reads `Warbandeer_Characters/data/achievementcatalog.lua`, which already exists to
be the *"single source of truth for the achievement ids Warbandeer's views track"* — so this
couples the generator to a declared contract, not to view internals. Two consequences worth
knowing:

- **Adding an id to that catalog requires regenerating the bundle**, or the desktop app
  renders the new row without a name.
- **A tracked id that DB2 doesn't know aborts the generator.** The catalog is small and
  hand-authored, so a miss means a stale entry, not missing data. The `achievementcatalog.id`
  rule in `lint-stale-ids.ps1` catches the same thing at PR time with a friendlier message.

## Regenerating

```
pwsh ./Tooling/update-static-data.ps1
```

| Flag | Effect |
|---|---|
| `-Check` | Don't write; exit 1 if the bundle is stale. CI staleness gate. |
| `-CacheDir <dir>` | Reuse downloaded responses instead of refetching. Use this while iterating — the icons listfile is ~2 MB. |
| `-Build <v>` | Pin a specific client build instead of the latest. |
| `-Product <p>` | wago product; `wow` = live retail, `wowt` = PTR. |
| `-CatalogFile <f>` | Lua file the achievement filter reads ids from. Defaults to `Warbandeer_Characters/data/achievementcatalog.lua`. |

## What it pulls

- `db2/CurrencyTypes/csv?build=<b>` — `ID`, `Name_lang`, `InventoryIconFileID`, `MaxQty`, `Quality`.
- `db2/Achievement/csv?build=<b>` — `ID`, `Title_lang`, `Points`, `IconFileID`.
- `api/files?search=interface/icons/` — the listfile slice mapping FileDataID → path, so an icon
  FileDataID becomes a renderable icon **name** (`inv_misc_coin_01`) rather than an opaque
  number. There is no per-FileDataID endpoint (`?search=` matches on path), so the whole icons
  map is fetched once — hence `-CacheDir`.

## Guards

The generator aborts rather than writing a wrong file when:

- a required column is missing from either table (a DB2 rename must fail loudly, not emit nulls);
- fewer than `-MinRows` currency rows, or `-MinAchievementRows` achievement rows, come back
  (truncated download);
- no achievement ids parse out of the catalog file (its shape changed);
- **a tracked achievement id is absent from `Achievement.db2`** — a stale catalog entry, reported
  with every offending id rather than failing on the first;
- the icons listfile has fewer than `-MinIcons` entries;
- regeneration would drop more than `-MaxDeletePct` % of *either* table (a table missing from the
  previous bundle is treated as newly added, not as a 100% deletion);
- more than `-MaxUnresolvedPct` % of *real* currency icon ids miss the listfile.

That last guard is deliberately scoped to rows that **have** an icon id. Most currencies
(~916 of 1,490) carry `InventoryIconFileID = 0` — DB2 simply has no icon for them, which is
expected and reported separately. A spike in genuinely *unresolved* ids means the icons fetch
broke, which is what the threshold catches.

There is no equivalent unresolved-icon threshold for achievements: every tracked id currently
carries a real `IconFileID` that resolves, and the set is small enough that a single null is
worth noticing rather than averaging away. The counts are printed either way.

## Determinism

The bundle records the build it came from and **no generation timestamp**, and the generator
normalises its output to LF. A rerun against an unchanged build produces a byte-identical
file — otherwise the scheduled refresh would open an empty-diff PR every week.

## Refresh cadence

`.github/workflows/update-static-data.yml` runs **weekly** and opens a PR only when the data
changed. It is **not** auto-merged — a data diff deserves a human glance before it becomes a
shipped exe.

**A data refresh no longer needs a hand-written version bump.** It used to: the bundle is
embedded with `include_str!`, so its path is an app change, and immutable releases meant
merging one without bumping the version failed the release build. Since
[#700](https://github.com/nazumods/wow/pull/700), `app-release.yml` runs on a daily cron and
`.github/scripts/app-release.sh` bumps the version itself when it finds unreleased commits
under `apps/warbandeer-desktop/` — and its doc-only exclusion is `**/*.md`, so
`data/static-data.json` counts as a real app change and cuts its own release. Merge the
refresh; the bump follows on the next cron.

## Consuming the bundle from another repo

The desktop app embeds the file at compile time, so it never fetches it. For consumers
*outside* this repo, `.github/workflows/publish-static-data.yml` attaches the bundle to a
GitHub release after it lands on `main`:

- **Tag:** `app-static-data-v<build>-<sha8>` — the `app-` prefix is load-bearing, it's what
  keeps the CurseForge publisher (`publish.yml`) from picking the release up. The `<sha8>`
  makes the tag content-addressed so a re-run is a no-op rather than an immutable-release
  error.
- **Asset:** always `static-data.json`.
- **Resolving the newest:** list releases and take the first tag prefixed `app-static-data-v`
  (they're newest-first). The releases are published with `--latest=false`, so the repo's
  "Latest release" badge is unaffected — don't use the `/releases/latest` endpoint.

`nazumods/wow` is public, so the fetch needs no authentication.
