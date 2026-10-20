#requires -Version 7
<#
.SYNOPSIS
  Tests Warbandeer_Collected/tools/update-sets.ps1 -Weapons -Forever, which generates
  data/weaponsources_forever.lua (Forever's own weapon appearances) from Forever's wago build (nazumods/wow#994).

.DESCRIPTION
  Runs the REAL script with Invoke-WebRequest replaced by a function (functions outrank cmdlets, and a
  function defined here is visible to the script it calls) that serves wago's /api/builds and synthetic
  Forever-shaped DB2 CSVs. Like Forever's real build it has no Journal* or encounter/quest source tables:
  those answer HTTP 400 "Table not found", as wago does. Every case writes a temp -WeaponsForeverFile (the
  real data file is never touched) and reads the file, the output and the exit code.

  The fixture: 10000 Item rows, of which items 1..600 are one-handed swords (type 14) and 601..602 shields
  (type 18), each item its own appearance (100000 + item id); 5000 ItemModifiedAppearance rows, quest-sourced
  (2) unless a case says otherwise; an ItemSparse row (ExpansionID 0) for every item except 9.

  Plain PowerShell, not Pester, so it runs wherever pwsh does; it is a step of the test.yml
  `wago-build-resolution` job. UPDATE_SETS_SCRIPT points the mutation checks at a scratch copy.
  Exit 0 = every case passed; 1 = a case failed.

  pwsh Tooling/tests/update-sets-forever-weapons.test.ps1
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Target = if ($env:UPDATE_SETS_SCRIPT) { $env:UPDATE_SETS_SCRIPT } else { Join-Path $PSScriptRoot '..' '..' 'Warbandeer_Collected' 'tools' 'update-sets.ps1' }
if (-not (Test-Path $script:Target)) { Write-Output "FAIL: $($script:Target) does not exist"; exit 1 }

$script:Failures = 0
# The script caches each CSV under <temp>/wbc-weapons-<build>, so two runs of this test at once (or a real
# generator run of the same build) would overwrite each other's fixtures. Point the temp dir at one of our own.
$script:TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "update-sets-forever-weapons-994-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $script:TempRoot | Out-Null
$env:TMP = $script:TempRoot; $env:TEMP = $script:TempRoot; $env:TMPDIR = $script:TempRoot
$global:Wago994 =@{ Builds = '{}'; Tables = @{}; Requested = [System.Collections.Generic.List[string]]::new() }

# The stand-in for the real cmdlet: /api/builds as Content, a known table into -OutFile, a table the case
# doesn't serve as wago's 400 "Table not found" (a real HttpResponseException, which the script reads the
# status code of), and a table mapped to $null as a 500.
function Invoke-WebRequest {
  [CmdletBinding()]
  param([string]$Uri, [string]$UserAgent, [switch]$UseBasicParsing, [string]$OutFile)
  $global:Wago994.Requested.Add($Uri)
  if ($Uri -eq 'https://wago.tools/api/builds') { return [pscustomobject]@{ Content = $global:Wago994.Builds } }
  if ($Uri -match '^https://wago\.tools/db2/(\w+)/csv\?build=') {
    $t = $Matches[1]
    $status = 400
    if ($global:Wago994.Tables.ContainsKey($t)) {
      $csv = $global:Wago994.Tables[$t]
      if ($null -ne $csv) {
        if ($OutFile) { [System.IO.File]::WriteAllText($OutFile, $csv); return }
        return [pscustomobject]@{ Content = $csv }
      }
      $status = 500
    }
    $msg = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]$status)
    throw [Microsoft.PowerShell.Commands.HttpResponseException]::new("Response status code does not indicate success: $status.", $msg)
  }
  throw "STOP-994: unexpected request $Uri"
}

function New-Build([string]$Version, [string]$Created) { @{ product = 'wow_classic_beta'; version = $Version; created_at = $Created } }
$goodBeta = @((New-Build '5.5.0.60000' '2025-05-01 10:00:00'), (New-Build '1.60.0.70000' '2026-10-10 08:00:00'), (New-Build '1.60.1.70450' '2026-10-16 08:00:00'))
$global:Wago994.Builds = ([ordered]@{ wow = @(New-Build '12.1.5.70391' '2026-10-13 21:16:02'); wow_classic_beta = $goodBeta } | ConvertTo-Json -Depth 5)

# Build the fixture tables. $SourceOf maps an item id to a TransmogSourceTypeEnum (default 2, quest);
# $NoSparse lists items without an ItemSparse row; $Items/$Imas size the two tables.
# $Swords is how many items (1..$Swords) are swords; the two after them are shields. $Retail also serves the
# Journal* / encounter / quest tables (header only), which Forever's build doesn't have.
function Set-Tables([hashtable]$SourceOf = @{}, [int[]]$NoSparse = @(9), [int]$Items = 10000, [int]$Imas = 5000, [int]$Swords = 600, [switch]$Retail) {
  $it = [System.Text.StringBuilder]::new("ID,ClassID,SubclassID,InventoryType`n")
  for ($i = 1; $i -le $Items; $i++) {
    if ($i -le $Swords) { [void]$it.Append("$i,2,7,13`n") }        # one-handed sword -> type 14
    elseif ($i -le $Swords + 2) { [void]$it.Append("$i,4,6,14`n") } # shield -> type 18
    else { [void]$it.Append("$i,0,0,0`n") }                         # not a weapon
  }
  $ima = [System.Text.StringBuilder]::new("ID,ItemID,ItemAppearanceModifierID,ItemAppearanceID,OrderIndex,TransmogSourceTypeEnum,Flags`n")
  for ($i = 1; $i -le $Imas; $i++) {
    $src = if ($SourceOf.ContainsKey($i)) { $SourceOf[$i] } else { 2 }
    [void]$ima.Append("$i,$i,0,$(100000 + $i),0,$src,0`n")
  }
  $sp = [System.Text.StringBuilder]::new("ID,Display_lang,ExpansionID`n")
  for ($i = 1; $i -le $Items; $i++) { if ($i -notin $NoSparse) { [void]$sp.Append("$i,`"Item $i`",0`n") } }
  $global:Wago994.Tables = @{
    Item = $it.ToString(); ItemModifiedAppearance = $ima.ToString(); ItemSparse = $sp.ToString()
    CollectableSourceInfo = "Description,ID,SourceTypeEnum,ItemModifiedAppearanceID,HouseDecorID`n"
    CollectableSourceVendorSparse = "ID,VendorMapID,CollectableSourceInfoID`n"
    Map = "ID,ExpansionID,InstanceType`n0,0,0`n"
  }
  if ($Retail) {
    $global:Wago994.Tables['CollectableSourceEncounterSparse'] = "ID,CollectableSourceInfoID,JournalEncounterID`n"
    $global:Wago994.Tables['CollectableSourceQuestSparse'] = "ID,CollectableSourceInfoID,QuestMapID`n"
    $global:Wago994.Tables['JournalEncounter'] = "ID,JournalInstanceID`n"
    $global:Wago994.Tables['JournalInstance'] = "ID,Name_lang,MapID`n"
    $global:Wago994.Tables['JournalTier'] = "ID,Expansion`n"
    $global:Wago994.Tables['JournalTierXInstance'] = "ID,JournalTierID,JournalInstanceID`n"
  }
}

# Runs the script in -Weapons -Forever mode against a temp file -> @{ Exit; Out; Text; Requested }.
function Invoke-ForeverWeapons([hashtable]$ScriptArgs = @{}, $Pre = $null) {
  $tmp = Join-Path ([System.IO.Path]::GetTempPath()) "update-sets-forever-weapons-994-$([guid]::NewGuid().ToString('N')).lua"
  try {
    if ($null -ne $Pre) { [System.IO.File]::WriteAllText($tmp, $Pre) }
    $global:Wago994.Requested.Clear()
    $a = @{ Weapons = $true; Forever = $true; WeaponsForeverFile = $tmp }
    foreach ($k in $ScriptArgs.Keys) { $a[$k] = $ScriptArgs[$k] }
    foreach ($k in @($a.Keys)) { if ($null -eq $a[$k]) { $a.Remove($k) } }
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
      Exit = $code; Out = ($lines -join "`n")
      Text = $(if (Test-Path -LiteralPath $tmp) { [System.IO.File]::ReadAllText($tmp) } else { $null })
      Bom = $(if (Test-Path -LiteralPath $tmp) { $b = [System.IO.File]::ReadAllBytes($tmp); $b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF } else { $null })
      Requested = @($global:Wago994.Requested)
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
  else { Write-Output "FAIL ${Name}: '$Needle' not in output"; $script:Failures++ }
}
function Test-Lacks([string]$Name, [string]$Haystack, [string]$Needle) {
  if (-not $Haystack.Contains($Needle)) { Write-Output "PASS $Name" }
  else { Write-Output "FAIL ${Name}: '$Needle' unexpectedly in text"; $script:Failures++ }
}
function Test-Failed([string]$Name, $Result) {
  if ($Result.Exit -eq 'throw' -or ($Result.Exit -ne 0 -and $null -ne $Result.Exit)) { Write-Output "PASS $Name" }
  else { Write-Output "FAIL ${Name}: expected a failure, exit was '$($Result.Exit)'"; $script:Failures++ }
}
# The visual ids in one generated row (by name), one type column.
function Get-Column([string]$Text, [string]$Row, [int]$Type) {
  $block = [regex]::Match($Text, "(?s)tinsert\(ns\.WeaponSources, \{\n  id = \d+,\n  name = `"$Row`",.*?\n\}\)").Value
  $m = [regex]::Match($block, "(?m)^    \[$Type\] = \{ ([\d, ]+) \},$")
  if ($m.Success) { return @($m.Groups[1].Value -split ', ' | ForEach-Object { [int]$_ }) }
  return @()
}

$sentinel = "-- sentinel: must survive an aborted run`n"

# 1. newest 1.60 build, the gate, the replacement, the header ---------------------------------------------
Set-Tables
$r = Invoke-ForeverWeapons
Test-Case 'a clean run exits 0' 0 $r.Exit
Test-Contains 'the header records product, build and date' $r.Text '-- Generated from wago.tools weapon appearances (product wow_classic_beta, build 1.60.1.70450, 2026-10-16) by tools/update-sets.ps1 -Weapons -Forever; do not hand-edit.'
$lines = @($r.Text -split "`n")
$code = @($lines | Where-Object { $_ -and -not $_.StartsWith('--') -and -not $_.StartsWith('---') })
Test-Case 'the gate comes before any write' 'if not (ns.flavor and ns.flavor.isForever) then return end' $code[2]
Test-Case 'ns.WeaponSources is replaced right after the gate' 'ns.WeaponSources = {}' $code[3]
Test-Case 'writes the file without a UTF-8 BOM' $false $r.Bom
Test-Contains 'fetches the newest 1.60 build' ($r.Requested -join ' ') 'Item/csv?build=1.60.1.70450'

# 2. Forever's missing tables are skipped, and named --------------------------------------------------------
foreach ($t in 'CollectableSourceEncounterSparse', 'CollectableSourceQuestSparse', 'JournalEncounter', 'JournalInstance', 'JournalTier', 'JournalTierXInstance') {
  Test-Contains "a missing $t is skipped and named" $r.Out "no $t table (HTTP 400) -- skipped."
}

# 3. bucketing: quest row by type, sparse filter, invalid source, hidden -> Other ---------------------------
Set-Tables -SourceOf @{ 7 = 5; 10 = 9; 601 = 3 }
$r = Invoke-ForeverWeapons
$quest14 = Get-Column $r.Text 'Quest' 14
Test-Case 'quest swords land in the Quest row, type 14 (600 less hidden 7, unnamed 9, invalid 10)' 597 $quest14.Count
Test-Case 'an item without an ItemSparse row is left out' $false (100009 -in $quest14)
Test-Lacks 'an item without an ItemSparse row is nowhere in the file' $r.Text '100009'
Test-Lacks 'a NotValidForTransmog-only visual is left out' $r.Text '100010'
Test-Case 'a HiddenUntilCollected visual lands in the Other row' '100007' ((Get-Column $r.Text 'Other' 14) -join ',')
Test-Case 'a vendor shield lands in the Vendor row, type 18' '100601' ((Get-Column $r.Text 'Vendor' 18) -join ',')
Test-Case 'a quest shield lands in the Quest row, type 18' '100602' ((Get-Column $r.Text 'Quest' 18) -join ',')
Test-Contains 'release is ExpansionID + 1' $r.Text "  release = 1,"
Test-Contains 'reports the count' $r.Out 'Forever weapons: 3 source row(s), 600 appearance(s).'

# 4. the Forever floors: under 10000 items, or under 500 placed, refuses and leaves the file -----------------
Set-Tables -Items 9999
$r = Invoke-ForeverWeapons @{} $sentinel
Test-Failed 'under 10000 Item rows: fails' $r
Test-Contains 'under 10000 Item rows: says so' $r.Out 'Item under 10000 rows'
Test-Case 'under 10000 Item rows: the file is untouched' $sentinel $r.Text
Set-Tables -Imas 4999
$r = Invoke-ForeverWeapons @{} $sentinel
Test-Failed 'under 5000 ItemModifiedAppearance rows: fails' $r
Test-Contains 'under 5000 ItemModifiedAppearance rows: says so' $r.Out 'ItemModifiedAppearance under 5000 rows'
Test-Case 'under 5000 ItemModifiedAppearance rows: the file is untouched' $sentinel $r.Text
$noSparse = 1..150
Set-Tables -NoSparse $noSparse
$r = Invoke-ForeverWeapons @{} $sentinel
Test-Failed 'under 500 placed: fails' $r
Test-Contains 'under 500 placed: says so' $r.Out '(<500)'
Test-Case 'under 500 placed: the file is untouched' $sentinel $r.Text

# 5. a table that fails for another reason still aborts (only "not found" is optional) -----------------------
Set-Tables
$global:Wago994.Tables['JournalEncounter'] = $null   # -> HTTP 500
$r = Invoke-ForeverWeapons @{} $sentinel
Test-Failed 'a 500 on an optional table: fails' $r
Test-Case 'a 500 on an optional table: the file is untouched' $sentinel $r.Text

# 6. Retail -Weapons keeps its floors and its required tables ----------------------------------------------
Set-Tables
$tmpRetail = Join-Path ([System.IO.Path]::GetTempPath()) "update-sets-retail-994-$([guid]::NewGuid().ToString('N')).lua"
[System.IO.File]::WriteAllText($tmpRetail, $sentinel)
$r = Invoke-ForeverWeapons @{ Forever = $null; WeaponsForeverFile = $null; WeaponsFile = $tmpRetail; Product = 'wow'; Build = '12.1.5.70391' }
Test-Failed 'Retail: 10000 Item rows is still under its 50000 floor' $r
Test-Contains 'Retail: names the 50000 floor' $r.Out 'Item under 50000 rows'
Set-Tables -Items 50000 -Imas 50000
$r = Invoke-ForeverWeapons @{ Forever = $null; WeaponsForeverFile = $null; WeaponsFile = $tmpRetail; Product = 'wow'; Build = '12.1.5.70391' }
Test-Failed 'Retail: a missing encounter table still aborts' $r
Test-Lacks 'Retail: a missing table is not skipped' $r.Out 'skipped.'
Test-Case 'Retail: weaponsources.lua is untouched' $sentinel ([System.IO.File]::ReadAllText($tmpRetail))
# A complete Retail run: the Forever-only rules don't apply, so an item with no ItemSparse row still counts.
Set-Tables -Items 50000 -Imas 50000 -Swords 3100 -Retail
$r = Invoke-ForeverWeapons @{ Forever = $null; WeaponsForeverFile = $null; WeaponsFile = $tmpRetail; Product = 'wow'; Build = '12.1.5.70391' }
Test-Case 'Retail: a complete run exits 0' 0 $r.Exit
$retailText = [System.IO.File]::ReadAllText($tmpRetail)
Test-Contains 'Retail: an item with no ItemSparse row is still placed' $retailText '100009'
Test-Contains 'Retail: places all 3102' $r.Out 'placed 3102 weapon appearances'
# ... and Retail keeps its 50000-row ItemModifiedAppearance floor and its 3000-placed floor.
Set-Tables -Items 50000 -Imas 49999 -Swords 3100 -Retail
$r = Invoke-ForeverWeapons @{ Forever = $null; WeaponsForeverFile = $null; WeaponsFile = $tmpRetail; Product = 'wow'; Build = '12.1.5.70391' }
Test-Contains 'Retail: keeps the 50000 ItemModifiedAppearance floor' $r.Out 'ItemModifiedAppearance under 50000 rows'
Set-Tables -Items 50000 -Imas 50000 -Swords 2900 -Retail
$r = Invoke-ForeverWeapons @{ Forever = $null; WeaponsForeverFile = $null; WeaponsFile = $tmpRetail; Product = 'wow'; Build = '12.1.5.70391' }
Test-Failed 'Retail: under 3000 placed fails' $r
Test-Contains 'Retail: names the 3000 floor' $r.Out '(<3000)'
Remove-Item -LiteralPath $tmpRetail -ErrorAction SilentlyContinue

# 7. no churn: an unchanged rerun on a newer build leaves the file byte-identical; -Check never writes ---------
Set-Tables
$global:Wago994.Builds = ([ordered]@{ wow_classic_beta = @(New-Build '1.60.1.70425' '2026-10-01 08:00:00') } | ConvertTo-Json -Depth 5)
$first = Invoke-ForeverWeapons
$global:Wago994.Builds = ([ordered]@{ wow_classic_beta = $goodBeta } | ConvertTo-Json -Depth 5)
$r = Invoke-ForeverWeapons @{} $first.Text
Test-Case 'an unchanged rerun leaves the file byte-identical' $first.Text $r.Text
Test-Contains 'an unchanged rerun says so' $r.Out 'no change'
$r = Invoke-ForeverWeapons @{ Check = $true } $first.Text
Test-Case '-Check: a current file exits 0' 0 $r.Exit
$r = Invoke-ForeverWeapons @{ Check = $true } $sentinel
Test-Case '-Check: a stale file exits 1' 1 $r.Exit
Test-Case '-Check: a stale file is not written' $sentinel $r.Text

# 8. -Build pins; -PtrDelta is refused (Forever has no PTR) ---------------------------------------------------
$r = Invoke-ForeverWeapons @{ Build = '1.60.0.70000' }
Test-Contains '-Build pins a listed build' $r.Text 'build 1.60.0.70000,'
$r = Invoke-ForeverWeapons @{ PtrDelta = $true } $sentinel
Test-Failed '-PtrDelta is refused' $r
Test-Case '-PtrDelta: the file is untouched' $sentinel $r.Text

Remove-Item -LiteralPath $script:TempRoot -Recurse -Force -ErrorAction SilentlyContinue
if ($script:Failures -gt 0) {
  Write-Output "FAILED: $($script:Failures) case(s)"
  exit 1
}
Write-Output 'OK: all cases passed'
exit 0
