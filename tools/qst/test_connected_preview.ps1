Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$runner = Join-Path $PSScriptRoot 'run_connected_preview.ps1'
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

  Write-Host "Connected preview launcher tests: PASS ($passed scenarios)."
} finally {
  $env:SUPABASE_URL = $originalUrl
  $env:SUPABASE_ANON_KEY = $originalKey
  Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
