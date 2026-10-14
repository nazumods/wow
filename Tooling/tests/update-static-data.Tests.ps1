<#
  Pester spec for update-static-data.ps1's Get-IconImage classification (nazumods/wow#889) and its
  Select-WagoBuild build selection (nazumods/wow#954).

  The generator is a run-on-load script, not a module, so there is nothing to Import-Module and
  dot-sourcing it would run the whole wago fetch pipeline. Instead we lift ONLY the functions under
  test (Get-IconImage, Select-WagoBuild) out of the real script by their AST and define them here, so
  the test exercises the shipped code verbatim while the production script stays free of any
  test-only scaffolding.

  Not wired into CI (the repo runs busted + luacheck only); run locally with:
    pwsh -NoProfile -Command "Invoke-Pester -Path Tooling/tests/update-static-data.Tests.ps1"
#>

BeforeAll {
  $scriptPath = Join-Path $PSScriptRoot '..' 'update-static-data.ps1'
  $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
  $functions = $ast.FindAll({
      param($node)
      $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
    }, $true)
  $script:ScriptAst = $ast
  foreach ($name in 'Get-IconImage', 'Select-WagoBuild') {
    $fn = $functions | Where-Object { $_.Name -eq $name } | Select-Object -First 1
    if (-not $fn) { throw "$name was not found in $scriptPath" }
    . ([scriptblock]::Create($fn.Extent.Text))
  }
  # Get-IconImage reads $IconSize (a script param) to build the CDN url; supply the default.
  $script:IconSize = 'medium'

  # A wago HTTP error carries a response with a status code (what Invoke-WebRequest -ErrorAction
  # Stop throws in PS7); a transport failure — DNS, connection reset, timeout — has no response.
  function New-HttpError([int]$StatusCode) {
    $resp = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]$StatusCode)
    [Microsoft.PowerShell.Commands.HttpResponseException]::new("HTTP $StatusCode", $resp)
  }
}

Describe 'Get-IconImage' {
  It 'returns the image bytes when the CDN serves a JPEG' {
    Mock Invoke-WebRequest { [pscustomobject]@{ Content = [byte[]]@(0xFF, 0xD8, 0x11, 0x22) } }
    $r = Get-IconImage 'inv_misc_coin_01'
    $r.GetType().Name | Should -Be 'Byte[]'
    $r.Length | Should -Be 4
    $r[0] | Should -Be 0xFF
    $r[1] | Should -Be 0xD8
  }

  It 'records a genuine 404 as a zero-length (permanent) miss' {
    Mock Invoke-WebRequest { throw (New-HttpError 404) }
    $r = Get-IconImage 'ui_majorfaction_ vines'
    $r.GetType().Name | Should -Be 'Byte[]'
    $r.Length | Should -Be 0
  }

  It 'THROWS on a transport failure rather than baking a permanent empty' {
    Mock Invoke-WebRequest { throw [System.Net.Http.HttpRequestException]::new('The remote name could not be resolved') }
    { Get-IconImage 'inv_misc_coin_01' } | Should -Throw -ExpectedMessage '*not a 404*'
  }

  It 'THROWS on a 5xx (a server error is not a missing icon)' {
    Mock Invoke-WebRequest { throw (New-HttpError 503) }
    { Get-IconImage 'inv_misc_coin_01' } | Should -Throw -ExpectedMessage '*not a 404*'
  }

  It 'THROWS on a 429 (rate limiting is not a missing icon)' {
    Mock Invoke-WebRequest { throw (New-HttpError 429) }
    { Get-IconImage 'inv_misc_coin_01' } | Should -Throw -ExpectedMessage '*not a 404*'
  }

  It 'treats a 200 that is not a JPEG (HTML error page) as a miss, not a throw' {
    Mock Invoke-WebRequest { [pscustomobject]@{ Content = [System.Text.Encoding]::UTF8.GetBytes('<html>not found</html>') } }
    $r = Get-IconImage 'inv_misc_coin_01'
    $r.Length | Should -Be 0
  }
}

# wago's /api/builds is unsorted per product. For wow_classic_beta -- a shared bucket for every Classic
# beta since 2019 -- the first entry is a 2025 MoP Classic build while the NEWEST is WoW: Forever 1.60.
# The fixture keeps that shape (live data, 2026-10-14): MoP first, and inside the 1.60 family the older
# build listed before the newer one, so "first listed" is wrong both overall and within a family.
Describe 'Select-WagoBuild' {
  BeforeAll {
    $script:Builds = @(
      [pscustomobject]@{ version = '5.5.0.62071';  created_at = '2025-07-18 01:19:04' }
      [pscustomobject]@{ version = '1.60.1.70338'; created_at = '2026-10-10 05:05:05' }
      [pscustomobject]@{ version = '1.60.1.70374'; created_at = '2026-10-13 23:25:05' }
      [pscustomobject]@{ version = '3.4.0.50000';  created_at = '2024-01-01 00:00:00' }
    )
  }

  It 'with no filter returns the NEWEST BY DATE, not the first listed' {
    (Select-WagoBuild $script:Builds '' '').version | Should -Be '1.60.1.70374'
  }

  It 'returns the newest build inside a version family, not the first listed in it' {
    (Select-WagoBuild $script:Builds '' '1.60.').version | Should -Be '1.60.1.70374'
  }

  It 'selects another family by its prefix' {
    (Select-WagoBuild $script:Builds '' '5.5.').version | Should -Be '5.5.0.62071'
  }

  It 'pins an explicit -Build even when it is not the newest' {
    (Select-WagoBuild $script:Builds '1.60.1.70338' '').version | Should -Be '1.60.1.70338'
  }

  It 'lets an explicit -Build win over -VersionPrefix' {
    (Select-WagoBuild $script:Builds '1.60.1.70338' '5.5.').version | Should -Be '1.60.1.70338'
  }

  It 'throws on a -Build the product does not list' {
    { Select-WagoBuild $script:Builds '9.9.9.1' '' 'wow_classic_beta' } | Should -Throw -ExpectedMessage "*no build '9.9.9.1'*"
  }

  It 'matches -Build exactly, not as a prefix of a listed build' {
    { Select-WagoBuild $script:Builds '1.60.1.7033' '' 'wow_classic_beta' } | Should -Throw -ExpectedMessage "*no build '1.60.1.7033'*"
  }

  It 'throws when no build starts with -VersionPrefix' {
    { Select-WagoBuild $script:Builds '' '7.' 'wow_classic_beta' } | Should -Throw -ExpectedMessage "*starts with '7.'*"
  }

  It 'compares created_at as dates, not as text' {
    # As text '...T01:00:00Z' sorts after '... 23:59:00' ('T' > ' '); as dates it is the earlier build.
    $mixed = @(
      [pscustomobject]@{ version = '1.60.1.1'; created_at = '2026-10-13T01:00:00Z' }
      [pscustomobject]@{ version = '1.60.1.2'; created_at = '2026-10-13 23:59:00' }
    )
    (Select-WagoBuild $mixed '' '').version | Should -Be '1.60.1.2'
  }

  It 'throws when the list is empty' {
    { Select-WagoBuild @() '' '' 'wow' } | Should -Throw -ExpectedMessage "*no 'wow' build*"
  }

  # The tests above drive the function directly; the original bug (`$list[0]`) lived in the code that
  # CALLS it. Pin that boundary: the script resolves its build through Select-WagoBuild, handing it the
  # operator's -Build and -VersionPrefix, and no longer indexes the build list by position.
  It 'is what the script calls to resolve its build, with -Build and -VersionPrefix' {
    $calls = @($script:ScriptAst.FindAll({
          param($node)
          $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Select-WagoBuild'
        }, $true))
    $calls.Count | Should -Be 1
    $calls[0].Extent.Text | Should -Match '\$Build\b'
    $calls[0].Extent.Text | Should -Match '\$VersionPrefix\b'
    $script:ScriptAst.Extent.Text | Should -Not -Match '\$list\[0\]'
  }
}
