function New-PlanningEvalLedgerUri {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][string]$ProjectUrl,
    [Parameter(Mandatory = $true)][string]$OwnerId,
    [Parameter(Mandatory = $true)][string]$AttemptKey
  )
  $columns = 'id,user_id,operation,idempotency_key,status,actual_input_tokens,actual_output_tokens,actual_cost_micros'
  $pattern = [uri]::EscapeDataString("like.${AttemptKey}:*")
  return "$ProjectUrl/rest/v1/ai_budget_reservations?select=$columns&user_id=eq.$OwnerId&operation=eq.quest_planning&idempotency_key=$pattern&limit=201"
}

function Measure-PlanningEvalLedgerCost {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Reservations,
    [Parameter(Mandatory = $true)][string]$OwnerId,
    [Parameter(Mandatory = $true)][string]$AttemptKey,
    [Parameter(Mandatory = $true)][double]$InputUsdPerMillionTokens,
    [Parameter(Mandatory = $true)][double]$OutputUsdPerMillionTokens,
    [Parameter(Mandatory = $true)][double]$CurrentEstimatedUsd,
    [Parameter(Mandatory = $true)][double]$MaxEstimatedUsd
  )

  if ($Reservations.Count -eq 0 -or $Reservations.Count -gt 200 -or
      $MaxEstimatedUsd -le 0 -or $InputUsdPerMillionTokens -le 0 -or
      $OutputUsdPerMillionTokens -le 0) {
    throw 'planning_eval_abort: Planning usage ledger is missing or oversized.'
  }
  $seenIds = @{}
  $inputTokens = 0L
  $outputTokens = 0L
  $costMicros = 0L
  foreach ($row in $Reservations) {
    $id = [string]$row.id
    if ([string]::IsNullOrWhiteSpace($id) -or $seenIds.ContainsKey($id) -or
        [string]$row.user_id -cne $OwnerId -or
        [string]$row.operation -cne 'quest_planning' -or
        -not ([string]$row.idempotency_key).StartsWith("${AttemptKey}:", [StringComparison]::Ordinal) -or
        [string]$row.status -cne 'settled') {
      throw 'planning_eval_abort: Planning usage ledger is incomplete or belongs to another attempt.'
    }
    $seenIds[$id] = $true
    $inputCount = 0L
    $outputCount = 0L
    $micros = 0L
    if (-not [long]::TryParse([string]$row.actual_input_tokens, [ref]$inputCount) -or
        -not [long]::TryParse([string]$row.actual_output_tokens, [ref]$outputCount) -or
        -not [long]::TryParse([string]$row.actual_cost_micros, [ref]$micros) -or
        $inputCount -lt 0 -or $outputCount -lt 0 -or $micros -lt 0) {
      throw 'planning_eval_abort: Planning usage ledger has missing actual tokens or cost.'
    }
    $inputTokens += $inputCount
    $outputTokens += $outputCount
    $costMicros += $micros
  }
  if ($inputTokens + $outputTokens -le 0) {
    throw 'planning_eval_abort: Planning usage ledger reports no provider tokens.'
  }
  $pricedTokensUsd = ($inputTokens * $InputUsdPerMillionTokens +
    $outputTokens * $OutputUsdPerMillionTokens) / 1000000
  $caseUsd = [math]::Max($pricedTokensUsd, $costMicros / 1000000)
  $totalUsd = $CurrentEstimatedUsd + $caseUsd
  if ($totalUsd -gt $MaxEstimatedUsd) {
    throw 'planning_eval_abort: The approved estimated planning list-cost ceiling was exceeded.'
  }
  return [pscustomobject]@{
    input_tokens = $inputTokens
    output_tokens = $outputTokens
    case_usd = $caseUsd
    total_usd = $totalUsd
  }
}
