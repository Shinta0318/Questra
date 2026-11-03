$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/planning_eval_cost_guard.ps1"

function New-Reservation($Id, $Owner, $Key, $Status, $InputCount, $OutputCount, $Micros) {
  return [pscustomobject]@{
    id = $Id; user_id = $Owner; operation = 'quest_planning';
    idempotency_key = $Key; status = $Status;
    actual_input_tokens = $InputCount; actual_output_tokens = $OutputCount;
    actual_cost_micros = $Micros
  }
}

function Assert-Rejected($Rows, $Owner, $Key, $Limit) {
  $rejected = $false
  try {
    Measure-PlanningEvalLedgerCost -Reservations $Rows -OwnerId $Owner -AttemptKey $Key `
      -InputUsdPerMillionTokens 1 -OutputUsdPerMillionTokens 2 `
      -CurrentEstimatedUsd 0 -MaxEstimatedUsd $Limit | Out-Null
  } catch {
    if ($_.Exception.Message.StartsWith('planning_eval_abort:')) { $rejected = $true } else { throw }
  }
  if (-not $rejected) { throw 'Invalid planning ledger must stop the run.' }
}

$owner = '11111111-1111-4111-8111-111111111111'
$key = 'qst380-offline-case-1'
$rows = @(
  (New-Reservation 'a' $owner "${key}:understanding:hash" 'settled' 100 50 200),
  (New-Reservation 'b' $owner "${key}:mission:hash" 'settled' 200 75 250)
)
$cost = Measure-PlanningEvalLedgerCost -Reservations $rows -OwnerId $owner -AttemptKey $key `
  -InputUsdPerMillionTokens 1 -OutputUsdPerMillionTokens 2 `
  -CurrentEstimatedUsd 0 -MaxEstimatedUsd 0.01
if ($cost.input_tokens -ne 300 -or $cost.output_tokens -ne 125 -or
    [math]::Abs($cost.case_usd - 0.00055) -gt 0.00000001) {
  throw 'All pass usage and the conservative price estimate must be counted.'
}

$uri = New-PlanningEvalLedgerUri -ProjectUrl 'https://example.supabase.co' -OwnerId $owner -AttemptKey $key
if ($uri -notmatch '/rest/v1/ai_budget_reservations\?' -or
    [uri]::UnescapeDataString($uri) -notmatch [regex]::Escape("idempotency_key=like.${key}:*")) {
  throw 'Ledger query must select the complete attempt prefix.'
}

Assert-Rejected @() $owner $key 0.01
Assert-Rejected @($rows[0], $rows[0]) $owner $key 0.01
Assert-Rejected @((New-Reservation 'a' 'other' "${key}:mission:hash" 'settled' 1 1 1)) $owner $key 0.01
Assert-Rejected @((New-Reservation 'a' $owner 'other:mission:hash' 'settled' 1 1 1)) $owner $key 0.01
Assert-Rejected @((New-Reservation 'a' $owner "${key}:mission:hash" 'released' 1 1 1)) $owner $key 0.01
Assert-Rejected @((New-Reservation 'a' $owner "${key}:mission:hash" 'settled' $null 1 1)) $owner $key 0.01
Assert-Rejected @((New-Reservation 'a' $owner "${key}:mission:hash" 'settled' 1 1 $null)) $owner $key 0.01
Assert-Rejected @((New-Reservation 'a' $owner "${key}:mission:hash" 'settled' 1 1 -1)) $owner $key 0.01
Assert-Rejected @((1..201 | ForEach-Object { New-Reservation "row-$_" $owner "${key}:mission:hash-$_" 'settled' 1 1 1 })) $owner $key 0.01
Assert-Rejected $rows $owner $key 0.0001
Write-Host 'Planning evaluation ledger guard: PASS (no network or provider calls).'
