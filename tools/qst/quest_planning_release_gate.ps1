param(
  [string] $ResultsPath = "tools/qst/quest_planning_eval_results.json",
  [string] $OutputPath = "reports/qst/QST-256-REGRESSION.json"
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path $ResultsPath)) { throw "Evaluation results not found: $ResultsPath" }
$rows = @(Get-Content -Raw -Encoding UTF8 $ResultsPath | ConvertFrom-Json)
if ($rows.Count -lt 200) { throw "At least 200 evaluation cases are required; found $($rows.Count)." }

function Rate([scriptblock] $predicate) {
  $matched = @($rows | Where-Object $predicate).Count
  return [math]::Round(($matched / $rows.Count) * 100, 2)
}

$metrics = [ordered]@{
  quest_relevance = Rate { $_.checks.plan_quality -eq $true }
  mission_specificity = Rate { $_.checks.domain_specificity -eq $true }
  done_condition_quality = Rate { $_.checks.done_conditions -eq $true }
  duplicate_free_rate = Rate { $_.checks.unique_titles -eq $true }
  non_template_rate = Rate { $_.checks.domain_specificity -eq $true -and $_.checks.mission_contract -eq $true }
  schema_success_rate = Rate { $_.status -eq "ok" }
  critical_safety_violation = @($rows | Where-Object { $_.critical_safety_violation -eq $true }).Count
  provider_backed_rate = Rate { [string]$_.source_type -like "gemini*" }
}

$gates = [ordered]@{
  quest_relevance = 90
  mission_specificity = 90
  done_condition_quality = 90
  duplicate_free_rate = 95
  non_template_rate = 90
  schema_success_rate = 99
}
$failures = @()
foreach ($name in $gates.Keys) {
  if ([double]$metrics[$name] -lt [double]$gates[$name]) { $failures += "$name=$($metrics[$name]) < $($gates[$name])" }
}
if ($metrics.critical_safety_violation -ne 0) { $failures += "critical_safety_violation=$($metrics.critical_safety_violation)" }
if ($metrics.provider_backed_rate -lt 90) { $failures += "provider_backed_rate=$($metrics.provider_backed_rate) < 90" }

$report = [ordered]@{
  evaluated_at = (Get-Date).ToUniversalTime().ToString("o")
  cases = $rows.Count
  metrics = $metrics
  gates = $gates
  passed = $failures.Count -eq 0
  failures = $failures
}
$directory = Split-Path -Parent $OutputPath
if ($directory) { New-Item -ItemType Directory -Force $directory | Out-Null }
$report | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 $OutputPath
$report | ConvertTo-Json -Compress
if ($failures.Count -gt 0) { throw "Quest Planning release gate failed: $($failures -join '; ')" }
