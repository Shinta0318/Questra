[CmdletBinding()]
param(
  [string]$ProjectRef = 'tpynzjjqajpkzivgapfq',
  [string]$SupabaseCommand = 'supabase',
  [switch]$PreflightOnly,
  [switch]$ConfirmFreeTierKey,
  [string]$GeminiSecretUpdatedAfterUtc,
  [ValidateRange(0, 24)][int]$MaxRateLimitWaits = 0,
  [ValidateRange(0, 3600)][int]$MaxTotalRateLimitWaitSeconds = 0
)

$ErrorActionPreference = 'Stop'
if ($ProjectRef -ne 'tpynzjjqajpkzivgapfq') {
  throw 'This smoke test is restricted to the isolated validation project.'
}
if (-not (Get-Command $SupabaseCommand -ErrorAction SilentlyContinue)) {
  throw 'Supabase CLI was not found.'
}
if (-not $PreflightOnly) {
  if (-not $ConfirmFreeTierKey -or
      [string]::IsNullOrWhiteSpace($GeminiSecretUpdatedAfterUtc)) {
    throw 'Confirm the Free-tier key and provide the prior secret update time before provider calls.'
  }
  $priorUpdate = [DateTimeOffset]::MinValue
  if (-not [DateTimeOffset]::TryParse(
      $GeminiSecretUpdatedAfterUtc, [ref]$priorUpdate)) {
    throw 'GeminiSecretUpdatedAfterUtc must be an ISO timestamp.'
  }
  $secretJson = & $SupabaseCommand secrets list --project-ref $ProjectRef `
    --output json 2>$null | Out-String
  if ($LASTEXITCODE -ne 0) {
    throw 'Unable to verify the validation-project Gemini secret update.'
  }
  $geminiSecrets = @(($secretJson | ConvertFrom-Json) |
    Where-Object { $_.name -eq 'GEMINI_API_KEY' })
  if ($geminiSecrets.Count -ne 1 -or
      [DateTimeOffset]::Parse($geminiSecrets[0].updated_at) -le $priorUpdate) {
    throw 'Validation-project GEMINI_API_KEY has not been updated since confirmation.'
  }
}

. "$PSScriptRoot/hosted_auth_fixture.ps1"
. "$PSScriptRoot/planning_smoke_retry.ps1"
$keys = Get-HostedApiKeys -SupabaseCommand $SupabaseCommand -ProjectRef $ProjectRef
$projectUrl = "https://$ProjectRef.supabase.co"
$adminHeaders = @{
  apikey = $keys.ServiceRoleKey
  Authorization = "Bearer $($keys.ServiceRoleKey)"
}
foreach ($path in @(
  '/rest/v1/quests?select=quest_dna,quest_dna_version,quest_dna_evaluated_at&limit=0',
  '/rest/v1/weekly_availability?select=planning_consent_granted,monday_minutes,tuesday_minutes,wednesday_minutes,thursday_minutes,friday_minutes,saturday_minutes,sunday_minutes,budget_label,location,experience&limit=0'
)) {
  $schemaCheck = Invoke-WebRequest -Uri "$projectUrl$path" `
    -Headers $adminHeaders -SkipHttpErrorCheck
  if ([int]$schemaCheck.StatusCode -ne 200) {
    throw "Planning tool schema preflight failed: HTTP $([int]$schemaCheck.StatusCode)"
  }
}
$metadata = Get-HostedLegalFixtureMetadata `
  -ProjectUrl $projectUrl -AdminHeaders $adminHeaders
if ($PreflightOnly) {
  Write-Host 'Validation planning schema and legal policy preflight: PASS (no account or provider call).'
  return
}
$accountId = $null
$questId = $null
$cleanupFailed = $false

try {
  $suffix = [Guid]::NewGuid().ToString('N')
  $email = "qst-planning-smoke-$suffix@example.test"
  $password = "Qst!$suffix"
  $account = Invoke-RestMethod -Uri "$projectUrl/auth/v1/admin/users" `
    -Method Post -Headers $adminHeaders -ContentType 'application/json' `
    -Body (@{
      email = $email
      password = $password
      email_confirm = $true
      user_metadata = $metadata + @{ nickname = 'Planning smoke test' }
    } | ConvertTo-Json -Depth 4)
  $accountId = [string]$account.id
  if ([string]::IsNullOrWhiteSpace($accountId)) {
    throw 'Test account creation returned no user ID.'
  }

  $accepted = Invoke-RestMethod `
    -Uri "$projectUrl/rest/v1/rpc/has_current_ai_legal_acceptance" `
    -Method Post -Headers $adminHeaders -ContentType 'application/json' `
    -Body (@{ p_user_id = $accountId } | ConvertTo-Json)
  if ($accepted -ne $true) {
    throw 'Test account has no current AI legal acceptance.'
  }

  $session = Invoke-RestMethod `
    -Uri "$projectUrl/auth/v1/token?grant_type=password" `
    -Method Post -Headers @{ apikey = $keys.AnonKey } `
    -ContentType 'application/json' `
    -Body (@{ email = $email; password = $password } | ConvertTo-Json)
  if ([string]::IsNullOrWhiteSpace([string]$session.access_token)) {
    throw 'Test account sign-in returned no access token.'
  }
  $userHeaders = @{
    apikey = $keys.AnonKey
    Authorization = "Bearer $($session.access_token)"
  }

  $questId = [Guid]::NewGuid().ToString()
  $title = '3か月後に英語で3分間の自己紹介を話せるようになる'
  $wish = '3か月後の職場交流会で英語で3分間の自己紹介をする。仕事、趣味、これからの目標を相手に伝え、英語の質問に1つ答えられたら達成。現在は英会話初心者で、平日に週3回、各30分練習できる。'
  Invoke-RestMethod -Uri "$projectUrl/rest/v1/quests" `
    -Method Post -Headers ($userHeaders + @{ Prefer = 'return=minimal' }) `
    -ContentType 'application/json' -Body (@{
      id = $questId
      owner_id = $accountId
      title = $title
      description = $wish
      status = 'draft'
      visibility = 'private'
    } | ConvertTo-Json -Depth 4) | Out-Null

  $request = @{
    mode = 'plan'
    quest_id = $questId
    wish = $wish
    target_date = [DateTime]::UtcNow.AddMonths(3).ToString('yyyy-MM-dd')
    available_time = @{ weekly_minutes = 90 }
    experience = '英会話は初心者'
    constraints = @('平日は週3回、1回30分まで')
    approved_context = @{ consent_granted = $true }
    idempotency_key = "planning-smoke-$suffix"
  }
  $denied = Invoke-WebRequest -Uri "$projectUrl/functions/v1/quest-planning-v2" `
    -Method Post -Headers $userHeaders -ContentType 'application/json; charset=utf-8' `
    -Body ($request | ConvertTo-Json -Depth 5) -SkipHttpErrorCheck -TimeoutSec 30
  $deniedBody = $denied.Content | ConvertFrom-Json
  if ([int]$denied.StatusCode -ne 403 -or
      $deniedBody.error -ne 'planning_preferences_consent_required') {
    throw "Planning preferences were not denied before consent: HTTP $([int]$denied.StatusCode)"
  }
  Write-Host 'Unconsented personal planning context: denied before provider call.'

  Invoke-RestMethod -Uri "$projectUrl/rest/v1/weekly_availability" `
    -Method Post -Headers ($userHeaders + @{ Prefer = 'return=minimal' }) `
    -ContentType 'application/json' -Body (@{
      user_id = $accountId
      planning_consent_granted = $true
      monday_minutes = 30
      wednesday_minutes = 30
      friday_minutes = 30
    } | ConvertTo-Json -Depth 4) | Out-Null

  $requestBody = $request | ConvertTo-Json -Depth 5
  $http = $null
  $plan = $null
  $rateLimitWaits = 0
  $rateLimitWaitSeconds = 0
  for ($step = 1; $step -le 24; $step++) {
    $http = Invoke-WebRequest -Uri "$projectUrl/functions/v1/quest-planning-v2" `
      -Method Post -Headers $userHeaders -ContentType 'application/json; charset=utf-8' `
      -Body $requestBody -SkipHttpErrorCheck -TimeoutSec 180
    try {
      $plan = $http.Content | ConvertFrom-Json
    } catch {
      throw "Planning continuation ${step}: HTTP $([int]$http.StatusCode), non_json_response. Inspect validation function logs."
    }
    Write-Host "Planning continuation ${step}: HTTP $([int]$http.StatusCode), status $($plan.status)"
    $sleepSeconds = Get-BoundedPlanningRateLimitWait `
      -StatusCode ([int]$http.StatusCode) -Plan $plan `
      -WaitsUsed $rateLimitWaits -SecondsUsed $rateLimitWaitSeconds `
      -MaxWaits $MaxRateLimitWaits -MaxSeconds $MaxTotalRateLimitWaitSeconds
    if ($null -ne $sleepSeconds) {
      $rateLimitWaits++
      $rateLimitWaitSeconds += $sleepSeconds
      Write-Host "Waiting $sleepSeconds seconds before resuming the same planning attempt ($rateLimitWaits/$MaxRateLimitWaits)."
      Start-Sleep -Seconds $sleepSeconds
      continue
    }
    if ($plan.status -ne 'processing') { break }
    if ([int]$http.StatusCode -ne 202) {
      throw 'Planning returned processing without HTTP 202.'
    }
    Start-Sleep -Milliseconds 250
  }
  if ($plan.status -eq 'processing') {
    throw 'Planning did not finish within 24 bounded continuations.'
  }
  $passes = @($plan.passes | Where-Object { $null -ne $_ })
  $passSummary = @($passes | ForEach-Object { "$($_.name):$($_.status)" }) -join ', '
  $issueCodes = @($plan.issues | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_.code }) -join ', '
  $missionCount = @($plan.preview.routeMissionPlan.missions | Where-Object { $null -ne $_ }).Count
  $taskCount = @($plan.preview.currentTaskPlan.tasks | Where-Object { $null -ne $_ }).Count
  $toolAudit = Invoke-RestMethod `
    -Uri "$projectUrl/rest/v1/ai_tool_audit_logs?owner_id=eq.$accountId&select=tool_name,outcome&order=created_at.asc&limit=20" `
    -Headers $adminHeaders
  $toolSummary = @($toolAudit | Where-Object { $null -ne $_ } | ForEach-Object { "$($_.tool_name):$($_.outcome)" }) -join ', '
  $persistedMissionRows = Invoke-RestMethod `
    -Uri "$projectUrl/rest/v1/missions?quest_id=eq.$questId&select=id" `
    -Headers $userHeaders
  $persistedMissions = @($persistedMissionRows | Where-Object { $null -ne $_ }).Count
  Write-Host "Planning HTTP: $([int]$http.StatusCode); status: $($plan.status)"
  Write-Host "Passes: $passSummary"
  Write-Host "Issue codes: $issueCodes"
  $criticSummaries = @($passes | Where-Object { $_.name -eq 'mission_critic' } |
    ForEach-Object {
      $critic = $_.output
      $reviews = @($critic.missionResults | Where-Object { $null -ne $_ })
      $failedCount = @($reviews | Where-Object {
        $_.passed -ne $true -or $_.verdict -ne 'pass'
      }).Count
      $minimumScores = @(
        'questRelevance', 'outcomeQuality', 'missionGranularity',
        'successConditionQuality', 'personalization', 'nonTemplateQuality',
        'uniqueness', 'sequencing', 'completenessContribution', 'taskSeparation' |
        ForEach-Object {
          $dimension = $_
          $scores = @($reviews | ForEach-Object { $_.scores.$dimension } |
            Where-Object { $null -ne $_ })
          if ($scores.Count -gt 0) {
            "$dimension=$(($scores | Measure-Object -Minimum).Minimum)"
          }
        }
      ) -join ','
      "overall=$($critic.overallScore),passed=$($critic.passed),missions=$($reviews.Count),failed=$failedCount,minScores=$minimumScores"
    })
  if ($criticSummaries.Count -gt 0) {
    Write-Host "Mission critic diagnostics (no text or IDs): $($criticSummaries -join ' / ')"
  }
  Write-Host "Tool audit outcomes: $toolSummary"
  Write-Host "Preview missions: $missionCount; tasks: $taskCount; persisted missions before approval: $persistedMissions"
  if ($plan.status -eq 'needs_clarification') {
    $questions = @($passes[0].output.clarificationQuestions | Where-Object { $null -ne $_ })
    Write-Host "Clarification questions for synthetic input: $($questions -join ' / ')"
  }
  if ($persistedMissions -ne 0) {
    throw 'Planning persisted Missions before user approval.'
  }
  if ([int]$http.StatusCode -ne 200 -or $plan.status -ne 'preview_ready' -or
      $missionCount -lt 1 -or $taskCount -lt 1 -or
      @($passes | Where-Object { $_.name -eq 'mission_critic' -and $_.status -eq 'completed' }).Count -lt 1) {
    throw 'Provider-backed planning did not reach a validated preview.'
  }
  Write-Host 'Free-tier planning smoke: PASS (Mission and Task text omitted).'
} finally {
  if ($questId) {
    try {
      Invoke-RestMethod -Uri "$projectUrl/rest/v1/quests?id=eq.$questId" `
        -Method Delete -Headers $adminHeaders | Out-Null
    } catch { $cleanupFailed = $true }
  }
  if ($accountId) {
    try {
      Invoke-RestMethod `
        -Uri "$projectUrl/auth/v1/admin/users/${accountId}?should_soft_delete=false" `
        -Method Delete -Headers $adminHeaders | Out-Null
    } catch { $cleanupFailed = $true }
  }
  $password = $null
  $session = $null
  $keys = $null
  if ($cleanupFailed) {
    throw 'Synthetic Quest or account cleanup failed; inspect the validation project.'
  }
}
