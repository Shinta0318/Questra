$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/incident_control_guard.ps1"
$script:passed = 0

function Assert-True([bool]$Value, [string]$Message) {
  if (-not $Value) { throw $Message }
}
function Assert-Throws([scriptblock]$Action) {
  $failed = $false
  try { & $Action | Out-Null } catch { $failed = $true }
  Assert-True $failed 'Expected failure, but the drill reported success.'
}
function Reset-Control {
  $script:control = [pscustomobject]@{ enabled = $true; disabled_reason = $null; updated_at = '2026-01-01T00:00:00.000000Z' }
  $script:mode = 'normal'
  $script:writes = 0
}
$read = {
  if ($script:mode -eq 'readback-conflict' -and $script:writes -eq 2) {
    $script:control.enabled = $false
    $script:control.disabled_reason = 'operator_stop_after_restore'
  }
  [pscustomobject]@{
    enabled = $script:control.enabled
    disabled_reason = $script:control.disabled_reason
    updated_at = $script:control.updated_at
  }
}
$exchange = {
  param($expected, $replacement)
  if ($script:mode -eq 'conflict-before-pause' -and $script:writes -eq 0) {
    $script:control.enabled = $false
    $script:control.disabled_reason = 'operator_stop'
  }
  if ($script:mode -eq 'conflict-before-restore' -and $script:writes -eq 1) {
    $script:control.disabled_reason = 'operator_stop'
  }
  if ($script:mode -eq 'timestamp-only-conflict' -and $script:writes -eq 1) {
    $script:control.updated_at = '2026-01-02T00:00:00.000000Z'
  }
  if ($script:mode -eq 'restore-network-failure' -and $script:writes -eq 1) {
    throw 'Simulated network failure.'
  }
  if (Test-IncidentControlEqual $script:control $expected) {
    $script:control = [pscustomobject]@{
      enabled = $replacement.enabled
      disabled_reason = $replacement.disabled_reason
      updated_at = $replacement.updated_at
    }
    $script:writes++
    if ($script:mode -eq 'ambiguous-pause' -and $script:writes -eq 1) { throw 'Pause response lost.' }
    [pscustomobject]@{
      enabled = $script:control.enabled
      disabled_reason = $script:control.disabled_reason
      updated_at = $script:control.updated_at
    }
  }
}
function Test-Scenario([string]$Name, [scriptblock]$Action) {
  Reset-Control
  & $Action
  $script:passed++
  Write-Host "PASS $Name"
}
function Run-Pause {
  Invoke-GuardedPlanningPause -ReadControl $read -CompareExchange $exchange -RunId 'unit-test'
}

Test-Scenario 'pause and restore' {
  $result = Run-Pause
  Assert-True ($script:control.enabled -and $script:writes -eq 2) 'Normal restoration failed.'
  Assert-True ($result.RestoredAt -ge $result.DisabledAt) 'Invalid observation order.'
}
Test-Scenario 'preserve existing reason exactly' {
  $script:control.disabled_reason = 'reviewed, (operator) "note" & other'
  Run-Pause | Out-Null
  Assert-True ($script:control.disabled_reason -ceq 'reviewed, (operator) "note" & other') 'Previous reason was erased.'
}
Test-Scenario 'already disabled is never reopened' {
  $script:control.enabled = $false
  Assert-Throws { Run-Pause }
  Assert-True (-not $script:control.enabled -and $script:writes -eq 0) 'Existing stop was changed.'
}
Test-Scenario 'pause compare-and-set conflict' {
  $script:mode = 'conflict-before-pause'
  Assert-Throws { Run-Pause }
  Assert-True (-not $script:control.enabled -and $script:writes -eq 0) 'Concurrent stop was overwritten.'
}
Test-Scenario 'restore compare-and-set conflict' {
  $script:mode = 'conflict-before-restore'
  Assert-Throws { Run-Pause }
  Assert-True ($script:control.disabled_reason -eq 'operator_stop' -and -not $script:control.enabled -and $script:writes -eq 1) 'Operator stop was reopened.'
}
Test-Scenario 'timestamp-only concurrent edit' {
  $script:mode = 'timestamp-only-conflict'
  Assert-Throws { Run-Pause }
  Assert-True (-not $script:control.enabled -and $script:writes -eq 1) 'Timestamp conflict was ignored.'
}
Test-Scenario 'ambiguous pause response cleanup but no success' {
  $script:mode = 'ambiguous-pause'
  Assert-Throws { Run-Pause }
  Assert-True ($script:control.enabled -and $script:writes -eq 2) 'Owned pause was not restored after response loss.'
}
Test-Scenario 'restore failure stays paused' {
  $script:mode = 'restore-network-failure'
  Assert-Throws { Run-Pause }
  Assert-True (-not $script:control.enabled -and $script:writes -eq 1) 'Failed restoration reported success.'
}
Test-Scenario 'readback conflict does not trigger another write' {
  $script:mode = 'readback-conflict'
  Assert-Throws { Run-Pause }
  Assert-True (-not $script:control.enabled -and $script:writes -eq 2) 'Readback conflict was overwritten.'
}
Test-Scenario 'null reason filter and timestamp normalization' {
  $script:control.updated_at = [DateTimeOffset]'2026-01-01T09:00:00+09:00'
  $filter = New-IncidentControlFilter $script:control
  Assert-True ($filter -match '&enabled=eq.true&disabled_reason=is.null&updated_at=eq.2026-01-01T00%3A00%3A00.000000Z$') 'Unsafe null/timestamp filter.'
}
Test-Scenario 'reason cannot inject a REST query predicate' {
  $script:control.disabled_reason = 'quoted",&enabled=eq.false\reason'
  $filter = New-IncidentControlFilter $script:control
  Assert-True ($filter.Split('&').Count -eq 4) 'Reason injected a query parameter.'
  $reason = $filter.Split('&')[2].Substring('disabled_reason=eq.'.Length)
  Assert-True ([Uri]::UnescapeDataString($reason) -ceq '"quoted\",&enabled=eq.false\\reason"') 'Reason was not quoted correctly.'
}
Test-Scenario 'one-hour receipt boundary' {
  $result = Resolve-IncidentTimeline -Detected '2026-01-01T00:00:00Z' -Stopped '2026-01-01T00:15:00Z' -Acknowledged '2026-01-01T01:00:00Z' -Now ([DateTimeOffset]'2026-01-02T00:00:00Z')
  Assert-True (($result.Acknowledged - $result.Detected).TotalMinutes -eq 60) 'One-hour boundary failed.'
}
Test-Scenario 'slow receipt is not hidden by fast script execution' {
  Assert-Throws { Resolve-IncidentTimeline -Detected '2026-01-01T00:00:00Z' -Stopped '2026-01-01T00:15:00Z' -Acknowledged '2026-01-01T01:00:01Z' }
}
Test-Scenario 'out-of-order receipts rejected' {
  Assert-Throws { Resolve-IncidentTimeline -Detected '2026-01-01T00:00:00Z' -Stopped '2026-01-01T00:15:00Z' -Acknowledged '2026-01-01T00:10:00Z' }
}
Test-Scenario 'future receipts rejected' {
  Assert-Throws { Resolve-IncidentTimeline -Detected '2026-01-01T00:00:00Z' -Stopped '2026-01-01T00:15:00Z' -Acknowledged '2026-01-01T00:30:00Z' -Now ([DateTimeOffset]'2026-01-01T00:20:00Z') }
}
Test-Scenario 'ambiguous local timestamp rejected' {
  Assert-Throws { Resolve-IncidentTimeline -Detected '2026-01-01 00:00:00' -Stopped '2026-01-01T00:15:00Z' -Acknowledged '2026-01-01T00:30:00Z' }
}
Write-Host "$script:passed incident guard scenarios passed (no network calls)."
