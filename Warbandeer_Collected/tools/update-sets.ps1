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
  [switch]$Check
)

$ErrorActionPreference = 'Stop'
$SetsFile = (Resolve-Path -LiteralPath $SetsFile).Path

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

# --- 2. wago sets -> $byGroup[gid][difficultyLabel][classId] = Lua line -----
$rows = Get-Csv 'TransmogSet'
if (-not $rows) { throw 'No rows returned from wago.tools.' }

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

# Resolve a group's set lines, or $null to leave the block unchanged.
function Get-SetsBody([int]$gid, [string]$difficulty) {
  if (-not $byGroup.ContainsKey($gid)) { return $null }
  $labels = $byGroup[$gid]
  $use = $null
  if ($difficulty) {
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
$curDiff = $null
$changed = 0
$i = 0
while ($i -lt $lines.Count) {
  $line = $lines[$i]

  # Structural matches are whitespace-tolerant: the hand-maintained file has
  # stray-space quirks like a 3-space indent or a ` } ,` close.
  if ($line -match '^\s+id\s*=\s*(\d+),\s*$') { $curId = [int]$Matches[1]; $out.Add($line); $i++; continue }
  if ($line -match '^\s+name\s*=\s*"(.*)",\s*$') {
    $curDiff = if ($Matches[1] -match '\(([^)]+)\)\s*$') { $Matches[1] } else { $null }
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
    $body = Get-SetsBody $curId $curDiff
    if ($null -eq $body) {
      for ($k = $i; $k -le $j; $k++) { $out.Add($lines[$k]) }   # leave unchanged
    } else {
      $orig = if ($j -gt $i + 1) { $lines[($i + 1)..($j - 1)] } else { @() }
      $out.Add('  sets = {'); $body | ForEach-Object { $out.Add($_) }; $out.Add('  },')
      if (($orig -join "`n") -ne ($body -join "`n")) { $changed++ }
    }
    $i = $j + 1; continue
  }

  $out.Add($line); $i++
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
