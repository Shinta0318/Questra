[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[a-z0-9]{20}$')]
  [string]$ProjectRef,
  [string]$CasesPath = 'tools/qst/quest_planning_eval_200.json',
  [string]$SafetyCasesPath = 'tools/qst/quest_planning_safety_eval_cases.json',
  [string]$OutputPath = 'tools/qst/quest_planning_eval_results.json',
  [ValidateRange(2100, 60000)]
  [int]$DelayMilliseconds = 2100,
  [ValidateRange(1, 48)]
  [int]$MaxContinuationsPerCase = 24,
  [ValidateRange(1, 1800)]
  [int]$MaxSecondsPerCase = 600,
  [Parameter(Mandatory = $true)]
  [ValidateRange(0.000001, 1000)]
  [double]$InputUsdPerMillionTokens,
  [Parameter(Mandatory = $true)]
  [ValidateRange(0.000001, 1000)]
  [double]$OutputUsdPerMillionTokens,
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[A-Za-z0-9._-]{3,80}$')]
  [string]$PricingVersion,
  [ValidateRange(0, 1000)]
  [double]$MaxEstimatedPlanningListCostUsd = 0,
  [string]$SupabaseCommand = 'supabase',
  [switch]$SyntheticAccountConsentApproved,
  [switch]$ProviderUsageApproved
)

$ErrorActionPreference = 'Stop'
if (-not $SyntheticAccountConsentApproved) {
  throw 'Explicit approval for synthetic account legal and AI acceptance is required before provider-backed evaluation.'
}
if (-not $ProviderUsageApproved) {
  throw 'Explicit approval for provider usage is required before provider-backed evaluation.'
}
if ($MaxEstimatedPlanningListCostUsd -le 0) {
  throw 'An approved estimated planning list-cost ceiling is required before provider-backed evaluation.'
}
. "$PSScriptRoot/provider_eval_material.ps1"
. "$PSScriptRoot/hosted_auth_fixture.ps1"
. "$PSScriptRoot/planning_eval_continuation.ps1"
. "$PSScriptRoot/planning_eval_cost_guard.ps1"
. "$PSScriptRoot/planning_eval_quota_guard.ps1"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $repoRoot
$sourceCommit = (& dart "$PSScriptRoot/read_candidate_source_commit.dart").Trim()
if ($LASTEXITCODE -ne 0 -or $sourceCommit -notmatch '^[0-9a-f]{40}$') { throw 'Unable to resolve valid candidate source commit.' }
if (& git status --porcelain) { throw 'Provider-backed evaluation requires a clean candidate worktree.' }
if (-not (Get-Command $SupabaseCommand -ErrorAction SilentlyContinue)) { throw 'Supabase CLI was not found.' }
foreach ($pair in @(@($CasesPath, 'tools/qst/quest_planning_eval_200.json'), @($SafetyCasesPath, 'tools/qst/quest_planning_safety_eval_cases.json'))) {
  if ((Resolve-Path $pair[0]).Path -ne (Resolve-Path $pair[1]).Path) {
    throw 'Only the committed synthetic evaluation corpus may be sent to the provider.'
  }
}

$cases = @(Get-Content -Raw -Encoding UTF8 $CasesPath | ConvertFrom-Json)
if ($cases.Count -lt 200) { throw "At least 200 cases are required; found $($cases.Count)." }
$safetyCases = @(Get-Content -Raw -Encoding UTF8 $SafetyCasesPath | ConvertFrom-Json)
if ($safetyCases.Count -lt 10) { throw 'At least 10 safety boundary cases are required.' }
$keys = Get-HostedApiKeys -SupabaseCommand $SupabaseCommand -ProjectRef $ProjectRef
$anonKey = $keys.AnonKey
$serviceRoleKey = $keys.ServiceRoleKey

$projectUrl = "https://$ProjectRef.supabase.co"
$runId = [Guid]::NewGuid().ToString('N')
$adminHeaders = @{ apikey = $serviceRoleKey; Authorization = "Bearer $serviceRoleKey" }
$policyUri = "$projectUrl/rest/v1/ai_usage_policies?select=monthly_hard_limit&operation=eq.quest_planning&subscription_state=eq.free&enabled=eq.true"
try {
  $policies = @(Invoke-RestMethod -Uri $policyUri -Method Get -Headers $adminHeaders)
} catch {
  throw 'planning_eval_abort: The hosted Quest-planning quota policy could not be read.'
}
Assert-PlanningEvalQuotaCapacity -Policies $policies -CaseCount 200
$fixtureMetadata = Get-HostedLegalFixtureMetadata `
  -ProjectUrl $projectUrl -AdminHeaders $adminHeaders
$accounts = [System.Collections.Generic.List[object]]::new()
$cleanupSucceededCount = 0
$results = [System.Collections.Generic.List[object]]::new()
$estimatedRunListCostUsd = 0.0

try {
  $email = "qst400-$runId@example.test"
  $password = "Qst400!-$([Guid]::NewGuid().ToString('N'))"
  $account = Invoke-RestMethod -Uri "$projectUrl/auth/v1/admin/users" -Method Post -Headers $adminHeaders `
    -ContentType 'application/json' -Body (@{ email = $email; password = $password; email_confirm = $true; user_metadata = $fixtureMetadata + @{ nickname = 'QST400 Eval' } } | ConvertTo-Json -Depth 4)
  $accounts.Add($account) | Out-Null
  $session = Invoke-RestMethod -Uri "$projectUrl/auth/v1/token?grant_type=password" -Method Post `
    -Headers @{ apikey = $anonKey } -ContentType 'application/json' `
    -Body (@{ email = $email; password = $password } | ConvertTo-Json)
  $userHeaders = @{ apikey = $anonKey; Authorization = "Bearer $($session.access_token)" }

  foreach ($case in $cases | Select-Object -First 200) {
    if ($estimatedRunListCostUsd -ge $MaxEstimatedPlanningListCostUsd) {
      throw 'planning_eval_abort: The approved estimated planning list-cost ceiling was reached before the next case.'
    }
    $started = [DateTime]::UtcNow
    $questId = [Guid]::NewGuid().ToString()
    try {
      Invoke-RestMethod -Uri "$projectUrl/rest/v1/quests" -Method Post -Headers ($userHeaders + @{ Prefer = 'return=minimal' }) `
        -ContentType 'application/json' -Body (@{ id = $questId; owner_id = $account.id; title = $case.title; description = $case.description; status = 'draft'; visibility = 'private' } | ConvertTo-Json) | Out-Null
      $request = @{
        mode = 'plan'; quest_id = $questId; wish = "$($case.title)`n$($case.description)";
        available_time = @{ weekly_minutes = $case.planning_context.weekly_minutes };
        budget = $case.planning_context.budget_label; experience = $case.planning_context.experience;
        approved_context = @{ consent_granted = $true; preferences = @($case.planning_context.preferences) };
        idempotency_key = "qst380-$runId-$($case.id)"
      }
      $response = Invoke-PlanningEvalPreview -MaxContinuations $MaxContinuationsPerCase `
        -MaxSeconds $MaxSecondsPerCase -InvokeRequest {
          Invoke-RestMethod -Uri "$projectUrl/functions/v1/quest-planning-v2" -Method Post -Headers $userHeaders `
            -ContentType 'application/json; charset=utf-8' -Body ($request | ConvertTo-Json -Depth 8)
        }
      $providers = @($response.passes | Where-Object { $null -ne $_.provider } | ForEach-Object { $_.provider })
      $ledgerUri = New-PlanningEvalLedgerUri -ProjectUrl $projectUrl `
        -OwnerId ([string]$account.id) -AttemptKey ([string]$request.idempotency_key)
      try {
        $reservations = @(Invoke-RestMethod -Uri $ledgerUri -Method Get -Headers $userHeaders)
      } catch {
        throw 'planning_eval_abort: Planning usage ledger could not be read.'
      }
      $caseCost = Measure-PlanningEvalLedgerCost -Reservations $reservations `
        -OwnerId ([string]$account.id) -AttemptKey ([string]$request.idempotency_key) `
        -InputUsdPerMillionTokens $InputUsdPerMillionTokens `
        -OutputUsdPerMillionTokens $OutputUsdPerMillionTokens `
        -CurrentEstimatedUsd $estimatedRunListCostUsd `
        -MaxEstimatedUsd $MaxEstimatedPlanningListCostUsd
      $estimatedRunListCostUsd = $caseCost.total_usd
      $inputTokens = $caseCost.input_tokens
      $outputTokens = $caseCost.output_tokens
      $estimatedCost = $caseCost.case_usd
      $material = New-PlanningEvalMaterial $response
      $materialChecks = Test-PlanningEvalMaterial $material $response
      $missions = @($material.missions)
      $titles = @($missions | ForEach-Object { [string]$_.title })
      $combined = (@($missions | ForEach-Object { "$($_.title) $($_.objective) $($_.successCondition)" }) -join ' ')
      $domainHits = @($case.expected_keywords | Where-Object { $combined -match [regex]::Escape([string]$_) }).Count
      $contractPass = $materialChecks.Contract
      $criticPass = $materialChecks.Critic
      $providerBacked = $providers.Count -gt 0 -and
        @($providers | Where-Object provider -ne 'gemini').Count -eq 0 -and
        @($providers | Where-Object { $null -ne $_.error }).Count -eq 0
      $results.Add([ordered]@{
        id = $case.id; evaluation_type = 'planning'; status = if ($response.status -eq 'preview_ready') { 'ok' } else { 'invalid' };
        run_id = $runId; candidate_source_commit = $sourceCommit; source_type = if ($providerBacked) { 'gemini_interactions' } else { 'non_provider' };
        pricing_version = $PricingVersion;
        model_versions = @($providers | ForEach-Object { "$($_.model)@$($_.modelVersion)" } | Sort-Object -Unique);
        thinking_levels = @($providers | ForEach-Object { [string]$_.thinkingLevel } | Sort-Object -Unique);
        provider_trace_ids = @($providers | ForEach-Object { [string]$_.traceId } | Sort-Object -Unique);
        versions = $response.versions; mission_count = $missions.Count;
        review_material = $material;
        duration_ms = [int]([DateTime]::UtcNow - $started).TotalMilliseconds;
        input_tokens = $inputTokens; output_tokens = $outputTokens; estimated_cost_usd = [math]::Round($estimatedCost, 8);
        critical_safety_violation = $false;
        checks = [ordered]@{
          plan_quality = $criticPass; domain_specificity = $domainHits -ge 2; done_conditions = $contractPass;
          unique_titles = @($titles | Sort-Object -Unique).Count -eq $titles.Count; mission_contract = $contractPass;
          schema_valid = $materialChecks.ServerValidated;
          usage_recorded = $inputTokens -gt 0 -and $outputTokens -gt 0
        }
      }) | Out-Null
    } catch {
      if ($_.Exception.Message.StartsWith('planning_eval_abort:')) { throw }
      $results.Add([ordered]@{ id = $case.id; evaluation_type = 'planning'; status = 'error'; run_id = $runId; candidate_source_commit = $sourceCommit; pricing_version = $PricingVersion; source_type = 'error'; duration_ms = [int]([DateTime]::UtcNow - $started).TotalMilliseconds; error_category = 'provider_or_contract_failure'; critical_safety_violation = $false; checks = @{} }) | Out-Null
    }
    if ($DelayMilliseconds -gt 0) { Start-Sleep -Milliseconds $DelayMilliseconds }
  }

  foreach ($case in $safetyCases) {
    $started = [DateTime]::UtcNow
    try {
      $response = Invoke-RestMethod -Uri "$projectUrl/functions/v1/moderate-quest-intent" -Method Post -Headers $userHeaders `
        -ContentType 'application/json; charset=utf-8' -Body (@{ input = $case.input } | ConvertTo-Json)
      $safe = [string]$response.action -eq [string]$case.expected_action
      $sourceType = [string]$response.source_type
      $nonFallbackSource = $sourceType -in @('gemini_interactions', 'deterministic_safety')
      $results.Add([ordered]@{
        id = $case.id; evaluation_type = 'safety'; status = if ($nonFallbackSource) { 'ok' } else { 'invalid' };
        run_id = $runId; candidate_source_commit = $sourceCommit; pricing_version = $PricingVersion;
        source_type = $sourceType; provider_model = $response.provider_model; policy_version = $response.policy_version;
        expected_action = $case.expected_action; actual_action = $response.action;
        review_material = New-SafetyEvalMaterial $response;
        duration_ms = [int]([DateTime]::UtcNow - $started).TotalMilliseconds;
        critical_safety_violation = -not $safe; checks = @{ safety_expected_action = $safe; non_fallback_source = $nonFallbackSource }
      }) | Out-Null
    } catch {
      throw 'planning_eval_abort: Safety moderation failed; the evaluation stopped without recording a partial run.'
    }
  }
} finally {
  foreach ($ephemeralAccount in $accounts) {
    try {
      Invoke-RestMethod -Uri "$projectUrl/auth/v1/admin/users/$($ephemeralAccount.id)?should_soft_delete=false" -Method Delete -Headers $adminHeaders | Out-Null
      $cleanupSucceededCount++
    } catch { Write-Warning 'QST-380 ephemeral account requires manual cleanup.' }
  }
}

if ($cleanupSucceededCount -ne 1 -or $accounts.Count -ne 1) {
  throw 'No evaluation evidence was written because cleanup did not complete.'
}
$results | ConvertTo-Json -Depth 12 | Set-Content -Encoding UTF8 $OutputPath
Write-Host "Provider-backed evaluation recorded $($results.Count) cases for $sourceCommit."
