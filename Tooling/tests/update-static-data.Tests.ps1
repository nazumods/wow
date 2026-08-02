<#
  Pester spec for update-static-data.ps1's Get-IconImage classification (nazumods/wow#889).

  The generator is a run-on-load script, not a module, so there is nothing to Import-Module and
  dot-sourcing it would run the whole wago fetch pipeline. Instead we lift ONLY the Get-IconImage
  function out of the real script by its AST and define it here, so the test exercises the shipped
  code verbatim while the production script stays free of any test-only scaffolding.

  Not wired into CI (the repo runs busted + luacheck only); run locally with:
    pwsh -NoProfile -Command "Invoke-Pester -Path Tooling/tests/update-static-data.Tests.ps1"
#>

BeforeAll {
  $scriptPath = Join-Path $PSScriptRoot '..' 'update-static-data.ps1'
  $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
  $fn = $ast.Find({
      param($node)
      $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Get-IconImage'
    }, $true)
  if (-not $fn) { throw "Get-IconImage was not found in $scriptPath" }
  . ([scriptblock]::Create($fn.Extent.Text))
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
