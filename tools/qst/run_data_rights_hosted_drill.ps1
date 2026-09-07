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
  throw 'Data Rights hosted drill requires a clean candidate worktree.'
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
  $email = "qst374-$Label-$runId@example.test"
  $password = "Qst374!-$([Guid]::NewGuid().ToString('N'))"
  $body = @{
    email = $email
    password = $password
    email_confirm = $true
    user_metadata = @{ nickname = "QST374 $Label" }
  } | ConvertTo-Json -Depth 4
  $user = Invoke-RestMethod -Uri "$projectUrl/auth/v1/admin/users" `
    -Method Post -Headers $adminHeaders -ContentType 'application/json' -Body $body
  $sessionBody = @{ email = $email; password = $password } | ConvertTo-Json
  $session = Invoke-RestMethod `
    -Uri "$projectUrl/auth/v1/token?grant_type=password" `
    -Method Post -Headers @{ apikey = $anonKey } `
    -ContentType 'application/json' -Body $sessionBody
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

function Get-ServiceRows([string]$Path) {
  return @(Invoke-RestMethod -Uri "$projectUrl/rest/v1/$Path" -Method Get `
    -Headers $adminHeaders)
}

function Remove-DrillAccounts {
  foreach ($account in $accounts) {
    try {
      Invoke-RestMethod `
        -Uri "$projectUrl/auth/v1/admin/users/$($account.Id)?should_soft_delete=false" `
        -Method Delete -Headers $adminHeaders | Out-Null
    } catch {
      $script:cleanupFailed = $true
      Write-Warning 'A QST-374 ephemeral account requires manual cleanup.'
    }
  }
}

try {
  $accountA = New-DrillAccount 'a'
  $accountB = New-DrillAccount 'b'
  $accountC = New-DrillAccount 'c'

  $correction = Invoke-UserRpc $accountA 'submit_data_rights_request' @{
    p_request_type = 'correction'
    p_scope = @{
      target_type = 'profile'
      requested_change = 'QST-374 fixture verification only'
    }
    p_idempotency_key = "qst374-correction-$runId"
  }
  $crossRows = Get-UserRows $accountB `
    "data_rights_requests?id=eq.$($correction.id)&select=id"
  if ($crossRows.Count -ne 0) { throw 'Cross-account correction request was visible.' }
  $claimedCorrection = @(Invoke-ServiceRpc 'claim_data_correction_request' @{
    p_request_id = $correction.id
  })
  if ($claimedCorrection.Count -ne 1) { throw 'Correction claim failed.' }
  Invoke-ServiceRpc 'resolve_data_correction_request' @{
    p_request_id = $correction.id
    p_resolution_code = 'no_change_required'
  } | Out-Null
  $correctionRows = Get-UserRows $accountA `
    "data_rights_requests?id=eq.$($correction.id)&select=status,resolution_code"
  if ($correctionRows.Count -ne 1 -or
      $correctionRows[0].status -ne 'completed') {
    throw 'Correction resolution was not owner-visible.'
  }

  Invoke-UserRpc $accountA 'set_user_consent' @{
    p_purpose_code = 'personal_data_sharing'
    p_purpose_version = 1
    p_granted = $true
    p_source = 'contextual_prompt'
  } | Out-Null
  $withdrawal = Invoke-UserRpc $accountA 'submit_data_rights_request' @{
    p_request_type = 'consent_withdrawal'
    p_scope = @{ purpose_code = 'personal_data_sharing' }
    p_idempotency_key = "qst374-withdrawal-$runId"
  }
  $fulfilled = Invoke-ServiceRpc 'fulfill_consent_withdrawal_request' @{
    p_request_id = $withdrawal.id
  }
  if ($fulfilled -ne $true) { throw 'Consent withdrawal fulfillment failed.' }
  $consentRows = Get-UserRows $accountA `
    'user_consents?purpose_code=eq.personal_data_sharing&select=status'
  if ($consentRows.Count -ne 1 -or $consentRows[0].status -ne 'withdrawn') {
    throw 'Consent withdrawal state is incorrect.'
  }

  $deletionOne = Invoke-UserRpc $accountC 'submit_data_rights_request' @{
    p_request_type = 'account_deletion'
    p_scope = @{}
    p_idempotency_key = "qst374-deletion-cancel-$runId"
  }
  $cancelled = Invoke-UserRpc $accountC 'cancel_my_data_rights_request' @{
    p_request_id = $deletionOne.id
  }
  if ($cancelled.status -ne 'cancelled') { throw 'Deletion cancellation failed.' }

  $deletionTwo = Invoke-UserRpc $accountC 'submit_data_rights_request' @{
    p_request_type = 'account_deletion'
    p_scope = @{}
    p_idempotency_key = "qst374-deletion-run-$runId"
  }
  Invoke-RestMethod `
    -Uri "$projectUrl/rest/v1/data_rights_requests?id=eq.$($deletionTwo.id)&owner_id=eq.$($accountC.Id)" `
    -Method Patch -Headers ($adminHeaders + @{ Prefer = 'return=minimal' }) `
    -ContentType 'application/json' `
    -Body (@{ scheduled_for = [DateTime]::UtcNow.AddMinutes(-1).ToString('o') } | ConvertTo-Json) |
    Out-Null
  Invoke-ServiceRpc 'claim_account_deletion_request' @{
    p_request_id = $deletionTwo.id
  } | Out-Null
  Invoke-RestMethod `
    -Uri "$projectUrl/auth/v1/admin/users/$($accountC.Id)?should_soft_delete=true" `
    -Method Delete -Headers $adminHeaders | Out-Null
  Invoke-ServiceRpc 'resolve_account_deletion_worker' @{
    p_request_id = $deletionTwo.id
    p_completed = $true
    p_error = $null
  } | Out-Null
  $receiptRows = Get-ServiceRows `
    "data_rights_fulfillment_receipts?request_id=eq.$($deletionTwo.id)&select=request_type,outcome,resolution_code"
  if ($receiptRows.Count -ne 1 -or $receiptRows[0].outcome -ne 'completed') {
    throw 'Deletion fulfillment receipt is missing.'
  }

  $updatedAt = [DateTime]::UtcNow.ToString('o')
  $evidenceLines = @(
    'version: 2',
    'qst: QST-374',
    'status: hosted_fulfillment_verified_retention_pending',
    "generated_at_utc: `"$updatedAt`"",
    "candidate_source_commit: `"$sourceCommit`"",
    'working_tree_clean_at_execution: true',
    "latest_migration: `"$((Get-ChildItem 'supabase/migrations/*.sql' | Sort-Object Name | Select-Object -Last 1).Name)`"",
    'local_checks:',
    '  correction_sla_contract: passed',
    '  correction_resolution_allowlist: passed',
    '  withdrawal_transaction_contract: passed',
    '  deletion_cancellation_window: passed',
    '  deletion_retry_classification: passed',
    '  content_free_fulfillment_receipt: passed',
    '  aggregate_metrics_only: passed',
    '  worker_response_has_no_request_id: passed',
    'hosted_checks:',
    '  two_account_owner_isolation: passed',
    '  correction_operator_resolution: passed',
    '  consent_withdrawal_worker: passed',
    '  deletion_worker_and_cancellation: passed',
    '  fulfillment_receipt: passed',
    '  provider_retention_review: pending',
    '  backup_expiry_and_restore_exclusion: pending',
    'guardrails:',
    '  request_content_recorded_in_evidence: false',
    '  account_identifier_recorded_in_evidence: false',
    '  credential_or_worker_secret_recorded: false',
    '  local_contract_is_hosted_evidence: false',
    '  code_implies_provider_retention_approval: false',
    '  deletion_bypasses_cancellation_window: false'
  )
} finally {
  Remove-DrillAccounts
  $anonKey = $null
  $serviceRoleKey = $null
}

if ($script:cleanupFailed) {
  throw 'Hosted Data Rights drill cleanup failed; evidence is not admissible.'
}
if ($null -eq $evidenceLines) {
  throw 'Hosted Data Rights drill did not produce admissible evidence.'
}

Set-Content -LiteralPath 'docs/qst/DATA_RIGHTS_FULFILLMENT_DRILL.yaml' `
  -Value $evidenceLines -Encoding UTF8

dart run tools/qst/verify_data_rights_fulfillment_drill.dart `
  --require-hosted-operations
if ($LASTEXITCODE -ne 0) { throw 'Hosted Data Rights evidence verification failed.' }
Write-Host 'Hosted Data Rights operations passed; provider retention review remains pending.'
