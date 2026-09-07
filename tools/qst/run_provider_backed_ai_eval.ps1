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
  [ValidateRange(8, 20)]
  [int]$AccountShardCount = 8,
  [Parameter(Mandatory = $true)]
  [ValidateRange(0.000001, 1000)]
  [double]$InputUsdPerMillionTokens,
  [Parameter(Mandatory = $true)]
  [ValidateRange(0.000001, 1000)]
  [double]$OutputUsdPerMillionTokens,
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[A-Za-z0-9._-]{3,80}$')]
  [string]$PricingVersion,
  [string]$SupabaseCommand = 'supabase'
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/provider_eval_material.ps1"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $repoRoot
$sourceCommit = (& git rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $sourceCommit -notmatch '^[0-9a-f]{40}$') { throw 'Unable to resolve candidate source commit.' }
if (& git status --porcelain) { throw 'Provider-backed evaluation requires a clean candidate worktree.' }
if ((Get-Content -Raw -Encoding UTF8 'docs/qst/BETA_CANDIDATE.yaml') -notmatch "source_commit: `"$sourceCommit`"") {
  throw 'Provider-backed evaluation requires the Beta candidate manifest to match HEAD.'
}
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
$keyJson = & $SupabaseCommand projects api-keys --project-ref $ProjectRef 2>$null | Out-String | ConvertFrom-Json
$anonKey = ($keyJson.keys | Where-Object name -eq 'anon').api_key
$serviceRoleKey = ($keyJson.keys | Where-Object name -eq 'service_role').api_key
if ([string]::IsNullOrWhiteSpace($anonKey) -or [string]::IsNullOrWhiteSpace($serviceRoleKey)) { throw 'Hosted keys were not returned.' }

$projectUrl = "https://$ProjectRef.supabase.co"
$runId = [Guid]::NewGuid().ToString('N')
$adminHeaders = @{ apikey = $serviceRoleKey; Authorization = "Bearer $serviceRoleKey" }
$accounts = [System.Collections.Generic.List[object]]::new()
$userHeaderShards = [System.Collections.Generic.List[object]]::new()
$cleanupSucceededCount = 0
$results = [System.Collections.Generic.List[object]]::new()

try {
  for ($shard = 0; $shard -lt $AccountShardCount; $shard++) {
    $email = "qst400-$runId-$shard@example.test"
    $password = "Qst400!-$([Guid]::NewGuid().ToString('N'))"
    $account = Invoke-RestMethod -Uri "$projectUrl/auth/v1/admin/users" -Method Post -Headers $adminHeaders `
      -ContentType 'application/json' -Body (@{ email = $email; password = $password; email_confirm = $true; user_metadata = @{ nickname = "QST400 Eval $shard" } } | ConvertTo-Json -Depth 4)
    $accounts.Add($account) | Out-Null
    $session = Invoke-RestMethod -Uri "$projectUrl/auth/v1/token?grant_type=password" -Method Post `
      -Headers @{ apikey = $anonKey } -ContentType 'application/json' `
      -Body (@{ email = $email; password = $password } | ConvertTo-Json)
    $userHeaderShards.Add(@{ apikey = $anonKey; Authorization = "Bearer $($session.access_token)" }) | Out-Null
  }

  $caseIndex = 0
  foreach ($case in $cases | Select-Object -First 200) {
    $started = [DateTime]::UtcNow
    $questId = [Guid]::NewGuid().ToString()
    $shardIndex = $caseIndex % $accounts.Count
    $account = $accounts[$shardIndex]
    $userHeaders = $userHeaderShards[$shardIndex]
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
      $response = Invoke-RestMethod -Uri "$projectUrl/functions/v1/quest-planning-v2" -Method Post -Headers $userHeaders `
        -ContentType 'application/json; charset=utf-8' -Body ($request | ConvertTo-Json -Depth 8)
      $material = New-PlanningEvalMaterial $response
      $materialChecks = Test-PlanningEvalMaterial $material $response
      $missions = @($material.missions)
      $providers = @($response.passes | Where-Object { $null -ne $_.provider } | ForEach-Object { $_.provider })
      $inputTokens = 0
      $outputTokens = 0
      foreach ($provider in $providers) {
        $inputTokens += [int]$provider.usage.inputTokens
        $outputTokens += [int]$provider.usage.outputTokens
      }
      $estimatedCost = ($inputTokens * $InputUsdPerMillionTokens + $outputTokens * $OutputUsdPerMillionTokens) / 1000000
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
      $results.Add([ordered]@{ id = $case.id; evaluation_type = 'planning'; status = 'error'; run_id = $runId; candidate_source_commit = $sourceCommit; pricing_version = $PricingVersion; source_type = 'error'; duration_ms = [int]([DateTime]::UtcNow - $started).TotalMilliseconds; error_category = 'provider_or_contract_failure'; critical_safety_violation = $false; checks = @{} }) | Out-Null
    }
    $caseIndex++
    if ($DelayMilliseconds -gt 0) { Start-Sleep -Milliseconds $DelayMilliseconds }
  }

  $userHeaders = $userHeaderShards[0]
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
      $results.Add([ordered]@{ id = $case.id; evaluation_type = 'safety'; status = 'error'; run_id = $runId; candidate_source_commit = $sourceCommit; pricing_version = $PricingVersion; source_type = 'error'; duration_ms = [int]([DateTime]::UtcNow - $started).TotalMilliseconds; error_category = 'safety_provider_failure'; critical_safety_violation = $true; checks = @{ safety_expected_action = $false; non_fallback_source = $false } }) | Out-Null
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

if ($cleanupSucceededCount -ne $accounts.Count -or $accounts.Count -ne $AccountShardCount) {
  throw 'No evaluation evidence was written because cleanup did not complete.'
}
$results | ConvertTo-Json -Depth 12 | Set-Content -Encoding UTF8 $OutputPath
Write-Host "Provider-backed evaluation recorded $($results.Count) cases for $sourceCommit."
