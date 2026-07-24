# Updating the transmog set data (`data/sets.lua` + `data/sets_late.lua`)

The Collected feature's set list (`ns.Sets`) is **regenerated from Blizzard's client
database** via [wago.tools](https://wago.tools). The hand-curated body is split across two
files for load time — [`../data/sets.lua`](../data/sets.lua) (Vanilla→Shadowlands, plus the
`ns.Releases`/`ns.ReleaseIcons` preamble) and [`../data/sets_late.lua`](../data/sets_late.lua)
(Dragonflight→Midnight) — and the generated mega-sets live in `sets_expand.lua` (see below).
The normal `update-sets.ps1` pass rewrites the `sets = {}` blocks in **both** body files. It
feeds both render paths:

- `/collected` (and `/collect`) — the standalone Collected window.
- `/wbc` → Collected tab — Warbandeer's `views/CollectedView.lua` (OptionalDep).

> The `tools/` folder is **maintainer-only** — excluded from the published
> CurseForge zip and from release change-detection, so editing it never ships or
> triggers a release.

> For the full map of what wago.tools exposes — every product, API endpoint, and the
> 1103-table DB2 catalog this generator pulls from — see
> [`wago-tools-reference.md`](wago-tools-reference.md).

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
source of truth**, so verify before adding. Blizzard `test`-named groups are skipped
automatically; groups listed in `excludes.txt` are reported as deliberate exclusions, not
candidates (see **Exclusions** below); no Lua is touched.

The report is a point-in-time snapshot (regenerable on demand, not kept in sync) — re-run
it after a patch. Inclusion stays editorial and incremental: pick a group from the report
and add it with the same shell as a raid tier below.

### Exclusions (`excludes.txt`)

The deliberate-exclusion list is the single source of truth shared by `-AuditCoverage` and
`-Expand`. Two granularities:

- **`<id>`** — exclude a whole group: the audit counts it as a deliberate exclusion (not
  "uncaptured"), and `-Expand` skips all its labels. For content we'll never add — test
  placeholders the `test`-name regex misses (e.g. `6`, `7` = "Parent/Child Chain Set"), or
  sets whose shape doesn't fit the class × set grid (`198` Trading Post cosmetic ensembles).
- **`<id>:<label>`** — exclude one `-Expand` row (see **Dead rows** above).

`'#'` starts a comment; each line carries the reason. The audit header reports the count
(`N are deliberately excluded`), so the floor stays honest.

### Set-level audit (`-AuditSets`)

`-AuditCoverage` is **group-level** (every wago group captured or excluded). But within a
captured group we render only a representative set per class — overlap labels, merges, and
excludes drop the rest, so the **set-level** count is lower (≈82%). To see and triage the
gap:

```
pwsh ./update-sets.ps1 -AuditSets
```

It diffs every placeable wago set against the cells in `data/sets.lua`,
`data/sets_late.lua` and `data/sets_expand.lua` and writes the un-rendered ones to
[`../data/sets_review.lua`](../data/sets_review.lua) as rows under an
ephemeral **"Review"** category — one row per set, classes from its `ClassMask`. Reload
and **filter Category → Review** to browse them in-game (sorted by expansion), decide which
deserve real curation (a new `expand-groups.txt` row, a merge, etc.), then **`git checkout
data/sets_review.lua`** to empty it. The committed `sets_review.lua` is an empty stub
(loaded by the `.toc` so the review rows light up when populated); never commit a populated
copy.

**Appearance-duplicates are skipped, not listed.** A set's identity is its exact list of
**`ItemModifiedAppearanceID`s** (its source items, from `TransmogSetItem`) — **not** its
name/label/`ClassMask`. Those three do *not* identify a look: the Alliance and Horde recolors of
a PvP set share all three yet are visually distinct, as are season recolors. So the audit keys
each set on its sorted-IMA signature; when an un-rendered set's signature exactly matches an
already-rendered one, its look is already on the grid, so it's dropped from Review (reported as
a skipped count) rather than flagged as a gap. What remains is genuine: distinct recolors to
capture (Alliance/Horde + season variants via `mergeseason`, armor-tile sets via `mergeset`,
20th-Anniversary re-releases via `assemble`) and recolor catalogs left as-is. Whole groups and
individual `set:<id>`s in `excludes.txt` are skipped too.

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
filled `ns.Sets` row per label for the groups listed in
[`expand-groups.txt`](expand-groups.txt), into its own data file
[`../data/sets_expand.lua`](../data/sets_expand.lua) (loaded right after `sets.lua` in the
toc; fenced `-- >>> AUTO-EXPAND … -- <<< AUTO-EXPAND`, the whole file rewritten each run):

```
pwsh ./update-sets.ps1 -Expand          # regenerates from expand-groups.txt
```

The canonical group list is **`expand-groups.txt`** — one **`id:Category[:byset]`** line per
group (`'#'` comments). To add a mega-set, add a line and re-run `-Expand`; to refresh after a
patch, just re-run `-Expand`. For each group it buckets sets by **label** (default — one row
per recolor/source variant) or by **set** (`byset` mode — one row per named ensemble, for
label-less flat lists like the Trading Post that grow over time), decomposes `ClassMask` into
class slots (first/lowest id wins, `{}` for gaps), and:

- **skips** labels/sets whose union `ClassMask` has no class bits (heritage/cosmetic/weapon
  pieces) and the bare no-label bucket of an otherwise-labeled group — both logged;
- **keeps but logs** *overlap* labels (recolors collapsing to one slot per class — only a
  representative appearance shows; the rest aren't separable from wago's data);
- infers `release` from the group's max `ExpansionID` and tags every row the given category.

`sets_expand.lua` is **owned wholesale by `-Expand`** — the normal `update-sets.ps1` pass only
touches `sets.lua` and never reads it (its byset rows resolve by set name, which the single-label
resolver would clobber). So refresh it by re-running `-Expand`, not the normal generator. The
weekly workflow runs both (normal pass for the hand-curated `sets.lua`, then `-Expand` for
`sets_expand.lua`), so new Trading Post ensembles land automatically.

**Merge directives** (also in `expand-groups.txt`, all generate into the same block) assemble
rows that a plain `id:Category` line can't, each `| `-delimited with an optional trailing
`| <release>` (1=Vanilla…12=Midnight) overriding wago's `ExpansionID`:

- **`merge <id>+<id>+… | Cat | Name`** — one class-disjoint row from several whole groups
  (armor-type / source splits of one logical set spanning group ids).
- **`mergeset <setid>+… | Cat | Name`** — merge specific **set** ids into one row (the owning
  group's byset/label rows skip them); for armor pieces of one set listed individually.
- **`eachset <setid>+… | Cat`** — emit **one row per set**, named `<set name> (<colour>)` (the
  colour/source is the label's last ` - `-delimited segment). The opposite of `mergeset`: for
  overlapping single-armor recolours that can't tile a full class row but are each a distinct
  appearance worth showing (the Legion/MoP recolour-catalogue leftovers).
- **`mergelabels <id>+… | Cat | NamePrefix`** — armor-type groups sharing source labels → one
  `NamePrefix (label)` row per label, tiling armor types across the groups.
- **`assemble <setid>:<classId>+… | Cat | Name`** — explicit set→class pairs, for all-class
  recolors that mask-merges can't tell apart (20th-Anniversary tier sets).
- **`mergeseason <groupId> | Cat`** — **own a whole PvP-style group**: bucket all its placeable
  sets by `ItemNameDescription` label, then greedy class-disjoint-tile each label into one row
  per visually-distinct recolor (Alliance/Horde faction variants share name+label+`ClassMask`
  but are different looks, so they tile into separate rows). Tile 1 is `(label)`, the 2nd+ get
  `(label II)`, `(label III)`. **Remove the group's hand-curated body rows first** — this
  regenerates every bracket/faction uniformly and owns the group. Set identity is the appearance
  (`TransmogSetItem`), so this captures the faction/season recolors the single-faction body rows
  left out (the bulk of the set-level gap).

**Dead rows — `excludes.txt`.** A few generated rows exist in wago but render **empty
in-game**: their appearance sources don't resolve to items on a live client (typically
defunct limited-time event content, e.g. Legion Remix/Timerunning). They pass the offline
checks but show as blank rows. Find them in-game with **`/collected coverage`** (it lists
rows that render nothing), then add an **`<id>:<label>`** line (label verbatim) to
[`excludes.txt`](excludes.txt) and re-run `-Expand` — the listed rows are skipped (logged
`exclude …`). This is the only way to drop them persistently, since the block is
regenerated wholesale each run. See **Exclusions** below — the same file drops whole
groups from the audit.

> **Coverage ceiling.** Overlap labels and cosmetic (`class=0`) pieces mean a few
> *appearances* per mega-set can't be shown in a per-class grid — this captures every
> **group**, not literally every appearance. Validate in-game with `/collected coverage`.

## Regenerating the weapon sources (`-Weapons`)

The **Weapons view** (the `Armor / Weapons` grid toggle) is backed by
[`../data/weaponsources.lua`](../data/weaponsources.lua) (`ns.WeaponSources`), owned
wholesale by **`-Weapons`** — every weapon + off-hand **appearance** bucketed by **source**
(row) × **weapon type** (column), per expansion:

```
pwsh ./update-sets.ps1 -Weapons          # regenerate data/weaponsources.lua
pwsh ./update-sets.ps1 -Weapons -Check    # staleness only, write nothing (exit 1 if stale)
```

Unlike armor, **Blizzard never grouped weapons into `TransmogSet` records**, so the grouping
is **derived from DB2** (no hand-curation, no `expand-groups.txt` equivalent). The join:

| Signal | Table | Gives |
|---|---|---|
| source **type** | `ItemModifiedAppearance.TransmogSourceTypeEnum` | `Enum.TransmogSource` per appearance (drop/quest/vendor/world/craft/achiev/TP; **HiddenUntilCollected → Other**) |
| specific **source** | `CollectableSourceInfo` + `CollectableSource{Encounter,Quest,Vendor}Sparse` | the encounter / quest map / vendor map |
| weapon **type** (column) | `Item.ClassID/SubclassID/InventoryType` | `Enum.TransmogCollectionType` (ClassID 2; **Shield/Holdable are Armor class 4**) |
| instance **expansion** | `JournalTier` via `JournalTierXInstance` | release — **not `Map.ExpansionID`**, which is 0 for brand-new maps (filter the `9000` "Current Season" tier) |
| raid vs dungeon | `Map.InstanceType` | 2 = Raid, 1 = Dungeon, 0 = World Boss |

Values in `types` are `ItemAppearanceID`s (the visuals); the in-game scan resolves collected
state per visual. Design decisions baked in (see the design doc — `Notes/wow-collected-weapons-view-design.md`):

- **One representative source per visual**, priority **drop > quest > vendor > TP > world > craft > achiev**.
- **HiddenUntilCollected sources fall back to an `Other` row.** `TransmogSource.HiddenUntilCollected` (5) is how Timewalking reissues and other masked-source items are flagged — the one *obtainable* source type outside the priority above, so without this the visual is **silently dropped** (never placed, never counted — the *Warglaives of Azzinoth* bug, #670). It's bucketed by the collectible item's own expansion. Genuinely uncollectable sources — `CantCollect` (6) / `NotValidForTransmog` (9) / `None` (0) — stay out, so the grid's % isn't padded with looks that can never reach 100%.
- **Dungeon/raid wings merge** into the base instance (`Dire Maul - Gordok Commons` → `Dire Maul`).
- **PvP weapons stay under `Vendor`** (no clean offline PvP signal yet) — a future refinement.
- **Artifact weapons are excluded** (`ArtifactAppearance*` is a separate spec-coupled subsystem) — a fast-follow.
- Appearances whose expansion can't be resolved land in a **`release = 0`** ("Other") bucket, not dropped.

**Ownership & cadence.** The file is regenerated wholesale each run; refresh it by re-running
`-Weapons` (never hand-edit). Row ids are **stable** — instance rows `9_200_000 + JournalInstanceID`,
per-expansion aggregates `9_300_000 + …` — clear of armor `setId`s and the `weapons.lua`
illusion/arsenal ids. Guards mirror the other modes (row floors on `Item`/`ItemModifiedAppearance`,
a min-placed floor, a build stamp that updates only on a real change). It downloads a broader table
set than the armor pass — notably **`ItemSparse` (~50 MB)**, streamed for just `ID`+`ExpansionID`.
It refreshes **weekly**: [`update-collected-weapons.yml`](../../.github/workflows/update-collected-weapons.yml)
regenerates on a schedule (Wednesdays), lints **and** runs the specs against the fresh file (the
busted step catches a regen that drops an arsenal appearance — the #670 invariant luacheck can't
see), and opens a PR (`bot/collected-weapons-refresh`) when the data moved; you review and merge.
The week-long gap to the next retry makes a failed run costly, so it raises a tracking issue on the
**first** failure (auto-closed on recovery), unlike the daily set refresh. Run `-Weapons` by hand after a
content patch if you don't want to wait for the weekly.

> **Verify in-game** after a refresh: `/reload`, toggle to Weapons, and spot-check a raid
> (Molten Core's `Dagger` cell should read 4). A `/collected coverage` weapons variant catches
> rows that resolve offline but render empty on a live client.

## Weapon PTR preview (`-Weapons -PtrDelta`)

The Weapons grid has a **PTR PREVIEW** toggle (like the armor grid): flip it and the grid becomes the
weapon/off-hand **appearances on the PTR (`wowt`) but not yet on live (`wow`)** — muted-blue "upcoming"
counts, with a `+N appearances upcoming · PTR <build>` header tally. That delta lives in
[`../data/weaponsources_ptr.lua`](../data/weaponsources_ptr.lua) (`ns.WeaponPtrSources` +
`ns.WeaponPtrBuild`), generated by the same script in **`-Weapons -PtrDelta`** mode:

```
pwsh ./update-sets.ps1 -Weapons -PtrDelta          # latest live vs latest PTR
pwsh ./update-sets.ps1 -Weapons -PtrDelta -Check   # patch-aware staleness (exit 2 = new PTR patch)
```

Weapons have no `TransmogSet` grouping, so the delta is at the **appearance** level: it runs the full
`-Weapons` bucketing pipeline over the PTR build (shared `Get-WeaponRows`), then keeps only visuals
**absent from the live weapon-visual set** (a light `Item` + `ItemModifiedAppearance` pull of the live
build). The output has the identical `{ id, name, release, category, types }` shape as
`weaponsources.lua`; instance/lockouts are moot for unreleased content.

**New-patch detection** mirrors the armor PTR path: `-Check` is a cheap, patch-aware probe (build list
only, no CSV) reading `ns.WeaponPtrBuild.ptr` — exit `2` on a new PTR *patch* (or a missing file), `0`
on the same patch, else a real error. Within-patch build bumps are ignored (the PTR churns).
[`.github/workflows/update-collected-weapons-ptr.yml`](../../.github/workflows/update-collected-weapons-ptr.yml)
runs it **daily**; on exit 2 it regenerates, lints, and opens a PR (`bot/collected-weapons-ptr-refresh`)
replacing the whole list — you review the (volatile) diff and merge. Two consecutive failures raise a
tracking issue (auto-closed on recovery), like the armor PTR watcher.

> The grid + counter render on the **live** client (the appearances just aren't collectible yet); the
> 3D drill-in is disabled for upcoming weapons — log into the PTR to preview them in 3D.
