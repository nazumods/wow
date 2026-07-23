<#
  lint-stale-ids.ps1 — validate hand-authored WoW id literals across the suite's static data
  files against the live client DB2 (wago.tools), so a stale or fat-fingered id is caught in CI
  instead of by a user hitting a blank/mismatched row. Supersedes the standalone
  verify-weapons.ps1 — its two checks are now the illusions.*/arsenals.* rules below.

  Each RULE names a data file, an id-extractor, and the DB2 column those ids must resolve against;
  the engine fetches each table once and checks membership. Adding a file to the lint = adding a
  rule. Most rules extract with a single-capture `rx` regex; a file whose ids don't fit one regex
  supplies an `extract` scriptblock instead (see arsenals.visualID).

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
    * illusion sourceIDs map to TransmogIllusion.SpellItemEnchantmentID, NOT .ID (.ID runs
      2..103, the sourceIDs ~5000+). Arsenal ids are APPEARANCE ids since #653 (they were itemIDs
      while the arsenals lived in the armour grid) -> ItemAppearance.ID.
    * Medium tier (glyphinfo/learnedunlocks/collectiblesources) all resolved cleanly — unlike the
      cheap tier's challengetames, SpellName (~404k rows) and QuestV2 keep the old spell/quest ids,
      so glyph->GlyphProperties.ID, spell->SpellName.ID, quest/startQuest->QuestV2.ID all hard-check.

  Usage:
    pwsh Tooling/lint-stale-ids.ps1              # full (pulls Item, the one big table)
    pwsh Tooling/lint-stale-ids.ps1 -SkipBig     # skip big-table rules (fast; races/prof/mount-spell)
    pwsh Tooling/lint-stale-ids.ps1 -Build 12.0.7.68453 -CacheDir .wago-cache
  Exit 0 = every fail-rule id resolves; 1 = one or more stale.

  wago politeness: -CacheDir <dir> reads/writes each table's CSV under <dir> instead of re-pulling,
  and both CI workflows wrap it in an actions/cache keyed on the resolved build -- so wago's heavy
  endpoints are hit ~once per client build, not per run. All requests send an identifying User-Agent.
#>
param(
  [string]$Build,
  [switch]$SkipBig,
  [string]$CacheDir
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent

# arsenals.lua lists each arsenal's appearances in a multi-id `visuals = { N, N, ... }` block, so
# this rule extracts with a scriptblock rather than one regex. The `types` map's keys are a SUBSET
# of `visuals` (asserted in spec/arsenals_spec.lua), so pulling from `visuals` alone covers every
# id without also picking up that map's VALUES, which are weapon-type enums, not appearances.
# (The engine strips Lua comments before calling it, so stray comment digits can't leak in.)
$extractArsenalVisuals = {
  param($text)
  $ids = @()
  foreach ($blk in [regex]::Matches($text, 'visuals\s*=\s*\{([^}]*)\}')) {
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
  # #653 split data/weapons.lua in two, so these two rules replace the old weapons.* pair. Illusion
  # sourceIDs still resolve as TransmogIllusion.SpellItemEnchantmentID (NOT .ID); the arsenals now
  # carry APPEARANCE ids rather than itemIDs, since they became Weapons-grid rows keyed the same way
  # the generated data/weaponsources.lua is — so they check against ItemAppearance.ID.
  @{ file='Warbandeer_Collected/data/illusions.lua';       label='illusions.sourceID';               rx='\[(\d+)\]\s*=\s*\d+';            table='TransmogIllusion'; col='SpellItemEnchantmentID'; sev='fail'; big=$false }
  @{ file='Warbandeer_Collected/data/arsenals.lua';        label='arsenals.visualID';                extract=$extractArsenalVisuals;      table='ItemAppearance';   col='ID';                    sev='fail'; big=$false }
  # Medium tier — the larger catalogs. All mappings probed & confirmed (no trimmed source like
  # challengetames): glyph->GlyphProperties.ID, spell->SpellName.ID, quest/startQuest->QuestV2.ID.
  @{ file='Warbandeer_Characters/data/collectiblesources.lua'; label='collectiblesources.itemID';    rx='\[(\d+)\]\s*=';                    table='Item';            col='ID'; sev='fail'; big=$true  }
  @{ file='Warbandeer_Characters/data/learnedunlocks.lua';     label='learnedunlocks.itemID';         rx='itemID\s*=\s*(\d+)';               table='Item';            col='ID'; sev='fail'; big=$true  }
  @{ file='Warbandeer_Characters/data/learnedunlocks.lua';     label='learnedunlocks.spell';          rx='spell\s*=\s*(\d+)';                table='SpellName';       col='ID'; sev='fail'; big=$true  }
  @{ file='Warbandeer_Characters/data/glyphinfo.lua';          label='glyphinfo.itemID';              rx='(?:itemID|startItem)\s*=\s*(\d+)'; table='Item';            col='ID'; sev='fail'; big=$true  }
  @{ file='Warbandeer_Characters/data/glyphinfo.lua';          label='glyphinfo.glyph';               rx='glyph\s*=\s*(\d+)';                table='GlyphProperties'; col='ID'; sev='fail'; big=$false }
  @{ file='Warbandeer_Characters/data/glyphinfo.lua';          label='glyphinfo.spell';               rx='spell\s*=\s*(\d+)';                table='SpellName';       col='ID'; sev='fail'; big=$true  }
  @{ file='Warbandeer_Characters/data/glyphinfo.lua';          label='glyphinfo.quest';               rx='(?:quest|startQuest)\s*=\s*(\d+)'; table='QuestV2';         col='ID'; sev='fail'; big=$true  }
)

# Identify ourselves so heavy automated traffic to wago.tools is attributable, not anonymous.
$wagoHeaders = @{ 'User-Agent' = 'Warbandeer-suite-ci (github.com/nazumods/wow)' }

# ── resolve build -- skipped entirely when the caller pins -Build (the CI workflows resolve it once
# for the cache key and pass it through, so a cached run makes no /api/builds call either) ──
if (-not $Build) {
  $Build = ((Invoke-WebRequest -Uri 'https://wago.tools/api/builds/wow/latest' -Headers $wagoHeaders -UseBasicParsing).Content | ConvertFrom-Json).version
}
if ($CacheDir -and -not (Test-Path $CacheDir)) { New-Item -ItemType Directory -Path $CacheDir | Out-Null }
Write-Host ("Linting hand-authored ids against wow build $Build{0}`n" -f $(if ($CacheDir) { " (cache $CacheDir)" } else { "" })) -ForegroundColor Cyan

# ── table CSV text: fetched once per run, and when -CacheDir is set, persisted per build on disk
# so a re-run for the same build reads it instead of re-pulling. The CI workflows wrap <CacheDir>
# in a build-keyed actions/cache, so wago's heavy endpoints are hit ~once per client build. ──
$csvCache = @{}
function Get-Csv([string]$table) {
  if ($csvCache.ContainsKey($table)) { return $csvCache[$table] }
  $file = if ($CacheDir) { Join-Path $CacheDir "$table.csv" } else { $null }
  if ($file -and (Test-Path $file)) {
    $text = Get-Content -Raw $file
  } else {
    $text = (Invoke-WebRequest -Uri "https://wago.tools/db2/$table/csv?build=$Build" -Headers $wagoHeaders -UseBasicParsing).Content
    if ($file) { Set-Content -Path $file -Value $text -NoNewline }
  }
  $csvCache[$table] = $text
  return $text
}

# ── id-set per (table,col), built once from the table CSV and cached ──
$setCache = @{}
function Get-IdSet($table, $col, $big) {
  $key = "$table|$col"
  if ($setCache.ContainsKey($key)) { return $setCache[$key] }
  $text = Get-Csv $table
  $set = @{}
  if ($big) {
    # Huge table: ID is column 1, so hash the first field of each raw line (ConvertFrom-Csv is
    # minutes-slow at six-figure rows). Big rules only ever target the first-column ID.
    if ($col -ne 'ID') { throw "big-table rule for $table must key on ID (col 1), got $col" }
    foreach ($line in $text -split "`n") {
      $c = $line.IndexOf(','); if ($c -gt 0) { $id = $line.Substring(0, $c); if ($id -match '^\d+$') { $set[[int]$id] = $true } }
    }
  } else {
    # Small table: ConvertFrom-Csv handles the quoted, comma-bearing *_lang string columns that a
    # naive split would misalign (the id column often sits after several localized name fields).
    $text | ConvertFrom-Csv | ForEach-Object {
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
