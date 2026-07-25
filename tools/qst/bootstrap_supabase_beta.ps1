[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[a-z0-9]{20}$')]
  [string]$ProjectRef,

  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
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

if ($Region -notmatch '^[a-z0-9-]+$') {
  throw 'Region may contain only lowercase letters, digits, and hyphens.'
}
if ($Owner -match '[\r\n"]') {
  throw 'Owner must be a single YAML-safe line without double quotes.'
}
if ($DashboardEvidence -match '[\r\n"]') {
  throw 'DashboardEvidence must be a single YAML-safe line without double quotes.'
}

$requiredFunctions = @(
  'arc-chat',
  'arc-quest-guide',
  'generate-arc-advice',
  'generate-mission',
  'generate-quest-guides',
  'generate-star-map',
  'auth-login',
  'moderate-quest-intent',
  'research-mission-resources'
)
$latestMigrationFile = Get-ChildItem 'supabase/migrations/*.sql' |
  Sort-Object Name |
  Select-Object -Last 1

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

function Quote-Yaml {
  param([string]$Value)
  return '"' + $Value.Replace('\', '\\').Replace('"', '\"') + '"'
}

if (-not (Get-Command supabase -ErrorAction SilentlyContinue)) {
  throw 'Supabase CLI was not found. Install it from the official Supabase CLI documentation.'
}
if (-not (Test-Path 'supabase/config.toml')) {
  throw 'supabase/config.toml is missing.'
}
if (-not $latestMigrationFile) {
  throw 'No Supabase migration was found.'
}
foreach ($functionName in $requiredFunctions) {
  if (-not (Test-Path "supabase/functions/$functionName/index.ts")) {
    throw "Missing Edge Function: $functionName"
  }
}

$secretPath = if ([System.IO.Path]::IsPathRooted($SecretEnvFile)) {
  $SecretEnvFile
} else {
  Join-Path $repoRoot $SecretEnvFile
}
if (-not (Test-Path -LiteralPath $secretPath)) {
  throw "Secret env file was not found: $SecretEnvFile"
}
$secretContent = Get-Content -LiteralPath $secretPath
if (-not ($secretContent -match '^AI_PROVIDER=gemini$')) {
  throw 'Beta secret env file must define AI_PROVIDER=gemini.'
}
if (-not ($secretContent -match '^GEMINI_API_KEY=.+')) {
  throw 'Beta secret env file must define GEMINI_API_KEY.'
}
if ($secretContent -match '^GEMINI_API_KEY=replace-with-server-side-secret$') {
  throw 'Replace the example GEMINI_API_KEY before bootstrap.'
}

$cliVersion = Invoke-SupabaseCommand @('--version')
Write-Host "Project ref: $ProjectRef"
Write-Host "Region: $Region"
Write-Host "Owner: $Owner"
Write-Host "Latest migration: $($latestMigrationFile.Name)"
Write-Host "Functions: $($requiredFunctions -join ', ')"

if (-not $Apply) {
  Write-Host 'Preflight passed. Re-run with -Apply to change the linked Beta project.'
  exit 0
}

$projectsList = Invoke-SupabaseCommand @('projects', 'list')
if (-not $projectsList.Contains($ProjectRef)) {
  throw "The authenticated Supabase account cannot see project $ProjectRef."
}
if (-not $projectsList.Contains($Region)) {
  throw "Project list evidence does not contain expected region $Region."
}

Invoke-SupabaseCommand @('link', '--project-ref', $ProjectRef) | Out-Null
Invoke-SupabaseCommand @('db', 'push', '--linked') | Out-Null
$migrationList = Invoke-SupabaseCommand @('migration', 'list', '--linked')
$latestMigrationId = $latestMigrationFile.BaseName.Split('_')[0]
if (-not $migrationList.Contains($latestMigrationId)) {
  throw "Remote migration evidence does not contain $latestMigrationId."
}

Invoke-SupabaseCommand @(
  'secrets', 'set', '--project-ref', $ProjectRef, '--env-file', $SecretEnvFile
) | Out-Null
$secretList = Invoke-SupabaseCommand @('secrets', 'list', '--project-ref', $ProjectRef)
foreach ($requiredSecret in @('AI_PROVIDER', 'GEMINI_API_KEY')) {
  if (-not $secretList.Contains($requiredSecret)) {
    throw "Remote secret list does not contain $requiredSecret."
  }
}

$deployedAt = [DateTime]::UtcNow.ToString('o')
foreach ($functionName in $requiredFunctions) {
  Invoke-SupabaseCommand @(
    'functions', 'deploy', $functionName, '--project-ref', $ProjectRef
  ) | Out-Null
}

$sourceCommit = (& git rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($sourceCommit)) {
  throw 'Unable to resolve candidate source commit.'
}
$updatedAt = [DateTime]::UtcNow.ToString('o')
$evidencePath = 'docs/qst/BETA_SUPABASE_PROJECT.yaml'
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('version: 1')
$lines.Add('status: verified')
$lines.Add("updated_at_utc: $(Quote-Yaml $updatedAt)")
$lines.Add("candidate_source_commit: $(Quote-Yaml $sourceCommit)")
$lines.Add('project:')
$lines.Add("  ref: $(Quote-Yaml $ProjectRef)")
$lines.Add("  region: $(Quote-Yaml $Region)")
$lines.Add("  owner: $(Quote-Yaml $Owner)")
$lines.Add('  access_verified: true')
$lines.Add("  dashboard_evidence: $(Quote-Yaml $DashboardEvidence)")
$lines.Add("  linked_at_utc: $(Quote-Yaml $updatedAt)")
$lines.Add("  cli_version: $(Quote-Yaml $cliVersion.Trim())")
$lines.Add('migrations:')
$lines.Add('  status: applied')
$lines.Add("  latest_local: $(Quote-Yaml $latestMigrationFile.Name)")
$lines.Add("  remote_head: $(Quote-Yaml $latestMigrationFile.Name)")
$lines.Add('  command: "supabase migration list --linked"')
$lines.Add('functions:')
foreach ($functionName in $requiredFunctions) {
  $lines.Add("  - name: $functionName")
  $lines.Add('    status: deployed')
  $lines.Add("    deployed_at_utc: $(Quote-Yaml $deployedAt)")
}
$lines.Add('secrets:')
$lines.Add('  status: verified')
$lines.Add('  storage: server_side_only')
$lines.Add('  values_recorded: false')
$lines.Add('  required_names:')
$lines.Add('    - AI_PROVIDER')
$lines.Add('    - GEMINI_API_KEY')
$lines.Add('  optional_names:')
$lines.Add('    - GEMINI_MODEL')
$lines.Add('    - OPENAI_API_KEY')
$lines.Add('    - OPENAI_MODEL')
$lines.Add('client_configuration:')
$lines.Add('  status: pending_candidate_run')
$lines.Add('  allowed_dart_defines:')
$lines.Add('    - SUPABASE_URL')
$lines.Add('    - SUPABASE_ANON_KEY')
$lines.Add('  prohibited_dart_defines:')
$lines.Add('    - SUPABASE_SERVICE_ROLE_KEY')
$lines.Add('    - GEMINI_API_KEY')
$lines.Add('    - OPENAI_API_KEY')
$lines.Add('guardrails:')
$lines.Add('  local_fallback_is_cloud_evidence: false')
$lines.Add('  secret_values_may_be_committed: false')
$lines.Add('  dashboard_schema_changes_allowed: false')
$lines.Add('  require_cloud_verifier_for_completion: true')

Set-Content -LiteralPath $evidencePath -Value $lines -Encoding UTF8
Write-Host "Sanitized cloud evidence written to $evidencePath"
Write-Host 'Run: dart run tools/qst/verify_supabase_beta_bootstrap.dart --require-cloud'
