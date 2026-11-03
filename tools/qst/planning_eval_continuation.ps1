function Invoke-PlanningEvalPreview {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][scriptblock]$InvokeRequest,
    [ValidateRange(1, 48)][int]$MaxContinuations = 24,
    [ValidateRange(1, 1800)][int]$MaxSeconds = 600,
    [scriptblock]$Sleep = { param($milliseconds) Start-Sleep -Milliseconds $milliseconds }
  )

  $started = [DateTime]::UtcNow
  for ($attempt = 1; $attempt -le $MaxContinuations; $attempt++) {
    try {
      $response = & $InvokeRequest
    } catch {
      throw 'planning_eval_abort: The planning request failed; the provider evaluation stopped without recording a partial case.'
    }
    if ($null -eq $response) {
      throw 'planning_eval_abort: The planning response was empty.'
    }
    if ($response.status -eq 'preview_ready') {
      return $response
    }
    if ($response.status -eq 'retryable_error') {
      throw 'planning_eval_abort: Planning needs a retry or provider quota recovery; no automatic retry was made.'
    }
    if ($response.status -ne 'processing') {
      return $response
    }

    $delay = 0
    if (-not [int]::TryParse([string]$response.retry_after_ms, [ref]$delay) -or
        $delay -lt 50 -or $delay -gt 5000) {
      throw 'planning_eval_abort: Planning returned an invalid continuation delay.'
    }
    if ($attempt -ge $MaxContinuations -or
        ([DateTime]::UtcNow - $started).TotalMilliseconds + $delay -gt $MaxSeconds * 1000) {
      throw 'planning_eval_abort: Planning did not reach a final preview within the bounded continuation budget.'
    }
    & $Sleep $delay
  }

  throw 'planning_eval_abort: Planning continuation budget was exhausted.'
}
