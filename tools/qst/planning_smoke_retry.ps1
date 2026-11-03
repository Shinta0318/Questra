function Get-BoundedPlanningRateLimitWait {
  param(
    [int]$StatusCode,
    [object]$Plan,
    [int]$WaitsUsed,
    [int]$SecondsUsed,
    [int]$MaxWaits,
    [int]$MaxSeconds
  )

  $issueCodes = @($Plan.issues | Where-Object { $null -ne $_ } |
    ForEach-Object { [string]$_.code })
  if ($StatusCode -ne 429 -or $Plan.status -ne 'retryable_error' -or
      $issueCodes -notcontains 'rate_limited' -or $MaxWaits -le 0) {
    return $null
  }
  $wait = $Plan.retryAfterSeconds
  if ($wait -isnot [long] -or $wait -lt 1 -or $wait -gt 3600) {
    throw 'Rate-limited planning response did not provide a safe retry delay.'
  }
  $sleepSeconds = [int]$wait + 1
  if ($WaitsUsed -ge $MaxWaits -or $SecondsUsed + $sleepSeconds -gt $MaxSeconds) {
    throw 'Bounded Free-tier rate-limit wait budget was exhausted.'
  }
  return $sleepSeconds
}
