$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/provider_eval_material.ps1"
$passed = 0
function Assert-True([bool]$Value, [string]$Message) { if (-not $Value) { throw $Message } }
function Assert-Throws([scriptblock]$Action) {
  $failed = $false
  try { & $Action | Out-Null } catch { $failed = $true }
  Assert-True $failed 'Expected the malformed material to be rejected.'
}
function Fixture {
  @{
    status = 'preview_ready'
    approval_token = 'do-not-export-approval'
    preview_id = 'do-not-export-db-id'
    provider = @{ text = 'do-not-export-private-provider-text' }
    versions = @{ schema = 'mission-architecture-4.0' }
    passes = @(@{ name = 'mission_critic'; status = 'completed' }, @{ name = 'final_validation'; status = 'completed' })
    preview = @{
      qualityGate = @{ status = 'passed' }
      successContract = @{ questOutcome = '食文化を楽しむ一人旅'; successEvidence = @('旅行を完了'); constraints = @('予算の範囲内') }
      strategicPlan = @{ phases = @('準備','旅行'); milestones = @('移動と宿泊を確定') }
      routeMissionPlan = @{ missions = @(@{
        clientId = 'mission-a'; title = '移動と宿泊の手配を完了する'; objective = '希望の日程と予算に合う往復の交通と宿泊先を確保する';
        successCondition = '交通機関と宿泊施設の予約確認がそろっている'; expectedOutcome = '滞在日程と予約控え';
        reasonRequired = '現地で無理なく旅を楽しめるようにする'; confidence = 0.9; dependencies = @()
        approval_token = 'do-not-export-mission-token'
      }) }
      currentTaskPlan = @{ missionClientId = 'mission-a'; tasks = @(@{
        clientId = 'task-a'; title = '航空券の候補を比較する'; action = '希望の日程で航空券の料金と時刻を比較する'; doneCondition = '候補を選んで記録した'
      }) }
      missionCritic = @{ passed = $true; overallScore = 95; missionResults = @(@{
        clientId = 'mission-a'; passed = $true; verdict = 'pass'; scores = @{ questRelevance = 95 }; repairReasons = @()
      }) }
      groundingMetadata = @{ retrievedAt = '2026-09-01T00:00:00Z'; sources = @(@{ id = 'source-a'; title = '公式情報'; uri = 'https://example.invalid/official'; raw = 'do-not-export-raw' }) }
    }
  }
}
function Scenario([string]$Name, [scriptblock]$Test) {
  & $Test (Fixture)
  $script:passed++
  Write-Host "PASS $Name"
}
Scenario 'current route contract and separated Task content' {
  param($response)
  $material = New-PlanningEvalMaterial $response
  $checks = Test-PlanningEvalMaterial $material $response
  Assert-True ($checks.Contract -and $checks.Critic -and $checks.ServerValidated) 'Valid route failed.'
  Assert-True ($material.missions[0].objective -eq $response.preview.routeMissionPlan.missions[0].objective) 'Mission objective was lost.'
  Assert-True ($material.tasks[0].action -eq $response.preview.currentTaskPlan.tasks[0].action) 'Task action was lost.'
  Assert-True (($material | ConvertTo-Json -Depth 20) -notmatch 'do-not-export') 'Unapproved response fields were exported.'
}
Scenario 'legacy preview is not accepted as current Mission architecture' {
  param($response)
  $response.preview.missions = $response.preview.routeMissionPlan.missions
  $response.preview.Remove('routeMissionPlan')
  Assert-True (-not (Test-PlanningEvalMaterial (New-PlanningEvalMaterial $response) $response).Contract) 'Legacy flat Missions were accepted.'
}
Scenario 'repair may run critic twice' {
  param($response)
  $response.passes += @{ name = 'mission_critic'; status = 'completed' }
  Assert-True (Test-PlanningEvalMaterial (New-PlanningEvalMaterial $response) $response).Critic 'Second critic pass invalidated a repaired plan.'
}
Scenario 'completed critic is not a passing critic' {
  param($response)
  $response.preview.missionCritic.passed = $false
  Assert-True (-not (Test-PlanningEvalMaterial (New-PlanningEvalMaterial $response) $response).Critic) 'Failed critic passed.'
}
Scenario 'critic must cover each Mission once' {
  param($response)
  $response.preview.missionCritic.missionResults[0].clientId = 'other-mission'
  Assert-True (-not (Test-PlanningEvalMaterial (New-PlanningEvalMaterial $response) $response).Critic) 'Unrelated critic result passed.'
}
Scenario 'low overall score rejected' {
  param($response)
  $response.preview.missionCritic.overallScore = 84
  Assert-True (-not (Test-PlanningEvalMaterial (New-PlanningEvalMaterial $response) $response).Critic) 'Low critic score passed.'
}
Scenario 'string boolean is not accepted' {
  param($response)
  $response.preview.missionCritic.passed = 'true'
  Assert-True (-not (Test-PlanningEvalMaterial (New-PlanningEvalMaterial $response) $response).Critic) 'String flag passed.'
}
Scenario 'NaN confidence rejected' {
  param($response)
  $response.preview.routeMissionPlan.missions[0].confidence = [double]::NaN
  Assert-True (-not (Test-PlanningEvalMaterial (New-PlanningEvalMaterial $response) $response).Contract) 'NaN passed.'
}
Scenario 'latest failed final validator rejected' {
  param($response)
  $response.passes += @{ name = 'final_validation'; status = 'failed' }
  Assert-True (-not (Test-PlanningEvalMaterial (New-PlanningEvalMaterial $response) $response).ServerValidated) 'Failed final validation passed.'
}
Scenario 'empty success condition rejected' {
  param($response)
  $response.preview.routeMissionPlan.missions[0].successCondition = ''
  Assert-True (-not (Test-PlanningEvalMaterial (New-PlanningEvalMaterial $response) $response).Contract) 'Empty success condition passed.'
}
Scenario 'unexpected nested object rejected' {
  param($response)
  $response.preview.routeMissionPlan.missions[0].objective = @{ Authorization = 'secret' }
  Assert-Throws { New-PlanningEvalMaterial $response }
}
Scenario 'safety review retains response but excludes token' {
  $material = New-SafetyEvalMaterial @{ action = 'reframe'; user_message = '安全に進めよう'; approval_token = 'secret' }
  Assert-True ($material.assessment.user_message -eq '安全に進めよう') 'Safety response lost.'
  Assert-True (($material | ConvertTo-Json -Depth 5) -notmatch 'secret') 'Safety metadata leaked.'
}
Write-Host "$passed provider material scenarios passed."
