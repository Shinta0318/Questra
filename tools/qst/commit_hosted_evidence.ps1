[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet(
    'docs/qst/HOSTED_MIGRATION_DEPLOYMENT.yaml',
    'docs/qst/BETA_SUPABASE_PROJECT.yaml',
    'docs/qst/BETA_RLS_EVIDENCE.yaml',
    'docs/qst/BETA_DUAL_ACCOUNT_PERSISTENCE.yaml',
    'docs/qst/DATA_RIGHTS_FULFILLMENT_DRILL.yaml',
    'docs/qst/OBSERVABILITY_SINK_EVIDENCE.yaml',
    'docs/qst/HOSTED_EVIDENCE_RUN.yaml'
  )]
  [string]$Path,

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[a-f0-9]{40}$')]
  [string]$ExpectedSha
)

$ErrorActionPreference = 'Stop'
$repoRoot = (& git rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $repoRoot)) {
  throw 'Hosted evidence commit requires a Git worktree.'
}
Set-Location $repoRoot

$sourceCommit = (& dart "$PSScriptRoot/read_candidate_source_commit.dart").Trim()
if ($LASTEXITCODE -ne 0 -or $sourceCommit -cne $ExpectedSha) {
  throw 'Hosted evidence commit does not match the fixed candidate source.'
}
if (-not (Test-Path -LiteralPath $Path)) {
  throw "Hosted evidence file is missing: $Path"
}
$shaField = if ($Path -in @(
  'docs/qst/BETA_RLS_EVIDENCE.yaml',
  'docs/qst/BETA_DUAL_ACCOUNT_PERSISTENCE.yaml'
)) { 'source_commit_at_execution' } else { 'candidate_source_commit' }
$content = Get-Content -Raw -Encoding UTF8 -LiteralPath $Path
$shaPattern = "(?m)^$shaField`: `"?$ExpectedSha`"?\s*$"
if ($content -notmatch $shaPattern) {
  throw 'Hosted evidence file does not bind to the fixed candidate source.'
}

$status = @(& git status --porcelain=v1 --untracked-files=all)
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect hosted evidence changes.' }
if ($status.Count -ne 1 -or $status[0].Length -lt 4) {
  throw 'Exactly one hosted evidence file must change before its commit.'
}
$code = $status[0].Substring(0, 2)
$changedPath = $status[0].Substring(3).Replace('\', '/')
if ($code -notin @(' M', '??') -or $changedPath -cne $Path) {
  throw 'Hosted evidence commit refuses unrelated or staged changes.'
}

& dart "$PSScriptRoot/verify_candidate_preflight.dart"
if ($LASTEXITCODE -ne 0) { throw 'Candidate secret preflight failed.' }
& dart "$PSScriptRoot/verify_candidate_scope_partition.dart" --phase=evidence
if ($LASTEXITCODE -ne 0) { throw 'Evidence path classification failed.' }

& git add -- $Path
if ($LASTEXITCODE -ne 0) { throw 'Unable to stage hosted evidence.' }
& git diff --cached --check
if ($LASTEXITCODE -ne 0) { throw 'Hosted evidence has whitespace errors.' }
& git commit -m "Record hosted evidence: $([System.IO.Path]::GetFileName($Path))"
if ($LASTEXITCODE -ne 0) { throw 'Unable to commit hosted evidence.' }
if (& git status --porcelain=v1 --untracked-files=all) {
  throw 'Hosted evidence commit left a dirty worktree.'
}
$sourceAfter = (& dart "$PSScriptRoot/read_candidate_source_commit.dart").Trim()
if ($LASTEXITCODE -ne 0 -or $sourceAfter -cne $ExpectedSha) {
  throw 'Evidence commit changed the fixed candidate source.'
}
Write-Host "Hosted evidence committed: $Path"
