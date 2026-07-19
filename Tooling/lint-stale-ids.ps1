<#
  lint-stale-ids.ps1 — validate hand-authored WoW id literals across the suite's static data
  files against the live client DB2 (wago.tools), so a stale or fat-fingered id is caught in CI
  instead of by a user hitting a blank/mismatched row. Supersedes the standalone
  verify-weapons.ps1 — its two checks are now the weapons.* rules below.

  Each RULE names a data file, an id-extractor, and the DB2 column those ids must resolve against;
  the engine fetches each table once and checks membership. Adding a file to the lint = adding a
  rule. Most rules extract with a single-capture `rx` regex; a file whose ids don't fit one regex
  supplies an `extract` scriptblock instead (see weapons.arsenalItemID).

  Severity:
    fail  a miss means the id is stale/typo'd -> non-zero exit (CI gate).
    warn  the DB2 column is an INCOMPLETE mirror of the runtime lookup, so a miss is reported but
          not failed (see classmounts.spellID below).

  Coverage notes learned building this tier:
    * challengetames.lua is deliberately NOT linted: its creatureIDs are old-content npcs that the
      modern retail client trims out of Creature.db2 (they live server-side), so every entry would
      false-flag. No client-side source can validate them.
    * classmounts.spellID is warn-only: GetMountFromSpell resolves summon spells that are not the
      mount's Mount.SourceSpellID (e.g. 241856), so Mount.SourceSpellID catches most but not all.
      The 21 classmount itemIDs validate reliably against Item and stay fail-severity.
    * professioninfo.spellID is skipped (would need the huge Spell table for marginal value).
    * weapons illusion sourceIDs map to TransmogIllusion.SpellItemEnchantmentID, NOT .ID (.ID runs
      2..103, the sourceIDs ~5000+); weapons arsenal/pieces itemIDs -> Item.ID.

  Usage:
    pwsh Tooling/lint-stale-ids.ps1              # full (pulls Item, the one big table)
    pwsh Tooling/lint-stale-ids.ps1 -SkipBig     # skip big-table rules (fast; races/prof/mount-spell)
    pwsh Tooling/lint-stale-ids.ps1 -Build 12.0.7.68453
  Exit 0 = every fail-rule id resolves; 1 = one or more stale.
#>
param(
  [string]$Build,
  [switch]$SkipBig
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent

# weapons.lua stores arsenal itemIDs in two literal forms — `arsenal = N` and multi-id
# `pieces = { N, N, ... }` blocks — so this rule extracts with a scriptblock, not one regex.
# (The engine strips Lua comments before calling it, so stray comment digits can't leak in.)
$extractArsenalItems = {
  param($text)
  $ids = @()
  $ids += [regex]::Matches($text, 'arsenal\s*=\s*(\d+)') | ForEach-Object { [int]$_.Groups[1].Value }
  foreach ($blk in [regex]::Matches($text, 'pieces\s*=\s*\{([^}]*)\}')) {
    $ids += [regex]::Matches($blk.Groups[1].Value, '\d+') | ForEach-Object { [int]$_.Value }
  }
  $ids
}

# Each rule: file = repo-relative data file; rx = single-capture id regex (group 1) OR extract =
# a scriptblock taking the comment-stripped file text and returning the ids; table/col = DB2
# target; sev = fail|warn; big = six-figure table (ID is col 1, hashed from the raw CSV).
$rules = @(
  # races.lua: the explicit allied-race keys raceIdToFactionIndex[N] (the drift-prone ones; the
  # positional core races 1..11 are immutable and intentionally not parsed).
  @{ file='Warbandeer_Characters/data/races.lua';         label='races.raceId';                rx='raceIdToFactionIndex\[(\d+)\]'; table='ChrRaces';  col='ID';            sev='fail'; big=$false }
  @{ file='Warbandeer_Characters/data/professioninfo.lua'; label='professioninfo.skillLineID';        rx='skillLineID\s*=\s*(\d+)';        table='SkillLine'; col='ID';            sev='fail'; big=$false }
  @{ file='Warbandeer_Characters/data/professioninfo.lua'; label='professioninfo.skillLineVariantID'; rx='skillLineVariantID\s*=\s*(\d+)'; table='SkillLine'; col='ID';            sev='fail'; big=$false }
  @{ file='Warbandeer_Characters/data/professioninfo.lua'; label='professioninfo.midVariantID';       rx='midVariantID\s*=\s*(\d+)';       table='SkillLine'; col='ID';            sev='fail'; big=$false }
  @{ file='Warbandeer_Characters/data/classmounts.lua';    label='classmounts.itemID';               rx='itemID\s*=\s*(\d+)';             table='Item';      col='ID';            sev='fail'; big=$true  }
  @{ file='Warbandeer_Characters/data/classmounts.lua';    label='classmounts.spellID';              rx='spellID\s*=\s*(\d+)';            table='Mount';     col='SourceSpellID'; sev='warn'; big=$false }
  # weapons.lua (#516/#596): illusion sourceIDs resolve as TransmogIllusion.SpellItemEnchantmentID
  # (NOT .ID); arsenal/pieces itemIDs are real Item rows. Folded in from verify-weapons.ps1.
  @{ file='Warbandeer_Collected/data/weapons.lua';         label='weapons.illusionSourceID';         rx='sourceID\s*=\s*(\d+)';           table='TransmogIllusion'; col='SpellItemEnchantmentID'; sev='fail'; big=$false }
  @{ file='Warbandeer_Collected/data/weapons.lua';         label='weapons.arsenalItemID';            extract=$extractArsenalItems;        table='Item';      col='ID';            sev='fail'; big=$true  }
)

# ── resolve build (same source of truth as update-sets.ps1 / verify-weapons.ps1) ──
$builds = (Invoke-WebRequest -Uri 'https://wago.tools/api/builds' -UseBasicParsing).Content | ConvertFrom-Json
if (-not $Build) { $Build = $builds.wow[0].version }
Write-Host "Linting hand-authored ids against wow build $Build`n" -ForegroundColor Cyan

# ── id-set per (table,col), fetched once and cached ──
$setCache = @{}
function Get-IdSet($table, $col, $big) {
  $key = "$table|$col"
  if ($setCache.ContainsKey($key)) { return $setCache[$key] }
  $set = @{}
  $url = "https://wago.tools/db2/$table/csv?build=$Build"
  if ($big) {
    # Huge table: ID is column 1, so hash the first field of each raw line (ConvertFrom-Csv is
    # minutes-slow at six-figure rows). Big rules only ever target the first-column ID.
    if ($col -ne 'ID') { throw "big-table rule for $table must key on ID (col 1), got $col" }
    foreach ($line in (Invoke-WebRequest -Uri $url -UseBasicParsing).Content -split "`n") {
      $c = $line.IndexOf(','); if ($c -gt 0) { $id = $line.Substring(0, $c); if ($id -match '^\d+$') { $set[[int]$id] = $true } }
    }
  } else {
    # Small table: ConvertFrom-Csv handles the quoted, comma-bearing *_lang string columns that a
    # naive split would misalign (the id column often sits after several localized name fields).
    (Invoke-WebRequest -Uri $url -UseBasicParsing).Content | ConvertFrom-Csv | ForEach-Object {
      $v = $_.$col; if ($v -ne $null -and $v -ne '') { $set[[int]$v] = $true }
    }
  }
  $setCache[$key] = $set
  return $set
}

# ── run each rule ──
$srcCache = @{}
$fail = 0
foreach ($r in $rules) {
  if ($r.big -and $SkipBig) { Write-Host ("{0,-34} skipped (-SkipBig)" -f $r.label) -ForegroundColor DarkGray; continue }

  if (-not $srcCache.ContainsKey($r.file)) {
    $t = Get-Content -Raw (Join-Path $repo $r.file)
    $srcCache[$r.file] = [regex]::Replace($t, '--[^\r\n]*', '')   # strip Lua line comments first
  }
  $ids = if ($r.extract) { & $r.extract $srcCache[$r.file] }
         else { [regex]::Matches($srcCache[$r.file], $r.rx) | ForEach-Object { [int]$_.Groups[1].Value } }
  $ids = @($ids | Sort-Object -Unique)
  $set = Get-IdSet $r.table $r.col $r.big
  $miss = @($ids | Where-Object { -not $set.ContainsKey($_) })

  if ($miss.Count -eq 0) {
    Write-Host ("{0,-34} + {1,3} ids OK  ({2}.{3})" -f $r.label, $ids.Count, $r.table, $r.col) -ForegroundColor Green
  } elseif ($r.sev -eq 'warn') {
    Write-Host ("{0,-34} ~ {1} of {2} unresolved in {3}.{4} (best-effort): {5}" -f $r.label, $miss.Count, $ids.Count, $r.table, $r.col, ($miss -join ', ')) -ForegroundColor Yellow
  } else {
    Write-Host ("{0,-34} ! {1} of {2} MISSING from {3}.{4}: {5}" -f $r.label, $miss.Count, $ids.Count, $r.table, $r.col, ($miss -join ', ')) -ForegroundColor Red
    $fail += $miss.Count
  }
}

if ($fail) { Write-Host "`n$fail id(s) unresolved -- a data file is stale for build $Build." -ForegroundColor Red; exit 1 }
Write-Host "`nAll fail-severity ids resolve against build $Build." -ForegroundColor Green
exit 0
