<#
.SYNOPSIS
  Regenerate the inner `sets = { ... }` blocks of the hand-curated body files
  Warbandeer_Collected/data/sets.lua + data/sets_late.lua from live wago.tools
  TransmogSet data. (data/sets_expand.lua is owned by the separate -Expand mode.)

.DESCRIPTION
  Downloads the TransmogSet + ItemNameDescription tables once and rewrites each
  group's `sets = { ... }` block in place — ordered by classId with empty `{}`
  placeholders for missing classes.

  Two wago facts drive it:
    * A set's ClassMask is a bitfield of the classes it covers — a classic tier
      set is one class (1 = Warrior), a Raid Finder "armor type" set covers
      several (35 = Warrior|Paladin|Death Knight). The mask is decomposed so the
      set lands in every class slot it fills.
    * Several addon groups share one TransmogSetGroupID, one per difficulty
      (Antorus is four groups, all id 62). They are told apart by each set's
      ItemNameDescriptionID, which ItemNameDescription labels "Raid Finder" /
      "Normal" / "Heroic" / "Mythic" / etc. The difficulty is read from the
      group's curated `name` suffix — e.g. "Antorus ... (Heroic)" — and used to
      pick the matching rows.

  Everything else is preserved byte-for-byte: the `ns.Releases` / `ns.ReleaseIcons`
  preamble, all comments, and every group's curated metadata (`id`, `name`,
  `release`, `instance`, `difficulty`, `minLevel`). Group names are never touched.

  CONSERVATIVE: a group is rewritten only when its rows can be confidently
  resolved — the id exists in wago AND (the name's difficulty suffix maps to a
  label present for that id, OR the group has no suffix and its id carries a
  single difficulty). Anything else (Wrath 10/25-man tiers, custom "Timerunning"
  labels, ambiguous ids) is left exactly as written. To add a new tier, insert a
  group with an empty `sets = {}` and re-run.

  See UPDATING.md in this folder for the full workflow.

.PARAMETER SetsFile  Path to data/sets.lua. Defaults to ../data/sets.lua.
.PARAMETER Build     Optional client build (e.g. 11.2.0.61871). Omit for current.
.PARAMETER Check     Don't write; exit 1 if the file would change (CI staleness).

.EXAMPLE
  pwsh ./update-sets.ps1
.EXAMPLE
  pwsh ./update-sets.ps1 -Check
#>
[CmdletBinding()]
param(
  [string]$SetsFile = (Join-Path $PSScriptRoot '..' 'data' 'sets.lua'),
  [string]$Product = 'wow',
  [string]$Build,
  [int]$MinRows = 1000,       # abort if TransmogSet returns fewer (incomplete download)
  [int]$MaxDeletePct = 5,     # abort if regeneration would drop more than this % of sets
  [switch]$Check,
  # PTR-delta mode: regenerate data/sets_ptr.lua (ns.PtrSets) from the diff between
  # the latest live (wow) and PTR (wowt) TransmogSet tables — sets on the PTR but
  # not yet on live ("upcoming"). Volatile; run on demand, not on the weekly cadence.
  [switch]$PtrDelta,
  [string]$PtrFile = (Join-Path $PSScriptRoot '..' 'data' 'sets_ptr.lua'),
  [string]$LiveBuild,         # explicit live build for the delta (default: latest wow)
  [string]$PtrBuild,          # explicit PTR build for the delta (default: latest wowt)
  # Coverage-audit mode: report the wago TransmogSet groups we DON'T curate in
  # ns.Sets yet, categorized so a human can pick which to add. Writes a markdown
  # report; touches no Lua. See UPDATING.md ("Auditing coverage").
  [switch]$AuditCoverage,
  [string]$ReportFile = (Join-Path $PSScriptRoot 'coverage-report.md'),
  # Expand mode: auto-generate one curated ns.Sets row per wago label for each group
  # listed in tools/expand-groups.txt ("id:Category" lines), into data/sets_expand.lua
  # — the mechanical way to capture recolor/multi-source mega-sets without hand-seeding
  # dozens of shells. The file is the canonical spec, so a refresh is just `-Expand`
  # (no args). See UPDATING.md.
  [switch]$Expand,
  [string]$ExpandFile = (Join-Path $PSScriptRoot 'expand-groups.txt'),
  # Set-level audit: the group audit is 100%, but within captured groups we render only a
  # representative per class (overlap labels, merges, excludes). -AuditSets diffs every
  # placeable wago SET against the cells in sets.lua and writes the un-rendered ones as
  # rows under an ephemeral "Review" category into data/sets_review.lua — so they can be
  # browsed in-game (filter Category → Review) and triaged. Local-only: the committed file
  # is an empty stub; `git checkout` it when done. See UPDATING.md.
  [switch]$AuditSets,
  [string]$ReviewFile = (Join-Path $PSScriptRoot '..' 'data' 'sets_review.lua'),
  # Output file for the -Expand block — its own data file (loaded after sets.lua in the
  # .toc) so the generated rows don't bloat the hand-curated body. Owned wholesale by -Expand.
  [string]$ExpandSetsFile = (Join-Path $PSScriptRoot '..' 'data' 'sets_expand.lua'),
  # Weapons mode: generate data/weaponsources.lua (ns.WeaponSources) — every weapon/off-hand
  # APPEARANCE bucketed by source (row) x weapon type (column), derived from DB2. Blizzard never
  # grouped weapons into TransmogSet records, so the grouping is derived. Self-contained; see UPDATING.md.
  [switch]$Weapons,
  [string]$WeaponsFile = (Join-Path $PSScriptRoot '..' 'data' 'weaponsources.lua'),
  # Weapon PTR-preview delta: with -PtrDelta, -Weapons regenerates data/weaponsources_ptr.lua
  # (ns.WeaponPtrSources) — weapon/off-hand APPEARANCES on the PTR (wowt) but not yet on live (wow),
  # bucketed like weaponsources.lua. Volatile; the daily watcher runs it patch-gated. See UPDATING.md.
  [string]$WeaponsPtrFile = (Join-Path $PSScriptRoot '..' 'data' 'weaponsources_ptr.lua')
)

$ErrorActionPreference = 'Stop'
# Identify ourselves to wago.tools on every request (same UA as Tooling/lint-stale-ids.ps1), so the
# suite's automated traffic is attributable rather than an anonymous client. One default covers every
# Invoke-WebRequest below — the per-mode CSV helpers and the /api/builds lookups alike.
$PSDefaultParameterValues['Invoke-WebRequest:UserAgent'] = 'Warbandeer-suite-ci (github.com/nazumods/wow)'
$SetsFile = (Resolve-Path -LiteralPath $SetsFile).Path

# Single source of truth for deliberately-excluded wago groups/rows (tools/excludes.txt),
# read by both -AuditCoverage and -Expand. Two granularities:
#   <id>          — whole group: the audit won't list it as uncaptured, and -Expand skips
#                   every label. For content we'll never add (test placeholders, sets whose
#                   shape doesn't fit the class grid).
#   <id>:<label>  — one label-row: -Expand skips just that row (the group still counts as
#                   captured via its other labels). For -Expand rows that render empty on a
#                   live client (defunct-event sources that don't resolve to items).
# '#' starts a comment. Returns @{ groups = @{[int]=$true}; rows = @{"id|label"=$true} }.
function Get-Excludes {
  $g = @{}; $r = @{}; $s = @{}
  $f = Join-Path $PSScriptRoot 'excludes.txt'
  if (Test-Path -LiteralPath $f) {
    foreach ($ln in (Get-Content -LiteralPath $f)) {
      $t = ($ln -split '#', 2)[0].Trim()
      if (-not $t) { continue }
      if ($t -match '^set:\s*(\d+)') { $s[[int]$Matches[1]] = $true }   # -AuditSets only: drop one wago set id (data-quirk twin/orphan)
      elseif ($t -match ':') { $kv = $t -split ':', 2; $r["$([int]$kv[0].Trim())|$($kv[1].Trim())"] = $true }
      else { $g[[int]$t] = $true }
    }
  }
  return @{ groups = $g; rows = $r; sets = $s }
}

# Every wago group id referenced by tools/expand-groups.txt — the leading id of each
# normal/single/byset line, plus all components of each `merge` line. A merged row keeps
# only the lowest id, so the others vanish from sets.lua; the audit reads these so it
# still counts them as captured (not "uncaptured"). Returns @{[int]=$true}.
function Get-ExpandIds([string]$file) {
  $ids = @{}
  if (Test-Path -LiteralPath $file) {
    foreach ($ln in (Get-Content -LiteralPath $file)) {
      $t = ($ln -split '#', 2)[0].Trim()
      if (-not $t) { continue }
      if ($t -match '^mergelabels\s+(\S+)') { foreach ($x in ($Matches[1] -split '\+')) { $ids[[int]$x] = $true } }
      elseif ($t -match '^merge\s+(\S+)') { foreach ($x in ($Matches[1] -split '\+')) { $ids[[int]$x] = $true } }
      elseif ($t -match '^mergeseason\s+(\d+)') { $ids[[int]$Matches[1]] = $true }
      elseif ($t -match '^(\d+)') { $ids[[int]$Matches[1]] = $true }
    }
  }
  return $ids
}

# ── Coverage-audit mode ──────────────────────────────────────────────────────
# Report the wago TransmogSetGroups we DON'T yet curate in ns.Sets, with enough
# metadata (expansion, difficulty/variant labels, set count) to triage which to
# add. Self-contained (own single-build download); writes markdown, touches no Lua,
# and exits before the normal refresh below. Categories are heuristic — derived from
# each group's labels + name — so a human can scan, not a source of truth.
if ($AuditCoverage) {
  function AuditCsv([string]$table, [string]$build) {
    $url = "https://wago.tools/db2/$table/csv?build=$build"
    Write-Host "Fetching $url" -ForegroundColor Cyan
    (Invoke-WebRequest -Uri $url -UseBasicParsing -ErrorAction Stop).Content | ConvertFrom-Csv
  }

  # Resolve the live build (pin it — the bare endpoint serves PTR too).
  $builds = (Invoke-WebRequest -Uri 'https://wago.tools/api/builds' -UseBasicParsing -ErrorAction Stop).Content | ConvertFrom-Json
  if (-not $Build) { $Build = $builds.wow[0].version }
  $bMatch = $builds.wow | Where-Object { $_.version -eq $Build } | Select-Object -First 1
  $bDate  = if ($bMatch) { ($bMatch.created_at -split ' ')[0] } else { '' }
  Write-Host "Coverage audit against wow build $Build $bDate" -ForegroundColor Cyan

  $tsRows  = AuditCsv 'TransmogSet' $Build
  $grpRows = AuditCsv 'TransmogSetGroup' $Build
  $indRows = AuditCsv 'ItemNameDescription' $Build
  foreach ($col in @('ID', 'ClassMask', 'TransmogSetGroupID', 'ItemNameDescriptionID', 'ExpansionID')) {
    if ($col -notin $tsRows[0].PSObject.Properties.Name) { throw "TransmogSet CSV missing '$col' — aborting." }
  }
  if ($tsRows.Count -lt $MinRows) { throw "TransmogSet returned $($tsRows.Count) rows (< $MinRows) — incomplete download, aborting." }

  $grpName = @{}; foreach ($g in $grpRows) { $grpName[[int]$g.ID] = ([string]$g.Name_lang).Trim() }
  $indLabel = @{}; foreach ($d in $indRows) { $id = 0; [void][int]::TryParse($d.ID, [ref]$id); if ($id -gt 0) { $indLabel[$id] = ([string]$d.Description_lang).Trim() } }

  # Expansion names from ns.Releases (parsed so they track the live data); release
  # index = ExpansionID + 1, so a 0-based list aligns directly with ExpansionID.
  $rel = @()
  $raw = [System.IO.File]::ReadAllText($SetsFile)
  if ($raw -match '(?s)ns\.Releases\s*=\s*\{(.*?)\}') {
    $rel = [regex]::Matches($Matches[1], '"([^"]*)"') | ForEach-Object { $_.Groups[1].Value }
  }
  function ExpName([int]$e) { if ($e -ge 0 -and $e -lt $rel.Count) { $rel[$e] } else { "Expansion $e" } }

  # Curated wago group ids already in ns.Sets (the group-level `id = N,` lines), across
  # both hand-curated body files.
  $curated = @{}
  foreach ($bf in @($SetsFile, (Join-Path (Split-Path $SetsFile) 'sets_late.lua'))) {
    if (-not (Test-Path -LiteralPath $bf)) { continue }
    foreach ($ln in (Get-Content -LiteralPath $bf)) { if ($ln -match '^\s+id\s*=\s*(\d+),\s*$') { $curated[[int]$Matches[1]] = $true } }
  }
  # Also count merge-component ids: a merged row keeps only its lowest id, so the others
  # are captured (shown in that row) but no longer appear as `id = N,` lines above.
  foreach ($k in (Get-ExpandIds $ExpandFile).Keys) { $curated[$k] = $true }

  # Aggregate placeable rows (real group + at least one class bit) per group id.
  $grp = @{}
  foreach ($r in $tsRows) {
    $gid = 0; [void][int]::TryParse($r.TransmogSetGroupID, [ref]$gid); if ($gid -le 0) { continue }
    $mask = 0; [void][int]::TryParse($r.ClassMask, [ref]$mask); if ($mask -le 0) { continue }
    if (([string]$grpName[$gid]) -match '^(?i)test\b') { continue }   # skip Blizzard test placeholders
    if (-not $grp.ContainsKey($gid)) {
      $grp[$gid] = @{ name = $grpName[$gid]; sets = 0; exp = -1; labels = (New-Object 'System.Collections.Generic.HashSet[string]') }
    }
    $grp[$gid].sets++
    $e = 0; [void][int]::TryParse($r.ExpansionID, [ref]$e); if ($e -gt $grp[$gid].exp) { $grp[$gid].exp = $e }
    $ind = 0; [void][int]::TryParse($r.ItemNameDescriptionID, [ref]$ind)
    if ($indLabel.ContainsKey($ind) -and $indLabel[$ind]) { [void]$grp[$gid].labels.Add($indLabel[$ind]) }
  }

  # Heuristic category from the group's labels + name. Ordered: first match wins, so
  # the more specific signals (PvP brackets, Dungeon recolors) precede the generic
  # raid difficulty words. Purely a triage aid, not authoritative.
  $catRules = [ordered]@{
    'PvP'                            = 'gladiator|elite|aspirant|combatant|rival|duelist|\bhonor\b|war mode|\bpvp\b|arena|conquest'
    'Dungeon / Mythic+'              = '^dungeon|dungeons|mythic\+|dawn of the infinite|time rifts|horrific vision'
    'Delve'                          = 'delve'
    'Raid'                           = 'raid finder|\bnormal\b|\bheroic\b|\bmythic\b|\d+\s*player'
    'Profession / Crafted'           = 'craft|profession'
    'Trading Post / Anniversary'     = 'trading post|anniversary'
    'Timewalking'                    = 'timewalking'
    'Reputation / Renown / Campaign' = 'renown|campaign|reputation|quest reward'
    'World drops / quests'           = 'world drop|world quest|world and weekly|treasures|weekly|\bquest'
  }
  function Categorize([string]$name, [string[]]$labels) {
    $text = (@($name) + $labels) -join ' '
    foreach ($cat in $catRules.Keys) { if ($text -match "(?i)$($catRules[$cat])") { return $cat } }
    return 'Event / feature / other'
  }

  $excl = (Get-Excludes).groups
  $unc = @()
  foreach ($gid in ($grp.Keys | Sort-Object)) {
    if ($curated.ContainsKey($gid)) { continue }
    if ($excl.ContainsKey($gid)) { continue }   # deliberately excluded (excludes.txt)
    $g = $grp[$gid]
    $labels = @($g.labels) | Sort-Object
    $unc += [pscustomobject]@{
      id = $gid; name = $g.name; exp = $g.exp; release = (ExpName $g.exp)
      sets = $g.sets; labels = $labels; category = (Categorize $g.name $labels)
    }
  }

  # ── Build the markdown report ──────────────────────────────────────────────
  function MdCell([string]$s) { ([string]$s).Replace('|', '\|') }
  $catOrder = @($catRules.Keys) + 'Event / feature / other'
  $L = [System.Collections.Generic.List[string]]::new()
  $L.Add('# Collected coverage audit — uncaptured transmog-set groups')
  $L.Add('')
  $L.Add("Generated from wago.tools TransmogSet (product wow, build $Build$(if($bDate){", $bDate"})) by ``tools/update-sets.ps1 -AuditCoverage``.")
  $L.Add('')
  $L.Add("We curate **$($curated.Count) distinct wago group ids** in ``ns.Sets``. wago has **$($grp.Count) groups** with placeable rows; **$($excl.Count) are deliberately excluded** (``tools/excludes.txt``), leaving the **$($unc.Count)** below **not captured yet**. Categories are heuristic (from each group's difficulty/variant labels + name) — verify before adding. Inclusion is editorial: see ``tools/UPDATING.md``.")
  $L.Add('')
  $L.Add('## By category')
  $L.Add('')
  $L.Add('| Category | Groups |')
  $L.Add('| --- | ---: |')
  foreach ($c in $catOrder) { $n = ($unc | Where-Object { $_.category -eq $c }).Count; if ($n) { $L.Add("| $c | $n |") } }
  $L.Add('')
  $L.Add('## By expansion')
  $L.Add('')
  $L.Add('| Expansion | Groups |')
  $L.Add('| --- | ---: |')
  foreach ($e in ($unc | Select-Object -ExpandProperty exp -Unique | Sort-Object -Descending)) {
    $L.Add("| $(ExpName $e) | $(($unc | Where-Object { $_.exp -eq $e }).Count) |")
  }
  $L.Add('')
  $L.Add('## Groups by category')
  $L.Add('')
  foreach ($c in $catOrder) {
    $rows = @($unc | Where-Object { $_.category -eq $c } | Sort-Object -Property @{e = { $_.exp }; Descending = $true}, name)
    if (-not $rows) { continue }
    $L.Add("### $c ($($rows.Count))")
    $L.Add('')
    $L.Add('| id | name | expansion | sets | difficulty / variant labels |')
    $L.Add('| ---: | --- | --- | ---: | --- |')
    foreach ($r in $rows) {
      $lab = if ($r.labels.Count) { ($r.labels | ForEach-Object { MdCell $_ }) -join ', ' } else { '_(none)_' }
      $L.Add("| $($r.id) | $(MdCell $r.name) | $($r.release) | $($r.sets) | $lab |")
    }
    $L.Add('')
  }

  $report = ($L -join "`n").TrimEnd() + "`n"
  [System.IO.File]::WriteAllText($ReportFile, $report, [System.Text.UTF8Encoding]::new($false))
  Write-Host "Wrote $ReportFile ($($unc.Count) uncaptured group(s))." -ForegroundColor Green
  exit 0
}

# ── Set-level audit ──────────────────────────────────────────────────────────
# Group coverage is 100%, but within captured groups we render only a representative set
# per class. This diffs every placeable wago SET against the set ids that appear as cells
# in sets.lua and writes the un-rendered ones to data/sets_review.lua as rows under an
# ephemeral "Review" category — one row per set, classes from its ClassMask — so they can
# be browsed in-game and triaged. The committed sets_review.lua is an empty stub; this
# populates it locally. Self-contained download; exits before the normal refresh.
if ($AuditSets) {
  function ASCsv([string]$table, [string]$build) {
    $url = "https://wago.tools/db2/$table/csv?build=$build"
    Write-Host "Fetching $url" -ForegroundColor Cyan
    (Invoke-WebRequest -Uri $url -UseBasicParsing -ErrorAction Stop).Content | ConvertFrom-Csv
  }
  $builds = (Invoke-WebRequest -Uri 'https://wago.tools/api/builds' -UseBasicParsing -ErrorAction Stop).Content | ConvertFrom-Json
  if (-not $Build) { $Build = $builds.wow[0].version }
  Write-Host "Set-level audit against wow build $Build" -ForegroundColor Cyan
  $tsRows  = ASCsv 'TransmogSet' $Build
  $grpRows = ASCsv 'TransmogSetGroup' $Build
  $tsiRows = ASCsv 'TransmogSetItem' $Build
  if ($tsRows.Count -lt $MinRows) { throw "TransmogSet returned $($tsRows.Count) rows (< $MinRows) — incomplete download, aborting." }
  $grpName = @{}; foreach ($g in $grpRows) { $grpName[[int]$g.ID] = ([string]$g.Name_lang).Trim() }
  function LuaEsc([string]$s) { $s.Replace('\', '\\').Replace('"', '\"') }

  # Appearance identity = the set's exact list of ItemModifiedAppearanceIDs (its source items).
  # Name / bracket-label / ClassMask do NOT identify a look — the Alliance and Horde recolors of
  # a PvP set share all three yet are visually distinct, as are season recolors. Two sets are
  # duplicates ONLY when their appearance lists match. $imaKey is each set's sorted-IMA signature.
  $ima = @{}
  foreach ($r in $tsiRows) { $s = [int]$r.TransmogSetID; if (-not $ima.ContainsKey($s)) { $ima[$s] = @() }; $ima[$s] += [int]$r.ItemModifiedAppearanceID }
  $imaKey = @{}; foreach ($s in $ima.Keys) { $imaKey[$s] = (($ima[$s] | Sort-Object) -join ',') }

  # Rendered set ids = cell `id = N` in the curated files (NOT sets_review.lua, so re-runs diff
  # against real data). $haveByAppr is the set of rendered appearance signatures, so an
  # un-rendered set with the IDENTICAL look counts as already-shown rather than a gap.
  $have = @{}
  $dataDir = Split-Path $SetsFile
  foreach ($f in @($SetsFile, (Join-Path $dataDir 'sets_late.lua'), (Join-Path $dataDir 'sets_ptr.lua'), $ExpandSetsFile)) {
    if (Test-Path -LiteralPath $f) {
      foreach ($ln in (Get-Content -LiteralPath $f)) { if ($ln -match '\{\s*id\s*=\s*(\d+),\s*name\s*=.*classId') { $have[[int]$Matches[1]] = $true } }
    }
  }
  $haveByAppr = @{}
  foreach ($id in $have.Keys) { if ($imaKey.ContainsKey($id)) { $haveByAppr[$imaKey[$id]] = $true } }

  # Placeable wago sets (class bits, real non-test group) that aren't rendered ($miss, "Review").
  # A set whose exact appearance is already rendered (an appearance-duplicate of a curated set —
  # e.g. the Alliance/Horde or season recolor that won) is skipped, not a gap. Whole groups and
  # individual sets in excludes.txt are skipped too.
  $excl = Get-Excludes; $exclGroups = $excl.groups; $exclSets = $excl.sets
  $miss = @{}; $dupTwins = 0
  foreach ($r in $tsRows) {
    $m = [int]$r.ClassMask; $gid = [int]$r.TransmogSetGroupID; $sid = [int]$r.ID
    if ($m -le 0 -or $gid -le 0 -or $have.ContainsKey($sid) -or $exclSets.ContainsKey($sid)) { continue }
    if (($grpName[$gid]) -match '^(?i)test\b' -or $exclGroups.ContainsKey($gid)) { continue }
    if ($imaKey.ContainsKey($sid) -and $haveByAppr.ContainsKey($imaKey[$sid])) { $dupTwins++; continue }
    if (-not $miss.ContainsKey($gid)) { $miss[$gid] = @() }
    $miss[$gid] += $r
  }

  $rel = @(); $raw = [System.IO.File]::ReadAllText($SetsFile)
  if ($raw -match '(?s)ns\.Releases\s*=\s*\{(.*?)\}') { $rel = [regex]::Matches($Matches[1], '"([^"]*)"') | ForEach-Object { $_.Groups[1].Value } }

  $L = [System.Collections.Generic.List[string]]::new()
  $L.Add('---@type Warbandeer_Collected')
  $L.Add('local ns = select(2, ...)')
  $L.Add('local tinsert = tinsert')
  $L.Add('-- EPHEMERAL — generated by tools/update-sets.ps1 -AuditSets for in-game review of')
  $L.Add('-- wago sets not yet rendered (Category -> Review). DO NOT COMMIT a populated copy;')
  $L.Add('-- git checkout this file when done. The committed version is an empty stub.')
  $L.Add('')
  $total = 0
  foreach ($gid in ($miss.Keys | Sort-Object { $miss[$_].Count } -Descending)) {
    $L.Add("-- group $gid '$(LuaEsc $grpName[$gid])' — $($miss[$gid].Count) un-rendered")
    foreach ($r in ($miss[$gid] | Sort-Object { [int]$_.ID })) {
      $m = [int]$r.ClassMask; $e = 0; [void][int]::TryParse($r.ExpansionID, [ref]$e); $nm = LuaEsc ([string]$r.Name_lang)
      $L.Add('tinsert(ns.Sets, {')
      $L.Add("  id = $($r.ID),")
      $L.Add("  name = `"$nm #$($r.ID)`",")
      $L.Add("  release = $($e + 1),")
      $L.Add('  category = "Review",')
      $L.Add('  sets = {')
      for ($c = 1; $c -le 13; $c++) {
        if ($m -band (1 -shl ($c - 1))) { $L.Add("    { id = $($r.ID), name = `"$nm`", classId = $c },") } else { $L.Add('    {},') }
      }
      $L.Add('  },')
      $L.Add('})')
      $total++
    }
  }
  [System.IO.File]::WriteAllText($ReviewFile, ($L -join "`n").TrimEnd() + "`n", [System.Text.UTF8Encoding]::new($false))
  Write-Host "Wrote $ReviewFile — $total un-rendered (Review) across $($miss.Count) group(s); skipped $dupTwins appearance-duplicate(s)." -ForegroundColor Green
  Write-Host "Top groups:" -ForegroundColor Cyan
  foreach ($gid in ($miss.Keys | Sort-Object { $miss[$_].Count } -Descending | Select-Object -First 12)) {
    Write-Host ("  {0,4}  {1} '{2}'" -f $miss[$gid].Count, $gid, $grpName[$gid])
  }
  Write-Host "Review in-game (Category -> Review), then 'git checkout $ReviewFile'." -ForegroundColor Yellow
  exit 0
}

# ── Expand mode ──────────────────────────────────────────────────────────────
# Auto-generate one curated ns.Sets row per wago label for each listed group,
# decomposing ClassMask into class slots (first/lowest set id wins, {} for gaps) —
# the same model the normal fill uses, so these rows refresh on the weekly run too.
# Writes a single guarded block at the end of sets.lua (replaced wholesale each run).
# Argument: comma list of "id:Category" (e.g. "319:World,243:Dungeon"). Labels with no
# class bits (cosmetic/heritage) and the bare (no-label) bucket of a labeled group are
# skipped; overlap labels (recolors collapsing to one slot per class) are kept + logged.
# Self-contained download; exits before the normal refresh. See UPDATING.md.
if ($Expand) {
  function ExpCsv([string]$table, [string]$build) {
    $url = "https://wago.tools/db2/$table/csv?build=$build"
    Write-Host "Fetching $url" -ForegroundColor Cyan
    (Invoke-WebRequest -Uri $url -UseBasicParsing -ErrorAction Stop).Content | ConvertFrom-Csv
  }
  # Canonical group list lives in expand-groups.txt ("id:Category[:byset]" per line, '#'
  # comments). Default mode emits one row per ItemNameDescription label; the optional
  # `byset` mode emits one row per SET (named by the set's own name) — for label-less
  # groups that are a flat list of distinctly-named ensembles (the Trading Post).
  if (-not (Test-Path -LiteralPath $ExpandFile)) { throw "Expand group list not found: $ExpandFile" }
  $jobIds = @(); $jobCat = @{}; $jobMode = @{}; $merges = @(); $setMerges = @(); $mergedSetIds = @{}; $labelMerges = @(); $assembles = @(); $seasonMerges = @(); $eachSets = @()
  foreach ($ln in (Get-Content -LiteralPath $ExpandFile)) {
    $t = ($ln -split '#', 2)[0].Trim()
    if (-not $t) { continue }
    # `mergeseason <groupId> | <Category> [| <release>]` — own a whole PvP-style group: bucket
    # ALL its placeable sets by ItemNameDescription label, then greedy class-disjoint-tile each
    # label into one row per faction recolor (Alliance/Horde share name+label+mask but are
    # distinct looks). Names "<group> (<label>)", "<group> (<label> · 2)" for the 2nd+ tile.
    # The group's hand-curated body rows must be REMOVED (this regenerates them all uniformly).
    if ($t -match '^mergeseason\s+(.+)$') {
      $p = $Matches[1] -split '\s*\|\s*'
      if ($p.Count -lt 2 -or $p.Count -gt 3) { throw "Bad mergeseason line '$ln' — expected 'mergeseason groupId | Category [| release]'." }
      $seasonMerges += @{ gid = [int]$p[0].Trim(); cat = $p[1].Trim(); release = if ($p.Count -ge 3 -and $p[2].Trim()) { [int]$p[2].Trim() } else { $null } }
      continue
    }
    # `assemble <setid>:<classId>+... | <Category> | <Name>` — build one row from sets that
    # are each tagged all-classes in wago (the 20th-Anniversary tier recolors), assigning
    # each to its themed class explicitly (mask-based merges can't tell them apart).
    if ($t -match '^assemble\s+(.+)$') {
      $p = $Matches[1] -split '\s*\|\s*'
      if ($p.Count -lt 3 -or $p.Count -gt 4) { throw "Bad assemble line '$ln' — expected 'assemble setid:classId+... | Category | Name [| release]'." }
      $slots = @{}
      foreach ($pp in ($p[0] -split '\s*\+\s*')) { $sc = $pp -split ':', 2; $sid = [int]$sc[0].Trim(); $slots[[int]$sc[1].Trim()] = $sid; $mergedSetIds[$sid] = $true }
      $assembles += @{ slots = $slots; cat = $p[1].Trim(); name = $p[2].Trim(); release = if ($p.Count -ge 4 -and $p[3].Trim()) { [int]$p[3].Trim() } else { $null } }
      continue
    }
    # `mergeset <setid>+... | <Category> | <Name>` — merge specific SET ids into one row
    # (armor pieces of one set listed individually, e.g. Void-Bound inside the Trading
    # Post). The owning group's byset/label rows skip these set ids so there's no dup.
    if ($t -match '^mergeset\s+(.+)$') {
      $p = $Matches[1] -split '\s*\|\s*'
      if ($p.Count -lt 3 -or $p.Count -gt 4) { throw "Bad mergeset line '$ln' — expected 'mergeset setids | Category | Name [| release]'." }
      $sids = @($p[0] -split '\s*\+\s*' | ForEach-Object { [int]$_ })
      foreach ($s in $sids) { $mergedSetIds[$s] = $true }
      $setMerges += @{ sids = $sids; cat = $p[1].Trim(); name = $p[2].Trim(); release = if ($p.Count -ge 4 -and $p[3].Trim()) { [int]$p[3].Trim() } else { $null } }
      continue
    }
    # `eachset <setid>+... | <Category> [| <release>]` — emit ONE row per listed set (named by
    # its own name + colour/source label), NOT merged. For groups of overlapping single-armor
    # recolours that can't tile into a full class row (the Legion/MoP recolour-catalogue
    # leftovers) but are each a distinct, real appearance worth showing.
    if ($t -match '^eachset\s+(.+)$') {
      $p = $Matches[1] -split '\s*\|\s*'
      if ($p.Count -lt 2 -or $p.Count -gt 3) { throw "Bad eachset line '$ln' — expected 'eachset setids | Category [| release]'." }
      $sids = @($p[0] -split '\s*\+\s*' | ForEach-Object { [int]$_ })
      foreach ($s in $sids) { $mergedSetIds[$s] = $true }
      $eachSets += @{ sids = $sids; cat = $p[1].Trim(); release = if ($p.Count -ge 3 -and $p[2].Trim()) { [int]$p[2].Trim() } else { $null } }
      continue
    }
    # `mergelabels <id>+... | <Category> | <NamePrefix>` — for groups that are armor-type
    # splits each carrying the SAME source labels (the DF dungeon sets), emit one row per
    # label, merged across the groups: "<NamePrefix> (<label>)" tiling armor types.
    if ($t -match '^mergelabels\s+(.+)$') {
      $p = $Matches[1] -split '\s*\|\s*'
      if ($p.Count -lt 3 -or $p.Count -gt 4) { throw "Bad mergelabels line '$ln' — expected 'mergelabels ids | Category | NamePrefix [| release]'." }
      $labelMerges += @{
        ids = @($p[0] -split '\s*\+\s*' | ForEach-Object { [int]$_ }); cat = $p[1].Trim(); name = $p[2].Trim()
        release = if ($p.Count -ge 4 -and $p[3].Trim()) { [int]$p[3].Trim() } else { $null }
      }
      continue
    }
    # `merge <id>+<id>+... | <Category> | <Name>` — assemble ONE class-disjoint row from
    # several whole groups (armor-type / source splits of one logical set spanning ids).
    if ($t -match '^merge\s+(.+)$') {
      $p = $Matches[1] -split '\s*\|\s*'
      if ($p.Count -lt 3 -or $p.Count -gt 4) { throw "Bad merge line '$ln' — expected 'merge ids | Category | Name [| release]'." }
      $merges += @{
        ids = @($p[0] -split '\s*\+\s*' | ForEach-Object { [int]$_ }); cat = $p[1].Trim(); name = $p[2].Trim()
        release = if ($p.Count -ge 4 -and $p[3].Trim()) { [int]$p[3].Trim() } else { $null }   # override wago's (sometimes wrong) ExpansionID
      }
      continue
    }
    $kv = $t -split ':', 3
    if ($kv.Count -lt 2) { throw "Bad expand-groups.txt line '$ln' — expected 'id:Category[:byset|single]'." }
    $jid = [int]$kv[0].Trim(); $jobIds += $jid; $jobCat[$jid] = $kv[1].Trim()
    $jobMode[$jid] = if ($kv.Count -ge 3) { $kv[2].Trim() } else { '' }
  }
  if ($jobIds.Count -eq 0 -and $merges.Count -eq 0) { throw 'expand-groups.txt has no entries.' }

  $excl = Get-Excludes   # tools/excludes.txt — whole groups + "id:label" dead rows

  $builds = (Invoke-WebRequest -Uri 'https://wago.tools/api/builds' -UseBasicParsing -ErrorAction Stop).Content | ConvertFrom-Json
  if (-not $Build) { $Build = $builds.wow[0].version }
  Write-Host "Expand against wow build $Build" -ForegroundColor Cyan

  $tsRows  = ExpCsv 'TransmogSet' $Build
  $grpRows = ExpCsv 'TransmogSetGroup' $Build
  $indRows = ExpCsv 'ItemNameDescription' $Build
  foreach ($col in @('ID', 'Name_lang', 'ClassMask', 'TransmogSetGroupID', 'ItemNameDescriptionID', 'ExpansionID')) {
    if ($col -notin $tsRows[0].PSObject.Properties.Name) { throw "TransmogSet CSV missing '$col' — aborting." }
  }
  if ($tsRows.Count -lt $MinRows) { throw "TransmogSet returned $($tsRows.Count) rows (< $MinRows) — incomplete download, aborting." }

  $grpName = @{}; foreach ($g in $grpRows) { $grpName[[int]$g.ID] = ([string]$g.Name_lang).Trim() }
  $indLabel = @{}; foreach ($d in $indRows) { $id = 0; [void][int]::TryParse($d.ID, [ref]$id); if ($id -gt 0) { $indLabel[$id] = ([string]$d.Description_lang).Trim() } }
  function LuaEsc([string]$s) { $s.Replace('\', '\\').Replace('"', '\"') }

  $L = [System.Collections.Generic.List[string]]::new()
  $L.Add('---@type Warbandeer_Collected')
  $L.Add('local ns = select(2, ...)')
  $L.Add('local tinsert = tinsert')
  $L.Add('-- >>> AUTO-EXPAND — generated by tools/update-sets.ps1 -Expand; do not hand-edit.')
  $L.Add('-- One ns.Sets row per wago label (or per set, for byset groups like the Trading Post).')
  $L.Add('-- Re-run -Expand to refresh. Overlap labels show one representative set.')
  $emitted = 0
  foreach ($gid in $jobIds) {
    $cat = $jobCat[$gid]
    $rows = $tsRows | Where-Object { [int]$_.TransmogSetGroupID -eq $gid }
    if (-not $rows) { Write-Warning "Expand $gid — no rows; skipped."; continue }
    $exp = 0; foreach ($r in $rows) { $e = 0; [void][int]::TryParse($r.ExpansionID, [ref]$e); if ($e -gt $exp) { $exp = $e } }
    $release = $exp + 1
    $base = $grpName[$gid]
    $byset  = ($jobMode[$gid] -eq 'byset')
    $single = ($jobMode[$gid] -eq 'single')
    # Bucket key: one bucket for the whole group in single mode (collapse all variants
    # into one row); the set's own name in byset mode (one row per ensemble); else its
    # ItemNameDescription label (one row per recolor/source variant).
    $byl = [ordered]@{}
    foreach ($r in ($rows | Sort-Object { [int]$_.ID })) {
      if ($mergedSetIds.ContainsKey([int]$r.ID)) { continue }   # pulled into a mergeset row
      if ($single) { $key = '*' }
      elseif ($byset) { $key = ([string]$r.Name_lang).Trim() }
      else { $i = 0; [void][int]::TryParse($r.ItemNameDescriptionID, [ref]$i); $key = if ($indLabel.ContainsKey($i)) { $indLabel[$i] } else { '' } }
      if (-not $byl.Contains($key)) { $byl[$key] = @() }
      $byl[$key] += $r
    }
    foreach ($lab in $byl.Keys) {
      $rs = $byl[$lab]
      $slot = @{}; $union = 0; $overlap = $false
      foreach ($r in $rs) {
        $m = 0; [void][int]::TryParse($r.ClassMask, [ref]$m)
        if ($union -band $m) { $overlap = $true }
        $union = $union -bor $m
        for ($bb = 0; $bb -lt 13; $bb++) {
          if (($m -band (1 -shl $bb)) -eq 0) { continue }
          $c = $bb + 1
          if ($slot.ContainsKey($c)) { continue }
          $slot[$c] = @{ id = $r.ID; name = (LuaEsc ([string]$r.Name_lang)) }
        }
      }
      if ($excl.groups.ContainsKey($gid) -or $excl.rows.ContainsKey("$gid|$lab")) { Write-Host "  exclude $gid [$lab] — listed in excludes.txt" -ForegroundColor DarkYellow; continue }
      if ($union -eq 0) { Write-Host "  skip $gid [$lab] — no class bits (cosmetic/weapon)" -ForegroundColor DarkYellow; continue }
      if (-not $byset -and $lab -eq '' -and $byl.Count -gt 1) { Write-Host "  skip $gid [(no label)] in labeled group — ambiguous" -ForegroundColor DarkYellow; continue }
      if ($overlap -and -not $single) { Write-Host "  overlap $gid [$lab] — $($rs.Count) sets collapse to $($slot.Count) slots" -ForegroundColor Yellow }
      # single mode: name the one merged row "<group> (<common label prefix>)" — e.g. the
      # "Timewalking Vendor - <colour>" labels collapse to "(Timewalking Vendor)"; if the
      # labels share no common prefix before " - ", just use the group name.
      if ($single) {
        $pref = @($rs | ForEach-Object { $j = 0; [void][int]::TryParse($_.ItemNameDescriptionID, [ref]$j); if ($indLabel.ContainsKey($j)) { ($indLabel[$j] -split ' - ', 2)[0].Trim() } } | Where-Object { $_ } | Select-Object -Unique)
        $disp = LuaEsc $(if ($pref.Count -eq 1) { "$base ($($pref[0]))" } else { $base })
      } else {
        $disp = LuaEsc $(if ($byset) { $lab } elseif ($lab) { "$base ($lab)" } else { $base })
      }
      $L.Add('tinsert(ns.Sets, {')
      $L.Add("  id = $gid,")
      $L.Add("  name = `"$disp`",")
      $L.Add("  release = $release,")
      $L.Add("  category = `"$cat`",")
      $L.Add('  sets = {')
      $max = ($slot.Keys | Measure-Object -Maximum).Maximum
      for ($c = 1; $c -le $max; $c++) {
        if ($slot.ContainsKey($c)) { $L.Add("    { id = $($slot[$c].id), name = `"$($slot[$c].name)`", classId = $c },") }
        else { $L.Add('    {},') }
      }
      $L.Add('  },')
      $L.Add('})')
      $emitted++
    }
  }

  # ── merge directives: assemble ONE class-disjoint row from several whole groups ──
  # (armor-type / source splits of one logical set that span multiple group ids). First
  # /lowest set id wins per class — clean when the groups tile without overlap. The row
  # takes the lowest group id (so its cells key into db.sets consistently on scan).
  foreach ($mg in $merges) {
    $rows = $tsRows | Where-Object { [int]$_.TransmogSetGroupID -in $mg.ids }
    if (-not $rows) { Write-Warning "merge [$($mg.ids -join '+')] '$($mg.name)' — no rows; skipped."; continue }
    $slot = @{}; $union = 0; $exp = 0
    foreach ($r in ($rows | Sort-Object { [int]$_.ID })) {
      $e = 0; [void][int]::TryParse($r.ExpansionID, [ref]$e); if ($e -gt $exp) { $exp = $e }
      $m = 0; [void][int]::TryParse($r.ClassMask, [ref]$m); $union = $union -bor $m
      for ($bb = 0; $bb -lt 13; $bb++) {
        if (($m -band (1 -shl $bb)) -eq 0) { continue }
        $c = $bb + 1
        if ($slot.ContainsKey($c)) { continue }
        $slot[$c] = @{ id = $r.ID; name = (LuaEsc ([string]$r.Name_lang)) }
      }
    }
    if ($union -eq 0) { Write-Host "  skip merge '$($mg.name)' — no class bits" -ForegroundColor DarkYellow; continue }
    $gid = ($mg.ids | Measure-Object -Minimum).Minimum
    $rel = if ($mg.release) { $mg.release } else { $exp + 1 }
    Write-Host "  merge [$($mg.ids -join '+')] -> '$($mg.name)' ($($slot.Count) classes, release $rel)" -ForegroundColor Cyan
    $L.Add('tinsert(ns.Sets, {')
    $L.Add("  id = $gid,")
    $L.Add("  name = `"$(LuaEsc $mg.name)`",")
    $L.Add("  release = $rel,")
    $L.Add("  category = `"$($mg.cat)`",")
    $L.Add('  sets = {')
    $max = ($slot.Keys | Measure-Object -Maximum).Maximum
    for ($c = 1; $c -le $max; $c++) {
      if ($slot.ContainsKey($c)) { $L.Add("    { id = $($slot[$c].id), name = `"$($slot[$c].name)`", classId = $c },") }
      else { $L.Add('    {},') }
    }
    $L.Add('  },')
    $L.Add('})')
    $emitted++
  }

  # ── mergeset directives: merge specific SET ids into one row (within a group; the row
  # takes that group's id so its cells key into db.sets on scan, like its sibling rows) ──
  foreach ($sm in $setMerges) {
    $rows = $tsRows | Where-Object { [int]$_.ID -in $sm.sids }
    if (-not $rows) { Write-Warning "mergeset [$($sm.sids -join '+')] '$($sm.name)' — no rows; skipped."; continue }
    $slot = @{}; $union = 0; $exp = 0; $gid = [int]($rows | Select-Object -First 1).TransmogSetGroupID
    foreach ($r in ($rows | Sort-Object { [int]$_.ID })) {
      $e = 0; [void][int]::TryParse($r.ExpansionID, [ref]$e); if ($e -gt $exp) { $exp = $e }
      $m = 0; [void][int]::TryParse($r.ClassMask, [ref]$m); $union = $union -bor $m
      for ($bb = 0; $bb -lt 13; $bb++) {
        if (($m -band (1 -shl $bb)) -eq 0) { continue }
        $c = $bb + 1
        if ($slot.ContainsKey($c)) { continue }
        $slot[$c] = @{ id = $r.ID; name = (LuaEsc ([string]$r.Name_lang)) }
      }
    }
    if ($union -eq 0) { Write-Host "  skip mergeset '$($sm.name)' — no class bits" -ForegroundColor DarkYellow; continue }
    $rel = if ($sm.release) { $sm.release } else { $exp + 1 }
    Write-Host "  mergeset [$($sm.sids -join '+')] -> '$($sm.name)' ($($slot.Count) classes, release $rel)" -ForegroundColor Cyan
    $L.Add('tinsert(ns.Sets, {')
    $L.Add("  id = $gid,")
    $L.Add("  name = `"$(LuaEsc $sm.name)`",")
    $L.Add("  release = $rel,")
    $L.Add("  category = `"$($sm.cat)`",")
    $L.Add('  sets = {')
    $max = ($slot.Keys | Measure-Object -Maximum).Maximum
    for ($c = 1; $c -le $max; $c++) {
      if ($slot.ContainsKey($c)) { $L.Add("    { id = $($slot[$c].id), name = `"$($slot[$c].name)`", classId = $c },") }
      else { $L.Add('    {},') }
    }
    $L.Add('  },')
    $L.Add('})')
    $emitted++
  }

  # ── eachset directives: one row per listed set, NOT merged (overlapping single-armor
  # recolours that can't tile a full row). Named "<set name> (<colour>)" — the colour/source
  # is the label's last " - "-delimited segment, to disambiguate same-named recolours. ──
  foreach ($es in $eachSets) {
    foreach ($sid in $es.sids) {
      $r = $tsRows | Where-Object { [int]$_.ID -eq $sid } | Select-Object -First 1
      if (-not $r) { Write-Warning "eachset $sid — not found; skipped."; continue }
      $m = 0; [void][int]::TryParse($r.ClassMask, [ref]$m)
      if ($m -le 0) { Write-Host "  skip eachset $sid — no class bits" -ForegroundColor DarkYellow; continue }
      $gid = [int]$r.TransmogSetGroupID; $e = 0; [void][int]::TryParse($r.ExpansionID, [ref]$e)
      $rel = if ($es.release) { $es.release } else { $e + 1 }
      $i = 0; [void][int]::TryParse($r.ItemNameDescriptionID, [ref]$i)
      $lab = if ($indLabel.ContainsKey($i)) { $indLabel[$i] } else { '' }
      $suf = if ($lab) { " ($(($lab -split ' - ')[-1].Trim()))" } else { '' }
      $nm = LuaEsc ([string]$r.Name_lang)
      $disp = LuaEsc ("$([string]$r.Name_lang)$suf")
      Write-Host "  eachset $sid -> '$disp' (grp $gid, release $rel)" -ForegroundColor Cyan
      $L.Add('tinsert(ns.Sets, {')
      $L.Add("  id = $gid,")
      $L.Add("  name = `"$disp`",")
      $L.Add("  release = $rel,")
      $L.Add("  category = `"$($es.cat)`",")
      $L.Add('  sets = {')
      for ($c = 1; $c -le 13; $c++) {
        if ($m -band (1 -shl ($c - 1))) { $L.Add("    { id = $sid, name = `"$nm`", classId = $c },") } else { $L.Add('    {},') }
      }
      $L.Add('  },')
      $L.Add('})')
      $emitted++
    }
  }

  # ── assemble directives: one row from explicit set:class pairs (all-class anniversary sets) ──
  foreach ($as in $assembles) {
    $slot = @{}; $exp = 0; $gid = 0
    foreach ($c in ($as.slots.Keys | Sort-Object)) {
      $r = $tsRows | Where-Object { [int]$_.ID -eq $as.slots[$c] } | Select-Object -First 1
      if (-not $r) { Write-Warning "assemble '$($as.name)' — set $($as.slots[$c]) not found; skipped slot."; continue }
      if ($gid -eq 0) { $gid = [int]$r.TransmogSetGroupID }
      $e = 0; [void][int]::TryParse($r.ExpansionID, [ref]$e); if ($e -gt $exp) { $exp = $e }
      $slot[$c] = @{ id = $as.slots[$c]; name = (LuaEsc ([string]$r.Name_lang)) }
    }
    if ($slot.Count -eq 0) { Write-Host "  skip assemble '$($as.name)' — no sets resolved" -ForegroundColor DarkYellow; continue }
    $rel = if ($as.release) { $as.release } else { $exp + 1 }
    Write-Host "  assemble -> '$($as.name)' ($($slot.Count) classes, release $rel)" -ForegroundColor Cyan
    $L.Add('tinsert(ns.Sets, {')
    $L.Add("  id = $gid,")
    $L.Add("  name = `"$(LuaEsc $as.name)`",")
    $L.Add("  release = $rel,")
    $L.Add("  category = `"$($as.cat)`",")
    $L.Add('  sets = {')
    $max = ($slot.Keys | Measure-Object -Maximum).Maximum
    for ($c = 1; $c -le $max; $c++) {
      if ($slot.ContainsKey($c)) { $L.Add("    { id = $($slot[$c].id), name = `"$($slot[$c].name)`", classId = $c },") }
      else { $L.Add('    {},') }
    }
    $L.Add('  },')
    $L.Add('})')
    $emitted++
  }

  # ── mergelabels directives: one row per source label, merged across armor groups ──
  # (the DF dungeon sets — 4 armor groups each carrying Dungeons/Renown/World labels →
  # "<NamePrefix> (<label>)" rows that tile armor types). Row id = lowest group id.
  foreach ($lm in $labelMerges) {
    $rows = $tsRows | Where-Object { [int]$_.TransmogSetGroupID -in $lm.ids }
    if (-not $rows) { Write-Warning "mergelabels [$($lm.ids -join '+')] '$($lm.name)' — no rows; skipped."; continue }
    $gid = ($lm.ids | Measure-Object -Minimum).Minimum
    $byl = [ordered]@{}
    foreach ($r in ($rows | Sort-Object { [int]$_.ID })) {
      $i = 0; [void][int]::TryParse($r.ItemNameDescriptionID, [ref]$i)
      $lab = if ($indLabel.ContainsKey($i)) { $indLabel[$i] } else { '' }
      if (-not $byl.Contains($lab)) { $byl[$lab] = @() }
      $byl[$lab] += $r
    }
    foreach ($lab in $byl.Keys) {
      $slot = @{}; $union = 0; $exp = 0
      foreach ($r in $byl[$lab]) {
        $e = 0; [void][int]::TryParse($r.ExpansionID, [ref]$e); if ($e -gt $exp) { $exp = $e }
        $m = 0; [void][int]::TryParse($r.ClassMask, [ref]$m); $union = $union -bor $m
        for ($bb = 0; $bb -lt 13; $bb++) {
          if (($m -band (1 -shl $bb)) -eq 0) { continue }
          $c = $bb + 1
          if (-not $slot.ContainsKey($c)) { $slot[$c] = @{ id = $r.ID; name = (LuaEsc ([string]$r.Name_lang)) } }
        }
      }
      if ($union -eq 0 -or -not $lab) { continue }
      $rel = if ($lm.release) { $lm.release } else { $exp + 1 }
      $disp = LuaEsc "$($lm.name) ($lab)"
      Write-Host "  mergelabels [$($lm.ids -join '+')] -> '$($lm.name) ($lab)' ($($slot.Count) classes)" -ForegroundColor Cyan
      $L.Add('tinsert(ns.Sets, {')
      $L.Add("  id = $gid,")
      $L.Add("  name = `"$disp`",")
      $L.Add("  release = $rel,")
      $L.Add("  category = `"$($lm.cat)`",")
      $L.Add('  sets = {')
      $max = ($slot.Keys | Measure-Object -Maximum).Maximum
      for ($c = 1; $c -le $max; $c++) {
        if ($slot.ContainsKey($c)) { $L.Add("    { id = $($slot[$c].id), name = `"$($slot[$c].name)`", classId = $c },") }
        else { $L.Add('    {},') }
      }
      $L.Add('  },')
      $L.Add('})')
      $emitted++
    }
  }

  # ── mergeseason directives: own a whole group — bucket its placeable sets by label, then
  # greedy class-disjoint-tile each label into one row per faction recolor (Alliance/Horde &
  # season variants share name+label+mask but are distinct looks). Lowest-id faction tiles
  # first → "<group> (<label>)"; later tiles get "· 2", "· 3". The group's body rows must be
  # removed from sets.lua (this regenerates every bracket/faction uniformly). Row id = group id.
  foreach ($ms in $seasonMerges) {
    $rows = $tsRows | Where-Object { [int]$_.TransmogSetGroupID -eq $ms.gid -and [int]$_.ClassMask -gt 0 -and -not $mergedSetIds.ContainsKey([int]$_.ID) }
    if (-not $rows) { Write-Warning "mergeseason $($ms.gid) — no rows; skipped."; continue }
    $gname = $grpName[$ms.gid]
    $byl = [ordered]@{}
    foreach ($r in ($rows | Sort-Object { [int]$_.ID })) {
      $i = 0; [void][int]::TryParse($r.ItemNameDescriptionID, [ref]$i)
      $lab = if ($indLabel.ContainsKey($i)) { $indLabel[$i] } else { '' }
      if (-not $byl.Contains($lab)) { $byl[$lab] = @() }
      $byl[$lab] += $r
    }
    foreach ($lab in $byl.Keys) {
      $tiles = @()   # each: @{ slot = @{class->@{id,name}}; exp = N }
      foreach ($r in ($byl[$lab] | Sort-Object { [int]$_.ID })) {
        $m = [int]$r.ClassMask; $e = 0; [void][int]::TryParse($r.ExpansionID, [ref]$e)
        $tile = $null
        foreach ($cand in $tiles) {
          $clash = $false
          for ($bb = 0; $bb -lt 13; $bb++) { if (($m -band (1 -shl $bb)) -and $cand.slot.ContainsKey($bb + 1)) { $clash = $true; break } }
          if (-not $clash) { $tile = $cand; break }
        }
        if (-not $tile) { $tile = @{ slot = @{}; exp = 0 }; $tiles += $tile }
        for ($bb = 0; $bb -lt 13; $bb++) { if ($m -band (1 -shl $bb)) { $tile.slot[$bb + 1] = @{ id = $r.ID; name = (LuaEsc ([string]$r.Name_lang)) } } }
        if ($e -gt $tile.exp) { $tile.exp = $e }
      }
      $n = 0
      foreach ($tile in $tiles) {
        $n++
        $roman = @('', '', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX')[$n]
        $suffix = if ($lab) { if ($n -eq 1) { " ($lab)" } else { " ($lab $roman)" } } elseif ($n -eq 1) { '' } else { " ($roman)" }
        $disp = LuaEsc "$gname$suffix"
        $rel = if ($ms.release) { $ms.release } else { $tile.exp + 1 }
        Write-Host "  mergeseason $($ms.gid) -> '$disp' ($($tile.slot.Count) classes)" -ForegroundColor Cyan
        $L.Add('tinsert(ns.Sets, {')
        $L.Add("  id = $($ms.gid),")
        $L.Add("  name = `"$disp`",")
        $L.Add("  release = $rel,")
        $L.Add("  category = `"$($ms.cat)`",")
        $L.Add('  sets = {')
        $max = ($tile.slot.Keys | Measure-Object -Maximum).Maximum
        for ($c = 1; $c -le $max; $c++) {
          if ($tile.slot.ContainsKey($c)) { $L.Add("    { id = $($tile.slot[$c].id), name = `"$($tile.slot[$c].name)`", classId = $c },") }
          else { $L.Add('    {},') }
        }
        $L.Add('  },')
        $L.Add('})')
        $emitted++
      }
    }
  }
  $L.Add('-- <<< AUTO-EXPAND')

  # sets_expand.lua is wholly generated, so write it in full (EOL matched to the existing
  # file, falling back to sets.lua's convention on first generation).
  $eolSrc = if (Test-Path -LiteralPath $ExpandSetsFile) { $ExpandSetsFile } else { $SetsFile }
  $eol = if ([System.IO.File]::ReadAllText($eolSrc).Contains("`r`n")) { "`r`n" } else { "`n" }
  $newText = (($L -join "`n") -replace "`n", $eol) + $eol
  [System.IO.File]::WriteAllText($ExpandSetsFile, $newText, [System.Text.UTF8Encoding]::new($false))
  Write-Host "Expand: wrote $emitted row(s) across $($jobIds.Count) group(s) into $ExpandSetsFile." -ForegroundColor Green
  exit 0
}

# ── Weapon-appearance pipeline (shared by -Weapons and -Weapons -PtrDelta) ────
# Download the DB2 tables for ONE build and bucket every weapon/off-hand APPEARANCE by SOURCE (row)
# x weapon TYPE (column) — the derivation the -Weapons mode below documents in full. Factored out so
# the live emit and the PTR delta run byte-identical bucketing over their respective builds.
function WFetchBuild([string]$table, [string]$build) {
  # Per-build temp dir so a live+PTR run in one process doesn't clobber shared CSVs.
  $tmp = Join-Path ([IO.Path]::GetTempPath()) "wbc-weapons-$build"
  New-Item -ItemType Directory -Force -Path $tmp | Out-Null
  $out = Join-Path $tmp "$table.csv"
  Write-Host "Fetching https://wago.tools/db2/$table/csv?build=$build" -ForegroundColor Cyan
  Invoke-WebRequest -Uri "https://wago.tools/db2/$table/csv?build=$build" -UseBasicParsing -OutFile $out -ErrorAction Stop
  return $out
}
# Item.ClassID/SubclassID/InventoryType -> Enum.TransmogCollectionType id (null = not a weapon/off-hand).
function WType($it) {
  if (-not $it) { return $null }
  $c = [int]$it.ClassID; $s = [int]$it.SubclassID; $iv = [int]$it.InventoryType
  if ($c -eq 2) {
    switch ($s) { 0 {13} 1 {20} 2 {25} 3 {26} 4 {15} 5 {22} 6 {24} 7 {14} 8 {21}
                  9 {28} 10 {23} 13 {17} 15 {16} 18 {27} 19 {12} default {$null} }
  } elseif ($c -eq 4) {
    if ($s -eq 6) { 18 } elseif ($iv -eq 23) { 19 } else { $null }   # Shield / Held In Off-hand
  } else { $null }
}
function WCols($rows, [string]$table, [string[]]$cols) {
  foreach ($c in $cols) { if ($c -notin $rows[0].PSObject.Properties.Name) { throw "$table CSV missing '$c' column — aborting." } }
}

# Full pipeline for $build → the { key -> @{ name; cat; rel; minInst; types } } row map (types keyed by
# TransmogCollectionType → HashSet[int] of visual ids). Returns @{ rows; placed; otherPlaced }.
function Get-WeaponRows([string]$build) {
  # --- item + appearance tables ---
  $item = @{}
  Import-Csv (WFetchBuild 'Item' $build) | ForEach-Object { $item[$_.ID] = $_ }
  if ($item.Count -lt 50000) { throw "Item under 50000 rows ($($item.Count)) — incomplete download, aborting." }
  $ima = Import-Csv (WFetchBuild 'ItemModifiedAppearance' $build)
  WCols $ima 'ItemModifiedAppearance' @('ItemID', 'ItemAppearanceID', 'TransmogSourceTypeEnum')
  if ($ima.Count -lt 50000) { throw "ItemModifiedAppearance under 50000 rows ($($ima.Count)) — incomplete download, aborting." }

  # ItemSparse -> ExpansionID (0-based). ~50 MB; stream just ID + ExpansionID (quoted-CSV-safe).
  Add-Type -AssemblyName Microsoft.VisualBasic
  $itemExp = @{}
  $tp = New-Object Microsoft.VisualBasic.FileIO.TextFieldParser((WFetchBuild 'ItemSparse' $build))
  $tp.TextFieldType = 'Delimited'; $tp.SetDelimiters(','); $tp.HasFieldsEnclosedInQuotes = $true
  $hdr = $tp.ReadFields(); $idIdx = [Array]::IndexOf($hdr, 'ID'); $exIdx = [Array]::IndexOf($hdr, 'ExpansionID')
  if ($idIdx -lt 0 -or $exIdx -lt 0) { throw 'ItemSparse CSV missing ID/ExpansionID column — aborting.' }
  while (-not $tp.EndOfData) { $f = $tp.ReadFields(); $itemExp[$f[$idIdx]] = [int]$f[$exIdx] }
  $tp.Close()

  # --- source-detail lookups (the specific encounter/quest/vendor per appearance) ---
  $imaToCs = @{}
  foreach ($r in (Import-Csv (WFetchBuild 'CollectableSourceInfo' $build))) {
    if ($r.HouseDecorID -eq '0' -and $r.ItemModifiedAppearanceID -ne '0' -and -not $imaToCs.ContainsKey($r.ItemModifiedAppearanceID)) {
      $imaToCs[$r.ItemModifiedAppearanceID] = $r.ID } }
  $csToEnc = @{}; foreach ($r in (Import-Csv (WFetchBuild 'CollectableSourceEncounterSparse' $build))) { if (-not $csToEnc.ContainsKey($r.CollectableSourceInfoID)) { $csToEnc[$r.CollectableSourceInfoID] = $r.JournalEncounterID } }
  $csToQMap = @{}; foreach ($r in (Import-Csv (WFetchBuild 'CollectableSourceQuestSparse' $build))) { if (-not $csToQMap.ContainsKey($r.CollectableSourceInfoID)) { $csToQMap[$r.CollectableSourceInfoID] = $r.QuestMapID } }
  $csToVMap = @{}; foreach ($r in (Import-Csv (WFetchBuild 'CollectableSourceVendorSparse' $build))) { if (-not $csToVMap.ContainsKey($r.CollectableSourceInfoID)) { $csToVMap[$r.CollectableSourceInfoID] = $r.VendorMapID } }

  # --- journal + map lookups ---
  $encToInst = @{}; foreach ($r in (Import-Csv (WFetchBuild 'JournalEncounter' $build))) { $encToInst[$r.ID] = $r.JournalInstanceID }
  $jInst = @{}; foreach ($r in (Import-Csv (WFetchBuild 'JournalInstance' $build))) { $jInst[$r.ID] = $r }
  $jMap  = @{}; foreach ($r in (Import-Csv (WFetchBuild 'Map' $build))) { $jMap[$r.ID] = $r }
  # Instance expansion via its real Journal tier (Map.ExpansionID is 0 for brand-new maps).
  $tierExp = @{}; foreach ($r in (Import-Csv (WFetchBuild 'JournalTier' $build))) { $tierExp[$r.ID] = [int]$r.Expansion }
  $instTiers = @{}
  foreach ($r in (Import-Csv (WFetchBuild 'JournalTierXInstance' $build))) {
    $e = $tierExp[$r.JournalTierID]
    if ($e) { if (-not $instTiers.ContainsKey($r.JournalInstanceID)) { $instTiers[$r.JournalInstanceID] = New-Object System.Collections.ArrayList }
              [void]$instTiers[$r.JournalInstanceID].Add($e) } }

  function WMapRel($mapId) { if ($mapId -and $jMap.ContainsKey($mapId)) { [int]$jMap[$mapId].ExpansionID + 1 } else { 0 } }
  function WInstRel($insId, $mapId) {
    if ($instTiers.ContainsKey($insId)) {
      $reals = @($instTiers[$insId] | Where-Object { $_ -gt 0 -and $_ -lt 9000 })   # drop the "Current Season" pseudo-tier (9000)
      if ($reals.Count) { return [int]((($reals | Measure-Object -Minimum).Minimum) / 100) }
    }
    return (WMapRel $mapId)
  }
  function WItemRel($itemId) { if ($itemExp.ContainsKey($itemId)) { $e = $itemExp[$itemId]; if ($e -lt 0) { 0 } else { $e + 1 } } else { 0 } }

  # --- index weapon visuals (dedup by ItemAppearanceID = the visual) ---
  $visType = @{}; $visImas = @{}
  foreach ($m in $ima) {
    $wt = WType $item[$m.ItemID]
    if (-not $wt) { continue }
    $aid = $m.ItemAppearanceID
    if (-not $visType.ContainsKey($aid)) { $visType[$aid] = $wt; $visImas[$aid] = New-Object System.Collections.ArrayList }
    [void]$visImas[$aid].Add(@{ ima = $m.ID; src = [int]$m.TransmogSourceTypeEnum; item = $m.ItemID })
  }

  # --- resolve each visual to one representative row ---
  $PRIO = 1, 2, 3, 10, 4, 8, 7   # drop > quest > vendor > trading post > world > craft > achievement
  $wRows = @{}
  function WAdd($key, $name, $cat, $rel, $minInst, $typeId, $aid) {
    if (-not $wRows.ContainsKey($key)) { $wRows[$key] = @{ name = $name; cat = $cat; rel = $rel; minInst = $minInst; types = @{} } }
    $R = $wRows[$key]
    if ($minInst -and (-not $R.minInst -or $minInst -lt $R.minInst)) { $R.minInst = $minInst }
    if (-not $R.types.ContainsKey($typeId)) { $R.types[$typeId] = New-Object 'System.Collections.Generic.HashSet[int]' }
    [void]$R.types[$typeId].Add([int]$aid)
  }
  $placed = 0; $otherPlaced = 0
  foreach ($aid in $visType.Keys) {
    $wt = $visType[$aid]; $done = $false
    foreach ($st in $PRIO) {
      foreach ($c in ($visImas[$aid] | Where-Object { $_.src -eq $st })) {
        if ($st -eq 1) {
          $ci = $imaToCs[$c.ima]; if (-not $ci) { continue }
          $enc = $csToEnc[$ci];   if (-not $enc) { continue }
          $insId = $encToInst[$enc]; if (-not $insId) { continue }
          $ii = $jInst[$insId]; if (-not $ii) { continue }
          $mp = $jMap[$ii.MapID]; $it = if ($mp) { [int]$mp.InstanceType } else { -1 }
          $cat = switch ($it) { 2 {'Raid'} 1 {'Dungeon'} 0 {'World Boss'} default {$null} }
          if (-not $cat) { continue }
          $nm = ($ii.Name_lang -split ' - ', 2)[0]   # merge wings (Dire Maul - X, Stratholme - X)
          $rel = WInstRel $insId $ii.MapID
          WAdd "INST|$nm|$rel" $nm $cat $rel ([int]$insId) $wt $aid; $done = $true; break
        } elseif ($st -eq 2) {
          $ci = $imaToCs[$c.ima]; $qm = if ($ci) { $csToQMap[$ci] } else { $null }
          $rel = if ($qm) { WMapRel $qm } else { 0 }; if ($rel -eq 0) { $rel = WItemRel $c.item }
          WAdd "QUEST|$rel" 'Quest' 'Quest' $rel $null $wt $aid; $done = $true; break
        } elseif ($st -eq 3) {
          $ci = $imaToCs[$c.ima]; $vm = if ($ci) { $csToVMap[$ci] } else { $null }
          $rel = if ($vm) { WMapRel $vm } else { 0 }; if ($rel -eq 0) { $rel = WItemRel $c.item }
          WAdd "VENDOR|$rel" 'Vendor' 'Vendor' $rel $null $wt $aid; $done = $true; break
        } elseif ($st -eq 10) { $rel = WItemRel $c.item; WAdd "TP|$rel" 'Trading Post' 'Trading Post' $rel $null $wt $aid; $done = $true; break }
          elseif ($st -eq 4) { $rel = WItemRel $c.item; WAdd "WORLD|$rel" 'World Drop' 'World Drop' $rel $null $wt $aid; $done = $true; break }
          elseif ($st -eq 8) { $rel = WItemRel $c.item; WAdd "CRAFT|$rel" 'Crafted' 'Crafted' $rel $null $wt $aid; $done = $true; break }
          elseif ($st -eq 7) { $rel = WItemRel $c.item; WAdd "ACHIEV|$rel" 'Achievement' 'Achievement' $rel $null $wt $aid; $done = $true; break }
      }
      if ($done) { break }
    }
    # Fallback — HiddenUntilCollected (Enum.TransmogSource 5): how Timewalking reissues and other
    # masked-source items are flagged. $PRIO covers every OTHER obtainable source type but not 5, so
    # without this a hidden-source visual (the Warglaives of Azzinoth reissue, 34777/8461) is dropped
    # SILENTLY — never placed, never counted, no warning. Keep it in an "Other" row bucketed by the
    # collectible item's own expansion. Visuals whose only weapon sources are CantCollect (6) /
    # NotValidForTransmog (9) / None (0) are genuinely uncollectable and stay out. See #670.
    if (-not $done) {
      $hidden = @($visImas[$aid] | Where-Object { $_.src -eq 5 })
      if ($hidden.Count) {
        $rels = @($hidden | ForEach-Object { WItemRel $_.item } | Where-Object { $_ -gt 0 })
        $rel = if ($rels.Count) { ($rels | Measure-Object -Minimum).Minimum } else { 0 }
        WAdd "OTHER|$rel" 'Other' 'Other' $rel $null $wt $aid; $done = $true; $otherPlaced++
      }
    }
    if ($done) { $placed++ }
  }
  if ($placed -lt 3000) { throw "Only $placed weapon appearances placed (<3000) — incomplete data, aborting." }
  Write-Host "  [$build] placed $placed weapon appearances into $($wRows.Count) source rows ($otherPlaced via the HiddenUntilCollected 'Other' fallback)." -ForegroundColor Cyan
  return @{ rows = $wRows; placed = $placed; otherPlaced = $otherPlaced }
}

# The set of weapon/off-hand ItemAppearanceIDs present on $build — just Item + ItemModifiedAppearance
# (a fraction of the full pipeline), for diffing the PTR appearances against live in -Weapons -PtrDelta.
function Get-WeaponVisualSet([string]$build) {
  $item = @{}
  Import-Csv (WFetchBuild 'Item' $build) | ForEach-Object { $item[$_.ID] = $_ }
  if ($item.Count -lt 50000) { throw "Item under 50000 rows ($($item.Count)) for $build — incomplete download, aborting." }
  $set = New-Object 'System.Collections.Generic.HashSet[int]'
  foreach ($m in (Import-Csv (WFetchBuild 'ItemModifiedAppearance' $build))) {
    if (WType $item[$m.ItemID]) { [void]$set.Add([int]$m.ItemAppearanceID) }
  }
  return $set
}

# Shared emit for the weapon row map (ns.WeaponSources or ns.WeaponPtrSources): stable synthetic ids
# (instance rows 9_200_000 + min JournalInstanceID; per-expansion aggregates 9_300_000 + catIndex*20 +
# release, both clear of armor setIds and the weapons.lua illusion/arsenal ids), ordered expansion →
# category → name. Returns the row-literal lines; the caller wraps them with the file's own preamble.
function Write-WeaponRowLiterals($rows, [string]$tableVar) {
  function WEsc([string]$s) { $s.Replace('\', '\\').Replace('"', '\"') }
  $catIdx = @{ 'Quest' = 1; 'Vendor' = 2; 'World Drop' = 3; 'Crafted' = 4; 'Trading Post' = 5; 'Achievement' = 6; 'Other' = 7 }
  function WRowId($r) { if ($r.minInst) { 9200000 + [int]$r.minInst } else { $ci = $catIdx[$r.cat]; if (-not $ci) { $ci = 9 }; 9300000 + $ci * 20 + [int]$r.rel } }
  $catRank = @{ 'Raid' = 1; 'Dungeon' = 2; 'World Boss' = 3; 'Quest' = 4; 'Vendor' = 5; 'World Drop' = 6; 'Crafted' = 7; 'Trading Post' = 8; 'Achievement' = 9; 'Other' = 10 }
  $typeOrder = 13, 14, 15, 16, 17, 20, 21, 22, 24, 23, 28, 25, 27, 26, 12, 18, 19   # grid column order (matches the look-builder)
  $ordered = $rows.Values | Sort-Object @{ e = { [int]$_.rel } }, @{ e = { $catRank[$_.cat] } }, @{ e = { $_.name } }
  $out = [System.Collections.Generic.List[string]]::new()
  foreach ($r in $ordered) {
    $out.Add("tinsert($tableVar, {")
    $out.Add("  id = $(WRowId $r),")
    $out.Add("  name = ""$(WEsc $r.name)"",")
    $out.Add("  release = $([int]$r.rel),")
    $out.Add("  category = ""$($r.cat)"",")
    $out.Add('  types = {')
    foreach ($t in $typeOrder) {
      if ($r.types.ContainsKey($t)) {
        $vids = (($r.types[$t] | Sort-Object) -join ', ')
        $out.Add("    [$t] = { $vids },")
      }
    }
    $out.Add('  },')
    $out.Add('})')
    $out.Add('')
  }
  return @{ lines = $out; count = @($ordered).Count }
}

# ── Weapon PTR-delta mode ────────────────────────────────────────────────────
# Emit data/weaponsources_ptr.lua (ns.WeaponPtrSources / ns.WeaponPtrBuild): weapon/off-hand
# APPEARANCES on the PTR (wowt) but NOT yet on live (wow) — the weapon analogue of the armor
# -PtrDelta below. The delta is at the APPEARANCE level (weapons have no TransmogSet grouping):
# run the full bucketing pipeline over the PTR build, then keep only visuals absent from the live
# weapon-visual set. Must sit before `if ($PtrDelta)` so the -Weapons -PtrDelta combo lands here.
if ($Weapons -and $PtrDelta) {
  $wBuilds = (Invoke-WebRequest -Uri 'https://wago.tools/api/builds' -UseBasicParsing -ErrorAction Stop).Content | ConvertFrom-Json
  if (-not $LiveBuild) { $LiveBuild = $wBuilds.wow[0].version }
  if (-not $PtrBuild)  { $PtrBuild  = $wBuilds.wowt[0].version }
  if (-not $LiveBuild -or -not $PtrBuild) { throw 'Could not resolve live/PTR builds from wago.tools.' }
  $ptrMatch = $wBuilds.wowt | Where-Object { $_.version -eq $PtrBuild } | Select-Object -First 1
  $ptrDate  = if ($ptrMatch) { ($ptrMatch.created_at -split ' ')[0] } else { '' }
  Write-Host "Weapon PTR delta: live $LiveBuild  vs  PTR $PtrBuild $ptrDate" -ForegroundColor Cyan

  # -Check: patch-aware staleness (no CSV download), reading ns.WeaponPtrBuild.ptr. Exit 0 = same
  # patch (up to date), 2 = new patch / file missing (regenerate), else a real error. Mirrors -PtrDelta.
  if ($Check) {
    $stamped = $null
    if (Test-Path -LiteralPath $WeaponsPtrFile) {
      $cur = [System.IO.File]::ReadAllText($WeaponsPtrFile)
      if ($cur -match 'ns\.WeaponPtrBuild\s*=\s*\{[^}]*ptr\s*=\s*"([^"]+)"') { $stamped = $Matches[1] }
    }
    if (-not $stamped) { Write-Host "weaponsources_ptr.lua missing or unstamped — regenerate (latest PTR $PtrBuild)." -ForegroundColor Yellow; exit 2 }
    $have = ($stamped -split '\.')[0..2] -join '.'
    $want = ($PtrBuild -split '\.')[0..2] -join '.'
    if ($have -ne $want) { Write-Host "NEW PTR PATCH: $have -> $want (stamped $stamped, latest $PtrBuild) — replace the upcoming weapons." -ForegroundColor Yellow; exit 2 }
    Write-Host "PTR up to date: still patch $have (stamped $stamped, latest $PtrBuild)." -ForegroundColor Green; exit 0
  }

  $ptr = Get-WeaponRows $PtrBuild
  $liveVis = Get-WeaponVisualSet $LiveBuild
  Write-Host "Live weapon visuals: $($liveVis.Count)." -ForegroundColor Cyan

  # Keep only PTR visuals absent from live; drop emptied type columns and rows.
  $ptrOnly = @{}; $upCount = 0
  foreach ($key in $ptr.rows.Keys) {
    $r = $ptr.rows[$key]
    $types = @{}
    foreach ($t in $r.types.Keys) {
      $fresh = @($r.types[$t] | Where-Object { -not $liveVis.Contains([int]$_) })
      if ($fresh.Count) { $types[$t] = $fresh; $upCount += $fresh.Count }
    }
    if ($types.Count) { $ptrOnly[$key] = @{ name = $r.name; cat = $r.cat; rel = $r.rel; minInst = $r.minInst; types = $types } }
  }
  Write-Host "Upcoming weapon appearances: $upCount across $($ptrOnly.Count) source rows." -ForegroundColor Cyan

  $body = Write-WeaponRowLiterals $ptrOnly 'ns.WeaponPtrSources'
  $L = [System.Collections.Generic.List[string]]::new()
  $L.Add('---@type Warbandeer_Collected')
  $L.Add('local ns = select(2, ...)')
  $L.Add('local tinsert = tinsert')
  $L.Add('-- luacheck: no max line length')
  $L.Add("-- Generated from wago.tools weapon PTR delta (live $LiveBuild vs PTR $PtrBuild$(if($ptrDate){", $ptrDate"})) by tools/update-sets.ps1 -Weapons -PtrDelta.")
  $L.Add('-- Weapon/off-hand APPEARANCES on the PTR but not yet on live ("upcoming"), same source x weapon')
  $L.Add('-- type shape as weaponsources.lua. VOLATILE — regenerate on demand; not part of the weekly refresh.')
  $L.Add('')
  $L.Add('---@class Warbandeer_Collected')
  $L.Add('---@field WeaponPtrSources table[] PTR-only weapon-appearance source groups (same shape as ns.WeaponSources)')
  $L.Add('---@field WeaponPtrBuild { live: string, ptr: string } the builds this delta was generated from')
  $L.Add('ns.WeaponPtrSources = {}')
  $L.Add("ns.WeaponPtrBuild = { live = ""$LiveBuild"", ptr = ""$PtrBuild"" }")
  $L.Add('')
  foreach ($ln in $body.lines) { $L.Add($ln) }
  $newText = ($L -join "`n").TrimEnd() + "`n"

  # Staleness ignores the build-stamp line, so a within-patch build bump with identical data is no diff.
  function WPtrStrip([string]$s) { (($s -split "`n") | Where-Object { $_ -notmatch '^-- Generated from wago\.tools' }) -join "`n" }
  $curPtr = if (Test-Path -LiteralPath $WeaponsPtrFile) { [System.IO.File]::ReadAllText($WeaponsPtrFile) } else { '' }
  if ((WPtrStrip $curPtr) -ne (WPtrStrip $newText)) {
    [System.IO.File]::WriteAllText($WeaponsPtrFile, $newText, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Wrote $WeaponsPtrFile ($($body.count) upcoming source rows, $upCount appearances)." -ForegroundColor Green
  } else {
    Write-Host 'No changes — weaponsources_ptr.lua already current.' -ForegroundColor Green
  }
  exit 0
}

# ── PTR-delta mode ──────────────────────────────────────────────────────────
# Emit data/sets_ptr.lua (ns.PtrSets / ns.PtrBuild) from the live↔PTR TransmogSet
# diff. Self-contained (its own two-build downloads) and exits before the normal
# single-build live refresh below.
if ($PtrDelta) {
  function PtrCsv([string]$table, [string]$build) {
    $url = "https://wago.tools/db2/$table/csv?build=$build"
    Write-Host "Fetching $url" -ForegroundColor Cyan
    (Invoke-WebRequest -Uri $url -UseBasicParsing -ErrorAction Stop).Content | ConvertFrom-Csv
  }
  function PtrTrim($s) { if ($null -eq $s) { '' } else { ([string]$s).Trim() } }
  function PtrEsc([string]$s) { $s.Replace('\', '\\').Replace('"', '\"') }
  # The patch a build belongs to = its first three version components (12.1.0.68301
  # -> 12.1.0). A new PTR PATCH (12.1.0 -> 12.1.5) means a fresh content cycle whose
  # whole upcoming list should be replaced; within-patch build bumps (…68301 -> …69xxx)
  # are routine churn the daily watcher deliberately ignores.
  function PtrPatch([string]$v) { ($v -split '\.')[0..2] -join '.' }

  # Resolve both builds (explicit overrides, else the latest of each product). The
  # bare /csv endpoint serves the newest build across ALL products, so always pin one.
  $builds = (Invoke-WebRequest -Uri 'https://wago.tools/api/builds' -UseBasicParsing -ErrorAction Stop).Content | ConvertFrom-Json
  if (-not $LiveBuild) { $LiveBuild = $builds.wow[0].version }
  if (-not $PtrBuild)  { $PtrBuild  = $builds.wowt[0].version }
  if (-not $LiveBuild -or -not $PtrBuild) { throw 'Could not resolve live/PTR builds from wago.tools.' }
  $ptrMatch = $builds.wowt | Where-Object { $_.version -eq $PtrBuild } | Select-Object -First 1
  $ptrDate  = if ($ptrMatch) { ($ptrMatch.created_at -split ' ')[0] } else { '' }
  Write-Host "PTR delta: live $LiveBuild  vs  PTR $PtrBuild $ptrDate" -ForegroundColor Cyan

  # -Check is a cheap, PATCH-aware staleness probe (no CSV download): it reports only
  # whether a new PTR PATCH has opened since the committed list was generated — the
  # signal the daily watcher acts on. Exit codes: 0 = same patch (up to date),
  # 2 = new patch / file missing (regenerate), anything else = a real error (throw).
  if ($Check) {
    $stamped = $null
    if (Test-Path -LiteralPath $PtrFile) {
      $cur = [System.IO.File]::ReadAllText($PtrFile)
      if ($cur -match 'ns\.PtrBuild\s*=\s*\{[^}]*ptr\s*=\s*"([^"]+)"') { $stamped = $Matches[1] }
    }
    if (-not $stamped) {
      Write-Host "sets_ptr.lua missing or unstamped — regenerate (latest PTR $PtrBuild)." -ForegroundColor Yellow
      exit 2
    }
    $have = PtrPatch $stamped
    $want = PtrPatch $PtrBuild
    if ($have -ne $want) {
      Write-Host "NEW PTR PATCH: $have -> $want (stamped $stamped, latest $PtrBuild) — replace the upcoming list." -ForegroundColor Yellow
      exit 2
    }
    Write-Host "PTR up to date: still patch $have (stamped $stamped, latest $PtrBuild)." -ForegroundColor Green
    exit 0
  }

  $liveRows = PtrCsv 'TransmogSet' $LiveBuild
  $ptrRows  = PtrCsv 'TransmogSet' $PtrBuild
  $grpRows  = PtrCsv 'TransmogSetGroup' $PtrBuild
  $indRows  = PtrCsv 'ItemNameDescription' $PtrBuild   # difficulty/variant labels per set
  # Same integrity guards as the live path: expected schema + a row floor catch a
  # truncated/error response (HTML parsed as CSV, half-finished download).
  foreach ($col in @('ID', 'Name_lang', 'ClassMask', 'TransmogSetGroupID', 'ItemNameDescriptionID')) {
    if ($col -notin $ptrRows[0].PSObject.Properties.Name) { throw "PTR TransmogSet CSV missing '$col' column — aborting." }
  }
  if ($liveRows.Count -lt $MinRows -or $ptrRows.Count -lt $MinRows) {
    throw "TransmogSet under MinRows ($MinRows): live $($liveRows.Count), PTR $($ptrRows.Count) — incomplete download, aborting."
  }

  $liveIds = @{}; foreach ($r in $liveRows) { $liveIds[$r.ID] = $true }
  $grpName = @{}; foreach ($g in $grpRows) { $grpName[[int]$g.ID] = PtrTrim $g.Name_lang }
  $indLabel = @{}; foreach ($d in $indRows) { $id = 0; [void][int]::TryParse($d.ID, [ref]$id); if ($id -gt 0) { $indLabel[$id] = PtrTrim $d.Description_lang } }
  # Resolve a set's group name + its difficulty/variant label (e.g. "Mythic", "Elite").
  function PtrNameOf($row) {
    $gid = [int]$row.TransmogSetGroupID
    if ($grpName.ContainsKey($gid) -and $grpName[$gid]) { return $grpName[$gid] }
    return (PtrTrim $row.Name_lang)
  }
  function PtrLabelOf($row) {
    $ind = 0; [void][int]::TryParse($row.ItemNameDescriptionID, [ref]$ind)
    if ($indLabel.ContainsKey($ind)) { return $indLabel[$ind] }
    return ''
  }

  # PTR-only, placeable rows (a real group + at least one class bit).
  $delta = $ptrRows | Where-Object {
    -not $liveIds.ContainsKey($_.ID) -and [int]$_.TransmogSetGroupID -gt 0 -and [int]$_.ClassMask -gt 0
  }

  # First pass: which group names carry more than one difficulty/variant label, so a
  # raid (Raid Finder/Normal/Heroic/Mythic) or PvP set (Gladiator/Elite/...) splits into
  # one row per label, while a single-variant set (a delve/world-quest/renown set) stays
  # a single bare-named row. Armor-type variants of one set share a label, so they merge.
  $nameLabels = @{}
  foreach ($r in $delta) {
    $name = PtrNameOf $r
    if (-not $name) { continue }
    if (-not $nameLabels.ContainsKey($name)) { $nameLabels[$name] = New-Object 'System.Collections.Generic.HashSet[string]' }
    [void]$nameLabels[$name].Add((PtrLabelOf $r))
  }

  # Bucket by (group name, label). The display name gets a " (Label)" suffix only when
  # the group has multiple labels. id = the lowest group id in the bucket (difficulty
  # rows of one raid share it, matching the live data); first/lowest set id wins per
  # class slot. minId + difficulty rank order the rows (Raid Finder→Mythic, then others).
  $diffRank = @{ 'Raid Finder' = 1; 'Normal' = 2; 'Heroic' = 3; 'Mythic' = 4 }
  $buckets = [ordered]@{}
  foreach ($r in ($delta | Sort-Object { [int]$_.ID })) {
    $name = PtrNameOf $r
    if (-not $name) { continue }
    $sName = PtrTrim $r.Name_lang
    $label = PtrLabelOf $r
    $gid   = [int]$r.TransmogSetGroupID
    $sid   = [int]$r.ID
    $display = if ($nameLabels[$name].Count -gt 1 -and $label) { "$name ($label)" } else { $name }
    if (-not $buckets.Contains($display)) {
      $rank = if ($diffRank.ContainsKey($label)) { $diffRank[$label] } else { 99 }
      $buckets[$display] = @{ minGid = $gid; minId = $sid; rank = $rank; slots = @{} }
    }
    $bk = $buckets[$display]
    if ($gid -lt $bk.minGid) { $bk.minGid = $gid }
    if ($sid -lt $bk.minId) { $bk.minId = $sid }
    $mask = [int]$r.ClassMask
    for ($b = 0; $b -lt 13; $b++) {
      if (($mask -band (1 -shl $b)) -eq 0) { continue }
      $c = $b + 1
      if ($bk.slots.ContainsKey($c)) { continue }
      $bk.slots[$c] = @{ id = $sid; name = $sName }
    }
  }

  # release index for upcoming sets = the newest expansion (last ns.Releases entry,
  # parsed from sets.lua so it tracks the live data without a second hardcoded list).
  $release = 12
  $live = [System.IO.File]::ReadAllText($SetsFile)
  if ($live -match '(?s)ns\.Releases\s*=\s*\{(.*?)\}') {
    $n = ([regex]::Matches($Matches[1], '"')).Count / 2
    if ($n -ge 1) { $release = [int]$n }
  }

  $L = [System.Collections.Generic.List[string]]::new()
  $L.Add('---@type Warbandeer_Collected')
  $L.Add('local ns = select(2, ...)')
  $L.Add('local tinsert = tinsert')
  $L.Add("-- Generated from wago.tools TransmogSet PTR delta (live $LiveBuild vs PTR $PtrBuild$(if($ptrDate){", $ptrDate"})) by tools/update-sets.ps1 -PtrDelta.")
  $L.Add('-- Sets present on the PTR but not yet on live ("upcoming"). VOLATILE — regenerate')
  $L.Add('-- on demand; not part of the weekly live refresh. release tags the newest expansion;')
  $L.Add('-- instance/difficulty are omitted (no lockouts for unreleased content).')
  $L.Add('')
  $L.Add('---@class Warbandeer_Collected')
  $L.Add('---@field PtrSets table[] PTR-only set groups (same shape as ns.Sets)')
  $L.Add('---@field PtrBuild { live: string, ptr: string } the builds this delta was generated from')
  $L.Add('ns.PtrSets = {}')
  $L.Add("ns.PtrBuild = { live = ""$LiveBuild"", ptr = ""$PtrBuild"" }")
  $L.Add('')

  foreach ($k in ($buckets.Keys | Sort-Object { $buckets[$_].minGid }, { $buckets[$_].rank }, { $buckets[$_].minId })) {
    $bucket = $buckets[$k]
    $L.Add('tinsert(ns.PtrSets, {')
    $L.Add("  id = $($bucket.minGid),")
    $L.Add("  name = ""$(PtrEsc $k)"",")
    $L.Add("  release = $release,")
    $L.Add('  sets = {')
    $maxC = ($bucket.slots.Keys | Measure-Object -Maximum).Maximum
    for ($c = 1; $c -le $maxC; $c++) {
      if ($bucket.slots.ContainsKey($c)) {
        $slot = $bucket.slots[$c]
        $slotName = PtrEsc $slot.name
        $L.Add("    { id = $($slot.id), name = ""$slotName"", classId = $c },")
      } else {
        $L.Add('    {},')
      }
    }
    $L.Add('  },')
    $L.Add('})')
    $L.Add('')
  }

  $newText = ($L -join "`n").TrimEnd() + "`n"
  [System.IO.File]::WriteAllText($PtrFile, $newText, [System.Text.UTF8Encoding]::new($false))
  Write-Host "Wrote $PtrFile ($($buckets.Count) upcoming row(s))." -ForegroundColor Green
  exit 0
}

# ── Weapons mode ─────────────────────────────────────────────────────────────
# Emit data/weaponsources.lua (ns.WeaponSources): every weapon + off-hand APPEARANCE
# bucketed by SOURCE (row) x weapon TYPE (column). Unlike armor, Blizzard never grouped
# weapons into TransmogSet records, so the grouping is DERIVED from DB2:
#   ItemModifiedAppearance.TransmogSourceTypeEnum -> coarse source bucket (every appearance)
#   CollectableSourceInfo + CollectableSource{Encounter,Quest,Vendor}Sparse -> the specific source
#   Item.ClassID/SubclassID/InventoryType -> weapon type (ClassID 2; Shield/Holdable are Armor class 4)
#   JournalTier via JournalTierXInstance -> instance expansion (Map.ExpansionID is 0 for new maps)
#   Map.InstanceType -> Raid (2) / Dungeon (1) / World Boss (0)
# One representative source per visual: drop > quest > vendor > TP > world > craft > achiev.
# Dungeon/raid wings (Dire Maul - X, Stratholme - X) merge into the base instance. Self-contained;
# exits before the normal live refresh. See UPDATING.md ("Regenerating the weapon sources").
if ($Weapons) {
  # Resolve the build (pin it — the bare endpoint serves PTR/beta too).
  $wBuilds = (Invoke-WebRequest -Uri 'https://wago.tools/api/builds' -UseBasicParsing -ErrorAction Stop).Content | ConvertFrom-Json
  if (-not $Build) { $Build = $wBuilds.$Product[0].version }
  $wMatch = $wBuilds.$Product | Where-Object { $_.version -eq $Build } | Select-Object -First 1
  $wDate  = if ($wMatch) { ($wMatch.created_at -split ' ')[0] } else { '' }
  Write-Host "Weapon sources against $Product build $Build $wDate" -ForegroundColor Cyan

  $wr = Get-WeaponRows $Build
  $wRows = $wr.rows; $placed = $wr.placed

  # --- emit ns.WeaponSources ---
  $body = Write-WeaponRowLiterals $wRows 'ns.WeaponSources'
  $L = [System.Collections.Generic.List[string]]::new()
  $L.Add('---@type Warbandeer_Collected')
  $L.Add('local ns = select(2, ...)')
  $L.Add('local tinsert = tinsert')
  $L.Add('-- luacheck: no max line length')
  $L.Add("-- Generated from wago.tools ($Product build $Build$(if($wDate){", $wDate"})) by tools/update-sets.ps1 -Weapons.")
  $L.Add('-- Every weapon/off-hand APPEARANCE bucketed by source (row) x weapon type (column);')
  $L.Add('-- types are keyed by Enum.TransmogCollectionType, values are ItemAppearanceIDs (visuals).')
  $L.Add('-- Derived wholesale from DB2 — do not hand-edit; regenerate with -Weapons. See UPDATING.md.')
  $L.Add('')
  $L.Add('---@class Warbandeer_Collected')
  $L.Add('---@field WeaponSources table[] weapon-appearance source groups: `{ id, name, release, category, types = { [transmogCollectionType] = { visualID... } } }`')
  $L.Add('ns.WeaponSources = {}')
  $L.Add('')
  foreach ($ln in $body.lines) { $L.Add($ln) }
  $newText = ($L -join "`n").TrimEnd() + "`n"

  # Staleness: compare ignoring the build-stamp line, so a build bump with identical data is no diff.
  function WStrip([string]$s) { (($s -split "`n") | Where-Object { $_ -notmatch '^-- Generated from wago\.tools' }) -join "`n" }
  $cur = if (Test-Path -LiteralPath $WeaponsFile) { [System.IO.File]::ReadAllText($WeaponsFile) } else { '' }
  $wChanged = (WStrip $cur) -ne (WStrip $newText)
  if ($Check) {
    if ($wChanged) { Write-Host 'weaponsources.lua is OUT OF DATE.' -ForegroundColor Yellow; exit 1 }
    Write-Host 'weaponsources.lua is up to date.' -ForegroundColor Green; exit 0
  }
  if ($wChanged) {
    [System.IO.File]::WriteAllText($WeaponsFile, $newText, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Wrote $WeaponsFile ($($body.count) source rows, $placed appearances)." -ForegroundColor Green
  } else {
    Write-Host 'No changes — weaponsources.lua already current.' -ForegroundColor Green
  }
  exit 0
}

# Resolve the build to pull: an explicit -Build, else the latest build of -Product
# (default 'wow' = live retail). The bare /csv endpoint serves the newest build
# across ALL products — including the PTR — so always pin a real product build.
$all = (Invoke-WebRequest -Uri 'https://wago.tools/api/builds' -UseBasicParsing -ErrorAction Stop).Content | ConvertFrom-Json
$list = $all.$Product
if (-not $list) { throw "wago.tools has no builds for product '$Product'." }
if (-not $Build) { $Build = $list[0].version }
$match = $list | Where-Object { $_.version -eq $Build } | Select-Object -First 1
$buildDate = if ($match) { ($match.created_at -split ' ')[0] } else { '' }
Write-Host "Using $Product build $Build $buildDate" -ForegroundColor Cyan

function Get-Csv([string]$table) {
  $url = "https://wago.tools/db2/$table/csv?build=$Build"
  Write-Host "Fetching $url" -ForegroundColor Cyan
  (Invoke-WebRequest -Uri $url -UseBasicParsing -ErrorAction Stop).Content | ConvertFrom-Csv
}

# --- 1. Difficulty label per ItemNameDescriptionID -------------------------
$label = @{}
foreach ($d in (Get-Csv 'ItemNameDescription')) {
  $id = 0; [void][int]::TryParse($d.ID, [ref]$id)
  if ($id -gt 0) { $label[$id] = $d.Description_lang.Trim() }
}
# Integrity: the core difficulty labels must be present, else the discriminator
# is broken and difficulty tiers would resolve wrong (incomplete/garbage download).
$have = $label.Values | Select-Object -Unique
foreach ($req in @('Raid Finder', 'Normal', 'Heroic', 'Mythic')) {
  if ($have -notcontains $req) { throw "ItemNameDescription is missing the '$req' label — incomplete download, aborting." }
}

# --- 2. wago sets -> $byGroup[gid][difficultyLabel][classId] = Lua line -----
$rows = Get-Csv 'TransmogSet'
if (-not $rows) { throw 'No rows returned from wago.tools (TransmogSet).' }
# Integrity: expected schema + a sane row floor guard against truncated / error
# responses (e.g. an HTML error page parsed as CSV, or a half-finished download).
foreach ($col in @('ID', 'Name_lang', 'ClassMask', 'TransmogSetGroupID', 'ItemNameDescriptionID')) {
  if ($col -notin $rows[0].PSObject.Properties.Name) { throw "TransmogSet CSV is missing the '$col' column — unexpected response, aborting." }
}
if ($rows.Count -lt $MinRows) { throw "TransmogSet returned only $($rows.Count) rows (< MinRows $MinRows) — likely an incomplete download, aborting." }

$byGroup = @{}
foreach ($r in ($rows | Sort-Object { [int]$_.ID })) {
  $gid = 0; [void][int]::TryParse($r.TransmogSetGroupID, [ref]$gid)
  if ($gid -le 0) { continue }
  $mask = 0; [void][int]::TryParse($r.ClassMask, [ref]$mask)
  if ($mask -le 0) { continue }
  $ind = 0; [void][int]::TryParse($r.ItemNameDescriptionID, [ref]$ind)
  $lbl = if ($label.ContainsKey($ind)) { $label[$ind] } else { '' }
  $name = $r.Name_lang.Replace('\', '\\').Replace('"', '\"')

  if (-not $byGroup.ContainsKey($gid)) { $byGroup[$gid] = @{} }
  if (-not $byGroup[$gid].ContainsKey($lbl)) { $byGroup[$gid][$lbl] = @{} }
  $slot = $byGroup[$gid][$lbl]
  for ($b = 0; $b -lt 13; $b++) {
    if (($mask -band (1 -shl $b)) -eq 0) { continue }
    $classId = $b + 1
    if ($slot.ContainsKey($classId)) { continue }   # first set (lowest ID) wins
    $slot[$classId] = '    {{ id = {0}, name = "{1}", classId = {2} }},' -f $r.ID, $name, $classId
  }
}

# Curated `(Difficulty)` name suffixes that differ from wago's ItemNameDescription
# label, loaded from difficulty-aliases.txt ("curated => wago" per line) and
# translated before matching — keeps tidy in-game names like the Wrath "(10 Normal)".
$DifficultyAlias = @{}
$aliasFile = Join-Path $PSScriptRoot 'difficulty-aliases.txt'
if (Test-Path -LiteralPath $aliasFile) {
  foreach ($ln in (Get-Content -LiteralPath $aliasFile)) {
    $t = $ln.Trim()
    if (-not $t -or $t.StartsWith('#')) { continue }
    $kv = $t -split '\s*=>\s*', 2
    if ($kv.Count -eq 2) { $DifficultyAlias[$kv[0].Trim()] = $kv[1].Trim() }
  }
}

# Resolve a group's set lines, or $null to leave the block unchanged.
function Get-SetsBody([int]$gid, [string]$difficulty) {
  if (-not $byGroup.ContainsKey($gid)) { return $null }
  $labels = $byGroup[$gid]
  $use = $null
  if ($difficulty) {
    if ($DifficultyAlias.ContainsKey($difficulty)) { $difficulty = $DifficultyAlias[$difficulty] }
    if ($labels.ContainsKey($difficulty)) { $use = $difficulty } else { return $null }
  }
  elseif ($labels.Count -eq 1) { $use = @($labels.Keys)[0] }
  else { return $null }   # no suffix but several difficulties -> ambiguous

  $slot = $labels[$use]
  $max = ($slot.Keys | Measure-Object -Maximum).Maximum
  for ($c = 1; $c -le $max; $c++) {
    if ($slot.ContainsKey($c)) { $slot[$c] } else { '    {},' }
  }
}

# --- 3. Rewrite each group's sets block in place ---------------------------
# The hand-curated body spans two files (sets.lua + sets_late.lua); the normal pass
# fills every `sets = {}` block in each. sets_expand.lua is owned by -Expand, not here.
$BodyFiles = @($SetsFile, (Join-Path (Split-Path $SetsFile) 'sets_late.lua'))

$results  = @()   # per body file: @{ Path; Raw; Eol; Out } (Out is the rewritten line list)
$changed  = 0
$origSets = 0
$newSets  = 0

foreach ($file in $BodyFiles) {
  $raw   = [System.IO.File]::ReadAllText($file)
  $eol   = if ($raw.Contains("`r`n")) { "`r`n" } else { "`n" }
  $lines = $raw -split "`r?`n"

  $out     = [System.Collections.Generic.List[string]]::new()
  $curId   = 0
  $curName = ''
  $curDiff = $null
  $i = 0
  while ($i -lt $lines.Count) {
    $line = $lines[$i]

    # Structural matches are whitespace-tolerant: the hand-maintained file has
    # stray-space quirks like a 3-space indent or a ` } ,` close.
    if ($line -match '^\s+id\s*=\s*(\d+),\s*$') { $curId = [int]$Matches[1]; $out.Add($line); $i++; continue }
    if ($line -match '^\s+name\s*=\s*"(.*)",\s*$') {
      $curName = $Matches[1]
      $curDiff = if ($curName -match '\(([^)]+)\)\s*$') { $Matches[1] } else { $null }
      $out.Add($line); $i++; continue
    }

    # Single-line empty stub: `  sets = {},` (used when seeding a new tier).
    if ($line -match '^\s*sets\s*=\s*\{\s*\}\s*,?\s*$') {
      $body = Get-SetsBody $curId $curDiff
      if ($null -eq $body) { $out.Add($line) }
      else { $out.Add('  sets = {'); $body | ForEach-Object { $out.Add($_) }; $out.Add('  },'); $changed++ }
      $i++; continue
    }

    # Multi-line block: `  sets = {` ... `  },` (whitespace-tolerant close).
    if ($line -match '^\s*sets\s*=\s*\{\s*$') {
      $j = $i + 1
      while ($j -lt $lines.Count -and $lines[$j] -notmatch '^\s*\}\s*,\s*$') { $j++ }
      $orig = if ($j -gt $i + 1) { $lines[($i + 1)..($j - 1)] } else { @() }
      $body = Get-SetsBody $curId $curDiff

      # Per-group guard: don't let a populated tier (>=10 sets) lose more than half
      # its entries in one refresh — almost always a partial download, not a real
      # change. Leave that group as written and warn.
      if ($null -ne $body) {
        $origN = ($orig | Where-Object { $_ -match '^\s*\{\s*id\s*=\s*\d+' }).Count
        $newN  = ($body | Where-Object { $_ -match '^\s*\{\s*id\s*=\s*\d+' }).Count
        if ($origN -ge 10 -and $newN -lt ($origN / 2)) {
          Write-Warning "Group $curId '$curName' would shrink $origN -> $newN sets (>50%) — left unchanged."
          $body = $null
        }
      }

      if ($null -eq $body) {
        for ($k = $i; $k -le $j; $k++) { $out.Add($lines[$k]) }   # leave unchanged
      } else {
        $out.Add('  sets = {'); $body | ForEach-Object { $out.Add($_) }; $out.Add('  },')
        if (($orig -join "`n") -ne ($body -join "`n")) { $changed++ }
      }
      $i = $j + 1; continue
    }

    $out.Add($line); $i++
  }

  $origSets += ($lines | Where-Object { $_ -match '^\s*\{\s*id\s*=\s*\d+' }).Count
  $newSets  += ($out   | Where-Object { $_ -match '^\s*\{\s*id\s*=\s*\d+' }).Count
  $results  += @{ Path = $file; Raw = $raw; Eol = $eol; Out = $out }
}

# Guard: refuse a mass deletion of set entries (summed across both body files).
# Catches partial downloads where groups come back with missing classes.
$floor = [math]::Floor($origSets * (1 - $MaxDeletePct / 100))
if ($origSets -gt 0 -and $newSets -lt $floor) {
  throw "Refusing to write: set entries would drop $origSets -> $newSets (more than $MaxDeletePct%). Likely incomplete wago data — aborting."
}

# Stamp the source build as a comment — but only when the data actually changed, so an
# unchanged weekly run produces no diff (and no PR) over a build bump alone. The stamp
# lives in the file that already carries it (sets.lua); the other body file has none.
if ($changed -gt 0) {
  $date = if ($buildDate) { ", $buildDate" } else { '' }
  $stamp = "-- Generated from wago.tools TransmogSet (product $Product, build $Build$date) by tools/update-sets.ps1."
  $stamped = $false
  foreach ($r in $results) {
    $rOut = $r.Out
    for ($k = 0; $k -lt $rOut.Count; $k++) {
      if ($rOut[$k] -match '^-- Generated from wago\.tools TransmogSet') { $rOut[$k] = $stamp; $stamped = $true; break }
    }
    if ($stamped) { break }
  }
  if (-not $stamped) {
    $rOut = $results[0].Out
    $anchor = 0
    for ($k = 0; $k -lt $rOut.Count; $k++) { if ($rOut[$k] -match '^local tinsert = tinsert\s*$') { $anchor = $k + 1; break } }
    $rOut.Insert($anchor, $stamp)
  }
}

foreach ($r in $results) { $r.NewText = ($r.Out -join $r.Eol) }
$anyChange = @($results | Where-Object { $_.NewText -ne $_.Raw }).Count -gt 0

if ($Check) {
  if ($anyChange) { Write-Host "sets data is OUT OF DATE ($changed group(s) would change)." -ForegroundColor Yellow; exit 1 }
  Write-Host 'sets data is up to date.' -ForegroundColor Green; exit 0
}

if ($anyChange) {
  foreach ($r in $results) {
    if ($r.NewText -ne $r.Raw) {
      [System.IO.File]::WriteAllText($r.Path, $r.NewText, [System.Text.UTF8Encoding]::new($false))
      Write-Host "Updated $($r.Path)." -ForegroundColor Green
    }
  }
  Write-Host "$changed group(s) changed." -ForegroundColor Green
} else {
  Write-Host 'No changes — sets data already current.' -ForegroundColor Green
}
