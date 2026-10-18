#requires -Version 7
<#
.SYNOPSIS
  Tests what Tooling/lint-stale-ids.ps1 does when a build has no DB2 table for a rule (nazumods/wow#954).

.DESCRIPTION
  Runs the REAL script with Invoke-WebRequest replaced by a function (functions outrank cmdlets, and a
  function defined here is visible to the script it calls). The stand-in serves every DB2 table as one CSV
  that holds every number found in every data file the script lints (the files are read from the script's
  own `file='...'` rules), under every column the rules key on, so with all tables present every rule
  resolves and the run exits 0. Tables named in a case answer the way wago answers for a table the build
  lacks: an HttpResponseException with status 400 and the body {"errors": "Table not found."}, the shape
  observed for TransmogIllusion on Forever's 1.60.1.70338. Other named tables answer with a different
  failure (a 500, or a 400 with another body), which must still stop the run.

  Plain PowerShell, not Pester, so it runs wherever pwsh does; it is a step of the test.yml
  `wago-build-resolution` job. Exit 0 = every case passed; 1 = a case failed.

  pwsh Tooling/tests/lint-stale-ids.missing-table.test.ps1
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$lint = Join-Path $PSScriptRoot '..' 'lint-stale-ids.ps1'
$repo = Join-Path $PSScriptRoot '..' '..'
if (-not (Test-Path $lint)) { Write-Output "FAIL: $lint does not exist"; exit 1 }

$script:Failures = 0
$build = '1.60.1.70338'

# One CSV for every table: ID first (the big-table rules hash column 1), then every other column a rule
# keys on; each row repeats one number in every column. Numbers are kept to 9 digits so [int] never overflows.
$lintText = Get-Content -Raw $lint
$files = @([regex]::Matches($lintText, "file='([^']+)'") | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
if ($files.Count -lt 5) { Write-Output "FAIL: found only $($files.Count) data files in the script's rules"; exit 1 }
$numbers = @(foreach ($f in $files) {
  [regex]::Matches((Get-Content -Raw (Join-Path $repo $f)), '\d+') | ForEach-Object { $_.Value } | Where-Object { $_.Length -le 9 }
}) | Sort-Object -Unique
$cols = @('ID') + @([regex]::Matches($lintText, "col='([^']+)'") | ForEach-Object { $_.Groups[1].Value } |
  Where-Object { $_ -ne 'ID' } | Sort-Object -Unique)
$csv = [System.Text.StringBuilder]::new()
$null = $csv.Append(($cols -join ',') + "`n")
foreach ($n in $numbers) { $null = $csv.Append((@($n) * $cols.Count -join ',') + "`n") }
$global:Lint954Csv = $csv.ToString()

$global:Lint954Missing = @()
$global:Lint954Broken = @{}
$global:Lint954Requested = [System.Collections.Generic.List[string]]::new()

# The error Invoke-WebRequest raises for an HTTP failure: an HttpResponseException carrying the status, with
# the response body in the error record's ErrorDetails (what wago's 400 looked like on 2026-10-18).
function New-WagoError([int]$Status, [string]$Body) {
  $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]$Status)
  $ex = [Microsoft.PowerShell.Commands.HttpResponseException]::new("Response status code does not indicate success: $Status.", $response)
  $er = [System.Management.Automation.ErrorRecord]::new($ex, 'WebCmdletWebResponseException', [System.Management.Automation.ErrorCategory]::InvalidOperation, $null)
  $er.ErrorDetails = [System.Management.Automation.ErrorDetails]::new($Body)
  $er
}

function Invoke-WebRequest {
  param([string]$Uri, $Headers, [switch]$UseBasicParsing)
  if ($Uri -notmatch '^https://wago\.tools/db2/([^/]+)/csv\?build=') { throw "unexpected request: $Uri" }
  $table = $Matches[1]
  $global:Lint954Requested.Add($table)
  if ($global:Lint954Missing -contains $table) { throw (New-WagoError 400 "{`n  `"errors`": `"Table not found.`"`n}") }
  if ($global:Lint954Broken.ContainsKey($table)) { throw (New-WagoError $global:Lint954Broken[$table].Status $global:Lint954Broken[$table].Body) }
  [pscustomobject]@{ Content = $global:Lint954Csv }
}

# Runs the script against $build with the given tables missing or broken -> @{ Text; Exit; Error }.
function Invoke-Lint([string[]]$Missing = @(), [hashtable]$Broken = @{}, [string]$CacheDir) {
  $global:Lint954Missing = $Missing
  $global:Lint954Broken = $Broken
  $global:Lint954Requested.Clear()
  $lines = [System.Collections.Generic.List[string]]::new()
  $lintArgs = @{ Product = 'wow_classic_beta'; Build = $build }
  if ($CacheDir) { $lintArgs.CacheDir = $CacheDir }
  $err = ''
  $global:LASTEXITCODE = $null
  try {
    # Strict mode is inherited by child scopes, and the script under test is not written for it.
    & { Set-StrictMode -Off; & $lint @lintArgs } *>&1 | ForEach-Object { $null = $lines.Add([string]$_) }
  } catch {
    $err = $_.Exception.Message
  }
  @{ Text = ($lines -join "`n"); Exit = $global:LASTEXITCODE; Error = $err }
}

function Test-Case([string]$Name, $Expected, $Actual) {
  if ("$Actual" -eq "$Expected") { Write-Output "PASS $Name" }
  else { Write-Output "FAIL ${Name}: expected '$Expected', got '$Actual'"; $script:Failures++ }
}
function Test-Match([string]$Name, [string]$Text, [string]$Pattern) {
  if ($Text -match $Pattern) { Write-Output "PASS $Name" }
  else { Write-Output "FAIL ${Name}: /$Pattern/ not found"; $script:Failures++ }
}
function Test-NoMatch([string]$Name, [string]$Text, [string]$Pattern) {
  if ($Text -notmatch $Pattern) { Write-Output "PASS $Name" }
  else { Write-Output "FAIL ${Name}: /$Pattern/ should not appear"; $script:Failures++ }
}

# Baseline: every table present, so every rule resolves (proves the fixture covers every id).
$r = Invoke-Lint
Test-Case 'all tables: exit 0' '0' $r.Exit
Test-Match 'all tables: every fail-rule id resolves' $r.Text 'All fail-severity ids resolve against build 1\.60\.1\.70338'
Test-NoMatch 'all tables: nothing skipped' $r.Text 'skipped'

# The Forever case: TransmogIllusion is missing. That rule is reported and skipped, the next rule still runs.
$r = Invoke-Lint -Missing 'TransmogIllusion'
Test-Case 'missing TransmogIllusion: the run does not abort' '' $r.Error
Test-Match 'missing TransmogIllusion: the rule is reported as skipped' $r.Text 'illusions\.sourceID\s+! skipped: build 1\.60\.1\.70338 has no TransmogIllusion table, so \d+ ids are unchecked'
Test-Match 'missing TransmogIllusion: the next rule still runs' $r.Text 'arsenals\.visualID\s+\+\s+\d+ ids OK'
Test-Match 'missing TransmogIllusion: the last rule still runs' $r.Text 'currency\.id\s+\+\s+\d+ ids OK'
Test-Case 'missing TransmogIllusion: a skipped fail-rule still exits 1' '1' $r.Exit
Test-Match 'missing TransmogIllusion: the summary counts it' $r.Text '1 fail-severity rule\(s\) skipped -- build 1\.60\.1\.70338 has no table for them'
Test-NoMatch 'missing TransmogIllusion: no id is reported stale' $r.Text 'unresolved'

$r = Invoke-Lint -Missing 'TransmogIllusion', 'GlyphProperties'
Test-Match 'two missing tables: both rules are reported' $r.Text 'glyphinfo\.glyph\s+! skipped: build \S+ has no GlyphProperties table'
Test-Match 'two missing tables: the summary counts both' $r.Text '2 fail-severity rule\(s\) skipped'
Test-Case 'two missing tables: exit 1' '1' $r.Exit

# A missing table behind several rules (Item: four fail-rules) is asked for once and skips all four.
$r = Invoke-Lint -Missing 'Item'
Test-Match 'missing Item: the summary counts every rule on it' $r.Text '4 fail-severity rule\(s\) skipped'
Test-Case 'missing Item: wago is asked for it once' '1' @($global:Lint954Requested | Where-Object { $_ -eq 'Item' }).Count

# A warn-rule's missing table is reported but not counted.
$r = Invoke-Lint -Missing 'Mount'
Test-Match 'missing Mount (warn rule): reported as skipped' $r.Text 'classmounts\.spellID\s+~ skipped: build \S+ has no Mount table \(best-effort rule, not counted\)'
Test-Case 'missing Mount (warn rule): exit 0' '0' $r.Exit
Test-NoMatch 'missing Mount (warn rule): no skipped count in the summary' $r.Text 'rule\(s\) skipped'

# Any other failure still stops the run: a 500, and a 400 whose body is not "Table not found."
$r = Invoke-Lint -Broken @{ TransmogIllusion = @{ Status = 500; Body = '<html>Internal Server Error</html>' } }
Test-Match 'a 500: the run stops with the error' $r.Error '500'
Test-NoMatch 'a 500: no later rule runs' $r.Text 'arsenals\.visualID'
Test-NoMatch 'a 500: nothing is reported as skipped' $r.Text 'skipped'

$r = Invoke-Lint -Broken @{ TransmogIllusion = @{ Status = 400; Body = '{"errors": "Invalid build."}' } }
Test-Match 'a 400 with another body: the run stops with the error' $r.Error '400'
Test-NoMatch 'a 400 with another body: no later rule runs' $r.Text 'arsenals\.visualID'

$r = Invoke-Lint -Broken @{ TransmogIllusion = @{ Status = 503; Body = '{"errors": "Table not found."}' } }
Test-Match 'a 503 whose body says Table not found: the run stops with the error' $r.Error '503'
Test-NoMatch 'a 503 whose body says Table not found: no later rule runs' $r.Text 'arsenals\.visualID'

# -CacheDir: a missing table writes no cache file; the tables that exist are cached as before.
$cache = Join-Path ([System.IO.Path]::GetTempPath()) ("lint954-" + [guid]::NewGuid().ToString('N'))
try {
  $r = Invoke-Lint -Missing 'TransmogIllusion' -CacheDir $cache
  Test-Case 'cache: no file for the missing table' 'False' (Test-Path (Join-Path $cache 'TransmogIllusion.csv'))
  Test-Case 'cache: a present table is cached' 'True' (Test-Path (Join-Path $cache 'ChrRaces.csv'))
} finally {
  if (Test-Path $cache) { Remove-Item -Recurse -Force $cache }
}

if ($script:Failures -gt 0) {
  Write-Output "FAILED: $($script:Failures) case(s)"
  exit 1
}
Write-Output 'OK: all cases passed'
