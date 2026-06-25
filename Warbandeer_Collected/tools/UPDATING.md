# Updating the transmog set data (`data/sets.lua`)

The Collected feature's set list (`ns.Sets` in [`../data/sets.lua`](../data/sets.lua))
is **regenerated from Blizzard's client database** via [wago.tools](https://wago.tools).
It feeds both render paths, which share the one file:

- `/collected` (and `/collect`) — the standalone Collected window.
- `/wbc` → Collected tab — Warbandeer's `views/CollectedView.lua` (OptionalDep).

> The `tools/` folder is **maintainer-only** — excluded from the published
> CurseForge zip and from release change-detection, so editing it never ships or
> triggers a release.

## It's automated

`.github/workflows/update-collected-sets.yml` runs **weekly (and on demand)**: it
executes the generator against live wago data, lints the result, and — if anything
changed — opens/updates a PR (`bot/collected-set-refresh`). You just review and
merge. Trigger it manually from the Actions tab ("Run workflow") any time, e.g.
right after a patch.

> One-time repo setting: **Settings → Actions → General → Workflow permissions →
> "Allow GitHub Actions to create and approve pull requests."** Without it the
> create-PR step fails.

## What the generator does (`update-sets.ps1`)

It rewrites **only** each group's inner `sets = { ... }` block, keyed by the
group's curated `id`. Everything else — the `ns.Releases`/`ns.ReleaseIcons`
preamble, comments, and every group's `id`/`name`/`release`/`instance`/
`difficulty`/`minLevel` — is preserved byte-for-byte. Group **names are never
touched** (they carry the difficulty suffix the dressing room parses).

Two wago facts drive it:

- **ClassMask is a bitfield.** A classic tier set is one class (`1` = Warrior); a
  Raid Finder "armor type" set covers several (`35` = Warrior|Paladin|Death
  Knight, one Plate set). The mask is decomposed so a set lands in **every** class
  slot it fills, with `{}` for classes with no set.
- **Difficulty tiers share a TransmogSetGroupID.** Antorus is four groups, all
  `id = 62`, told apart by each set's `ItemNameDescriptionID`, which the
  `ItemNameDescription` table labels *Raid Finder / Normal / Heroic / Mythic*. The
  generator reads the difficulty from the group's `name` suffix — e.g.
  `... (Heroic)` — and picks the matching rows.

It is **conservative**: a group is rewritten only when it resolves confidently —
the id exists in wago **and** (the name's difficulty suffix maps to a label present
for that id, **or** the group has no suffix and the id carries a single
difficulty). Anything else — Wrath 10/25-man tiers, custom labels like
`(Timerunning/Remix)`, ambiguous ids — is **left exactly as written**.

**Source build.** It pulls the latest **live retail** build (product `wow`),
resolved from `wago.tools/api/builds` and pinned explicitly — the bare `/csv`
endpoint serves the newest build across *all* products, including the PTR, which
would add unreleased sets. The build it generated from is recorded as a comment
near the top of `data/sets.lua`, e.g.:

```lua
-- Generated from wago.tools TransmogSet (product wow, build 12.0.7.68275, 2026-06-23) by tools/update-sets.ps1.
```

The stamp updates only when the set data actually changes, so a build bump alone
never produces a diff (or a PR).

| ClassMask bit | classId | Class | | ClassMask bit | classId | Class |
|---|---|---|---|---|---|---|
| 1   | 1 | Warrior | | 64   | 7  | Shaman |
| 2   | 2 | Paladin | | 128  | 8  | Mage |
| 4   | 3 | Hunter  | | 256  | 9  | Warlock |
| 8   | 4 | Rogue   | | 512  | 10 | Monk |
| 16  | 5 | Priest  | | 1024 | 11 | Druid |
| 32  | 6 | Death Knight | | 2048 | 12 | Demon Hunter |
|     |   |         | | 4096 | 13 | Evoker |

## Safety guards

**Whole-run aborts** (writes nothing, exits non-zero — the workflow fails and no PR
opens) if the data looks bad or a refresh would destroy curated data:

- the `TransmogSet` CSV is missing an expected column (an HTML error page parsed as
  CSV, or a schema change);
- fewer than `-MinRows` rows came back (default **1000** — truncated/empty download);
- `ItemNameDescription` is missing a core difficulty label (Raid Finder / Normal /
  Heroic / Mythic), which would mis-resolve difficulty tiers;
- regeneration would drop more than `-MaxDeletePct`% of the **total** set entries
  (default **5%**).

**Per-group skip** (one group only, the rest still refresh): if regenerating a
populated tier (**≥10 sets**) would cut it to **less than half** its entries — almost
always a partial download rather than a real change — that group is left as written
and logged with a warning.

Because groups that don't resolve are also left unchanged, a partial download usually
preserves data; together these guards catch the cases that would otherwise gut or
corrupt the file.

## Running it by hand

```
pwsh ./update-sets.ps1                        # latest live (wow) build
pwsh ./update-sets.ps1 -Check                 # report staleness, write nothing (exit 1 if stale)
pwsh ./update-sets.ps1 -Build 11.2.0.61871    # pin a specific client build
pwsh ./update-sets.ps1 -Product wowt          # pull a different product (e.g. PTR)
pwsh ./update-sets.ps1 -MaxDeletePct 10       # loosen the set-deletion guard (default 5)
pwsh ./update-sets.ps1 -MinRows 2000          # raise the row-floor guard (default 1000)
```

Then verify in-game — `/reload`, and check **both** `/collected` and `/wbc` →
Collected render the affected tiers with correct class icons (a misaligned icon
means a missing `{}` placeholder).

## Adding a new raid tier

Auto-discovery isn't possible — nothing in the data separates raid tiers from PvP
seasons, test groups, etc. So add the group shell by hand, then let the generator
fill the sets:

1. Find the **TransmogSetGroupID**: search `TransmogSetGroup` on wago by raid name —
   `https://wago.tools/db2/TransmogSetGroup?filter[Name_lang]=<raid>`.
2. Add a `tinsert(ns.Sets, { ... })` in the matching expansion section with a
   **`(Difficulty)` suffix that matches a wago label** (Raid Finder / Normal /
   Heroic / Mythic) and an empty `sets = {},`:

   ```lua
   tinsert(ns.Sets, {
     id = 305,
     name = "Liberation of Undermine (Heroic)",
     release = 11,
     instance = 2769,   -- optional: JournalInstanceID, for lockout linking
     difficulty = 16,   -- optional: difficultyID
     minLevel = 80,
     sets = {},         -- generator fills this
   })
   ```
3. Run `pwsh ./update-sets.ps1` (or the scheduled job) — the empty `sets = {}` is
   populated from wago.

`release` indexes `ns.Releases` (1 = Vanilla … 12 = Midnight). `instance` /
`difficulty` are only needed for lockout linking; copy a sibling tier's values or
look them up on wago (`JournalInstance`).
