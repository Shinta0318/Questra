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
  [switch]$Apply,
  [switch]$CommitEvidence
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $repoRoot

function Quote-Yaml([string]$Value) {
  return '"' + $Value.Replace('\', '\\').Replace('"', '\"') + '"'
}

$sourceCommit = (& dart "$PSScriptRoot/read_candidate_source_commit.dart").Trim()
if ($LASTEXITCODE -ne 0 -or $sourceCommit -notmatch '^[0-9a-f]{40}$') {
  throw 'Unable to resolve the candidate source commit.'
}
$workingTreeStatus = (& git status --porcelain)
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect the working tree.' }
if ($workingTreeStatus) {
  throw 'Hosted evidence must start from a clean candidate working tree.'
}
if ($Apply -and -not $CommitEvidence) {
  throw 'Apply requires -CommitEvidence so every hosted stage starts clean.'
}
if ($CommitEvidence -and -not $Apply) {
  throw '-CommitEvidence is valid only together with -Apply.'
}
if ($Apply) {
  & git var GIT_AUTHOR_IDENT *> $null
  if ($LASTEXITCODE -ne 0) { throw 'Git author identity is required.' }
  & git var GIT_COMMITTER_IDENT *> $null
  if ($LASTEXITCODE -ne 0) { throw 'Git committer identity is required.' }
}

function Commit-StageEvidence([string]$Path) {
  & "$PSScriptRoot/commit_hosted_evidence.ps1" -Path $Path `
    -ExpectedSha $sourceCommit
  if ($LASTEXITCODE -ne 0) { throw "Evidence commit failed: $Path" }
}
$probeUserJwt = $null
if ($Apply) {
  if (-not $env:SUPABASE_ANON_KEY -or -not $env:SUPABASE_USER_JWT) {
    throw 'Hosted AI auth verification requires SUPABASE_ANON_KEY and a temporary SUPABASE_USER_JWT in the process environment.'
  }
  if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw 'Hosted AI auth verification requires Node.js.'
  }
  $probeUserJwt = $env:SUPABASE_USER_JWT
  Remove-Item Env:SUPABASE_USER_JWT
}

dart run tools/qst/verify_hosted_evidence_runner_v2.dart
if ($LASTEXITCODE -ne 0) { throw 'Hosted evidence V2 preflight failed.' }

& "$PSScriptRoot/run_hosted_migration_deployment.ps1" `
  -ProjectRef $ProjectRef `
  -ExpectedSha $sourceCommit `
  -ConfirmProjectRef $(if ($Apply) { $ProjectRef } else { '' }) `
  -Execute:$Apply
if ($LASTEXITCODE -ne 0) { throw 'Hosted migration deployment failed.' }
if ($Apply) { Commit-StageEvidence 'docs/qst/HOSTED_MIGRATION_DEPLOYMENT.yaml' }

& "$PSScriptRoot/bootstrap_supabase_beta.ps1" `
  -ProjectRef $ProjectRef `
  -Region $Region `
  -Owner $Owner `
  -DashboardEvidence $DashboardEvidence `
  -SecretEnvFile $SecretEnvFile `
  -Apply:$Apply
if ($LASTEXITCODE -ne 0) { throw 'Supabase bootstrap failed.' }
if ($Apply) { Commit-StageEvidence 'docs/qst/BETA_SUPABASE_PROJECT.yaml' }
if (-not $Apply) {
  Write-Host 'Hosted evidence preflight passed. Re-run with -Apply -CommitEvidence to deploy and test.'
  exit 0
}

$env:SUPABASE_URL = "https://$ProjectRef.supabase.co"
$env:SUPABASE_USER_JWT = $probeUserJwt
try {
  node tools/qst/verify_hosted_ai_auth_boundary.mjs
  $aiAuthProbeExit = $LASTEXITCODE
} finally {
  Remove-Item Env:SUPABASE_USER_JWT -ErrorAction SilentlyContinue
  $probeUserJwt = $null
}
if ($aiAuthProbeExit -ne 0) {
  throw 'Hosted AI user boundary failed. Do not mark this deployment verified.'
}

& "$PSScriptRoot/capture_cloud_rls_evidence.ps1" `
  -ProjectRef $ProjectRef `
  -LinkedCli
if ($LASTEXITCODE -ne 0) { throw 'Cloud RLS evidence capture failed.' }
Commit-StageEvidence 'docs/qst/BETA_RLS_EVIDENCE.yaml'

& "$PSScriptRoot/run_qst199_cloud_acceptance.ps1" -ProjectRef $ProjectRef
if ($LASTEXITCODE -ne 0) { throw 'Dual-account hosted acceptance failed.' }
Commit-StageEvidence 'docs/qst/BETA_DUAL_ACCOUNT_PERSISTENCE.yaml'

& "$PSScriptRoot/run_data_rights_hosted_drill.ps1" -ProjectRef $ProjectRef
if ($LASTEXITCODE -ne 0) { throw 'Hosted Data Rights operations drill failed.' }
Commit-StageEvidence 'docs/qst/DATA_RIGHTS_FULFILLMENT_DRILL.yaml'

& "$PSScriptRoot/run_observability_hosted_drill.ps1" -ProjectRef $ProjectRef
if ($LASTEXITCODE -ne 0) { throw 'Hosted observability drill failed.' }
Commit-StageEvidence 'docs/qst/OBSERVABILITY_SINK_EVIDENCE.yaml'

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
  '  ai_user_boundary: passed',
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
Commit-StageEvidence 'docs/qst/HOSTED_EVIDENCE_RUN.yaml'

Write-Host 'Hosted evidence gate passed. Push only the reviewed evidence commits.'
