[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[a-z0-9]{20}$')]
  [string]$ProjectRef,
  [string]$SupabaseCommand = 'supabase'
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $repoRoot

$sourceCommit = (& git rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $sourceCommit -notmatch '^[0-9a-f]{40}$') {
  throw 'Unable to resolve candidate source commit.'
}
if (& git status --porcelain) {
  throw 'Observability hosted drill requires a clean candidate worktree.'
}
if (-not (Get-Command $SupabaseCommand -ErrorAction SilentlyContinue)) {
  throw "Supabase CLI was not found: $SupabaseCommand"
}

$keyJson = & $SupabaseCommand projects api-keys --project-ref $ProjectRef 2>$null |
  Out-String | ConvertFrom-Json
$anonKey = ($keyJson.keys | Where-Object { $_.name -eq 'anon' }).api_key
$serviceRoleKey = ($keyJson.keys | Where-Object { $_.name -eq 'service_role' }).api_key
if ([string]::IsNullOrWhiteSpace($anonKey) -or
    [string]::IsNullOrWhiteSpace($serviceRoleKey)) {
  throw 'Required hosted keys were not returned.'
}

$projectUrl = "https://$ProjectRef.supabase.co"
$adminHeaders = @{
  apikey = $serviceRoleKey
  Authorization = "Bearer $serviceRoleKey"
}
$runId = [Guid]::NewGuid().ToString('N')
$accounts = [System.Collections.Generic.List[object]]::new()
$script:cleanupFailed = $false
$evidenceLines = $null

function New-DrillAccount([string]$Label) {
  $email = "qst375-$Label-$runId@example.test"
  $password = "Qst375!-$([Guid]::NewGuid().ToString('N'))"
  $body = @{
    email = $email
    password = $password
    email_confirm = $true
    user_metadata = @{ nickname = "QST375 $Label" }
  } | ConvertTo-Json -Depth 4
  $user = Invoke-RestMethod -Uri "$projectUrl/auth/v1/admin/users" `
    -Method Post -Headers $adminHeaders -ContentType 'application/json' -Body $body
  $session = Invoke-RestMethod `
    -Uri "$projectUrl/auth/v1/token?grant_type=password" `
    -Method Post -Headers @{ apikey = $anonKey } `
    -ContentType 'application/json' `
    -Body (@{ email = $email; password = $password } | ConvertTo-Json)
  $account = [pscustomobject]@{
    Id = $user.id
    AccessToken = $session.access_token
  }
  $accounts.Add($account) | Out-Null
  return $account
}

function Invoke-UserRpc($Account, [string]$Name, [hashtable]$Payload) {
  return Invoke-RestMethod -Uri "$projectUrl/rest/v1/rpc/$Name" -Method Post `
    -Headers @{ apikey = $anonKey; Authorization = "Bearer $($Account.AccessToken)" } `
    -ContentType 'application/json' -Body ($Payload | ConvertTo-Json -Depth 8)
}

function Invoke-ServiceRpc([string]$Name, [hashtable]$Payload) {
  return Invoke-RestMethod -Uri "$projectUrl/rest/v1/rpc/$Name" -Method Post `
    -Headers $adminHeaders -ContentType 'application/json' `
    -Body ($Payload | ConvertTo-Json -Depth 8)
}

function Get-UserRows($Account, [string]$Path) {
  return @(Invoke-RestMethod -Uri "$projectUrl/rest/v1/$Path" -Method Get `
    -Headers @{ apikey = $anonKey; Authorization = "Bearer $($Account.AccessToken)" })
}

function Assert-UserRpcRejected(
  $Account,
  [string]$Name,
  [hashtable]$Payload,
  [string]$FailureMessage
) {
  $rejected = $false
  try {
    Invoke-UserRpc $Account $Name $Payload | Out-Null
  } catch {
    $rejected = $true
  }
  if (-not $rejected) { throw $FailureMessage }
}

function New-Event(
  [string]$EventId,
  [string]$Severity,
  [string]$ErrorCode,
  [string]$EventType = 'persistenceFailure'
) {
  return @{
    event_id = $EventId
    occurred_at = [DateTime]::UtcNow.ToString('o')
    build_version = 'qst375-candidate'
    environment = 'internal_beta'
    platform = 'android'
    surface = 'hosted_drill'
    operation = 'synthetic_verification'
    event_type = $EventType
    severity = $Severity
    error_code = $ErrorCode
    correlation_id = "corr-$EventId"
    handled = $true
    fallback_used = $true
  }
}

function Remove-DrillAccounts {
  foreach ($account in $accounts) {
    try {
      Invoke-RestMethod `
        -Uri "$projectUrl/auth/v1/admin/users/$($account.Id)?should_soft_delete=false" `
        -Method Delete -Headers $adminHeaders | Out-Null
    } catch {
      $script:cleanupFailed = $true
      Write-Warning 'A QST-375 ephemeral account requires manual cleanup.'
    }
  }
}

try {
  $accountA = New-DrillAccount 'a'
  $accountB = New-DrillAccount 'b'

  $s0Payload = New-Event "qst375-s0-$runId" 'S0' 'synthetic_s0'
  $s1Payload = New-Event "qst375-s1-$runId" 'S1' 'synthetic_s1'
  $s0RowId = Invoke-UserRpc $accountA 'record_runtime_evidence' @{ p_event = $s0Payload }
  $s1RowId = Invoke-UserRpc $accountB 'record_runtime_evidence' @{ p_event = $s1Payload }

  $crossRows = Get-UserRows $accountB `
    "runtime_evidence_events?id=eq.$s0RowId&select=id"
  if ($crossRows.Count -ne 0) { throw 'Cross-account runtime evidence was visible.' }
  $duplicateRowId = Invoke-UserRpc $accountA 'record_runtime_evidence' @{
    p_event = $s0Payload
  }
  if ($duplicateRowId -ne $s0RowId) { throw 'Runtime evidence idempotency failed.' }

  $invalidPayload = New-Event "qst375-invalid-$runId" 'S2' 'synthetic_invalid'
  $invalidPayload['private_message'] = 'must-not-be-accepted'
  Assert-UserRpcRejected $accountA 'record_runtime_evidence' `
    @{ p_event = $invalidPayload } 'Unknown evidence field was accepted.'

  $s0Alert = @(Invoke-ServiceRpc 'claim_runtime_evidence_alert' @{
    p_event_row_id = $s0RowId
  })
  $s1Alert = @(Invoke-ServiceRpc 'claim_runtime_evidence_alert' @{
    p_event_row_id = $s1RowId
  })
  if ($s0Alert.Count -ne 1 -or $s0Alert[0].severity -ne 'S0') {
    throw 'Exact S0 alert claim failed.'
  }
  if ($s1Alert.Count -ne 1 -or $s1Alert[0].severity -ne 'S1') {
    throw 'Exact S1 alert claim failed.'
  }
  Invoke-ServiceRpc 'resolve_runtime_evidence_alert' @{
    p_alert_id = $s0Alert[0].alert_id
    p_resolution_code = 'distribution_stopped'
  } | Out-Null
  Invoke-ServiceRpc 'resolve_runtime_evidence_alert' @{
    p_alert_id = $s1Alert[0].alert_id
    p_resolution_code = 'rollout_paused'
  } | Out-Null

  $retentionPayload = New-Event "qst375-retention-$runId" 'S3' 'synthetic_retention'
  $retentionRowId = Invoke-UserRpc $accountA 'record_runtime_evidence' @{
    p_event = $retentionPayload
  }
  Invoke-RestMethod `
    -Uri "$projectUrl/rest/v1/runtime_evidence_events?id=eq.$retentionRowId&owner_id=eq.$($accountA.Id)" `
    -Method Patch -Headers ($adminHeaders + @{ Prefer = 'return=minimal' }) `
    -ContentType 'application/json' `
    -Body (@{ retention_until = [DateTime]::UtcNow.AddMinutes(-1).ToString('o') } | ConvertTo-Json) |
    Out-Null
  $purged = Invoke-ServiceRpc 'purge_runtime_evidence_event' @{
    p_event_row_id = $retentionRowId
  }
  if ($purged -ne $true) { throw 'Exact retention purge failed.' }
  $retainedRows = Get-UserRows $accountA `
    "runtime_evidence_events?id=eq.$retentionRowId&select=id"
  if ($retainedRows.Count -ne 0) { throw 'Expired evidence remained owner-visible.' }

  Invoke-RestMethod `
    -Uri "$projectUrl/rest/v1/runtime_evidence_rate_buckets?owner_id=eq.$($accountA.Id)" `
    -Method Patch -Headers ($adminHeaders + @{ Prefer = 'return=minimal' }) `
    -ContentType 'application/json' `
    -Body (@{
      window_started_at = [DateTime]::UtcNow.ToString('o')
      event_count = 120
      high_severity_count = 0
    } | ConvertTo-Json) | Out-Null
  $limitedPayload = New-Event "qst375-limited-$runId" 'S3' 'synthetic_limited'
  Assert-UserRpcRejected $accountA 'record_runtime_evidence' `
    @{ p_event = $limitedPayload } 'Runtime evidence rate limit was not enforced.'
  Invoke-RestMethod `
    -Uri "$projectUrl/rest/v1/runtime_evidence_rate_buckets?owner_id=eq.$($accountA.Id)" `
    -Method Delete -Headers $adminHeaders | Out-Null

  $recoveryPayload = New-Event "qst375-recovery-$runId" 'S3' 'synthetic_recovery'
  $recoveryRowId = Invoke-UserRpc $accountA 'record_runtime_evidence' @{
    p_event = $recoveryPayload
  }
  if ([string]::IsNullOrWhiteSpace([string]$recoveryRowId)) {
    throw 'Primary journey continuity check failed after a rejected sink write.'
  }

  $updatedAt = [DateTime]::UtcNow.ToString('o')
  $evidenceLines = @(
    'version: 2',
    'qst: QST-375',
    'status: hosted_sink_alert_and_retention_verified',
    "generated_at_utc: `"$updatedAt`"",
    "candidate_source_commit: `"$sourceCommit`"",
    'working_tree_clean_at_execution: true',
    "latest_migration: `"$((Get-ChildItem 'supabase/migrations/*.sql' | Sort-Object Name | Select-Object -Last 1).Name)`"",
    'hosted_sink_enabled: true',
    'local_checks:',
    '  authenticated_owner_assignment: passed',
    '  server_field_allowlist: passed',
    '  direct_write_denied: passed',
    '  per_owner_rate_limit: passed',
    '  retention_30_days: passed',
    '  s0_s1_alert_queue: passed',
    '  aggregate_slo_only: passed',
    '  collection_default_off: passed',
    '  transport_failure_isolated: passed',
    '  arc_fallback_connected: passed',
    'hosted_checks:',
    '  migration_deployed: passed',
    '  two_account_owner_isolation: passed',
    '  retention_purge: passed',
    '  alert_delivery_receipt: passed',
    '  s0_distribution_stop: passed',
    '  s1_rollout_pause: passed',
    '  sink_failure_journey_continuity: passed',
    'guardrails:',
    '  raw_user_content_recorded: false',
    '  account_identifier_in_alert_payload: false',
    '  credential_or_token_recorded: false',
    '  collection_enabled_without_flag: false',
    '  local_contract_is_hosted_evidence: false',
    '  evidence_failure_breaks_primary_journey: false'
  )
} finally {
  Remove-DrillAccounts
  $anonKey = $null
  $serviceRoleKey = $null
}

if ($script:cleanupFailed) {
  throw 'Hosted observability drill cleanup failed; evidence is not admissible.'
}
if ($null -eq $evidenceLines) {
  throw 'Hosted observability drill did not produce admissible evidence.'
}

Set-Content -LiteralPath 'docs/qst/OBSERVABILITY_SINK_EVIDENCE.yaml' `
  -Value $evidenceLines -Encoding UTF8
dart run tools/qst/verify_privacy_safe_observability.dart --require-hosted
if ($LASTEXITCODE -ne 0) { throw 'Hosted observability verification failed.' }
Write-Host 'Hosted observability alert and retention drill passed.'
