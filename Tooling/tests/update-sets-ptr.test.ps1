#requires -Version 7
<#
.SYNOPSIS
  Tests which wago PTR build Warbandeer_Collected/tools/update-sets.ps1 -PtrDelta reads (nazumods/wow#945).

.DESCRIPTION
  Runs the REAL script, in both delta modes (armor `-PtrDelta` and `-Weapons -PtrDelta`), with
  Invoke-WebRequest replaced by a function (functions outrank cmdlets, and a function defined here is
  visible to the script it calls) that serves a per-case fixture modelled on wago's /api/builds and
  THROWS on any other URL, so every `-Check` run also proves it fetches nothing else. Each case writes
  a temp -PtrFile / -WeaponsPtrFile (the real data/ files are never touched) and reads the output and
  the exit code the daily watchers act on (0 = nothing to do, 2 = regenerate, 3 = regenerate + curate).

  The PTR source is the newest patch above live across wago's two PTR products, wowt and wowxptr (the
  12.1.5 PTR lived on wowxptr while wowt stopped at 12.1.0); an explicit -PtrBuild wins. Generation
  (which needs real CSVs) is not exercised here -- only the build resolution and the -Check verdicts.

  Plain PowerShell, not Pester, so it runs wherever pwsh does; it is a step of the test.yml
  `wago-build-resolution` job. Exit 0 = every case passed; 1 = a case failed.

  pwsh Tooling/tests/update-sets-ptr.test.ps1
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# The script under test; UPDATE_SETS_SCRIPT points the mutation checks at a scratch copy.
$script:Target = if ($env:UPDATE_SETS_SCRIPT) { $env:UPDATE_SETS_SCRIPT } else { Join-Path $PSScriptRoot '..' '..' 'Warbandeer_Collected' 'tools' 'update-sets.ps1' }
if (-not (Test-Path $script:Target)) { Write-Output "FAIL: $($script:Target) does not exist"; exit 1 }

$script:Failures = 0
$global:Wago945Json = '{}'
$global:Wago945Requested = [System.Collections.Generic.List[string]]::new()
$global:Wago945Agents = [System.Collections.Generic.List[string]]::new()
$userAgent = 'Warbandeer-suite-ci (github.com/nazumods/wow)'

# The stand-in for the real cmdlet: answers /api/builds from the current case's fixture, throws on anything else.
function Invoke-WebRequest {
  [CmdletBinding()]
  param([string]$Uri, [string]$UserAgent, [switch]$UseBasicParsing)
  $global:Wago945Requested.Add($Uri)
  $global:Wago945Agents.Add($UserAgent)
  if ($Uri -eq 'https://wago.tools/api/builds') { return [pscustomobject]@{ Content = $global:Wago945Json } }
  throw "STOP-945: unexpected request $Uri"
}

function New-Build([string]$Product, [string]$Version, [string]$Created) {
  @{ product = $Product; version = $Version; created_at = $Created }
}

# Fixture -> the JSON the stub serves. Each product's list is given in the order it should appear in the
# response (the real response is newest first; a case that wants to defeat a pick by position lists oldest first).
function Set-Fixture($Wow, $Wowt, $Wowxptr) {
  $f = [ordered]@{ wow = @($Wow) }
  if ($null -ne $Wowt) { $f.wowt = @($Wowt) }
  if ($null -ne $Wowxptr) { $f.wowxptr = @($Wowxptr) }
  $global:Wago945Json = $f | ConvertTo-Json -Depth 5
}

# A fixture given as raw JSON text: shapes the typed setter would normalise (a product that is a single
# object rather than an array, a null created_at, a malformed version).
function Set-RawFixture([string]$Json) { $global:Wago945Json = $Json }

# Runs the script in `-Check` mode for one delta mode -> @{ Exit; Out; Requested; Agent }.
# $Mode is 'armor' or 'weapons'; $Rows writes a `tinsert(` row line into the preview file; $Stamp is the
# ptr build stamped in it ($null = no file at all).
function Invoke-Check([string]$Mode, [hashtable]$ScriptArgs, [string]$Stamp, [bool]$Rows) {
  $tmp = Join-Path ([System.IO.Path]::GetTempPath()) "update-sets-ptr-945-$([guid]::NewGuid().ToString('N')).lua"
  try {
    if ($Stamp) {
      $stampLine = if ($Mode -eq 'armor') { "ns.PtrBuild = { live = ""$Stamp"", ptr = ""$Stamp"" }" } else { "ns.WeaponPtrBuild = { live = ""$Stamp"", ptr = ""$Stamp"" }" }
      $tableVar = if ($Mode -eq 'armor') { 'ns.PtrSets' } else { 'ns.WeaponPtrSources' }
      $text = "$stampLine`n"
      if ($Rows) { $text += "tinsert($tableVar, {`n  id = 1,`n})`n" }
      [System.IO.File]::WriteAllText($tmp, $text)
    }
    $global:Wago945Requested.Clear()
    $global:Wago945Agents.Clear()
    # A hashtable, splatted: an array would splat positionally and bind the switch names as values.
    $a = if ($Mode -eq 'armor') { @{ PtrDelta = $true; Check = $true; PtrFile = $tmp } } else { @{ Weapons = $true; PtrDelta = $true; Check = $true; WeaponsPtrFile = $tmp } }
    foreach ($k in $ScriptArgs.Keys) { $a[$k] = $ScriptArgs[$k] }
    $lines = [System.Collections.Generic.List[string]]::new()
    $global:LASTEXITCODE = $null
    $code = $null
    try {
      # Strict mode is inherited by child scopes, and the script under test is not written for it.
      & { Set-StrictMode -Off; & $script:Target @a } *>&1 | ForEach-Object { $null = $lines.Add([string]$_) }
      $code = $LASTEXITCODE
    } catch {
      $code = 'throw'
      $lines.Add("THROW: $($_.Exception.Message)")
    }
    @{
      Exit = $code; Out = ($lines -join "`n"); Requested = @($global:Wago945Requested)
      Agent = $(if ($global:Wago945Agents.Count) { $global:Wago945Agents[0] } else { '' })
    }
  } finally {
    Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
  }
}

function Test-Case([string]$Name, $Expected, $Actual) {
  if ("$Actual" -eq "$Expected") { Write-Output "PASS $Name" }
  else { Write-Output "FAIL ${Name}: expected '$Expected', got '$Actual'"; $script:Failures++ }
}
function Test-Contains([string]$Name, [string]$Haystack, [string]$Needle) {
  if ($Haystack.Contains($Needle)) { Write-Output "PASS $Name" }
  else { Write-Output "FAIL ${Name}: '$Needle' not in '$Haystack'"; $script:Failures++ }
}
function Test-Lacks([string]$Name, [string]$Haystack, [string]$Needle) {
  if (-not $Haystack.Contains($Needle)) { Write-Output "PASS $Name" }
  else { Write-Output "FAIL ${Name}: '$Needle' unexpectedly in '$Haystack'"; $script:Failures++ }
}

$liveNow = New-Build 'wow' '12.1.5.70391' '2026-10-13 21:16:02'
$stampOld = '12.1.0.69299'

foreach ($mode in 'armor', 'weapons') {
  # explicit-wowxptr: -PtrBuild is found under wowxptr; the file is stamped with the old patch.
  Set-Fixture @($liveNow) @(New-Build 'wowt' '12.1.0.69587' '2026-09-01 10:00:00') @(New-Build 'wowxptr' '12.1.5.70340' '2026-10-12 08:00:00')
  $r = Invoke-Check $mode @{ LiveBuild = '12.1.0.69933'; PtrBuild = '12.1.5.70340' } $stampOld $false
  Test-Case "$mode explicit-wowxptr: exit" 2 $r.Exit
  Test-Contains "$mode explicit-wowxptr: names wowxptr" $r.Out '[wowxptr]'
  Test-Contains "$mode explicit-wowxptr: new patch" $r.Out 'NEW PTR PATCH: 12.1.0 -> 12.1.5'
  Test-Case "$mode explicit-wowxptr: only /api/builds was fetched" 'https://wago.tools/api/builds' (@($r.Requested | Select-Object -Unique) -join ',')
  Test-Case "$mode explicit-wowxptr: the request identifies itself" $userAgent $r.Agent

  # default-picks-wowxptr: no -PtrBuild; wowt is stuck at 12.1.0, wowxptr carries 12.1.5.
  $r = Invoke-Check $mode @{ LiveBuild = '12.1.0.69933' } $stampOld $false
  Test-Case "$mode default-picks-wowxptr: exit" 2 $r.Exit
  Test-Contains "$mode default-picks-wowxptr: resolves the wowxptr head" $r.Out 'PTR 12.1.5.70340 [wowxptr]'

  # today-nothing-ahead: live 12.1.5.70391 is past both heads; the preview is already empty.
  $r = Invoke-Check $mode @{} $stampOld $false
  Test-Case "$mode today-nothing-ahead: exit" 0 $r.Exit
  Test-Contains "$mode today-nothing-ahead: says no stream is ahead" $r.Out 'No PTR stream is ahead of live'
  Test-Contains "$mode today-nothing-ahead: the verdict line names live and both heads" $r.Out '(live 12.1.5.70391; wowt 12.1.0.69587, wowxptr 12.1.5.70340) -- the preview is empty, nothing to do.'
  Test-Lacks "$mode today-nothing-ahead: never says still patch" $r.Out 'still patch'

  # no-file: nothing ahead but no preview file at all -> regenerate (the missing check comes first).
  $r = Invoke-Check $mode @{} $null $false
  Test-Case "$mode no-file: exit" 2 $r.Exit
  Test-Contains "$mode no-file: does not call the live build the latest PTR" $r.Out 'regenerate (no PTR stream is ahead of live)'

  # rows-no-stream: nothing ahead but the committed preview still lists rows of a patch that is now live.
  $r = Invoke-Check $mode @{} $stampOld $true
  Test-Case "$mode rows-no-stream: exit (armor 3 = regenerate + curate, weapons 2)" $(if ($mode -eq 'armor') { 3 } else { 2 }) $r.Exit
  Test-Contains "$mode rows-no-stream: LIVE CAUGHT UP" $r.Out 'LIVE CAUGHT UP'
  Test-Lacks "$mode rows-no-stream: never says still patch" $r.Out 'still patch'

  # rows-no-stream-stamp-ahead: the stamped patch is NOT yet live (e.g. a PTR stream that has vanished):
  # armor regenerates without the curate reminder (2); weapons 2 as always.
  $r = Invoke-Check $mode @{} '12.9.0.1' $true
  Test-Case "$mode rows-no-stream-stamp-ahead: exit" 2 $r.Exit
  Test-Contains "$mode rows-no-stream-stamp-ahead: says the preview is stale, not caught up" $r.Out 'STALE PREVIEW'
  Test-Lacks "$mode rows-no-stream-stamp-ahead: not LIVE CAUGHT UP" $r.Out 'LIVE CAUGHT UP'

  # wowt-ahead: wowt carries the newer patch; wowxptr is behind live.
  Set-Fixture @($liveNow) @(New-Build 'wowt' '12.2.0.71000' '2026-10-14 08:00:00') @(New-Build 'wowxptr' '12.1.5.70340' '2026-10-12 08:00:00')
  $r = Invoke-Check $mode @{} $stampOld $false
  Test-Case "$mode wowt-ahead: exit" 2 $r.Exit
  Test-Contains "$mode wowt-ahead: resolves wowt" $r.Out 'PTR 12.2.0.71000 [wowt]'

  # higher-patch-wins: both ahead; the higher patch wins whatever the dates say.
  Set-Fixture @($liveNow) @(New-Build 'wowt' '12.2.0.71000' '2026-10-14 08:00:00') @(New-Build 'wowxptr' '12.2.5.70000' '2026-10-01 08:00:00')
  $r = Invoke-Check $mode @{} $stampOld $false
  Test-Contains "$mode higher-patch-wins: wowxptr's 12.2.5 beats wowt's newer 12.2.0" $r.Out 'PTR 12.2.5.70000 [wowxptr]'

  # tie-newer-date: the same patch on both products -> the newer created_at, in either direction.
  Set-Fixture @($liveNow) @(New-Build 'wowt' '12.2.0.71000' '2026-10-14 08:00:00') @(New-Build 'wowxptr' '12.2.0.70900' '2026-10-10 08:00:00')
  $r = Invoke-Check $mode @{} $stampOld $false
  Test-Contains "$mode tie-newer-date: wowt newer" $r.Out 'PTR 12.2.0.71000 [wowt]'
  Set-Fixture @($liveNow) @(New-Build 'wowt' '12.2.0.70800' '2026-10-02 08:00:00') @(New-Build 'wowxptr' '12.2.0.70900' '2026-10-10 08:00:00')
  $r = Invoke-Check $mode @{} $stampOld $false
  Test-Contains "$mode tie-newer-date: wowxptr newer" $r.Out 'PTR 12.2.0.70900 [wowxptr]'

  # head-by-date: a product's list with the OLDER build first still resolves the newest by date.
  Set-Fixture @($liveNow) $null @((New-Build 'wowxptr' '12.2.0.70000' '2026-10-01 08:00:00'), (New-Build 'wowxptr' '12.2.0.70340' '2026-10-12 08:00:00'))
  $r = Invoke-Check $mode @{} $stampOld $false
  Test-Contains "$mode head-by-date: newest by created_at, not the first listed" $r.Out 'PTR 12.2.0.70340 [wowxptr]'

  # numeric-patch: 12.1.10 is above 12.1.9 (a text compare would say not).
  Set-Fixture @((New-Build 'wow' '12.1.9.60000' '2026-08-01 08:00:00')) @(New-Build 'wowt' '12.1.10.61000' '2026-09-01 08:00:00') $null
  $r = Invoke-Check $mode @{} $stampOld $false
  Test-Contains "$mode numeric-patch: 12.1.10 is ahead of live 12.1.9" $r.Out 'PTR 12.1.10.61000 [wowt]'

  # unlisted-explicit: an explicit build listed nowhere is used as given, product 'unlisted', no throw.
  Set-Fixture @($liveNow) @(New-Build 'wowt' '12.1.0.69587' '2026-09-01 10:00:00') @(New-Build 'wowxptr' '12.1.5.70340' '2026-10-12 08:00:00')
  $r = Invoke-Check $mode @{ PtrBuild = '12.9.9.1' } $stampOld $false
  Test-Case "$mode unlisted-explicit: exit" 2 $r.Exit
  Test-Contains "$mode unlisted-explicit: product unlisted" $r.Out 'PTR 12.9.9.1 [unlisted]'
  Test-Contains "$mode unlisted-explicit: used as given" $r.Out 'NEW PTR PATCH: 12.1.0 -> 12.9.9'

  # no-products: neither PTR product listed (a wago hiccup) -> the run FAILS, never "nothing ahead".
  Set-Fixture @($liveNow) $null $null
  $r = Invoke-Check $mode @{} $stampOld $true
  Test-Case "$mode no-products: the run throws (a watcher sees a failure, not an empty preview)" 'throw' $r.Exit
  Test-Contains "$mode no-products: says no builds are listed" $r.Out 'lists no builds for wowt or wowxptr'

  # malformed-version: a head with a non-numeric component never throws and is never ahead.
  Set-RawFixture '{"wow":[{"product":"wow","version":"12.1.5.70391","created_at":"2026-10-13 21:16:02"}],"wowt":[{"product":"wowt","version":"12.x.0.1","created_at":"2026-10-14 08:00:00"}],"wowxptr":[{"product":"wowxptr","version":"12.2.0.71000","created_at":"2026-10-14 08:00:00"}]}'
  $r = Invoke-Check $mode @{} $stampOld $false
  Test-Case "$mode malformed-version: exit" 2 $r.Exit
  Test-Contains "$mode malformed-version: the other product still resolves" $r.Out 'PTR 12.2.0.71000 [wowxptr]'

  # single-object-product + null created_at: wago shapes ConvertTo-Json would hide.
  Set-RawFixture '{"wow":[{"product":"wow","version":"12.1.5.70391","created_at":"2026-10-13 21:16:02"}],"wowt":{"product":"wowt","version":"12.2.0.71000","created_at":null},"wowxptr":[{"product":"wowxptr","version":"12.2.0.70900","created_at":"2026-10-10T08:00:00Z"}]}'
  $r = Invoke-Check $mode @{} $stampOld $false
  Test-Case "$mode odd-shapes: exit" 2 $r.Exit
  Test-Contains "$mode odd-shapes: a null created_at loses a tie, an ISO date parses" $r.Out 'PTR 12.2.0.70900 [wowxptr]'

  # one-product: wowxptr absent from wago's list entirely -> wowt alone decides.
  Set-Fixture @($liveNow) @(New-Build 'wowt' '12.2.0.71000' '2026-10-14 08:00:00') $null
  $r = Invoke-Check $mode @{} $stampOld $false
  Test-Contains "$mode one-product: a missing product is skipped" $r.Out 'PTR 12.2.0.71000 [wowt]'

  # same-patch: a stream on the stamped patch is up to date (the existing within-patch behaviour).
  Set-Fixture @((New-Build 'wow' '12.1.0.69000' '2026-08-01 08:00:00')) @(New-Build 'wowt' '12.2.0.71000' '2026-10-14 08:00:00') $null
  $r = Invoke-Check $mode @{} '12.2.0.70000' $false
  Test-Case "$mode same-patch: exit" 0 $r.Exit
  Test-Contains "$mode same-patch: up to date" $r.Out 'PTR up to date: still patch 12.2.0'
}

# D5: both generators name the source product in the `-- Generated from wago.tools ...` header (generation
# needs real CSVs, so this reads the script text: the header template for each mode carries [$ptrProduct]).
$scriptText = [System.IO.File]::ReadAllText($script:Target)
foreach ($hdr in 'TransmogSet PTR delta', 'weapon PTR delta') {
  $line = @($scriptText -split "`n" | Where-Object { $_ -match "Generated from wago\.tools $hdr" })
  Test-Case "header template ($hdr): one line" 1 $line.Count
  if ($line.Count -eq 1) { Test-Contains "header template ($hdr): names the product" $line[0] '[$ptrProduct]' }
}

if ($script:Failures -gt 0) {
  Write-Output "FAILED: $($script:Failures) case(s)"
  exit 1
}
Write-Output 'OK: all cases passed'
exit 0
