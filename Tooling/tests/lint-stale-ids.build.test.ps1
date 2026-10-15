#requires -Version 7
<#
.SYNOPSIS
  Tests how Tooling/lint-stale-ids.ps1 picks the wago build to lint (nazumods/wow#954).

.DESCRIPTION
  Runs the REAL script with Invoke-WebRequest replaced by a function (functions outrank cmdlets, and a
  function defined here is visible to the script it calls) that serves a fixture modelled on wago's
  /api/builds: a shared Classic-beta bucket listing a 5.5 build first, then Forever's 1.60.1 builds in
  the OPPOSITE of wago's real order (every live family is listed newest-first; here the older build comes
  first, so a pick by position cannot pass), with version look-alikes that are newer than them and one
  build whose date is in another format (M/d/yyyy: as text it sorts AFTER the others, as a date it is
  months earlier; ConvertFrom-Json leaves it a string, where it would turn an ISO 'T...Z' date into a
  DateTime). The stub also records each request's User-Agent header, and throws on the first DB2 table
  request, so each run ends right after the "Linting ... build X" line this test reads: nothing else is
  fetched and no cache is written.

  Plain PowerShell, not Pester, so it runs wherever pwsh does; it is a step of the test.yml
  `wago-build-resolution` job. Exit 0 = every case passed; 1 = a case failed.

  pwsh Tooling/tests/lint-stale-ids.build.test.ps1
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$lint = Join-Path $PSScriptRoot '..' 'lint-stale-ids.ps1'
if (-not (Test-Path $lint)) { Write-Output "FAIL: $lint does not exist"; exit 1 }

$script:Failures = 0
$global:Wago954Requested = [System.Collections.Generic.List[string]]::new()
$global:Wago954Agents = [System.Collections.Generic.List[string]]::new()

# The User-Agent every wago request must send (README: "all wago requests send an identifying User-Agent").
$userAgent = 'Warbandeer-suite-ci (github.com/nazumods/wow)'

$builds = [ordered]@{
  wow_classic_beta = @(
    @{ product = 'wow_classic_beta'; version = '5.5.0.62071';  created_at = '2025-07-18 01:19:04' }
    @{ product = 'wow_classic_beta'; version = '1.60.1.70338'; created_at = '2026-10-10 05:05:05' }
    @{ product = 'wow_classic_beta'; version = '1.60.1.70374'; created_at = '2026-10-13 23:25:05' }
    @{ product = 'wow_classic_beta'; version = '1.60.1.70399'; created_at = '3/1/2026 00:00:00' }
    @{ product = 'wow_classic_beta'; version = '11.60.0.9999'; created_at = '2026-10-14 00:00:00' }
    @{ product = 'wow_classic_beta'; version = '1.600.0.1';    created_at = '2026-10-14 01:00:00' }
    @{ product = 'wow_classic_beta'; version = '3.4.0.50000';  created_at = '2024-01-01 00:00:00' }
  )
  wow = @(
    @{ product = 'wow'; version = '12.1.5.70391'; created_at = '2026-10-13 21:16:02' }
  )
}
$global:Wago954BuildsJson = $builds | ConvertTo-Json -Depth 5

# The stand-in for the real cmdlet: answers the two builds endpoints, stops at the first DB2 table.
function Invoke-WebRequest {
  param([string]$Uri, $Headers, [switch]$UseBasicParsing)
  $global:Wago954Requested.Add($Uri)
  $global:Wago954Agents.Add($(if ($Headers -is [hashtable] -and $Headers.ContainsKey('User-Agent')) { [string]$Headers['User-Agent'] } else { '' }))
  if ($Uri -eq 'https://wago.tools/api/builds') { return [pscustomobject]@{ Content = $global:Wago954BuildsJson } }
  if ($Uri -match '^https://wago\.tools/api/builds/[^/]+/latest$') { return [pscustomobject]@{ Content = '{"version":"9.9.9.1"}' } }
  throw "STOP-954: $Uri"
}

# Runs the script with the parameters in $LintArgs (a hashtable, splatted) -> @{ Product; Build; Error;
# Requested; First; Agent }. The header is the first line the script writes; the run is expected to end in the
# stub's STOP (or an earlier throw).
function Invoke-Lint([hashtable]$LintArgs) {
  $global:Wago954Requested.Clear()
  $global:Wago954Agents.Clear()
  $lines = [System.Collections.Generic.List[string]]::new()
  $err = ''
  try {
    # Strict mode is inherited by child scopes, and the script under test is not written for it.
    & { Set-StrictMode -Off; & $lint @LintArgs } *>&1 | ForEach-Object { $null = $lines.Add([string]$_) }
  } catch {
    $err = $_.Exception.Message
  }
  $result = @{ Product = ''; Build = ''; Error = $err; Requested = @($global:Wago954Requested); First = ''; Agent = '' }
  if ($global:Wago954Requested.Count -gt 0) { $result.First = $global:Wago954Requested[0]; $result.Agent = $global:Wago954Agents[0] }
  $header = @($lines | Where-Object { $_ -match 'Linting hand-authored ids against (\S+) build (\S+)' })
  if ($header.Count -gt 0 -and $header[0] -match 'against (\S+) build (\S+)') {
    $result.Product = $Matches[1]
    $result.Build = $Matches[2]
  }
  $result
}

function Test-Case([string]$Name, $Expected, $Actual) {
  if ("$Actual" -eq "$Expected") {
    Write-Output "PASS $Name"
  } else {
    Write-Output "FAIL ${Name}: expected '$Expected', got '$Actual'"
    $script:Failures++
  }
}

function Test-Contains([string]$Name, [string]$Haystack, [string]$Needle) {
  if ($Haystack.Contains($Needle)) {
    Write-Output "PASS $Name"
  } else {
    Write-Output "FAIL ${Name}: '$Needle' not in '$Haystack'"
    $script:Failures++
  }
}

$r = Invoke-Lint @{ Product = 'wow_classic_beta'; VersionPrefix = '1.60.' }
Test-Case 'prefix 1.60.: Forever family, newest by date (not first listed, not a look-alike)' '1.60.1.70374' $r.Build
Test-Case 'prefix 1.60.: header names the product' 'wow_classic_beta' $r.Product
Test-Case 'prefix 1.60.: reads the full builds list' 'https://wago.tools/api/builds' $r.First
Test-Case 'prefix 1.60.: makes no /latest request' '0' @($r.Requested | Where-Object { $_ -like '*/latest' }).Count
Test-Case 'prefix 1.60.: the builds request identifies itself' $userAgent $r.Agent

$r = Invoke-Lint @{ Product = 'wow_classic_beta'; VersionPrefix = '5.5.' }
Test-Case 'prefix 5.5.: another family' '5.5.0.62071' $r.Build

$r = Invoke-Lint @{ Product = 'wow_classic_beta'; VersionPrefix = '7.' }
Test-Case 'prefix 7.: nothing to resolve' '' $r.Build
Test-Contains 'prefix 7.: says no build starts with it' $r.Error "starts with '7.'"

$r = Invoke-Lint @{ Product = 'nonesuch'; VersionPrefix = '1.' }
Test-Case 'unknown product with a prefix: nothing to resolve' '' $r.Build
Test-Contains 'unknown product with a prefix: says it has no builds' $r.Error "no builds for product 'nonesuch'"

$r = Invoke-Lint @{ Product = 'wow_classic_beta' }
Test-Case 'bare product: takes that product''s latest' '9.9.9.1' $r.Build
Test-Case 'bare product: asks /api/builds/<product>/latest' 'https://wago.tools/api/builds/wow_classic_beta/latest' $r.First
Test-Case 'bare product: the latest request identifies itself' $userAgent $r.Agent

$r = Invoke-Lint @{}
Test-Case 'default: the live retail product' 'wow' $r.Product
Test-Case 'default: asks /api/builds/wow/latest' 'https://wago.tools/api/builds/wow/latest' $r.First

$r = Invoke-Lint @{ Product = 'wow_classic_beta'; Build = '1.60.1.70338'; VersionPrefix = '5.5.' }
Test-Case '-Build: pinned outright, wins over -VersionPrefix' '1.60.1.70338' $r.Build
Test-Case '-Build: the product is still named in the header' 'wow_classic_beta' $r.Product
Test-Case '-Build: makes no builds request at all' '' (@($r.Requested | Where-Object { $_ -like '*/api/builds*' }) -join ',')

if ($script:Failures -gt 0) {
  Write-Output "FAILED: $($script:Failures) case(s)"
  exit 1
}
Write-Output 'OK: all cases passed'
