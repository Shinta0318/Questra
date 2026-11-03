$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/planning_eval_quota_guard.ps1"

function Assert-Rejected($Policies) {
  $rejected = $false
  try {
    Assert-PlanningEvalQuotaCapacity -Policies $Policies -CaseCount 200
  } catch {
    if ($_.Exception.Message.StartsWith('planning_eval_abort:')) { $rejected = $true } else { throw }
  }
  if (-not $rejected) { throw 'Impossible provider evaluation must be refused before account creation.' }
}

Assert-Rejected @()
Assert-Rejected @([pscustomobject]@{ monthly_hard_limit = 30 })
Assert-Rejected @([pscustomobject]@{ monthly_hard_limit = 150 })
Assert-Rejected @([pscustomobject]@{ monthly_hard_limit = 1999 })
Assert-Rejected @([pscustomobject]@{ monthly_hard_limit = 'unknown' })
Assert-Rejected @(
  [pscustomobject]@{ monthly_hard_limit = 2000 },
  [pscustomobject]@{ monthly_hard_limit = 2000 }
)
Assert-PlanningEvalQuotaCapacity -Policies @([pscustomobject]@{ monthly_hard_limit = 2000 }) -CaseCount 200
Write-Host 'Planning evaluation quota guard: PASS (no network or provider calls).'
