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
difficulty). Anything it can't resolve is **left exactly as written**.

When a curated `(Difficulty)` suffix doesn't match wago's label verbatim — e.g. the
Wrath `(10 Normal)` vs wago's `10 Player (Normal)` — add a `curated => wago label`
line to **`difficulty-aliases.txt`** and it resolves; no code change.

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

## Updating the PTR preview (`data/sets_ptr.lua`)

The **PTR PREVIEW** toggle in the Collected window lists the **upcoming** sets — on
the latest PTR (`wowt`) build but **not yet on live** (`wow`). That delta lives in
[`../data/sets_ptr.lua`](../data/sets_ptr.lua) (`ns.PtrSets` + `ns.PtrBuild`), fully
generated by the same script in **`-PtrDelta`** mode:

```
pwsh ./update-sets.ps1 -PtrDelta                 # latest live vs latest PTR
pwsh ./update-sets.ps1 -PtrDelta -Check          # report staleness, write nothing (exit 1 if stale)
pwsh ./update-sets.ps1 -PtrDelta -PtrBuild 12.1.0.68301 -LiveBuild 12.0.7.68275   # pin both
```

It downloads the live + PTR `TransmogSet` tables (plus `TransmogSetGroup` for names and
`ItemNameDescription` for difficulty/variant labels), keeps the set ids present on the
PTR but absent from live, and buckets them **by (group name, label)**: a group with more
than one label splits into a row per label with a `Name (Label)` suffix — a raid becomes
Raid Finder/Normal/Heroic/Mythic rows (ordered that way), PvP becomes Gladiator/Elite/…
rows — while a single-variant set (delve, world-quest, renown) stays one bare-named row
and its armor-type group-id variants merge into it. It decomposes `ClassMask` into class
slots (first/lowest set id wins) and writes the file from scratch — `release` tagged to
the newest expansion, `instance`/`difficulty` omitted (no lockouts for unreleased
content). Both build numbers are stamped at the top.

The same integrity guards (required columns, `-MinRows` floor) apply; the same
`ClassMask → classId` table above is used.

### New-patch detection (the part that's automated)

PTR builds churn — sets are added and removed between builds *within* a patch — so
unlike the live refresh, regenerating on every build would be noise. What matters is
a **new PTR patch** opening (e.g. `12.1.0` → `12.1.5`, or `12.2.0`): a fresh content
cycle whose *whole* upcoming list should be replaced. "Patch" = the first three
version components; the trailing build number is ignored.

`-Check` is a **patch-aware** probe (and cheap — it only reads wago's build list, no
CSV download). It compares the latest PTR patch against the `ptr` build stamped in
`ns.PtrBuild` and exits:

| Exit | Meaning |
|---|---|
| `0` | Same patch — nothing to do (a within-patch build bump alone is ignored) |
| `2` | A **new PTR patch** (or `sets_ptr.lua` missing/unstamped) — regenerate |
| other | A real error (wago unreachable, etc.) — the script threw |

```
pwsh ./update-sets.ps1 -PtrDelta -Check     # is a new PTR patch out? (exit 2 = yes)
```

[`.github/workflows/update-collected-ptr.yml`](../../.github/workflows/update-collected-ptr.yml)
runs this **daily** (and on demand). On exit `2` it regenerates `sets_ptr.lua`, lints
it, and opens a PR (`bot/collected-ptr-refresh`) replacing the old list — so a new
patch's preview lands automatically; you just review the (volatile) diff and merge.
Two consecutive failures raise a tracking issue (auto-closed on recovery), mirroring
the live job.

> To refresh the list **within** the current patch (pick up sets added since the last
> generate without waiting for a patch bump), just run `-PtrDelta` by hand and commit.

## Auditing coverage (what we're *not* capturing)

`ns.Sets` curates a **subset** of wago's transmog groups — wago has far more (PvP
seasons, dungeon / Mythic+ sets, delves, Trading Post, professions, world drops, …).
To see the gap, run **`-AuditCoverage`**:

```
pwsh ./update-sets.ps1 -AuditCoverage                       # write tools/coverage-report.md
pwsh ./update-sets.ps1 -AuditCoverage -ReportFile out.md    # custom output path
pwsh ./update-sets.ps1 -AuditCoverage -Build 12.0.7.68275   # pin a client build
```

It downloads the same three tables (`TransmogSet`, `TransmogSetGroup`,
`ItemNameDescription`), diffs the wago group ids against the ones already in `ns.Sets`,
and writes [`coverage-report.md`](coverage-report.md): every **uncaptured** group with
its expansion, set count, and difficulty/variant labels, bucketed into heuristic
**categories** (PvP, Dungeon / Mythic+, Delve, Raid, Profession / Crafted, Trading
Post, Timewalking, Reputation / Renown / Campaign, World drops / quests, and a
catch-all). Categories come from each group's labels + name — a **triage aid, not a
source of truth**, so verify before adding. Blizzard test placeholders are skipped; no
Lua is touched.

The report is a point-in-time snapshot (regenerable on demand, not kept in sync) — re-run
it after a patch. Inclusion stays editorial and incremental: pick a group from the report
and add it with the same shell as a raid tier below.

## Adding a new raid tier (or any audited group)

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

> **Tip — the difficulty suffix matches *any* `ItemNameDescription` label**, not just
> Raid Finder/Normal/Heroic/Mythic. A multi-label group (one carrying e.g. *Dungeons*,
> *World Drops*, *Renown*, or color names *Blue*/*Red*) is captured by seeding **one
> shell per label**, each `name = "Group (<label>)"`. A label fills cleanly when its
> sets are **class-disjoint**; a label that bundles recolors (multiple sets covering the
> same class) keeps only the lowest-id appearance per class.

## Expanding recolor / multi-source mega-sets (`-Expand`)

Some groups carry *dozens* of labels (Legion: World has 22 color variants, MoP: World
17). Hand-seeding a shell per label is tedious, so **`-Expand`** auto-generates one
filled `ns.Sets` row per label for the listed groups, into a single **guarded region**
at the end of `sets.lua` (`-- >>> AUTO-EXPAND … -- <<< AUTO-EXPAND`, replaced wholesale
each run):

```
pwsh ./update-sets.ps1 -Expand "319:World,320:Dungeon,321:Event,244:World"
```

Argument is a comma list of **`id:Category`**. For each group it buckets sets by label,
decomposes `ClassMask` into class slots (first/lowest id wins, `{}` for gaps — same model
as the normal fill, so the rows still refresh on the weekly run), and:

- **skips** labels whose union `ClassMask` has no class bits (heritage/cosmetic pieces)
  and the bare no-label bucket of an otherwise-labeled group — both logged;
- **keeps but logs** *overlap* labels (recolors collapsing to one slot per class — only a
  representative appearance shows; the rest aren't separable from wago's data);
- infers `release` from the group's max `ExpansionID` and tags every row the given category.

The region is plain `tinsert(ns.Sets, {...})` rows, so the normal generator re-resolves
them by id + label suffix — running `pwsh ./update-sets.ps1` afterwards is a no-op (verify
with `-Check`). Re-run `-Expand` (then the normal generator) to refresh after a patch.

**Dead rows — `expand-exclude.txt`.** A few generated rows exist in wago but render
**empty in-game**: their appearance sources don't resolve to items on a live client
(typically defunct limited-time event content, e.g. Legion Remix/Timerunning). They pass
the offline checks but show as blank rows. Find them in-game with **`/collected coverage`**
(it lists rows that render nothing), then add an **`id:label`** line (label verbatim) to
[`expand-exclude.txt`](expand-exclude.txt) and re-run `-Expand` — the listed labels are
skipped (logged `exclude …`). This is the only way to drop them persistently, since the
region is regenerated wholesale each run.

> **Coverage ceiling.** Overlap labels and cosmetic (`class=0`) pieces mean a few
> *appearances* per mega-set can't be shown in a per-class grid — this captures every
> **group**, not literally every appearance. Validate in-game with `/collected coverage`.
