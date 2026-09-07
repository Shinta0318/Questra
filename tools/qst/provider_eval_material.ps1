function Select-EvalFields($Source, [string[]]$Fields) {
  $selected = [ordered]@{}
  foreach ($field in $Fields) {
    $value = if ($null -eq $Source) { $null } else { $Source.$field }
    if ($null -ne $value) {
      foreach ($item in @($value)) {
        if ($item -isnot [string] -and $item -isnot [bool] -and $item -isnot [ValueType]) {
          throw 'Unexpected nested provider field in review material.'
        }
        if ($item -is [string] -and ($item.Length -gt 10000 -or $item -match 'eyJ[A-Za-z0-9_-]{20,}|AIza[0-9A-Za-z_-]{30,}')) {
          throw 'Unsafe provider field in review material.'
        }
      }
      if (@($value).Count -gt 100) { throw 'Oversized provider field in review material.' }
    }
    $selected[$field] = $value
  }
  return $selected
}

function New-PlanningEvalMaterial($Response) {
  $preview = $Response.preview
  $missions = @($preview.routeMissionPlan.missions | Where-Object { $null -ne $_ })
  $tasks = @($preview.currentTaskPlan.tasks | Where-Object { $null -ne $_ })
  if ($missions.Count -gt 20 -or $tasks.Count -gt 30) { throw 'Oversized plan in review material.' }
  $missionFields = @('clientId','title','objective','successCondition','expectedOutcome','reasonRequired',
    'coveredSuccessConditions','requiresCurrentFacts','groundedFactRefs','calendarDurationDays',
    'dependencies','required','parallelizable','childTaskEstimate','weight','confidence')
  $taskFields = @('clientId','title','action','purpose','doneCondition','expectedOutput',
    'estimatedEffortMinutes','dependencies','required','confidence')
  $critic = $preview.missionCritic
  $criticResults = @($critic.missionResults | Where-Object { $null -ne $_ })
  if ($criticResults.Count -gt 20) { throw 'Oversized critic in review material.' }
  return [ordered]@{
    version = 1
    result_status = [string]$Response.status
    success_contract = Select-EvalFields $preview.successContract @('questOutcome','successEvidence',
      'requiredConditions','optionalConditions','completionVerification','targetDate','constraints','assumptions','prohibitedShortcuts')
    strategy = Select-EvalFields $preview.strategicPlan @('phases','milestones','criticalPath','risks','optionalPaths','reviewPoints')
    missions = @($missions | ForEach-Object { Select-EvalFields $_ $missionFields })
    current_mission_client_id = $preview.currentTaskPlan.missionClientId
    tasks = @($tasks | ForEach-Object { Select-EvalFields $_ $taskFields })
    critic = [ordered]@{
      passed = $critic.passed
      overall_score = $critic.overallScore
      missions = @($criticResults | ForEach-Object {
        $entry = Select-EvalFields $_ @('clientId','passed','verdict','repairReasons','repairInstruction')
        $entry['scores'] = Select-EvalFields $_.scores @('questRelevance','outcomeQuality','missionGranularity',
          'successConditionQuality','personalization','nonTemplateQuality','uniqueness','sequencing','completenessContribution','taskSeparation')
        $entry
      })
    }
    sources = @($preview.groundingMetadata.sources | Where-Object { $null -ne $_ } | ForEach-Object { Select-EvalFields $_ @('id','title','uri') })
    retrieved_at = $preview.groundingMetadata.retrievedAt
  }
}

function Test-PlanningEvalMaterial($Material, $Response) {
  function Is-Number($Value) {
    return ($Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal]) -and
      -not [double]::IsNaN([double]$Value) -and -not [double]::IsInfinity([double]$Value)
  }
  $missions = @($Material.missions)
  $ids = @($missions | ForEach-Object clientId)
  $contract = $missions.Count -ge 1 -and $missions.Count -le 20 -and
    @($ids | Sort-Object -Unique).Count -eq $ids.Count
  foreach ($mission in $missions) {
    foreach ($field in @('clientId','title','objective','successCondition','expectedOutcome','reasonRequired')) {
      if ($mission[$field] -isnot [string] -or [string]::IsNullOrWhiteSpace($mission[$field])) { $contract = $false }
    }
    if (-not (Is-Number $mission.confidence) -or $mission.confidence -lt 0 -or $mission.confidence -gt 1) { $contract = $false }
  }
  $reviews = @($Material.critic.missions)
  $criticPass = $contract -and $Material.critic.passed -is [bool] -and $Material.critic.passed -eq $true -and
    (Is-Number $Material.critic.overall_score) -and $Material.critic.overall_score -ge 85 -and $reviews.Count -eq $missions.Count
  foreach ($id in $ids) {
    $matches = @($reviews | Where-Object clientId -CEQ $id)
    if ($matches.Count -ne 1 -or $matches[0].passed -isnot [bool] -or $matches[0].passed -ne $true -or $matches[0].verdict -cne 'pass') { $criticPass = $false }
  }
  $final = @($Response.passes | Where-Object name -eq 'final_validation' | Select-Object -Last 1)
  return [pscustomobject]@{
    Contract = $contract
    Critic = $criticPass -and $Response.preview.qualityGate.status -ceq 'passed'
    ServerValidated = $contract -and $Response.status -ceq 'preview_ready' -and
      $Response.versions.schema -ceq 'mission-architecture-4.0' -and $final.Count -eq 1 -and $final[0].status -ceq 'completed'
  }
}

function New-SafetyEvalMaterial($Response) {
  return [ordered]@{
    version = 1
    assessment = Select-EvalFields $Response @('action','category','severity','confidence',
      'reason_code','user_message','safe_alternative','policy_version','source_type','provider_model')
  }
}
