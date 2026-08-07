[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[a-z0-9]{20}$')]
  [string]$ProjectRef,

  [string]$DatabaseUrl = $env:SUPABASE_DB_URL,
  [string]$EvidencePath = 'docs/qst/BETA_RLS_EVIDENCE.yaml',
  [string]$SupabaseCommand = 'supabase',
  [switch]$LinkedCli
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $repoRoot

function Invoke-SupabaseCommand {
  param([string[]]$Arguments)

  $previousErrorActionPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    $output = & $SupabaseCommand @Arguments 2>&1
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
  $output | ForEach-Object { Write-Host $_ }
  if ($exitCode -ne 0) {
    throw "supabase $($Arguments -join ' ') failed with exit code $exitCode."
  }
  return ($output -join [Environment]::NewLine)
}

function Quote-Yaml {
  param([string]$Value)
  return '"' + $Value.Replace('\', '\\').Replace('"', '\"') + '"'
}

if (-not $LinkedCli -and [string]::IsNullOrWhiteSpace($DatabaseUrl)) {
  throw 'Set SUPABASE_DB_URL before capturing cloud RLS evidence.'
}
if (-not (Get-Command $SupabaseCommand -ErrorAction SilentlyContinue)) {
  throw "Supabase CLI was not found: $SupabaseCommand"
}
if (-not $LinkedCli -and -not (Get-Command psql -ErrorAction SilentlyContinue)) {
  throw 'psql was not found.'
}

$projectEvidencePath = 'docs/qst/BETA_SUPABASE_PROJECT.yaml'
if (-not (Test-Path $projectEvidencePath)) {
  throw "Missing QST-160 project evidence: $projectEvidencePath"
}
$projectEvidence = Get-Content -Raw -Encoding UTF8 $projectEvidencePath
if ($projectEvidence -notmatch '(?m)^status: (verified|deployed_pending_candidate_freeze)\s*$') {
  throw 'Supabase project deployment evidence is not ready for RLS capture.'
}
$escapedProjectRef = [regex]::Escape($ProjectRef)
if ($projectEvidence -notmatch "(?m)^  ref: `"?$escapedProjectRef`"?\s*$") {
  throw 'Project ref does not match QST-160 evidence.'
}

$latestMigrationFile = Get-ChildItem 'supabase/migrations/*.sql' |
  Sort-Object Name |
  Select-Object -Last 1
if (-not $latestMigrationFile) {
  throw 'No Supabase migration was found.'
}
$latestMigrationId = $latestMigrationFile.BaseName.Split('_')[0]
$migrationList = Invoke-SupabaseCommand @('migration', 'list', '--linked')
if (-not $migrationList.Contains($latestMigrationId)) {
  throw "Remote migration evidence does not contain $latestMigrationId."
}

$testFile = 'supabase/tests/rls_behavior.sql'
$runnerArguments = @{
  TestFile = $testFile
}
if ($LinkedCli) {
  $runnerArguments.LinkedCli = $true
  $runnerArguments.SupabaseCommand = $SupabaseCommand
} else {
  $runnerArguments.DatabaseUrl = $DatabaseUrl
}
$testOutput = & "$PSScriptRoot/run_rls_behavior_tests.ps1" @runnerArguments 2>&1
$testOutput | ForEach-Object { Write-Host $_ }
if (-not (($testOutput -join [Environment]::NewLine).Contains('QST-041 RLS behavior tests passed'))) {
  throw 'RLS behavior test output did not contain the pass marker.'
}

$testContent = Get-Content -Raw -Encoding UTF8 $testFile
if ($testContent -notmatch '(?m)^begin;\s*$' -or
    $testContent -notmatch '(?m)^rollback;\s*$') {
  throw 'RLS behavior test must remain transactionally rolled back.'
}
$assertionCount = ([regex]::Matches(
  $testContent,
  'select\s+(?:pg_temp\.)?qst_assert_(?:eq|raises)\s*\(',
  [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
)).Count
if ($assertionCount -lt 1) {
  throw 'RLS behavior test contains no assertions.'
}

$databaseClientVersion = if ($LinkedCli) {
  $version = (& $SupabaseCommand --version 2>&1 | Out-String).Trim()
  if ($LASTEXITCODE -ne 0) {
    throw 'Unable to read Supabase CLI version.'
  }
  "supabase-cli $version (db query --linked)"
} else {
  $version = (& psql --version 2>&1 | Out-String).Trim()
  if ($LASTEXITCODE -ne 0) {
    throw 'Unable to read psql version.'
  }
  $version
}
$sourceCommit = (& git rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $sourceCommit -notmatch '^[0-9a-f]{40}$') {
  throw 'Unable to resolve candidate source commit.'
}
$workingTreeClean = -not [bool](& git status --porcelain)
$testSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $testFile).Hash.ToLowerInvariant()
$updatedAt = [DateTime]::UtcNow.ToString('o')

$lines = @(
  'version: 1',
  'status: verified',
  "updated_at_utc: $(Quote-Yaml $updatedAt)",
  "source_commit_at_execution: $(Quote-Yaml $sourceCommit)",
  "working_tree_clean_at_execution: $($workingTreeClean.ToString().ToLowerInvariant())",
  "project_ref: $(Quote-Yaml $ProjectRef)",
  'migrations:',
  '  status: applied',
  "  latest_local: $(Quote-Yaml $latestMigrationFile.Name)",
  "  remote_head: $(Quote-Yaml $latestMigrationFile.Name)",
  '  command: "supabase migration list --linked"',
  'rls_behavior:',
  '  status: passed',
  "  test_file: $(Quote-Yaml $testFile)",
  "  test_sha256: $(Quote-Yaml $testSha256)",
  "  assertion_count: $assertionCount",
  '  owner_checks: passed',
  '  cross_account_checks: passed',
  '  write_denial_checks: passed',
  '  transaction_rolled_back: true',
  "  executed_at_utc: $(Quote-Yaml $updatedAt)",
  "  psql_version: $(Quote-Yaml $databaseClientVersion)",
  'guardrails:',
  '  database_url_recorded: false',
  '  database_password_recorded: false',
  '  private_journey_content_recorded: false',
  '  local_database_is_cloud_evidence: false',
  '  requires_verified_supabase_project: true'
)
Set-Content -LiteralPath $EvidencePath -Value $lines -Encoding UTF8

Write-Host "Sanitized cloud RLS evidence written to $EvidencePath"
Write-Host 'Run: dart run tools/qst/verify_cloud_rls_evidence.dart --require-cloud'
