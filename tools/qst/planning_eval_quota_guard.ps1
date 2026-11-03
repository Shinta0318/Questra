function Assert-PlanningEvalQuotaCapacity {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Policies,
    [Parameter(Mandatory = $true)][int]$CaseCount
  )

  # A successful preview requires ten distinct provider passes before optional repairs.
  $minimumPassesPerCase = 10
  if ($Policies.Count -ne 1 -or $null -eq $Policies[0]) {
    throw 'planning_eval_abort: The free Quest-planning policy is missing or ambiguous.'
  }
  $monthlyLimit = 0
  if (-not [int]::TryParse([string]$Policies[0].monthly_hard_limit, [ref]$monthlyLimit) -or
      $monthlyLimit -lt $CaseCount * $minimumPassesPerCase) {
    throw 'planning_eval_abort: One free account cannot complete the evaluation under its monthly planning-pass limit.'
  }
}
