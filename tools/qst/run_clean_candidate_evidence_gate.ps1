[CmdletBinding()]
param([string]$ResultsPath = 'tools/qst/quest_planning_eval_results.json')

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $repoRoot
$sourceCommit = (& git rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $sourceCommit -notmatch '^[a-f0-9]{40}$') { throw 'Unable to resolve candidate SHA.' }
if (& git status --porcelain) { throw 'Clean candidate evidence gate requires a clean worktree.' }
dart run tools/qst/verify_candidate_scope_partition.dart --require-clean
if ($LASTEXITCODE -ne 0) { throw 'Candidate scope partition failed.' }

dart run tools/qst/verify_hosted_evidence_bundle.dart --require-cloud --expected-sha=$sourceCommit
if ($LASTEXITCODE -ne 0) { throw 'Hosted evidence failed.' }
dart run tools/qst/verify_physical_accessibility_evidence.dart --require-physical
if ($LASTEXITCODE -ne 0) { throw 'Physical accessibility evidence failed.' }
dart run tools/qst/verify_dependency_notices.dart --require-release
if ($LASTEXITCODE -ne 0) { throw 'Dependency license evidence failed.' }
dart run tools/qst/verify_arc_asset_provenance.dart --require-release
if ($LASTEXITCODE -ne 0) { throw 'Arc chain-of-title evidence failed.' }
dart run tools/qst/verify_candidate_asset_package.dart --require-release
if ($LASTEXITCODE -ne 0) { throw 'Candidate asset package failed.' }
dart run tools/qst/verify_arc_asset_release_workflow.dart --require-release
if ($LASTEXITCODE -ne 0) { throw 'Arc asset release decision failed.' }
dart run tools/qst/verify_legal_signoff_intake.dart --require-approved
if ($LASTEXITCODE -ne 0) { throw 'Legal sign-off intake failed.' }
dart run tools/qst/verify_web_candidate_evidence.dart --require-web
if ($LASTEXITCODE -ne 0) { throw 'Supported Web candidate session failed.' }
dart run tools/qst/verify_android_candidate_evidence.dart --require-physical
if ($LASTEXITCODE -ne 0) { throw 'Physical Android candidate session failed.' }
dart run tools/qst/verify_hosted_migration_deployment.dart --require-cloud
if ($LASTEXITCODE -ne 0) { throw 'Hosted migration deployment failed.' }
dart run tools/qst/verify_beta_feedback_readiness.dart --require-operations
if ($LASTEXITCODE -ne 0) { throw 'Feedback operations evidence failed.' }
dart run tools/qst/verify_runtime_slo_drill.dart --require-hosted
if ($LASTEXITCODE -ne 0) { throw 'Runtime SLO evidence failed.' }
& "$PSScriptRoot/quest_planning_release_gate.ps1" -ResultsPath $ResultsPath
if ($LASTEXITCODE -ne 0) { throw 'Provider-backed AI gate failed.' }
dart run tools/qst/verify_provider_eval_run.dart --require-verified
if ($LASTEXITCODE -ne 0) { throw 'Provider evaluation evidence hashes failed.' }
dart run tools/qst/verify_incident_live_drill.dart --require-verified
if ($LASTEXITCODE -ne 0) { throw 'Incident live drill evidence failed.' }
dart run tools/qst/verify_clean_candidate_evidence.dart --expected-sha=$sourceCommit
if ($LASTEXITCODE -ne 0) { throw 'Cross-evidence SHA gate failed.' }
dart run tools/qst/generate_external_beta_go_no_go.dart
if ($LASTEXITCODE -ne 0) { throw 'External Beta decision generation failed.' }
dart run tools/qst/verify_external_beta_go_no_go.dart
if ($LASTEXITCODE -ne 0) { throw 'External Beta decision verification failed.' }

$decision = Get-Content -Raw -Encoding UTF8 'docs/qst/EXTERNAL_BETA_GO_NO_GO.yaml'
if ($decision -notmatch '(?m)^decision: go$') { throw 'External Beta remains NO-GO.' }
Write-Host "Clean candidate $sourceCommit passed every distribution evidence gate."
