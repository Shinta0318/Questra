[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[a-z0-9]{20}$')]
  [string]$ProjectRef,

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[a-z0-9-]+$')]
  [string]$Region,

  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$Owner,

  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$DashboardEvidence,

  [string]$SecretEnvFile = 'supabase/functions/.env.beta.local',
  [switch]$Apply
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $repoRoot

function Quote-Yaml([string]$Value) {
  return '"' + $Value.Replace('\', '\\').Replace('"', '\"') + '"'
}

$sourceCommit = (& git rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $sourceCommit -notmatch '^[0-9a-f]{40}$') {
  throw 'Unable to resolve the candidate source commit.'
}
$workingTreeStatus = (& git status --porcelain)
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect the working tree.' }
if ($workingTreeStatus) {
  throw 'Hosted evidence must start from a clean candidate working tree.'
}

dart run tools/qst/verify_hosted_evidence_runner_v2.dart
if ($LASTEXITCODE -ne 0) { throw 'Hosted evidence V2 preflight failed.' }

& "$PSScriptRoot/run_hosted_migration_deployment.ps1" `
  -ProjectRef $ProjectRef `
  -ExpectedSha $sourceCommit `
  -ConfirmProjectRef $(if ($Apply) { $ProjectRef } else { '' }) `
  -Execute:$Apply
if ($LASTEXITCODE -ne 0) { throw 'Hosted migration deployment failed.' }

& "$PSScriptRoot/bootstrap_supabase_beta.ps1" `
  -ProjectRef $ProjectRef `
  -Region $Region `
  -Owner $Owner `
  -DashboardEvidence $DashboardEvidence `
  -SecretEnvFile $SecretEnvFile `
  -Apply:$Apply
if ($LASTEXITCODE -ne 0) { throw 'Supabase bootstrap failed.' }
if (-not $Apply) {
  Write-Host 'Hosted evidence preflight passed. Re-run with -Apply to deploy and test.'
  exit 0
}

& "$PSScriptRoot/capture_cloud_rls_evidence.ps1" `
  -ProjectRef $ProjectRef `
  -LinkedCli
if ($LASTEXITCODE -ne 0) { throw 'Cloud RLS evidence capture failed.' }

& "$PSScriptRoot/run_qst199_cloud_acceptance.ps1" -ProjectRef $ProjectRef
if ($LASTEXITCODE -ne 0) { throw 'Dual-account hosted acceptance failed.' }

& "$PSScriptRoot/run_data_rights_hosted_drill.ps1" -ProjectRef $ProjectRef
if ($LASTEXITCODE -ne 0) { throw 'Hosted Data Rights operations drill failed.' }

& "$PSScriptRoot/run_observability_hosted_drill.ps1" -ProjectRef $ProjectRef
if ($LASTEXITCODE -ne 0) { throw 'Hosted observability drill failed.' }

dart run tools/qst/verify_supabase_beta_bootstrap.dart --require-cloud
if ($LASTEXITCODE -ne 0) { throw 'Hosted Supabase verification failed.' }
dart run tools/qst/verify_cloud_rls_evidence.dart --require-cloud
if ($LASTEXITCODE -ne 0) { throw 'Hosted RLS verification failed.' }
dart run tools/qst/verify_dual_account_persistence.dart --require-cloud
if ($LASTEXITCODE -ne 0) { throw 'Hosted dual-account verification failed.' }

$latestMigration = Get-ChildItem 'supabase/migrations/*.sql' |
  Sort-Object Name |
  Select-Object -Last 1
$updatedAt = [DateTime]::UtcNow.ToString('o')
$lines = @(
  'version: 1',
  'status: verified',
  "run_id: $(Quote-Yaml ([Guid]::NewGuid().ToString('N')))",
  "executed_at_utc: $(Quote-Yaml $updatedAt)",
  "candidate_source_commit: $(Quote-Yaml $sourceCommit)",
  'working_tree_clean_at_start: true',
  "project_ref: $(Quote-Yaml $ProjectRef)",
  "latest_migration: $(Quote-Yaml $latestMigration.Name)",
  'gates:',
  '  migrations_and_functions: passed',
  '  rls_behavior: passed',
  '  dual_account_journey: passed',
  '  data_export_owner_scope: passed',
  '  correction_owner_scope: passed',
  '  consent_withdrawal: passed',
  '  ephemeral_accounts_removed: passed',
  'extended_drills:',
  '  data_rights_fulfillment: passed_retention_review_pending',
  '  runtime_observability: passed',
  '  physical_accessibility: pending_qst376',
  '  dependency_license: pending_qst377',
  '  arc_asset_rights: pending_qst378',
  '  feedback_operations: pending_qst379',
  '  provider_backed_ai: pending_qst380',
  'guardrails:',
  '  credential_values_recorded: false',
  '  account_identifiers_recorded: false',
  '  private_journey_content_recorded: false',
  '  local_fallback_is_cloud_evidence: false'
)
Set-Content -LiteralPath 'docs/qst/HOSTED_EVIDENCE_RUN.yaml' -Value $lines -Encoding UTF8

dart run tools/qst/verify_hosted_evidence_bundle.dart `
  --require-cloud `
  --expected-sha=$sourceCommit
if ($LASTEXITCODE -ne 0) { throw 'Combined hosted evidence verification failed.' }

Write-Host 'Hosted evidence gate passed. Commit only sanitized evidence files.'
