# Updating the static data bundle

`src-tauri/data/static-data.json` is **generated** — never hand-edit it. It is the desktop
app's offline lookup layer: constant client data that SavedVariables only store ids for.

## Why it exists

WoW saves a currency *amount* keyed by id. The name, icon and cap live in DB2, which the
in-game addon reads through live API calls — but the desktop app ships as a single portable
exe with no network access, so it has nothing to resolve those ids against. This bundle is
that lookup table, generated in CI from [wago.tools](https://wago.tools) and embedded in the
exe with `include_str!`.

## Why only currencies

Currency metadata is the one lookup with **no Blizzard REST equivalent** — the Game Data API
has no currency endpoint at all — so it stays wago-sourced no matter what the app later
decides about API credentials. Data that REST *can* serve (achievements, titles, reputation
tiers, mounts, spell names) is deliberately out of scope; see
[#639](https://github.com/nazumods/wow/issues/639).

Adding a table later means extending the generator, not reworking it.

## Regenerating

```
pwsh ./apps/warbandeer-desktop/tools/update-static-data.ps1
```

| Flag | Effect |
|---|---|
| `-Check` | Don't write; exit 1 if the bundle is stale. CI staleness gate. |
| `-CacheDir <dir>` | Reuse downloaded responses instead of refetching. Use this while iterating — the icons listfile is ~2 MB. |
| `-Build <v>` | Pin a specific client build instead of the latest. |
| `-Product <p>` | wago product; `wow` = live retail, `wowt` = PTR. |

## What it pulls

- `db2/CurrencyTypes/csv?build=<b>` — `ID`, `Name_lang`, `InventoryIconFileID`, `MaxQty`, `Quality`.
- `api/files?search=interface/icons/` — the listfile slice mapping FileDataID → path, so
  `InventoryIconFileID` becomes a renderable icon **name** (`inv_misc_coin_01`) rather than an
  opaque number. There is no per-FileDataID endpoint (`?search=` matches on path), so the whole
  icons map is fetched once — hence `-CacheDir`.

## Guards

The generator aborts rather than writing a wrong file when:

- a required `CurrencyTypes` column is missing (a DB2 rename must fail loudly, not emit nulls);
- fewer than `-MinRows` currency rows come back (truncated download);
- the icons listfile has fewer than `-MinIcons` entries;
- regeneration would drop more than `-MaxDeletePct` % of currencies;
- more than `-MaxUnresolvedPct` % of *real* icon ids miss the listfile.

That last guard is deliberately scoped to rows that **have** an icon id. Most currencies
(~916 of 1,490) carry `InventoryIconFileID = 0` — DB2 simply has no icon for them, which is
expected and reported separately. A spike in genuinely *unresolved* ids means the icons fetch
broke, which is what the threshold catches.

## Determinism

The bundle records the build it came from and **no generation timestamp**, and the generator
normalises its output to LF. A rerun against an unchanged build produces a byte-identical
file — otherwise the scheduled refresh would open an empty-diff PR every week.

## Refresh cadence

`.github/workflows/update-static-data.yml` runs **weekly** and opens a PR only when the data
changed. It is **not** auto-merged, on purpose:

> The bundle is embedded in the exe, so its path triggers `app-release.yml`. GitHub releases
> are immutable, so merging a data change **without bumping the app version** fails the
> release build. Pair every data refresh with a version bump in the same PR.
