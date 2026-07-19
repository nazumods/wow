# wago.tools data-source reference

Every data source [wago.tools](https://wago.tools) exposes, enumerated and documented.
wago.tools is a community datamining site that mirrors Blizzard's client **CASC**
storage: the extracted client database (**DB2**) tables, the raw client **files**, and
the **build** manifest, each queryable per game build. Our Collected pipeline
([`update-sets.ps1`](update-sets.ps1) / [`UPDATING.md`](UPDATING.md)) uses exactly two of
these — `/api/builds` (to resolve the live build) and `/db2/{table}/csv` (to pull
`TransmogSet` & friends) — but the full surface is below.

> Snapshot: probed **2026-07-19** against retail build **12.1.0.68745** (PTR) /
> **12.0.7.68453** (live). Counts drift as Blizzard ships builds; the *shapes* are stable.
> The companion [`wago-tools-tables.txt`](wago-tools-tables.txt) is the full 1103-table
> catalog snapshot.

---

## 1. Products (the `product` / build axis)

Every data source is versioned by **build** (`MAJOR.MINOR.PATCH.BUILD`, e.g.
`12.0.7.68453`), and builds are grouped by **product** (which client stream). The 13
product codes currently served, with build counts and latest version as of the snapshot:

| Product code | Stream | Builds | Latest |
|---|---|---:|---|
| `wow` | Retail — **live** | 496 | 12.0.7.68453 |
| `wowt` | Retail — **PTR** (public test) | 468 | 12.1.0.68745 |
| `wowxptr` | Retail — secondary/experimental PTR | 105 | 12.0.7.68774 |
| `wow_beta` | Retail — next-expansion beta | 186 | 12.0.1.66220 |
| `wowlivetest` | Retail — live-event test realm (legacy) | 25 | 10.2.5.52646 |
| `wowz` | Retail — internal/submission (legacy) | 67 | 9.0.2.35978 |
| `wow_classic` | Classic — live (MoP Classic) | 274 | 5.5.4.68716 |
| `wow_classic_ptr` | Classic — PTR | 211 | 5.5.4.67849 |
| `wow_classic_beta` | Classic — beta | 114 | 5.5.0.62071 |
| `wow_classic_titan` | Classic — "Titan" engine/tech build | 24 | 3.80.1.68768 |
| `wow_classic_era` | Classic Era — live (Vanilla-era) | 105 | 1.15.8.67156 |
| `wow_classic_era_ptr` | Classic Era — PTR | 121 | 10.1.5.49595 |
| `wow_anniversary` | Anniversary / Fresh realms | 21 | 2.5.6.68775 |

The pipeline pins `wow` for the live refresh and `wowt` for the PTR-preview delta —
never the bare/newest build, which would mix products (see `UPDATING.md`, "Source build").

---

## 2. Builds API — `/api/builds*` (JSON)

The build manifest. This is the only official machine API besides files. All return JSON.

| Endpoint | Returns |
|---|---|
| `GET /api/builds` | **Every** version, as an object keyed by product → array of build records (newest first). |
| `GET /api/builds/latest` | The latest build **per product**, as an object keyed by product → one record. |
| `GET /api/builds/{product}/latest` | The single latest build for one product (e.g. `/api/builds/wow/latest`). |

Build record shape (from `/api/builds`):

```json
{ "product": "wow", "version": "12.0.7.68453", "created_at": "2026-07-06 23:57:02",
  "build_config": "34a1a445…", "product_config": "53020d32…", "cdn_config": "1deda1a1…",
  "is_bgdl": false }
```

`build_config` / `product_config` / `cdn_config` are the CASC config hashes for that
build; `is_bgdl` marks a background-download (streaming) build. The `/latest` variants
omit `is_bgdl`. This is what `update-sets.ps1` reads to resolve and pin a build.

---

## 3. Files & CASC — raw client files by FileDataID

Every asset in the client is addressed by a numeric **FileDataID (FDID)**. wago exposes
the listfile and the raw bytes:

| Endpoint | Returns |
|---|---|
| `GET /api/files` | The **listfile** for a build: every FDID → filename. Supports **version** and **format** flags (§5). Large (hundreds of thousands of rows) — always scope with `?version=` or `?product=`. |
| `GET /api/info/{fdid}` | JSON metadata for one file: `filename`, `type` (e.g. `db2`, `m2`, `blp`, `avi`), and `latest`/`chashes` (the content MD5 + build where it appears, per product). Invalid FDID → HTTP 400. |
| `GET /api/casc/{fdid}` | The **raw file bytes** (`application/octet-stream`) extracted from CASC. Supports **version** (defaults to latest). |

`/api/info/{fdid}` shape:

```json
{ "fdid": 1349477, "filename": "dbfilesclient/map.db2", "type": "db2",
  "latest": { "wow_beta": { "version": "7.0.1.20979", "product": "wow_beta",
                            "md5": "1815c2bd…", "fdid": 1349477 }, … },
  "chashes": [ … ] }
```

Note the DB2 tables themselves are files (`dbfilesclient/*.db2`) — but you rarely need the
raw `.db2`; use the parsed CSV export in §4 instead.

---

## 4. DB2 tables — the client database (1103 tables)

The heart of wago.tools: Blizzard's client database, extracted and parsed into
**1103 tables** (this build) across **1649** selectable build versions. Full catalog in
[`wago-tools-tables.txt`](wago-tools-tables.txt). Three access routes:

| Route | Purpose |
|---|---|
| `GET /db2/{table}/csv` | **CSV export** of an entire table. Accepts `?build=<full build>` or `?product=<code>`. **Always CSV** — the `format` flag is ignored here. This is the pipeline's data source. |
| `GET /db2/{table}` | Interactive **browser** page (Inertia/Vue). Requested as an Inertia partial it returns Laravel-**paginated JSON** — filterable, searchable, sortable (§4.1). |
| `GET /db2/{table}/diff` | Row-level **diff** of a table between two builds (the "what changed" view). |

CSV export used by the pipeline:

```
https://wago.tools/db2/TransmogSet/csv?build=12.0.7.68453
```

### 4.1 Interactive JSON (the browser's data feed)

`/db2/{table}` is an Inertia page; fetching it with the Inertia partial headers
(`X-Inertia: true`, `X-Inertia-Version: <hash>`, `X-Inertia-Partial-Data: data`) returns
just the paginated rows as JSON — a standard Laravel paginator:

```json
{ "props": { "data": { "current_page": 1, "per_page": …, "total": …,
  "data": [ { "ID": 10, "Season": 5, "ExpansionID": 8, … }, … ],
  "next_page_url": "…", "links": […] } } }
```

It also accepts the browser's query params (`?filter[Col]=…`, `?search=…`, `?sort=…`,
`?page=…`, `?build=…`). This is **not a documented/stable contract** (it's the SPA's
internal feed, and the Inertia version hash rotates on deploy) — prefer the CSV export for
automation. Useful for ad-hoc filtered lookups where downloading the whole CSV is overkill.

### 4.2 Column naming (DBD)

Column names come from the community **DBDefs** (WoWDBDefs) project. Named columns keep
their DBD names (`ID`, `ExpansionID`, `ClassMask`, `TransmogSetGroupID`, …); columns not
yet named in DBD appear as **`Field_<build>_NNN`** (e.g. `Field_9_2_0_42174_000`), with a
**`_lang`** suffix on localized strings (`Field_..._lang`, `Name_lang`, `Description_lang`).
The `/db2` page also carries DBD **foreign-key** metadata (`dbdFk`/`dbdMeta`) — the
inter-table relationships the browser renders as clickable links. **Guard against name
drift:** `update-sets.ps1` asserts its expected columns exist and aborts otherwise, exactly
because a DBD rename or a schema change can move a `Field_*` to a real name (or vice-versa)
between builds.

### 4.3 Tables this repo consumes

The Collected pipeline reads these (all under `/db2/<name>/csv`):

| Table | Used for |
|---|---|
| `TransmogSet` | The set rows — `ID`, `ClassMask`, `TransmogSetGroupID`, `ItemNameDescriptionID`, `ExpansionID`. |
| `TransmogSetGroup` | Group `ID` → `Name_lang` (display name). |
| `TransmogSetItem` | Set → `ItemModifiedAppearanceID` (the appearance signature for `-AuditSets` dedup). |
| `ItemNameDescription` | Difficulty/variant labels (Raid Finder / Normal / Heroic / Mythic, colours, …). |
| `ItemModifiedAppearance` | Appearance → item resolution (Wowhead source research). |

Adjacent transmog tables that exist if the feature ever needs them: `TransmogIllusion`
(enchant illusions — relevant to the #516/#596 weapon-illusion work, currently hand-authored
in [`../data/weapons.lua`](../data/weapons.lua)), `ItemAppearance`, `ArtifactAppearance` /
`ArtifactAppearanceSet`, `TransmogOutfit*`, `TransmogHoliday`, `TransmogSituation*`.

---

## 5. Version & format flags

Two query flags recur across the versioned endpoints (`/api/files`, `/api/casc/{fdid}`,
`/db2/{table}` and its `/csv`):

- **`?version=`** — a full build string (`?version=10.1.0.50000`). Selects that exact build.
- **`?product=`** — a product code (`?product=wow_classic_beta`). Resolves to that product's
  **latest** build. (The CSV route also accepts `?build=` as the version param.)
- **`?format=`** — `csv` (default) or `json`. Honored by **`/api/files`**; the
  `/db2/{table}/csv` route ignores it and always returns CSV.

Omitting the version selects the newest build across products (which is why the pipeline
always pins one — the bare newest is often a PTR/beta build).

---

## 6. Feature views (UI over the same DB2 + CASC data)

These are Vue pages, not separate data APIs — each is a rendered view over the DB2/CASC
sources above. Listed for completeness (all `GET`):

| Route | View |
|---|---|
| `/builds` | Build list / picker. |
| `/builds-diff` | Compare two builds (which DB2 tables/rows changed). |
| `/db2/{table}` | The DB2 table browser (§4). |
| `/journal/{instance?}` | Adventure/Dungeon Journal — encounters & loot. |
| `/atlas/{id}` | Atlas texture-sheet viewer. |
| `/files` | CASC file browser (over the listfile). |
| `/sounds` | Sound-file browser. |
| `/hotfixes` | Hotfix (live `DBCache`) viewer — DB2 overrides shipped between builds. |
| `/maps/{map?}`, `/maps/worldmap/{map?}` | Map & world-map viewer. |
| `/branding` | Branding assets. |
| `/apis` | This API index page (source of §2–§7). |

`/hotfixes` is worth knowing: Blizzard patches DB2 data live via hotfixes without a new
build, so a table's CSV can lag what's actually live — the hotfixes view surfaces those.

---

## 7. Webhooks — `/webhook`

`GET /webhook` (manage) / `POST /webhook` (register) — subscribe a callback to be notified
when a new build is detected. An alternative to polling `/api/builds`; our pipeline polls
on a schedule instead (see the GitHub workflows in `UPDATING.md`).

---

## 8. Not data sources (site infrastructure)

For completeness, the route table also exposes framework/ops endpoints that carry no game
data and should be ignored: `login` / `login/bnet` / `logout` (Battle.net auth),
`feedback*` (feedback form), and the Laravel toolchain — `horizon/*` (queue dashboard),
`_debugbar/*`, and `_ignition/*` (error handler).

---

## Appendix — quick reference

```
# Resolve builds
GET  https://wago.tools/api/builds                     # all versions, by product
GET  https://wago.tools/api/builds/latest              # latest per product
GET  https://wago.tools/api/builds/{product}/latest    # latest for one product

# DB2 tables (1103; see wago-tools-tables.txt)
GET  https://wago.tools/db2/{table}/csv?build={build}  # CSV export (pipeline path)
GET  https://wago.tools/db2/{table}/csv?product={code} # …or latest for a product
GET  https://wago.tools/db2/{table}/diff               # row diff between builds
GET  https://wago.tools/db2/{table}                    # browser; Inertia partial = paginated JSON

# Raw client files (by FileDataID)
GET  https://wago.tools/api/files?version={build}&format={csv|json}   # listfile
GET  https://wago.tools/api/info/{fdid}                # file metadata (JSON)
GET  https://wago.tools/api/casc/{fdid}?version={build}# raw file bytes

# Notifications
POST https://wago.tools/webhook                        # new-build webhook
```
