$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/planning_smoke_retry.ps1"

$limited = '{"status":"retryable_error","retryAfterSeconds":60,"issues":[{"code":"rate_limited"}]}' | ConvertFrom-Json
if ((Get-BoundedPlanningRateLimitWait 429 $limited 0 0 12 900) -ne 61) {
  throw 'A bounded rate limit must wait for the server delay plus one second.'
}
if ($null -ne (Get-BoundedPlanningRateLimitWait 429 $limited 0 0 0 0)) {
  throw 'Default policy must not retry a rate-limited provider call.'
}
if ($null -ne (Get-BoundedPlanningRateLimitWait 503 $limited 0 0 12 900)) {
  throw 'Only HTTP 429 may enter the rate-limit wait path.'
}
foreach ($case in @(
  @{ plan = $limited; waits = 12; seconds = 0 },
  @{ plan = $limited; waits = 0; seconds = 850 },
  @{ plan = ('{"status":"retryable_error","issues":[{"code":"rate_limited"}]}' | ConvertFrom-Json); waits = 0; seconds = 0 }
)) {
  $rejected = $false
  try {
    $null = Get-BoundedPlanningRateLimitWait 429 $case.plan $case.waits $case.seconds 12 900
  } catch {
    $rejected = $true
  }
  if (-not $rejected) { throw 'An exhausted or invalid retry budget must fail closed.' }
}
Write-Output 'Planning smoke retry policy: PASS (no network or provider call).'
