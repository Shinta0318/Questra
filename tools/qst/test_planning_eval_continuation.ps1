$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/planning_eval_continuation.ps1"

$script:calls = 0
$script:sleeps = @()
$ready = Invoke-PlanningEvalPreview -MaxContinuations 3 -InvokeRequest {
  $script:calls++
  if ($script:calls -eq 1) {
    return [pscustomobject]@{ status = 'processing'; retry_after_ms = 250 }
  }
  return [pscustomobject]@{ status = 'preview_ready'; preview_id = 'fixture' }
} -Sleep { param($milliseconds) $script:sleeps += $milliseconds }
if ($script:calls -ne 2 -or $ready.preview_id -ne 'fixture' -or
    $script:sleeps.Count -ne 1 -or $script:sleeps[0] -ne 250) {
  throw 'Processing continuation did not reach the preview with the expected bounded calls.'
}

$script:calls = 0
try {
  Invoke-PlanningEvalPreview -MaxContinuations 2 -InvokeRequest {
    $script:calls++
    return [pscustomobject]@{ status = 'processing'; retry_after_ms = 250 }
  } -Sleep { param($milliseconds) } | Out-Null
  throw 'Expected the continuation cap to stop the evaluation.'
} catch {
  if ($_.Exception.Message -notlike 'planning_eval_abort:*' -or $script:calls -ne 2) { throw }
}

$script:calls = 0
try {
  Invoke-PlanningEvalPreview -InvokeRequest {
    $script:calls++
    return [pscustomobject]@{ status = 'retryable_error'; issues = @('rate_limited') }
  } | Out-Null
  throw 'Expected a rate-limited case to stop the evaluation.'
} catch {
  if ($_.Exception.Message -notlike 'planning_eval_abort:*' -or $script:calls -ne 1) { throw }
}

$script:calls = 0
try {
  Invoke-PlanningEvalPreview -InvokeRequest {
    $script:calls++
    throw 'synthetic provider failure'
  } | Out-Null
  throw 'Expected a transport failure to stop the evaluation.'
} catch {
  if ($_.Exception.Message -notlike 'planning_eval_abort:*' -or $script:calls -ne 1) { throw }
}

try {
  Invoke-PlanningEvalPreview -InvokeRequest {
    return [pscustomobject]@{ status = 'processing'; retry_after_ms = 6000 }
  } | Out-Null
  throw 'Expected an invalid delay to stop the evaluation.'
} catch {
  if ($_.Exception.Message -notlike 'planning_eval_abort:*') { throw }
}

Write-Host 'Planning evaluation continuation: PASS (no network or provider calls).'
