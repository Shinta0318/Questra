[CmdletBinding()]
param(
  [string]$ProjectRef = 'tpynzjjqajpkzivgapfq',
  [string]$SupabaseCommand = 'supabase'
)

$ErrorActionPreference = 'Stop'
if ($ProjectRef -ne 'tpynzjjqajpkzivgapfq') {
  throw 'This smoke test is restricted to the isolated validation project.'
}
if (-not (Get-Command $SupabaseCommand -ErrorAction SilentlyContinue)) {
  throw 'Supabase CLI was not found.'
}

. "$PSScriptRoot/hosted_auth_fixture.ps1"
$keys = Get-HostedApiKeys -SupabaseCommand $SupabaseCommand -ProjectRef $ProjectRef
$projectUrl = "https://$ProjectRef.supabase.co"
$adminHeaders = @{
  apikey = $keys.ServiceRoleKey
  Authorization = "Bearer $($keys.ServiceRoleKey)"
}
$metadata = Get-HostedLegalFixtureMetadata `
  -ProjectUrl $projectUrl -AdminHeaders $adminHeaders
$accountId = $null
$cleanupFailed = $false

try {
  $suffix = [Guid]::NewGuid().ToString('N')
  $email = "qst-arc-smoke-$suffix@example.test"
  $password = "Qst!$suffix"
  $account = Invoke-RestMethod -Uri "$projectUrl/auth/v1/admin/users" `
    -Method Post -Headers $adminHeaders -ContentType 'application/json' `
    -Body (@{
      email = $email
      password = $password
      email_confirm = $true
      user_metadata = $metadata + @{ nickname = 'Arc smoke test' }
    } | ConvertTo-Json -Depth 4)
  $accountId = [string]$account.id
  if ([string]::IsNullOrWhiteSpace($accountId)) {
    throw 'Test account creation returned no user ID.'
  }

  $accepted = Invoke-RestMethod `
    -Uri "$projectUrl/rest/v1/rpc/has_current_ai_legal_acceptance" `
    -Method Post -Headers $adminHeaders -ContentType 'application/json' `
    -Body (@{ p_user_id = $accountId } | ConvertTo-Json)
  if ($accepted -ne $true) {
    throw 'Test account has no current AI legal acceptance.'
  }

  $session = Invoke-RestMethod `
    -Uri "$projectUrl/auth/v1/token?grant_type=password" `
    -Method Post -Headers @{ apikey = $keys.AnonKey } `
    -ContentType 'application/json' `
    -Body (@{ email = $email; password = $password } | ConvertTo-Json)
  if ([string]::IsNullOrWhiteSpace([string]$session.access_token)) {
    throw 'Test account sign-in returned no access token.'
  }

  $response = Invoke-RestMethod -Uri "$projectUrl/functions/v1/arc-chat" `
    -Method Post -Headers @{
      apikey = $keys.AnonKey
      Authorization = "Bearer $($session.access_token)"
    } -ContentType 'application/json; charset=utf-8' `
    -Body (@{
      message = 'シンガポールに行きたい。最初に何を考えればいい？'
      history = @()
    } | ConvertTo-Json -Depth 3)
  $sourceType = [string]$response.source_type
  Write-Host "Arc smoke response source: $sourceType"
  if ($sourceType -ne 'gemini_interactions') {
    throw 'Arc did not return a provider-backed response.'
  }
  if ([string]::IsNullOrWhiteSpace([string]$response.message)) {
    throw 'Arc returned an empty message.'
  }
  Write-Host 'Free-tier Arc provider smoke: PASS (response text omitted).'
} finally {
  if ($accountId) {
    try {
      Invoke-RestMethod `
        -Uri "$projectUrl/auth/v1/admin/users/${accountId}?should_soft_delete=false" `
        -Method Delete -Headers $adminHeaders | Out-Null
    } catch {
      $cleanupFailed = $true
    }
  }
  $password = $null
  $session = $null
  $keys = $null
  if ($cleanupFailed) {
    throw 'Test account cleanup failed; inspect the validation project.'
  }
}
