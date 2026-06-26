<#
.SYNOPSIS
  Regenerate the inner `sets = { ... }` blocks of
  Warbandeer_Collected/data/sets.lua from live wago.tools TransmogSet data.

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
  # listed in tools/expand-groups.txt ("id:Category" lines), into a guarded block of
  # sets.lua — the mechanical way to capture recolor/multi-source mega-sets without
  # hand-seeding dozens of shells. The file is the canonical spec, so a refresh is just
  # `-Expand` (no args). See UPDATING.md.
  [switch]$Expand,
  [string]$ExpandFile = (Join-Path $PSScriptRoot 'expand-groups.txt')
)

$ErrorActionPreference = 'Stop'
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
  $g = @{}; $r = @{}
  $f = Join-Path $PSScriptRoot 'excludes.txt'
  if (Test-Path -LiteralPath $f) {
    foreach ($ln in (Get-Content -LiteralPath $f)) {
      $t = ($ln -split '#', 2)[0].Trim()
      if (-not $t) { continue }
      if ($t -match ':') { $kv = $t -split ':', 2; $r["$([int]$kv[0].Trim())|$($kv[1].Trim())"] = $true }
      else { $g[[int]$t] = $true }
    }
  }
  return @{ groups = $g; rows = $r }
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
      if ($t -match '^merge\s+(\S+)') { foreach ($x in ($Matches[1] -split '\+')) { $ids[[int]$x] = $true } }
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

  # Curated wago group ids already in ns.Sets (the group-level `id = N,` lines).
  $curated = @{}
  foreach ($ln in ($raw -split "`r?`n")) { if ($ln -match '^\s+id\s*=\s*(\d+),\s*$') { $curated[[int]$Matches[1]] = $true } }
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
  $jobIds = @(); $jobCat = @{}; $jobMode = @{}; $merges = @(); $setMerges = @(); $mergedSetIds = @{}
  foreach ($ln in (Get-Content -LiteralPath $ExpandFile)) {
    $t = ($ln -split '#', 2)[0].Trim()
    if (-not $t) { continue }
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
  $L.Add('-- <<< AUTO-EXPAND')

  $raw = [System.IO.File]::ReadAllText($SetsFile)
  $eol = if ($raw.Contains("`r`n")) { "`r`n" } else { "`n" }
  $block = ($L -join "`n") -replace "`n", $eol
  $startMark = '-- >>> AUTO-EXPAND'
  $endMark = '-- <<< AUTO-EXPAND'
  if ($raw.Contains($startMark)) {
    $si = $raw.IndexOf($startMark)
    $ei = $raw.IndexOf($endMark) + $endMark.Length
    $newText = $raw.Substring(0, $si) + $block + $raw.Substring($ei)
  } else {
    $newText = $raw.TrimEnd() + $eol + $eol + $block + $eol
  }
  [System.IO.File]::WriteAllText($SetsFile, $newText, [System.Text.UTF8Encoding]::new($false))
  Write-Host "Expand: wrote $emitted row(s) across $($jobIds.Count) group(s) into $SetsFile." -ForegroundColor Green
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
$raw   = [System.IO.File]::ReadAllText($SetsFile)
$eol   = if ($raw.Contains("`r`n")) { "`r`n" } else { "`n" }
$lines = $raw -split "`r?`n"

$out     = [System.Collections.Generic.List[string]]::new()
$curId   = 0
$curName = ''
$curDiff = $null
$changed = 0
$i = 0
while ($i -lt $lines.Count) {
  $line = $lines[$i]

  # The AUTO-EXPAND block is owned wholesale by `-Expand` (its rows resolve by set name
  # in byset mode, which this single-label resolver would clobber). Copy it verbatim and
  # skip processing — re-run `-Expand` to refresh it.
  if ($line -match '^\s*-- >>> AUTO-EXPAND') {
    while ($i -lt $lines.Count) { $out.Add($lines[$i]); if ($lines[$i] -match '^\s*-- <<< AUTO-EXPAND') { break }; $i++ }
    $i++; continue
  }

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

# Guard: refuse a mass deletion of set entries. Catches partial downloads where
# groups come back with missing classes (which would otherwise blank out slots).
$origSets = ($lines | Where-Object { $_ -match '^\s*\{\s*id\s*=\s*\d+' }).Count
$newSets  = ($out   | Where-Object { $_ -match '^\s*\{\s*id\s*=\s*\d+' }).Count
$floor = [math]::Floor($origSets * (1 - $MaxDeletePct / 100))
if ($origSets -gt 0 -and $newSets -lt $floor) {
  throw "Refusing to write: set entries would drop $origSets -> $newSets (more than $MaxDeletePct%). Likely incomplete wago data — aborting."
}

# Stamp the source build as a comment — but only when the data actually changed,
# so an unchanged weekly run produces no diff (and no PR) over a build bump alone.
if ($changed -gt 0) {
  $date = if ($buildDate) { ", $buildDate" } else { '' }
  $stamp = "-- Generated from wago.tools TransmogSet (product $Product, build $Build$date) by tools/update-sets.ps1."
  $at = -1
  for ($k = 0; $k -lt $out.Count; $k++) { if ($out[$k] -match '^-- Generated from wago\.tools TransmogSet') { $at = $k; break } }
  if ($at -ge 0) { $out[$at] = $stamp }
  else {
    $anchor = 0
    for ($k = 0; $k -lt $out.Count; $k++) { if ($out[$k] -match '^local tinsert = tinsert\s*$') { $anchor = $k + 1; break } }
    $out.Insert($anchor, $stamp)
  }
}

$newText = $out -join $eol

if ($Check) {
  if ($newText -ne $raw) { Write-Host "sets.lua is OUT OF DATE ($changed group(s) would change)." -ForegroundColor Yellow; exit 1 }
  Write-Host 'sets.lua is up to date.' -ForegroundColor Green; exit 0
}

if ($newText -ne $raw) {
  [System.IO.File]::WriteAllText($SetsFile, $newText, [System.Text.UTF8Encoding]::new($false))
  Write-Host "Updated $SetsFile ($changed group(s) changed)." -ForegroundColor Green
} else {
  Write-Host 'No changes — sets.lua already current.' -ForegroundColor Green
}
