$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/planning_eval_version_policy.ps1"

function New-VersionRow($Pipeline, $Schema, $Prompts, $Models, $Thinking) {
  return [pscustomobject]@{
    versions = [pscustomobject]@{
      pipeline = $Pipeline
      schema = $Schema
      prompts = [pscustomobject]$Prompts
    }
    model_versions = $Models
    thinking_levels = $Thinking
  }
}

$first = New-VersionRow '4.0' 'mission-architecture-4.0' `
  @{ quest_understanding = 5; mission_critic = 3 } `
  @('gemini-flash@2026-10') @('low', 'high')
$differentPath = New-VersionRow '4.0' 'mission-architecture-4.0' `
  @{ quest_understanding = 5; strategic_plan = 2 } `
  @('gemini-flash@2026-10', 'gemini-pro@2026-10') @('medium', 'high')
$valid = Get-PlanningEvalVersionPolicy -PlanningRows @($first, $differentPath)
if ($valid.configuration_count -ne 1 -or
    $valid.prompt_version_conflict_count -ne 0 -or
    $valid.missing_version_evidence_count -ne 0) {
  throw 'Different valid model, thinking, and pass paths must share one policy without a false conflict.'
}

$changedPrompt = New-VersionRow '4.0' 'mission-architecture-4.0' `
  @{ quest_understanding = 6 } @('gemini-flash@2026-10') @('low')
$promptResult = Get-PlanningEvalVersionPolicy -PlanningRows @($first, $changedPrompt)
if ($promptResult.prompt_version_conflict_count -ne 1) {
  throw 'A prompt key changing version within one run must fail.'
}

$changedSchema = New-VersionRow '4.0' 'mission-architecture-5.0' `
  @{ quest_understanding = 5 } @('gemini-flash@2026-10') @('low')
$schemaResult = Get-PlanningEvalVersionPolicy -PlanningRows @($first, $changedSchema)
if ($schemaResult.configuration_count -ne 2) {
  throw 'A schema change within one run must fail.'
}

$missingModel = New-VersionRow '4.0' 'mission-architecture-4.0' `
  @{ quest_understanding = 5 } @() @('low')
$unresolvedModel = New-VersionRow '4.0' 'mission-architecture-4.0' `
  @{ quest_understanding = 5 } @('gemini-flash@unresolved') @('low')
$missing = Get-PlanningEvalVersionPolicy -PlanningRows @($missingModel, $unresolvedModel)
if ($missing.missing_version_evidence_count -ne 2) {
  throw 'Missing or unresolved model-version evidence must fail.'
}

Write-Host 'Planning evaluation version policy: PASS (no network or provider calls).'
