$ErrorActionPreference = 'Stop'
$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$tempParent = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$root = Join-Path $tempParent "questra-hosted-evidence-$([Guid]::NewGuid().ToString('N'))"
$root = [System.IO.Path]::GetFullPath($root)
$scopeManifest = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $sourceRoot 'docs/qst/CANDIDATE_SCOPE_PARTITION.yaml')
$branchMatches = [regex]::Matches($scopeManifest, '(?m)^branch:\s*(codex/[a-z0-9][a-z0-9-]*)\s*$')
if ($branchMatches.Count -ne 1) { throw 'Candidate scope manifest must pin one fixture branch.' }
$candidateBranch = $branchMatches[0].Groups[1].Value
if (-not $root.StartsWith($tempParent, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Temporary evidence fixture escaped the temporary directory.'
}

try {
  New-Item -ItemType Directory -Path (Join-Path $root 'docs/qst') -Force |
    Out-Null
  Set-Location $root
  & git init -q
  & git checkout -q -b $candidateBranch
  & git config user.name 'Questra evidence fixture'
  & git config user.email 'fixture@example.invalid'
  & git config commit.gpgsign false
  Set-Content -LiteralPath 'app.txt' -Value 'source' -Encoding UTF8
  Copy-Item -LiteralPath (Join-Path $sourceRoot 'docs/qst/CANDIDATE_SCOPE_PARTITION.yaml') `
    -Destination 'docs/qst/CANDIDATE_SCOPE_PARTITION.yaml'
  Copy-Item -LiteralPath (Join-Path $sourceRoot 'docs/qst/CANDIDATE_PREFLIGHT.yaml') `
    -Destination 'docs/qst/CANDIDATE_PREFLIGHT.yaml'
  & git add -- app.txt docs/qst/CANDIDATE_SCOPE_PARTITION.yaml `
    docs/qst/CANDIDATE_PREFLIGHT.yaml
  & git commit -qm source
  if ($LASTEXITCODE -ne 0) { throw 'Unable to create source fixture.' }
  $sourceSha = (& git rev-parse HEAD).Trim()
  Set-Content -LiteralPath 'docs/qst/BETA_CANDIDATE.yaml' `
    -Value "source_commit: `"$sourceSha`"" -Encoding UTF8
  & git add -- docs/qst/BETA_CANDIDATE.yaml
  & git commit -qm candidate
  if ($LASTEXITCODE -ne 0) { throw 'Unable to create candidate fixture.' }

  $evidencePaths = @(
    'docs/qst/HOSTED_MIGRATION_DEPLOYMENT.yaml',
    'docs/qst/BETA_SUPABASE_PROJECT.yaml',
    'docs/qst/BETA_RLS_EVIDENCE.yaml',
    'docs/qst/BETA_DUAL_ACCOUNT_PERSISTENCE.yaml',
    'docs/qst/DATA_RIGHTS_FULFILLMENT_DRILL.yaml',
    'docs/qst/OBSERVABILITY_SINK_EVIDENCE.yaml',
    'docs/qst/HOSTED_EVIDENCE_RUN.yaml'
  )
  foreach ($evidencePath in $evidencePaths) {
    $field = if ($evidencePath -in @(
      'docs/qst/BETA_RLS_EVIDENCE.yaml',
      'docs/qst/BETA_DUAL_ACCOUNT_PERSISTENCE.yaml'
    )) { 'source_commit_at_execution' } else { 'candidate_source_commit' }
    Set-Content -LiteralPath $evidencePath `
      -Value "${field}: `"$sourceSha`"" -Encoding UTF8
    & "$PSScriptRoot/commit_hosted_evidence.ps1" -Path $evidencePath `
      -ExpectedSha $sourceSha
    if ($LASTEXITCODE -ne 0 -or (& git status --porcelain)) {
      throw 'Evidence-only commit did not leave a clean worktree.'
    }
    $resolved = (& dart "$PSScriptRoot/read_candidate_source_commit.dart").Trim()
    if ($LASTEXITCODE -ne 0 -or $resolved -cne $sourceSha) {
      throw 'Evidence-only descendant lost the fixed candidate source.'
    }
  }

  Set-Content -LiteralPath 'runtime.txt' -Value 'unrelated' -Encoding UTF8
  Add-Content -LiteralPath $evidencePath -Value 'status: verified'
  $rejected = $false
  try {
    & "$PSScriptRoot/commit_hosted_evidence.ps1" -Path $evidencePath `
      -ExpectedSha $sourceSha *> $null
  } catch {
    $rejected = $true
  }
  if (-not $rejected) {
    throw 'Evidence commit accepted an unrelated runtime change.'
  }
  Write-Output 'Hosted evidence stage commit contract passed.'
} finally {
  Set-Location $sourceRoot
  $resolvedRoot = [System.IO.Path]::GetFullPath($root)
  if ($resolvedRoot -cne $root -or
      -not $resolvedRoot.StartsWith($tempParent, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Refusing to remove an unexpected temporary fixture path.'
  }
  if (Test-Path -LiteralPath $resolvedRoot) {
    Remove-Item -LiteralPath $resolvedRoot -Recurse -Force
  }
}
