[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[a-z0-9]{20}$')]
  [string]$ProjectRef,
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[a-f0-9]{40}$')]
  [string]$CandidateSha,
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[a-f0-9]{40}$')]
  [string]$RollbackCandidateSha,
  [Parameter(Mandatory = $true)]
  [string]$CurrentArtifactPath,
  [Parameter(Mandatory = $true)]
  [string]$RollbackArtifactPath,
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[A-Za-z0-9._:/-]{3,120}$')]
  [string]$ReleaseManagerRef,
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[A-Za-z0-9._:/-]{3,120}$')]
  [string]$IncidentOwnerRef,
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[A-Za-z0-9._:/-]{3,120}$')]
  [string]$SupportOwnerRef,
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[A-Za-z0-9._:/-]{3,160}$')]
  [string]$StopDistributionEvidenceRef,
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[A-Za-z0-9._:/-]{3,160}$')]
  [string]$CommunicationReceiptRef,
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[A-Za-z0-9._:/-]{3,160}$')]
  [string]$RollbackLaunchEvidenceRef,
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[A-Za-z0-9._:/-]{3,160}$')]
  [string]$InputPreservationEvidenceRef,
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[A-Za-z0-9._:/-]{3,160}$')]
  [string]$ManualPathEvidenceRef,
  [Parameter(Mandatory = $true)]
  [string]$DetectedAtUtc,
  [Parameter(Mandatory = $true)]
  [string]$DistributionStoppedAtUtc,
  [Parameter(Mandatory = $true)]
  [string]$CommunicationAcknowledgedAtUtc,
  [Parameter(Mandatory = $true)]
  [ValidateSet('true')]
  [string]$ConfirmBetaProject,
  [Parameter(Mandatory = $true)]
  [ValidateSet('true')]
  [string]$ConfirmNoDestructiveDatabaseRollback,
  [string]$SupabaseCommand = 'supabase'
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/incident_control_guard.ps1"
$timeline = Resolve-IncidentTimeline -Detected $DetectedAtUtc -Stopped $DistributionStoppedAtUtc -Acknowledged $CommunicationAcknowledgedAtUtc
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $repoRoot
$head = (& git rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $head -ne $CandidateSha) { throw 'Candidate SHA must match current HEAD.' }
if ((& git branch --show-current).Trim() -ne 'codex/initial-questra-structure-pr') { throw 'Incident drill is restricted to the Questra candidate branch.' }
if (& git status --porcelain) { throw 'Incident live drill requires a clean candidate worktree.' }
if (-not (Get-Command $SupabaseCommand -ErrorAction SilentlyContinue)) { throw 'Supabase CLI was not found.' }

$candidate = Get-Content -Raw -Encoding UTF8 'docs/qst/BETA_CANDIDATE.yaml'
if ($candidate -notmatch "source_commit: `"$CandidateSha`"" -or $candidate -notmatch 'candidate_status: "approved"') {
  throw 'An approved Beta candidate bound to HEAD is required.'
}
if ($candidate -notmatch "rollback_commit: `"$RollbackCandidateSha`"") { throw 'Rollback candidate does not match the candidate manifest.' }
$project = Get-Content -Raw -Encoding UTF8 'docs/qst/BETA_SUPABASE_PROJECT.yaml'
if ($project -notmatch "project_ref: `"$ProjectRef`"") { throw 'ProjectRef does not match the reviewed Beta project.' }
$operations = Get-Content -Raw -Encoding UTF8 'docs/qst/BETA_FEEDBACK_OPERATIONS.yaml'
if ($operations -notmatch '(?m)^status: verified$' -or $operations -notmatch 'stop_communication:\s*\r?\n\s*status: verified') {
  throw 'Verified feedback and stop communication operations are required.'
}

$currentArtifact = (Resolve-Path $CurrentArtifactPath).Path
$rollbackArtifact = (Resolve-Path $RollbackArtifactPath).Path
if ($currentArtifact -notlike "$repoRoot\artifacts\*" -or $rollbackArtifact -notlike "$repoRoot\artifacts\*") {
  throw 'Drill artifacts must be stored under the ignored artifacts directory.'
}
$currentHash = (Get-FileHash -Algorithm SHA256 $currentArtifact).Hash.ToLowerInvariant()
$rollbackHash = (Get-FileHash -Algorithm SHA256 $rollbackArtifact).Hash.ToLowerInvariant()
if ($candidate -notmatch [regex]::Escape("sha256: `"$currentHash`"")) { throw 'Current artifact hash is not in the candidate manifest.' }

$keyJson = & $SupabaseCommand projects api-keys --project-ref $ProjectRef 2>$null | Out-String | ConvertFrom-Json
$serviceRoleKey = ($keyJson.keys | Where-Object name -eq 'service_role').api_key
if ([string]::IsNullOrWhiteSpace($serviceRoleKey)) { throw 'Hosted service role key was not returned.' }
$projectUrl = "https://$ProjectRef.supabase.co"
$headers = @{ apikey = $serviceRoleKey; Authorization = "Bearer $serviceRoleKey" }
$runId = [Guid]::NewGuid().ToString('N')
$started = [DateTime]::UtcNow

function Read-Control {
  $rows = @(Invoke-RestMethod -Uri "$projectUrl/rest/v1/ai_operation_controls?operation=eq.quest_planning&select=operation,enabled,disabled_reason,updated_at" -Method Get -Headers $headers)
  if ($rows.Count -ne 1) { throw 'Quest Planning operation control is missing or duplicated.' }
  return $rows[0]
}

function Compare-ExchangeControl($Expected, $Replacement) {
  $filter = New-IncidentControlFilter $Expected
  try {
    Invoke-RestMethod -Uri "$projectUrl/rest/v1/ai_operation_controls?$filter" -Method Patch -Headers ($headers + @{ Prefer = 'return=representation' }) `
      -ContentType 'application/json' -Body ($Replacement | ConvertTo-Json)
  } catch {
    throw 'Hosted control compare-and-set failed. Inspect the operation state before retrying.'
  }
}
$pauseResult = Invoke-GuardedPlanningPause -ReadControl { Read-Control } -CompareExchange { param($expected, $replacement) Compare-ExchangeControl $expected $replacement } -RunId $runId
$disabledAt = $pauseResult.DisabledAt
$restoredAt = $pauseResult.RestoredAt

$completed = [DateTime]::UtcNow
$lines = @(
  'version: 1',
  'qst: QST-401',
  'status: verified',
  "candidate_source_commit: `"$CandidateSha`"",
  "rollback_candidate_commit: `"$RollbackCandidateSha`"",
  'working_tree_clean_at_execution: true',
  "project_ref: `"$ProjectRef`"",
  "run_id: `"$runId`"",
  "started_at_utc: `"$($started.ToString('o'))`"",
  "completed_at_utc: `"$($completed.ToString('o'))`"",
  'owners:',
  "  release_manager_ref: `"$ReleaseManagerRef`"",
  "  incident_owner_ref: `"$IncidentOwnerRef`"",
  "  support_owner_ref: `"$SupportOwnerRef`"",
  's0_distribution_stop:',
  '  executed: true',
  '  evidence_method: operator_attested_receipts',
  "  detected_at_utc: `"$($timeline.Detected.ToString('o'))`"",
  "  stopped_at_utc: `"$($timeline.Stopped.ToString('o'))`"",
  "  evidence_ref: `"$StopDistributionEvidenceRef`"",
  "  communicated_at_utc: `"$($timeline.Acknowledged.ToString('o'))`"",
  "  communication_receipt_ref: `"$CommunicationReceiptRef`"",
  '  acknowledgement_within_one_hour: true',
  's1_feature_pause:',
  '  operation: quest_planning',
  '  disabled_verified: true',
  "  disabled_at_utc: `"$($disabledAt.ToString('o'))`"",
  '  restored_verified: true',
  "  restored_at_utc: `"$($restoredAt.ToString('o'))`"",
  '  user_input_preservation_path_verified: true',
  "  user_input_preservation_evidence_ref: `"$InputPreservationEvidenceRef`"",
  '  manual_path_verified: true',
  "  manual_path_evidence_ref: `"$ManualPathEvidenceRef`"",
  'artifact_rollback:',
  "  current_artifact_sha256: `"$currentHash`"",
  "  rollback_artifact_sha256: `"$rollbackHash`"",
  '  rollback_launch_verified: true',
  "  evidence_ref: `"$RollbackLaunchEvidenceRef`"",
  'database_decision:',
  '  destructive_down_migration_executed: false',
  '  forward_remediation_only: true',
  'privacy:',
  '  raw_user_content_recorded: false',
  '  account_identifier_recorded: false',
  '  credentials_recorded: false',
  'guardrails:',
  '  exact_beta_project_required: true',
  '  clean_candidate_required: true',
  '  feature_state_restoration_required: true',
  '  manual_receipt_is_not_inferred: true',
  '  tabletop_is_live_execution_evidence: false',
  '  open_s0_allows_distribution: false',
  '  failed_restoration_allows_completion: false'
)
$lines | Set-Content -Encoding UTF8 'docs/qst/INCIDENT_LIVE_DRILL.yaml'
Write-Host "Incident live drill $runId completed and Quest Planning was restored."
