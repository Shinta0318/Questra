function ConvertTo-ControlTimestamp($Value) {
  if ([string]::IsNullOrWhiteSpace([string]$Value)) { throw 'Control timestamp is missing.' }
  $stamp = if ($Value -is [DateTimeOffset]) { $Value } elseif ($Value -is [DateTime]) { [DateTimeOffset]$Value } else {
    [DateTimeOffset]::Parse([string]$Value, [Globalization.CultureInfo]::InvariantCulture)
  }
  return $stamp.UtcDateTime.ToString("yyyy-MM-ddTHH:mm:ss.ffffff'Z'")
}

function New-IncidentControlFilter($Expected) {
  if ($Expected.enabled -isnot [bool]) { throw 'Control enabled flag is not boolean.' }
  $enabled = $Expected.enabled.ToString().ToLowerInvariant()
  $reason = 'is.null'
  if ($null -ne $Expected.disabled_reason) {
    $quoted = '"' + ([string]$Expected.disabled_reason).Replace('\', '\\').Replace('"', '\"') + '"'
    $reason = 'eq.' + [Uri]::EscapeDataString($quoted)
  }
  $stamp = [Uri]::EscapeDataString((ConvertTo-ControlTimestamp $Expected.updated_at))
  return "operation=eq.quest_planning&enabled=eq.$enabled&disabled_reason=$reason&updated_at=eq.$stamp"
}

function Test-IncidentControlEqual($Actual, $Expected) {
  return $Actual.enabled -is [bool] -and $Actual.enabled -eq $Expected.enabled -and
    $Actual.disabled_reason -ceq $Expected.disabled_reason -and
    (ConvertTo-ControlTimestamp $Actual.updated_at) -ceq (ConvertTo-ControlTimestamp $Expected.updated_at)
}

function Invoke-GuardedPlanningPause {
  param(
    [Parameter(Mandatory)][scriptblock]$ReadControl,
    [Parameter(Mandatory)][scriptblock]$CompareExchange,
    [Parameter(Mandatory)][string]$RunId
  )
  $before = & $ReadControl
  if ($before.enabled -isnot [bool] -or -not $before.enabled) {
    throw 'Quest Planning must be enabled before the live pause drill.'
  }
  $before.updated_at = ConvertTo-ControlTimestamp $before.updated_at
  $disabledAt = [DateTime]::UtcNow
  $paused = [pscustomobject]@{
    enabled = $false
    disabled_reason = "qst401_live_drill_$RunId"
    updated_at = ConvertTo-ControlTimestamp $disabledAt
  }
  $pauseConfirmed = $false
  $restoredAt = $null
  try {
    $rows = @(& $CompareExchange $before $paused)
    if ($rows.Count -ne 1) { throw 'Control changed before pause; drill did not acquire it.' }
    # Use the server timestamp representation in subsequent compare-and-set.
    $paused.updated_at = ConvertTo-ControlTimestamp $rows[0].updated_at
    if (-not (Test-IncidentControlEqual (& $ReadControl) $paused)) {
      throw 'Quest Planning pause was not observable in the hosted control table.'
    }
    $pauseConfirmed = $true
  } finally {
    $restoredAt = [DateTime]::UtcNow
    $restore = [pscustomobject]@{
      enabled = $before.enabled
      disabled_reason = $before.disabled_reason
      updated_at = ConvertTo-ControlTimestamp $restoredAt
    }
    # Never enable an operator's later stop. This predicate also safely handles
    # an ambiguous pause response: only this run's exact marker can be restored.
    $rows = @(& $CompareExchange $paused $restore)
    if ($rows.Count -ne 1) {
      throw 'Quest Planning control restoration failed: ownership changed or pause was not applied. Inspect the control manually.'
    }
    $restore.updated_at = ConvertTo-ControlTimestamp $rows[0].updated_at
    if (-not (Test-IncidentControlEqual (& $ReadControl) $restore)) {
      throw 'Quest Planning control restoration failed: readback differs. No further write attempted.'
    }
  }
  if (-not $pauseConfirmed) { throw 'Pause was not verified; drill cannot complete.' }
  return [pscustomobject]@{ DisabledAt = $disabledAt; RestoredAt = $restoredAt }
}

function Resolve-IncidentTimeline {
  param([string]$Detected, [string]$Stopped, [string]$Acknowledged,
    [DateTimeOffset]$Now = [DateTimeOffset]::UtcNow)
  $values = foreach ($value in @($Detected, $Stopped, $Acknowledged)) {
    if ($value -notmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,7})?Z$') {
      throw 'Incident receipt timestamps must be explicit UTC ISO-8601 values.'
    }
    [DateTimeOffset]::Parse($value, [Globalization.CultureInfo]::InvariantCulture)
  }
  if ($values[0] -gt $values[1] -or $values[1] -gt $values[2] -or $values[2] -gt $Now) {
    throw 'Incident receipt timestamps are out of order or in the future.'
  }
  if (($values[2] - $values[0]).TotalMinutes -gt 60) {
    throw 'Incident acknowledgement exceeded one hour; drill cannot be verified.'
  }
  return [pscustomobject]@{ Detected = $values[0]; Stopped = $values[1]; Acknowledged = $values[2] }
}
