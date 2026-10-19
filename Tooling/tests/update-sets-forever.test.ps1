#requires -Version 7
<#
.SYNOPSIS
  Tests Warbandeer_Collected/tools/update-sets.ps1 -Forever, which generates data/sets_forever.lua
  (Forever's transmog sets) from Forever's own wago build (nazumods/wow#989).

.DESCRIPTION
  Runs the REAL script with Invoke-WebRequest replaced by a function (functions outrank cmdlets, and a
  function defined here is visible to the script it calls) that serves wago's /api/builds and the
  TransmogSet CSV from per-case fixtures (the rows are build 1.60.1.70425's real seven), and THROWS
  on any other URL. Every case writes a temp -ForeverFile (the real data/sets_forever.lua is never
  touched) and reads the file, the output and the exit code.

  The build is the NEWEST BY DATE of wow_classic_beta whose version starts with 1.60. (that product is a
  shared bucket of several Classic betas, so the first listed is another family's); -Build pins one.

  Plain PowerShell, not Pester, so it runs wherever pwsh does; it is a step of the test.yml
  `wago-build-resolution` job. UPDATE_SETS_SCRIPT points the mutation checks at a scratch copy.
  Exit 0 = every case passed; 1 = a case failed.

  pwsh Tooling/tests/update-sets-forever.test.ps1
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Target = if ($env:UPDATE_SETS_SCRIPT) { $env:UPDATE_SETS_SCRIPT } else { Join-Path $PSScriptRoot '..' '..' 'Warbandeer_Collected' 'tools' 'update-sets.ps1' }
if (-not (Test-Path $script:Target)) { Write-Output "FAIL: $($script:Target) does not exist"; exit 1 }

$script:Failures = 0
$global:Wago989BuildsJson = '{}'
$global:Wago989Ts = ''
$global:Wago989Requested = [System.Collections.Generic.List[string]]::new()
$global:Wago989Agents = [System.Collections.Generic.List[string]]::new()
$userAgent = 'Warbandeer-suite-ci (github.com/nazumods/wow)'

# The stand-in for the real cmdlet. /api/builds and the CSV tables the suite's generators read are served from the
# current case (the generator under test must only ask for TransmogSet); anything else throws.
function Invoke-WebRequest {
  [CmdletBinding()]
  param([string]$Uri, [string]$UserAgent, [switch]$UseBasicParsing)
  $global:Wago989Requested.Add($Uri)
  $global:Wago989Agents.Add($UserAgent)
  if ($Uri -eq 'https://wago.tools/api/builds') { return [pscustomobject]@{ Content = $global:Wago989BuildsJson } }
  if ($Uri -match '^https://wago\.tools/db2/TransmogSet/csv\?build=') { return [pscustomobject]@{ Content = $global:Wago989Ts } }
  if ($Uri -match '^https://wago\.tools/db2/(TransmogSetGroup|ItemNameDescription)/csv\?build=') { return [pscustomobject]@{ Content = "ID,Name_lang`n1,x`n" } }
  throw "STOP-989: unexpected request $Uri"
}

function New-Build([string]$Version, [string]$Created) { @{ product = 'wow_classic_beta'; version = $Version; created_at = $Created } }
function Set-Builds($Beta) { $global:Wago989BuildsJson = ([ordered]@{ wow = @(New-Build '12.1.5.70391' '2026-10-13 21:16:02'); wow_classic_beta = @($Beta) } | ConvertTo-Json -Depth 5) }

# The seven real TransmogSet rows of build 1.60.1.70425 (header and column order as wago serves them), in a
# SCRAMBLED order so the sort is observable.
$header = 'Name_lang,ID,ClassMask,TrackingQuestID,Flags,TransmogSetGroupID,ItemNameDescriptionID,ParentTransmogSetID,CompleteWorldStateID,ExpansionID,PatchIntroduced,UiOrder,ConditionID'
$realRows = @(
  '"Veteran Adventurer''s Outdoor Wear",5914,0,97984,259,0,13968,0,18,0,16000,10,0',
  '"Green Snugglefin Murloc Romper",3634,0,82027,2,262,13968,0,1,9,100207,1640,0',
  '"Shen''dorei Skyseer''s Garb",5702,0,95979,259,393,14120,5700,18,0,0,1000,0',
  '"Spiritplume Celestial Collection",4397,0,89504,387,0,13967,0,1,10,110105,10,0',
  '"Shen''dorei Magister''s Garb",5700,0,95977,259,393,13967,0,18,0,0,1000,0',
  '"Al''Aketh Zealot''s Garb",5703,0,95980,259,393,14245,5700,18,0,0,1000,0',
  '"Shen''dorei Peacekeeper''s Garb",5701,0,95978,259,393,13968,5700,18,0,0,1000,0'
)
function Set-Ts([string[]]$Rows, [string]$Head = $header) { $global:Wago989Ts = (@($Head) + $Rows) -join "`n" }
$goodBeta = @((New-Build '5.5.0.60000' '2025-05-01 10:00:00'), (New-Build '1.60.0.70000' '2026-10-10 08:00:00'), (New-Build '1.60.1.70425' '2026-10-16 08:00:00'))

# Runs the script in -Forever mode against a temp file -> @{ Exit; Out; Text; Requested; Agent; Path }.
# $Pre = text to put in the temp file first ($null = no file); $ScriptArgs adds/overrides parameters.
function Invoke-Forever([hashtable]$ScriptArgs = @{}, $Pre = $null) {
  $tmp = Join-Path ([System.IO.Path]::GetTempPath()) "update-sets-forever-989-$([guid]::NewGuid().ToString('N')).lua"
  try {
    if ($null -ne $Pre) { [System.IO.File]::WriteAllText($tmp, $Pre) }
    $global:Wago989Requested.Clear(); $global:Wago989Agents.Clear()
    $a = @{ Forever = $true; ForeverFile = $tmp }
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
      Exit = $code; Out = ($lines -join "`n"); Path = $tmp
      Text = $(if (Test-Path -LiteralPath $tmp) { [System.IO.File]::ReadAllText($tmp) } else { $null })
      # ReadAllText strips a BOM, so look at the raw bytes: Lua 5.1's loadfile (busted) rejects one.
      Bom = $(if (Test-Path -LiteralPath $tmp) { $b = [System.IO.File]::ReadAllBytes($tmp); $b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF } else { $null })
      Requested = @($global:Wago989Requested)
      Agent = $(if ($global:Wago989Agents.Count) { $global:Wago989Agents[0] } else { '' })
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
  else { Write-Output "FAIL ${Name}: '$Needle' unexpectedly in text"; $script:Failures++ }
}
function Test-Failed([string]$Name, $Result) {
  # A refused run ends non-zero or throws.
  if ($Result.Exit -eq 'throw' -or ($Result.Exit -ne 0 -and $null -ne $Result.Exit)) { Write-Output "PASS $Name" }
  else { Write-Output "FAIL ${Name}: expected a failure, exit was '$($Result.Exit)'"; $script:Failures++ }
}

$sentinel = "-- sentinel: must survive an aborted run`n"

# 1. picks the newest 1.60 build by date, not the first listed ------------------------------------------
Set-Builds $goodBeta; Set-Ts $realRows
$r = Invoke-Forever
Test-Case 'picks the newest 1.60 build by date, not the first listed: exit' 0 $r.Exit
Test-Contains 'picks the newest 1.60 build by date, not the first listed: header names 1.60.1.70425' $r.Text 'build 1.60.1.70425,'
Test-Lacks 'picks the newest 1.60 build by date, not the first listed: not the 5.5 or the older 1.60' $r.Text 'build 5.5.0.60000'
Test-Contains 'picks the newest 1.60 build by date, not the first listed: fetches that build' ($r.Requested -join ' ') 'TransmogSet/csv?build=1.60.1.70425'

# 2. -Build pins a listed build; an unlisted -Build throws ----------------------------------------------------
$r = Invoke-Forever @{ Build = '1.60.0.70000' }
Test-Contains '-Build pins a listed build: that build is used' $r.Text 'build 1.60.0.70000,'
$r = Invoke-Forever @{ Build = '1.60.9.99999' } $sentinel
Test-Failed '-Build unlisted: fails' $r
Test-Case '-Build unlisted: the file is untouched' $sentinel $r.Text

# 3. no 1.60 build -> non-zero, file untouched ----------------------------------------------------------------
Set-Builds @((New-Build '5.5.0.60000' '2025-05-01 10:00:00'), (New-Build '4.4.1.58000' '2025-03-01 10:00:00'))
$r = Invoke-Forever @{} $sentinel
Test-Failed 'no 1.60 build: fails' $r
Test-Contains 'no 1.60 build: says so' $r.Out "starts with '1.60.'"
Test-Case 'no 1.60 build: the file is untouched' $sentinel $r.Text
Set-Builds $goodBeta

# 4. writes the gate, then 7 rows sorted by id ----------------------------------------------------------------
Set-Ts $realRows
$r = Invoke-Forever
$lines = @($r.Text -split "`n")
$afterLocal = @($lines | Select-Object -Skip ([array]::IndexOf($lines, 'local ns = select(2, ...)') + 1) | Where-Object { $_ -and -not $_.StartsWith('--') })
Test-Case 'writes the gate: the first statement after local ns is the flavor gate' 'if not (ns.flavor and ns.flavor.isForever) then return end' $afterLocal[0]
Test-Case 'writes the gate: ns.Sets is assigned next' 'ns.Sets = {' $afterLocal[1]
Test-Contains 'writes the gate: ns.PtrSets is emptied' $r.Text "`nns.PtrSets = {}`n"
Test-Contains 'writes the gate: ns.PtrBuild is cleared' $r.Text "`nns.PtrBuild = nil`n"
$ids = @([regex]::Matches($r.Text, '(?m)^  \{ id = (\d+),') | ForEach-Object { [int]$_.Groups[1].Value })
Test-Case 'writes 7 rows sorted by id' '3634,4397,5700,5701,5702,5703,5914' ($ids -join ',')
Test-Case 'writes the file without a UTF-8 BOM' $false $r.Bom

# 5. a ClassMask-0 set fills classId 1..13 with itself and is flagged allClasses -------------------------------
$row = [regex]::Match($r.Text, '(?s)  \{ id = 3634,.*?\n  \} \},').Value
Test-Contains 'a ClassMask-0 set is flagged allClasses' $row 'allClasses = true'
$cells = @([regex]::Matches($row, '(?m)^    \{ id = 3634, name = "Green Snugglefin Murloc Romper", classId = (\d+) \},$') | ForEach-Object { [int]$_.Groups[1].Value })
Test-Case 'a ClassMask-0 set fills classId 1..13 with itself' (1..13 -join ',') ($cells -join ',')

# 6. a set with class bits fills only its classes and has no flag -----------------------------------------------
Set-Ts ($realRows + '"Test Tier",6000,5,1,1,0,13968,0,1,3,1,1,0')
$r = Invoke-Forever
$row = [regex]::Match($r.Text, '(?s)  \{ id = 6000,.*?\n  \} \},').Value
Test-Lacks 'a set with class bits has no allClasses flag' $row 'allClasses'
$cellLines = @($row -split "`n" | Where-Object { $_.StartsWith('    ') })
Test-Case 'a set with class bits: mask 5 = bits 0 and 2 -> classId 1, a gap, classId 3' '{ id = 6000, name = "Test Tier", classId = 1 },|{},|{ id = 6000, name = "Test Tier", classId = 3 },' (($cellLines | ForEach-Object { $_.Trim() }) -join '|')

# The top class bit (bit 12, Evoker = classId 13) is decomposed too: twelve gaps, then classId 13.
Set-Ts ($realRows + '"Top Bit",6006,4096,1,1,0,13968,0,1,3,1,1,0')
$r = Invoke-Forever
$row = [regex]::Match($r.Text, '(?s)  \{ id = 6006,.*?\n  \} \},').Value
$cellLines = @($row -split "`n" | Where-Object { $_.StartsWith('    ') })
Test-Case 'a set with class bits: mask 4096 = bit 12 -> twelve gaps then classId 13' ((@('{},') * 12) + '{ id = 6006, name = "Top Bit", classId = 13 },' -join '|') (($cellLines | ForEach-Object { $_.Trim() }) -join '|')

# 7. release is ExpansionID + 1 --------------------------------------------------------------------------------
Set-Ts $realRows
$r = Invoke-Forever
$rel = @{}
foreach ($m in [regex]::Matches($r.Text, '(?m)^  \{ id = (\d+), name = ".*?", release = (\d+),')) { $rel[[int]$m.Groups[1].Value] = [int]$m.Groups[2].Value }
Test-Case 'release is ExpansionID + 1: 5700 -> 1' 1 $rel[5700]
Test-Case 'release is ExpansionID + 1: 3634 -> 10' 10 $rel[3634]
Test-Case 'release is ExpansionID + 1: 4397 -> 11' 11 $rel[4397]
Test-Contains 'every row is category World' $r.Text 'category = "World", allClasses = true'

# 8. names are Lua-escaped -----------------------------------------------------------------------------------
Set-Ts ($realRows + '"Say ""Hi"" \ bye",6001,0,1,1,0,13968,0,1,0,1,1,0')
$r = Invoke-Forever
Test-Contains 'names are Lua-escaped: quote and backslash' $r.Text 'name = "Say \"Hi\" \\ bye"'
Set-Ts $realRows

# 9. the header records product, build and date ---------------------------------------------------------------
$r = Invoke-Forever
Test-Contains 'the header records product, build and date' $r.Text '-- Generated from wago.tools TransmogSet (product wow_classic_beta, build 1.60.1.70425, 2026-10-16) by tools/update-sets.ps1 -Forever; do not hand-edit.'

# 10. 0 rows -> non-zero, file untouched; a CSV missing a column too -------------------------------------------
Set-Ts @()
$r = Invoke-Forever @{} $sentinel
Test-Failed '0 rows: fails' $r
Test-Contains '0 rows: names the empty table' $r.Out 'returned 0 rows'
Test-Case '0 rows: the file is untouched' $sentinel $r.Text
Set-Ts $realRows 'Name_lang,ID,ExpansionID'
$r = Invoke-Forever @{} $sentinel
Test-Failed 'a CSV missing ClassMask: fails' $r
Test-Contains 'a CSV missing ClassMask: names the column' $r.Out "missing 'ClassMask'"
Test-Case 'a CSV missing ClassMask: the file is untouched' $sentinel $r.Text
Set-Ts $realRows

# 11. an unchanged rerun leaves the file byte-identical ----------------------------------------------------------
$older = @((New-Build '1.60.1.70425' '2026-10-01 08:00:00'))
Set-Builds $older
$first = Invoke-Forever
Set-Builds $goodBeta   # same data, a NEWER build date
$r = Invoke-Forever @{} $first.Text
Test-Case 'an unchanged rerun leaves the file byte-identical: exit' 0 $r.Exit
Test-Case 'an unchanged rerun leaves the file byte-identical' $first.Text $r.Text
Test-Contains 'an unchanged rerun keeps the original date line' $r.Text '2026-10-01'
Test-Contains 'an unchanged rerun says so' $r.Out 'no change'
# ... and a real change does rewrite it (with the new header)
Set-Ts ($realRows + '"Brand New",6002,0,1,1,0,13968,0,1,0,1,1,0')
$r = Invoke-Forever @{} $first.Text
Test-Contains 'a changed body is rewritten' $r.Text 'id = 6002,'
Test-Contains 'a changed body is rewritten with the new header' $r.Text '2026-10-16'
Test-Contains 'a changed body reports the added id' $r.Out 'added [6002]'
Set-Ts $realRows

# 12. requests only /api/builds and the TransmogSet table, with the suite's User-Agent -------------------------------
$r = Invoke-Forever
Test-Case 'requests only /api/builds and the TransmogSet CSV' 'https://wago.tools/api/builds|https://wago.tools/db2/TransmogSet/csv?build=1.60.1.70425' (@($r.Requested | Select-Object -Unique) -join '|')
Test-Case 'the requests identify themselves' $userAgent $r.Agent

# 13. numeric sort: 3-digit and 5-digit ids order by value, not as text
Set-Ts ($realRows + '"Low",999,0,1,1,0,13968,0,1,0,1,1,0' + '"High",12000,0,1,1,0,13968,0,1,0,1,1,0')
$r = Invoke-Forever
$ids = @([regex]::Matches($r.Text, '(?m)^  \{ id = (\d+),') | ForEach-Object { [int]$_.Groups[1].Value })
Test-Case 'rows sort numerically by id' '999,3634,4397,5700,5701,5702,5703,5914,12000' ($ids -join ',')
Set-Ts $realRows

# 14. rows that would write a wrong or unloadable file are refused, file untouched
$badRows = [ordered]@{
  'a duplicate set id'            = '"Dup",3634,0,1,1,0,13968,0,1,0,1,1,0'
  'a ClassMask above the 13 bits' = '"Wide",6003,16384,1,1,0,13968,0,1,0,1,1,0'
  'a negative ClassMask'          = '"Neg",6004,-1,1,1,0,13968,0,1,0,1,1,0'
  'a negative ExpansionID'        = '"Early",6005,0,1,1,0,13968,0,1,-1,1,1,0'
  'an empty name'                 = '"",6006,0,1,1,0,13968,0,1,0,1,1,0'
  'a name with a newline'         = "`"Two`nLines`",6007,0,1,1,0,13968,0,1,0,1,1,0"
  'a non-numeric id'              = '"Odd",abc,0,1,1,0,13968,0,1,0,1,1,0'
}
foreach ($k in $badRows.Keys) {
  Set-Ts ($realRows + $badRows[$k])
  $r = Invoke-Forever @{} $sentinel
  Test-Failed "$k is refused" $r
  Test-Case "$k is refused: the file is untouched" $sentinel $r.Text
}
Set-Ts $realRows

# 15. -Check never writes: exit 1 when the file would change, 0 when current
$r = Invoke-Forever @{ Check = $true } $sentinel
Test-Case '-Check: a stale file exits 1' 1 $r.Exit
Test-Case '-Check: a stale file is not written' $sentinel $r.Text
$current = (Invoke-Forever).Text
$r = Invoke-Forever @{ Check = $true } $current
Test-Case '-Check: a current file exits 0' 0 $r.Exit
Test-Case '-Check: a current file is not rewritten' $current $r.Text
$r = Invoke-Forever @{ Check = $true }
Test-Case '-Check: a missing file exits 1 and is not created' 1 $r.Exit
Test-Case '-Check: a missing file is not created (no text)' '' $r.Text

if ($script:Failures -gt 0) {
  Write-Output "FAILED: $($script:Failures) case(s)"
  exit 1
}
Write-Output 'OK: all cases passed'
