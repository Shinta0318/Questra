[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[a-z0-9]{20}$')]
  [string]$ProjectRef,

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[a-f0-9]{40}$')]
  [string]$ExpectedSha,

  [string]$ConfirmProjectRef = '',
  [switch]$Execute
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $repoRoot

function Invoke-SupabaseCommand {
  param([string[]]$Arguments)
  $output = & supabase @Arguments 2>&1
  $exitCode = $LASTEXITCODE
  $output | ForEach-Object { Write-Host $_ }
  if ($exitCode -ne 0) {
    throw "supabase $($Arguments -join ' ') failed with exit code $exitCode."
  }
  return ($output -join [Environment]::NewLine)
}

function Get-RemoteVersions([string]$MigrationList) {
  return @(
    $MigrationList -split "`r?`n" |
      ForEach-Object {
        if ($_ -match '^\s*\d*\s*\|\s*(\d{14})\s*\|') { $Matches[1] }
      }
  )
}

function Quote-Yaml([string]$Value) {
  return '"' + $Value.Replace('\', '\\').Replace('"', '\"') + '"'
}

$head = (& git rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $head -ne $ExpectedSha) {
  throw 'Candidate SHA does not match HEAD.'
}
$branch = (& git branch --show-current).Trim()
if ($branch -ne 'codex/initial-questra-structure-pr') {
  throw 'Hosted migration deployment must run from the approved branch.'
}
if (& git status --porcelain) {
  throw 'Hosted migration deployment requires a clean worktree.'
}
if (-not (Get-Command supabase -ErrorAction SilentlyContinue)) {
  throw 'Supabase CLI is required; destructive repair is intentionally unsupported.'
}
if ($Execute -and $ConfirmProjectRef -cne $ProjectRef) {
  throw 'ConfirmProjectRef must exactly match ProjectRef before deployment.'
}
$linkedRefPath = 'supabase/.temp/project-ref'
if (-not (Test-Path -LiteralPath $linkedRefPath)) {
  throw 'Link the intended Supabase project before running this command.'
}
$linkedRef = (Get-Content -Raw -LiteralPath $linkedRefPath).Trim()
if ($linkedRef -cne $ProjectRef) {
  throw 'Linked Supabase project does not match the requested project.'
}

dart run tools/qst/verify_candidate_scope_partition.dart --require-clean
if ($LASTEXITCODE -ne 0) { throw 'Candidate scope verification failed.' }
dart run tools/qst/verify_hosted_migration_deployment.dart
if ($LASTEXITCODE -ne 0) { throw 'Migration deployment plan verification failed.' }

$localMigrations = @(Get-ChildItem 'supabase/migrations/*.sql' | Sort-Object Name)
$latestLocal = $localMigrations[-1]
$latestVersion = $latestLocal.BaseName.Split('_')[0]
$plannedRemoteHeadFile = '202608080006_route_proposal_stale_conflict_guard.sql'
$plannedRemoteVersion = $plannedRemoteHeadFile.Split('_')[0]
$plannedRemoteIndex = [Array]::FindIndex(
  $localMigrations,
  [Predicate[object]] { param($item) $item.Name -eq $plannedRemoteHeadFile }
)
if ($plannedRemoteIndex -lt 0) { throw 'Planned remote head is not in local migrations.' }
$pendingPlan = @($localMigrations | Select-Object -Skip ($plannedRemoteIndex + 1))

$cliVersion = Invoke-SupabaseCommand @('--version')
$beforeList = Invoke-SupabaseCommand @('migration', 'list', '--linked')
$remoteVersionsBefore = @(Get-RemoteVersions $beforeList)
if ($remoteVersionsBefore.Count -eq 0) { throw 'Unable to resolve hosted migration head.' }
$remoteHeadBefore = $remoteVersionsBefore[-1]
if ($remoteHeadBefore -ne $plannedRemoteVersion -and $remoteHeadBefore -ne $latestVersion) {
  throw "Unexpected hosted migration head $remoteHeadBefore. Refusing push."
}

Invoke-SupabaseCommand @('db', 'push', '--linked', '--dry-run') | Out-Null
if (-not $Execute) {
  Write-Host 'Dry-run passed. Re-run with -Execute and -ConfirmProjectRef to deploy.'
  exit 0
}

$pendingAtExecution = if ($remoteHeadBefore -eq $latestVersion) { 0 } else { $pendingPlan.Count }
if ($pendingAtExecution -gt 0) {
  Invoke-SupabaseCommand @('db', 'push', '--linked') | Out-Null
}
$afterList = Invoke-SupabaseCommand @('migration', 'list', '--linked')
$remoteVersionsAfter = @(Get-RemoteVersions $afterList)
if ($remoteVersionsAfter.Count -eq 0 -or $remoteVersionsAfter[-1] -ne $latestVersion) {
  throw 'Hosted migration head did not reach the latest local migration.'
}

$bytes = [Text.Encoding]::UTF8.GetBytes($afterList)
$digest = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
$executedAt = [DateTime]::UtcNow.ToString('o')
$remoteHeadBeforeFile = if ($remoteHeadBefore -eq $latestVersion) {
  $latestLocal.Name
} else {
  $plannedRemoteHeadFile
}
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('version: 1')
$lines.Add('qst: QST-394')
$lines.Add('status: verified')
$lines.Add("project_ref: $(Quote-Yaml $ProjectRef)")
$lines.Add("candidate_source_commit: $(Quote-Yaml $ExpectedSha)")
$lines.Add('working_tree_clean_at_execution: true')
$lines.Add("executed_at_utc: $(Quote-Yaml $executedAt)")
$lines.Add("cli_version: $(Quote-Yaml $cliVersion.Trim())")
$lines.Add('migrations:')
$lines.Add("  remote_head_before: $(Quote-Yaml $remoteHeadBeforeFile)")
$lines.Add("  latest_local: $(Quote-Yaml $latestLocal.Name)")
$lines.Add("  pending_at_plan: $($pendingPlan.Count)")
$lines.Add("  pending_at_execution: $pendingAtExecution")
$lines.Add("  applied_during_run: $pendingAtExecution")
$lines.Add("  remote_head_after: $(Quote-Yaml $latestLocal.Name)")
$lines.Add("  migration_list_sha256: $(Quote-Yaml $digest)")
$lines.Add('  pending_plan:')
foreach ($migration in $pendingPlan) {
  $lines.Add("    - $(Quote-Yaml $migration.Name)")
}
$lines.Add('execution:')
$lines.Add('  runner: tools/qst/run_hosted_migration_deployment.ps1')
$lines.Add('  requires:')
foreach ($requirement in @(
  'clean_candidate_sha',
  'explicit_project_ref_confirmation',
  'linked_project_match',
  'authenticated_supabase_cli',
  'successful_db_push_dry_run',
  'expected_remote_head_or_already_current'
)) { $lines.Add("    - $requirement") }
$lines.Add('guardrails:')
$lines.Add('  destructive_repair_allowed: false')
$lines.Add('  dashboard_only_change_allowed: false')
$lines.Add('  secret_values_recorded: false')
$lines.Add('  local_plan_is_hosted_evidence: false')
$lines.Add('  unexpected_remote_head_allows_push: false')
Set-Content -LiteralPath 'docs/qst/HOSTED_MIGRATION_DEPLOYMENT.yaml' -Value $lines -Encoding UTF8

dart run tools/qst/verify_hosted_migration_deployment.dart --require-cloud
if ($LASTEXITCODE -ne 0) { throw 'Hosted migration evidence verification failed.' }
Write-Host "Hosted migration deployment verified for $ExpectedSha."
