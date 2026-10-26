[CmdletBinding()]
param(
  [string]$ProjectRef = 'tpynzjjqajpkzivgapfq',
  [string]$SupabaseCommand = 'supabase',
  [string]$DenoCommand = 'deno'
)

$ErrorActionPreference = 'Stop'
if ($ProjectRef -ne 'tpynzjjqajpkzivgapfq') {
  throw 'This synthetic test is restricted to the isolated validation project.'
}
if (-not (Get-Command $SupabaseCommand -ErrorAction SilentlyContinue) -or
    -not (Get-Command $DenoCommand -ErrorAction SilentlyContinue)) {
  throw 'Supabase CLI and Deno must be available.'
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
. "$PSScriptRoot/hosted_auth_fixture.ps1"
$keys = Get-HostedApiKeys -SupabaseCommand $SupabaseCommand -ProjectRef $ProjectRef
$projectUrl = "https://$ProjectRef.supabase.co"
$adminHeaders = @{
  apikey = $keys.ServiceRoleKey
  Authorization = "Bearer $($keys.ServiceRoleKey)"
}
$metadata = Get-HostedLegalFixtureMetadata `
  -ProjectUrl $projectUrl -AdminHeaders $adminHeaders
$environmentNames = @(
  'SUPABASE_URL', 'SUPABASE_SERVICE_ROLE_KEY',
  'QST_CHECKPOINT_OWNER_A', 'QST_CHECKPOINT_OWNER_B',
  'QST_CHECKPOINT_QUEST_A', 'QST_CHECKPOINT_QUEST_B'
)
$previousEnvironment = @{}
foreach ($name in $environmentNames) {
  $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}
$accountIds = @()
$questIds = @()
$cleanupFailed = $false

try {
  foreach ($label in @('a', 'b')) {
    $suffix = [Guid]::NewGuid().ToString('N')
    $body = @{
      email = "qst-checkpoint-$label-$suffix@example.test"
      password = "Qst!$suffix"
      email_confirm = $true
      user_metadata = $metadata + @{ nickname = "Checkpoint $label" }
    } | ConvertTo-Json -Depth 4
    $account = Invoke-RestMethod -Uri "$projectUrl/auth/v1/admin/users" `
      -Method Post -Headers $adminHeaders -ContentType 'application/json' `
      -Body $body
    $accountIds += [string]$account.id
    $questId = [Guid]::NewGuid().ToString()
    $questIds += $questId
    $questBody = @{
      id = $questId
      owner_id = $account.id
      title = 'Synthetic checkpoint Quest'
      description = 'Disposable validation fixture'
      status = 'active'
      visibility = 'private'
    } | ConvertTo-Json -Depth 3
    Invoke-RestMethod -Uri "$projectUrl/rest/v1/quests" `
      -Method Post -Headers $adminHeaders -ContentType 'application/json' `
      -Body $questBody | Out-Null
  }

  $env:SUPABASE_URL = $projectUrl
  $env:SUPABASE_SERVICE_ROLE_KEY = $keys.ServiceRoleKey
  $env:QST_CHECKPOINT_OWNER_A = $accountIds[0]
  $env:QST_CHECKPOINT_OWNER_B = $accountIds[1]
  $env:QST_CHECKPOINT_QUEST_A = $questIds[0]
  $env:QST_CHECKPOINT_QUEST_B = $questIds[1]
  & $DenoCommand test --allow-env `
    "--allow-net=$ProjectRef.supabase.co,deno.land" `
    (Join-Path $repoRoot 'supabase/functions/_shared/quest_planning/pass_checkpoint_hosted_test.ts')
  if ($LASTEXITCODE -ne 0) { throw 'Hosted planning checkpoint test failed.' }
} finally {
  foreach ($questId in $questIds) {
    try {
      Invoke-RestMethod -Uri "$projectUrl/rest/v1/quests?id=eq.$questId" `
        -Method Delete -Headers $adminHeaders | Out-Null
    } catch { $cleanupFailed = $true }
  }
  foreach ($accountId in $accountIds) {
    try {
      Invoke-RestMethod `
        -Uri "$projectUrl/auth/v1/admin/users/${accountId}?should_soft_delete=false" `
        -Method Delete -Headers $adminHeaders | Out-Null
    } catch { $cleanupFailed = $true }
  }
  foreach ($name in $environmentNames) {
    [Environment]::SetEnvironmentVariable(
      $name, $previousEnvironment[$name], 'Process'
    )
  }
  $keys = $null
  if ($cleanupFailed) { throw 'Synthetic fixture cleanup needs manual review.' }
}

Write-Host 'Hosted checkpoint reuse and account isolation passed; fixtures removed.'
