<#
.SYNOPSIS
  Regenerate apps/warbandeer-desktop/src-tauri/data/static-data.json — the suite's
  offline currency lookup — from live wago.tools DB2 data.

.DESCRIPTION
  The desktop app ships as a single portable exe and never talks to the network, so
  anything it needs to render beyond raw SavedVariables has to be baked in at build
  time. This generator produces that bundle.

  Scope is deliberately ONE table: CurrencyTypes. Currency name/icon/quality has no
  Blizzard REST equivalent — the Game Data API has no currency endpoint at all — so
  it is wago-only regardless of whether the app ever gains API credentials. Tables
  that REST *can* serve (achievements, titles, reputations, mounts, spells) are left
  out on purpose; adding one later means extending the fetch below, not reworking this file.
  See UPDATING-static-data.md in this folder.

  Two wago endpoints drive it:
    * /db2/<table>/csv?build=<b> — the table itself, pinned to a real product build
      (the bare /csv endpoint serves the newest build across ALL products, including
      the PTR, so the build is always pinned explicitly).
    * /api/files?search=interface/icons/ — the listfile slice mapping FileDataID ->
      path. CurrencyTypes stores InventoryIconFileID, and a bare FileDataID is not
      renderable outside the client; the icon NAME is. There is no per-FileDataID
      lookup (?search= matches on path), so the whole icons map is fetched once and
      cached — see -CacheDir.

  The output carries NO generation timestamp, only the build it came from. A rerun
  against an unchanged build must produce a byte-identical file, or the scheduled
  refresh would open a PR every week with an empty diff.

.PARAMETER OutFile   Bundle path. Defaults to ../src-tauri/data/static-data.json.
.PARAMETER Product   wago product. 'wow' = live retail.
.PARAMETER Build     Optional client build (e.g. 12.0.7.68453). Omit for latest.
.PARAMETER CacheDir  Reuse downloaded responses instead of refetching (wago politeness).
.PARAMETER Check     Don't write; exit 1 if the bundle would change (CI staleness gate).

.EXAMPLE
  pwsh ./update-static-data.ps1
.EXAMPLE
  pwsh ./update-static-data.ps1 -Check
#>
[CmdletBinding()]
param(
  # The bundle lives with its embedding consumer, not with this script: the desktop app
  # compiles it in via include_str!, so it must sit under apps/warbandeer-desktop. The
  # generator lives here because it serves more than that one app (wow-companion consumes
  # the published release) and because anything under apps/warbandeer-desktop/ triggers
  # app-release.yml — a generator edit must not cut a desktop release.
  [string]$OutFile = (Join-Path $PSScriptRoot '..' 'apps' 'warbandeer-desktop' 'src-tauri' 'data' 'static-data.json'),
  [string]$Product = 'wow',
  [string]$Build,
  [string]$CacheDir,
  [int]$MinRows = 1200,     # abort if CurrencyTypes returns fewer (incomplete download)
  [int]$MinIcons = 20000,   # abort if the icons listfile looks truncated
  [int]$MaxDeletePct = 5,   # abort if regeneration would drop more than this % of currencies
  [int]$MaxUnresolvedPct = 5, # abort if this % of REAL icon ids miss the listfile (see below)
  [switch]$Check
)

$ErrorActionPreference = 'Stop'
# Identify ourselves to wago.tools on every request (same UA as the Collected generator
# and Tooling/lint-stale-ids.ps1), so the suite's automated traffic is attributable.
$PSDefaultParameterValues['Invoke-WebRequest:UserAgent'] = 'Warbandeer-suite-ci (github.com/nazumods/wow)'

# Columns this generator reads. A DB2 rename must abort loudly rather than silently
# emitting a bundle full of nulls — the whole point of pinning a schema assertion.
$RequiredColumns = @('ID', 'Name_lang', 'InventoryIconFileID', 'MaxQty', 'Quality')

function Get-Cached([string]$key, [string]$url, [int]$timeoutSec) {
  if ($CacheDir) {
    $null = New-Item -ItemType Directory -Force -Path $CacheDir
    $path = Join-Path $CacheDir "$key.cache"
    if (Test-Path $path) {
      Write-Host "Cached  $key" -ForegroundColor DarkGray
      return (Get-Content -LiteralPath $path -Raw)
    }
  }
  Write-Host "Fetching $url" -ForegroundColor Cyan
  $content = (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec $timeoutSec -ErrorAction Stop).Content
  if ($CacheDir) { [System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false)) }
  return $content
}

# --- 1. Resolve the build to pull ------------------------------------------
$all = (Get-Cached 'builds' 'https://wago.tools/api/builds' 60) | ConvertFrom-Json
$list = $all.$Product
if (-not $list) { throw "wago.tools has no builds for product '$Product'." }
if (-not $Build) { $Build = $list[0].version }
$match = $list | Where-Object { $_.version -eq $Build } | Select-Object -First 1
if (-not $match) { throw "wago.tools has no build '$Build' for product '$Product'." }
$buildDate = ($match.created_at -split ' ')[0]
Write-Host "Using $Product build $Build $buildDate" -ForegroundColor Cyan

# --- 2. CurrencyTypes ------------------------------------------------------
$rows = (Get-Cached "CurrencyTypes-$Build" "https://wago.tools/db2/CurrencyTypes/csv?build=$Build" 120) | ConvertFrom-Csv
if (-not $rows) { throw 'No rows returned from wago.tools (CurrencyTypes).' }
foreach ($col in $RequiredColumns) {
  if ($col -notin $rows[0].PSObject.Properties.Name) {
    throw "CurrencyTypes CSV is missing the '$col' column — DB2 schema changed, aborting."
  }
}
if ($rows.Count -lt $MinRows) {
  throw "CurrencyTypes returned only $($rows.Count) rows (< MinRows $MinRows) — likely an incomplete download, aborting."
}

# --- 3. FileDataID -> icon name -------------------------------------------
# One bulk fetch (~2 MB); there is no per-id endpoint. Names are stored bare
# ('inv_misc_coin_01') — the identity WoW itself uses — not the full blp path.
$icons = (Get-Cached 'icons' 'https://wago.tools/api/files?search=interface/icons/' 300) | ConvertFrom-Json -AsHashtable
if (-not $icons -or $icons.Count -lt $MinIcons) {
  throw "The icons listfile returned only $($icons.Count) entries (< MinIcons $MinIcons) — incomplete download, aborting."
}

function Resolve-IconName([string]$fileDataId) {
  $path = $icons[$fileDataId]
  if (-not $path) { return $null }
  return [System.IO.Path]::GetFileNameWithoutExtension($path)
}

# --- 4. Build the bundle ---------------------------------------------------
# Sorted by numeric id so the emitted JSON is stable across runs.
$currencies = [ordered]@{}
# Two very different reasons an icon comes out null, tracked apart on purpose:
#   noIconData — InventoryIconFileID is 0, i.e. DB2 has no icon for this currency.
#                Expected and benign; the majority of rows (mostly internal/retired
#                currencies) are like this.
#   unresolved — a REAL FileDataID that the listfile slice didn't cover. A handful is
#                normal (brand-new assets whose names aren't in the community listfile
#                yet), but a spike means the icons fetch is wrong — hence the guard.
$noIconData = 0
$unresolved = 0
foreach ($r in ($rows | Sort-Object { [int]$_.ID })) {
  $id = 0
  if (-not [int]::TryParse($r.ID, [ref]$id) -or $id -le 0) { continue }
  $name = $r.Name_lang.Trim()
  # Unnamed rows are internal placeholders — nothing to look up, so nothing to ship.
  if (-not $name) { continue }

  $fdid = 0; [void][int]::TryParse($r.InventoryIconFileID, [ref]$fdid)
  $icon = if ($fdid -gt 0) { Resolve-IconName $r.InventoryIconFileID } else { $null }
  if ($fdid -le 0) { $noIconData++ } elseif (-not $icon) { $unresolved++ }

  $maxQty = 0; [void][int]::TryParse($r.MaxQty, [ref]$maxQty)
  $quality = 0; [void][int]::TryParse($r.Quality, [ref]$quality)

  $currencies["$id"] = [ordered]@{
    name    = $name
    icon    = $icon
    maxQty  = $maxQty
    quality = $quality
  }
}
if ($currencies.Count -eq 0) { throw 'No named currencies resolved — aborting rather than writing an empty bundle.' }

# Guard the icon join specifically: rows that DO carry a FileDataID should almost all
# resolve. If they stop resolving, the listfile fetch changed shape and every icon in
# the bundle is about to go null — catch that here rather than in the app.
$withIcon = $currencies.Count - $noIconData
if ($withIcon -gt 0) {
  $unresolvedPct = [math]::Round(($unresolved / $withIcon) * 100, 2)
  if ($unresolvedPct -gt $MaxUnresolvedPct) {
    throw "$unresolvedPct% of currency icon ids missed the listfile ($unresolved/$withIcon, max $MaxUnresolvedPct%) — the icons fetch looks wrong, aborting."
  }
}

# Deletion guard: a schema shift or a bad build can silently gut the table. Compare
# against what we already ship and refuse a large drop.
if (Test-Path -LiteralPath $OutFile) {
  $prev = (Get-Content -LiteralPath $OutFile -Raw) | ConvertFrom-Json
  $prevCount = @($prev.currencies.PSObject.Properties).Count
  if ($prevCount -gt 0) {
    $dropPct = [math]::Round((($prevCount - $currencies.Count) / $prevCount) * 100, 2)
    if ($dropPct -gt $MaxDeletePct) {
      throw "Regeneration would drop $dropPct% of currencies ($prevCount -> $($currencies.Count), max $MaxDeletePct%) — aborting."
    }
  }
}

# No generatedAt: the bundle must be byte-identical for an unchanged build so the
# scheduled refresh only opens a PR when the DATA moved.
$bundle = [ordered]@{
  source     = 'wago.tools'
  generator  = 'Tooling/update-static-data.ps1'
  product    = $Product
  build      = $Build
  buildDate  = $buildDate
  currencies = $currencies
}

# ConvertTo-Json emits CRLF on Windows and LF on Linux. The scheduled refresh runs on
# ubuntu while regeneration is usually done on Windows, so without normalising, every
# CI run would "change" the whole file. Force LF and compare LF-normalised.
$json = (($bundle | ConvertTo-Json -Depth 6) -replace "`r`n", "`n") + "`n"
$existing = if (Test-Path -LiteralPath $OutFile) { (Get-Content -LiteralPath $OutFile -Raw) -replace "`r`n", "`n" } else { $null }

Write-Host "$($currencies.Count) currencies — $noIconData carry no icon in DB2, $unresolved icon ids missed the listfile." -ForegroundColor Cyan

if ($Check) {
  if ($json -ne $existing) {
    Write-Host 'static-data.json is STALE — rerun without -Check to regenerate.' -ForegroundColor Yellow
    exit 1
  }
  Write-Host 'static-data.json is current.' -ForegroundColor Green
  exit 0
}

if ($json -eq $existing) {
  Write-Host 'No changes — static-data.json already current.' -ForegroundColor Green
  exit 0
}

$null = New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile)
[System.IO.File]::WriteAllText($OutFile, $json, [System.Text.UTF8Encoding]::new($false))
Write-Host "Wrote $OutFile" -ForegroundColor Green
