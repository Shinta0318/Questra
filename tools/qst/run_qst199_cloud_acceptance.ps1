[CmdletBinding()]
param(
  [ValidatePattern('^[a-z0-9]{20}$')]
  [string]$ProjectRef = 'dhbmgwarnrtelrcrmmfk',
  [string]$SupabaseCommand = 'supabase',
  [switch]$CleanupOnly
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $repoRoot

if (-not (Get-Command $SupabaseCommand -ErrorAction SilentlyContinue)) {
  throw "Supabase CLI was not found: $SupabaseCommand"
}
if (-not (Get-Command dart -ErrorAction SilentlyContinue)) {
  throw 'Dart CLI was not found.'
}

$keyJson = & $SupabaseCommand projects api-keys --project-ref $ProjectRef 2>$null |
  Out-String |
  ConvertFrom-Json
$anonKey = ($keyJson.keys | Where-Object { $_.name -eq 'anon' }).api_key
$serviceRoleKey = (
  $keyJson.keys | Where-Object { $_.name -eq 'service_role' }
).api_key
if ([string]::IsNullOrWhiteSpace($anonKey) -or
    [string]::IsNullOrWhiteSpace($serviceRoleKey)) {
  throw 'Required anon or service_role key was not returned.'
}

$runId = [Guid]::NewGuid().ToString('N')
$accountAEmail = "qst199-a-$runId@example.test"
$accountBEmail = "qst199-b-$runId@example.test"
$accountAPassword = "Qst!A-$([Guid]::NewGuid().ToString('N'))"
$accountBPassword = "Qst!B-$([Guid]::NewGuid().ToString('N'))"
$projectUrl = "https://$ProjectRef.supabase.co"
$adminHeaders = @{
  apikey = $serviceRoleKey
  Authorization = "Bearer $serviceRoleKey"
}
$accountAId = $null
$accountBId = $null
$environmentNames = @(
  'SUPABASE_URL',
  'SUPABASE_ANON_KEY',
  'QST_BETA_ACCOUNT_A_EMAIL',
  'QST_BETA_ACCOUNT_A_PASSWORD',
  'QST_BETA_ACCOUNT_B_EMAIL',
  'QST_BETA_ACCOUNT_B_PASSWORD'
)
$previousEnvironment = @{}
foreach ($name in $environmentNames) {
  $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable(
    $name,
    'Process'
  )
}

function New-QstUser {
  param(
    [string]$Email,
    [string]$Password,
    [string]$Nickname
  )
  $body = @{
    email = $Email
    password = $Password
    email_confirm = $true
    user_metadata = @{ nickname = $Nickname }
  } | ConvertTo-Json -Depth 4
  return Invoke-RestMethod `
    -Uri "$projectUrl/auth/v1/admin/users" `
    -Method Post `
    -Headers $adminHeaders `
    -ContentType 'application/json' `
    -Body $body
}

function Remove-Qst199Users {
  $usersResponse = Invoke-RestMethod `
    -Uri "$projectUrl/auth/v1/admin/users?per_page=1000" `
    -Method Get `
    -Headers $adminHeaders
  foreach ($user in $usersResponse.users) {
    if ($user.email -like 'qst199-*@example.test') {
      Invoke-RestMethod `
        -Uri "$projectUrl/auth/v1/admin/users/$($user.id)?should_soft_delete=false" `
        -Method Delete `
        -Headers $adminHeaders | Out-Null
    }
  }
}

if ($CleanupOnly) {
  Remove-Qst199Users
  Write-Host 'Residual QST-199 accounts were removed.'
  exit 0
}

try {
  $accountA = New-QstUser `
    -Email $accountAEmail `
    -Password $accountAPassword `
    -Nickname 'QST199 Navigator A'
  $accountAId = $accountA.id
  $accountB = New-QstUser `
    -Email $accountBEmail `
    -Password $accountBPassword `
    -Nickname 'QST199 Navigator B'
  $accountBId = $accountB.id

  $env:SUPABASE_URL = $projectUrl
  $env:SUPABASE_ANON_KEY = $anonKey
  $env:QST_BETA_ACCOUNT_A_EMAIL = $accountAEmail
  $env:QST_BETA_ACCOUNT_A_PASSWORD = $accountAPassword
  $env:QST_BETA_ACCOUNT_B_EMAIL = $accountBEmail
  $env:QST_BETA_ACCOUNT_B_PASSWORD = $accountBPassword

  dart run tools/qst/run_dual_account_persistence.dart
  if ($LASTEXITCODE -ne 0) {
    throw "Dual-account acceptance failed with exit code $LASTEXITCODE."
  }
} finally {
  foreach ($accountId in @($accountAId, $accountBId)) {
    if (-not [string]::IsNullOrWhiteSpace($accountId)) {
      try {
        Invoke-RestMethod `
          -Uri "$projectUrl/auth/v1/admin/users/${accountId}?should_soft_delete=false" `
          -Method Delete `
          -Headers $adminHeaders | Out-Null
      } catch {
        Write-Warning 'An ephemeral QST-199 account needs manual cleanup.'
      }
    }
  }
  try {
    Remove-Qst199Users
  } catch {
    Write-Warning 'Residual QST-199 account scan needs manual review.'
  }
  foreach ($name in $environmentNames) {
    [Environment]::SetEnvironmentVariable(
      $name,
      $previousEnvironment[$name],
      'Process'
    )
  }
  $anonKey = $null
  $serviceRoleKey = $null
  $accountAEmail = $null
  $accountBEmail = $null
  $accountAPassword = $null
  $accountBPassword = $null
}

Write-Host 'QST-199 ephemeral accounts were removed.'
