Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$runner = Join-Path $PSScriptRoot 'run_connected_preview.ps1'
. (Join-Path $PSScriptRoot 'connected_preview_login_probe.ps1')
$shell = (Get-Process -Id $PID).Path
$temp = Join-Path ([IO.Path]::GetTempPath()) (
  'questra-preview-test-' + [guid]::NewGuid().ToString('N')
)
New-Item -ItemType Directory -Path $temp | Out-Null
$originalUrl = $env:SUPABASE_URL
$originalKey = $env:SUPABASE_ANON_KEY
$env:SUPABASE_URL = $null
$env:SUPABASE_ANON_KEY = $null
$passed = 0

function Invoke-Scenario {
  param(
    [string] $Name,
    [string] $Content,
    [bool] $ShouldPass,
    [string] $Message = ''
  )
  $path = Join-Path $temp "$Name.env"
  Set-Content -LiteralPath $path -Value $Content -Encoding UTF8
  $output = & $shell -NoProfile -File $runner `
    -ConfigPath $path -ValidateOnly -SkipRemoteProbe 2>&1
  $exit = $LASTEXITCODE
  if ($ShouldPass -and $exit -ne 0) {
    throw "$Name should pass: $($output -join ' ')"
  }
  if (-not $ShouldPass -and ($exit -eq 0 -or
      ($output -join ' ') -notmatch [regex]::Escape($Message))) {
    throw "$Name should fail with '$Message': $($output -join ' ')"
  }
  if (($output -join ' ') -match 'sb_publishable_[A-Za-z0-9_-]{20,}') {
    throw "$Name leaked the publishable key to output."
  }
  $script:passed++
  Write-Host "PASS $Name"
}

function ConvertTo-Base64Url {
  param([string] $Value)
  return [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Value)).
    TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

try {
  $validKey = 'sb_publishable_' + ('a' * 32)
  Invoke-Scenario -Name 'publishable-key' -ShouldPass $true -Content @"
SUPABASE_URL=https://abcdefghijklmnopqrst.supabase.co
SUPABASE_ANON_KEY=$validKey
"@

  Invoke-Scenario -Name 'secret-key-rejected' -ShouldPass $false `
    -Message 'secret key must never be used' -Content @"
SUPABASE_URL=https://abcdefghijklmnopqrst.supabase.co
SUPABASE_ANON_KEY=sb_secret_$('b' * 32)
"@

  $header = ConvertTo-Base64Url '{"alg":"HS256","typ":"JWT"}'
  $payload = ConvertTo-Base64Url '{"role":"service_role","ref":"abcdefghijklmnopqrst"}'
  Invoke-Scenario -Name 'service-role-rejected' -ShouldPass $false `
    -Message 'Only a Supabase anon client key is allowed' -Content @"
SUPABASE_URL=https://abcdefghijklmnopqrst.supabase.co
SUPABASE_ANON_KEY=$header.$payload.signature
"@

  Invoke-Scenario -Name 'prohibited-server-secret-name' -ShouldPass $false `
    -Message 'prohibited key name: GEMINI_API_KEY' -Content @"
SUPABASE_URL=https://abcdefghijklmnopqrst.supabase.co
SUPABASE_ANON_KEY=$validKey
GEMINI_API_KEY=must-not-enter-client-config
"@

  Invoke-Scenario -Name 'http-url-rejected' -ShouldPass $false `
    -Message 'hosted HTTPS Supabase project URL' -Content @"
SUPABASE_URL=http://abcdefghijklmnopqrst.supabase.co
SUPABASE_ANON_KEY=$validKey
"@

  Assert-LoginEntryResponse -StatusCode 401 `
    -Content '{"code":"invalid_credentials"}' `
    -AllowedOrigin 'http://127.0.0.1:5268' `
    -ExpectedOrigin 'http://127.0.0.1:5268'
  $passed++
  Write-Host 'PASS login-entry-valid'

  if (-not (Assert-LoginContractVersion -ActualVersion '2026-10-18.1' `
      -RequireCurrentContract)) {
    throw 'Current login contract should pass.'
  }
  $passed++
  Write-Host 'PASS login-contract-current'

  $legacy = Assert-LoginContractVersion -ActualVersion ''
  if ($legacy) {
    throw 'Legacy login contract should warn without passing.'
  }
  $passed++
  Write-Host 'PASS login-contract-legacy-warning'

  $rejected = $false
  try {
    Assert-LoginContractVersion -ActualVersion '' `
      -RequireCurrentContract | Out-Null
  } catch { $rejected = $true }
  if (-not $rejected) { throw 'Strict login contract should reject a missing version.' }
  $passed++
  Write-Host 'PASS login-contract-legacy-strict'

  $output = & $shell -NoProfile -File $runner `
    -ConfigPath (Join-Path $temp 'publishable-key.env') `
    -ValidateOnly -SkipRemoteProbe -RequireCurrentAuthContract 2>&1
  if ($LASTEXITCODE -eq 0 -or
      ($output -join ' ') -notmatch 'cannot be required while the remote probe is skipped') {
    throw 'Strict login contract must not allow a skipped remote probe.'
  }
  $passed++
  Write-Host 'PASS login-contract-no-probe-bypass'

  foreach ($case in @(
    @{ Name = 'login-entry-missing'; Status = 404; Content = '{}'; Origin = 'http://127.0.0.1:5268' },
    @{ Name = 'login-entry-wrong-code'; Status = 401; Content = '{"code":"other"}'; Origin = 'http://127.0.0.1:5268' },
    @{ Name = 'login-entry-wrong-cors'; Status = 401; Content = '{"code":"invalid_credentials"}'; Origin = 'http://localhost:3000' }
  )) {
    $failed = $false
    try {
      Assert-LoginEntryResponse -StatusCode $case.Status `
        -Content $case.Content -AllowedOrigin $case.Origin `
        -ExpectedOrigin 'http://127.0.0.1:5268'
    } catch { $failed = $true }
    if (-not $failed) { throw "$($case.Name) should fail." }
    $passed++
    Write-Host "PASS $($case.Name)"
  }

  Write-Host "Connected preview launcher tests: PASS ($passed scenarios)."
} finally {
  $env:SUPABASE_URL = $originalUrl
  $env:SUPABASE_ANON_KEY = $originalKey
  Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
