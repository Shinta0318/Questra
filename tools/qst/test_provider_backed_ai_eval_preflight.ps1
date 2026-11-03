$ErrorActionPreference = 'Stop'
foreach ($scenario in @(
  @{ switches = @(); expected = 'Explicit approval for synthetic account legal and AI acceptance' },
  @{ switches = @('-SyntheticAccountConsentApproved'); expected = 'Explicit approval for provider usage' },
  @{ switches = @('-SyntheticAccountConsentApproved', '-ProviderUsageApproved'); expected = 'An approved estimated planning list-cost ceiling' }
)) {
  $rejected = $false
  try {
    $parameters = @{
      ProjectRef = 'tpynzjjqajpkzivgapfq';
      InputUsdPerMillionTokens = 1;
      OutputUsdPerMillionTokens = 1;
      PricingVersion = 'synthetic-test'
    }
    foreach ($item in $scenario.switches) {
      $parameters[$item.TrimStart('-')] = $true
    }
    & "$PSScriptRoot/run_provider_backed_ai_eval.ps1" @parameters
  } catch {
    if ($_.Exception.Message -like "$($scenario.expected)*") {
      $rejected = $true
    } else {
      throw
    }
  }
  if (-not $rejected) { throw 'Provider-backed evaluation passed a required preflight guard.' }
}
Write-Output 'Provider-backed evaluation approval and cost preflight passed.'
