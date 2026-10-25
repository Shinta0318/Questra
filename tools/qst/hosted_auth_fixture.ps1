function ConvertFrom-HostedApiKeyJson {
  param([Parameter(Mandatory = $true)][string]$Json)

  $parsed = ConvertFrom-Json -InputObject $Json -NoEnumerate
  $rows = if ($parsed -is [array]) {
    @($parsed)
  } elseif ($null -ne $parsed.keys) {
    @($parsed.keys)
  } else {
    throw 'Hosted API key response has an unsupported shape.'
  }
  $anon = @($rows | Where-Object { $_.name -eq 'anon' })
  $serviceRole = @($rows | Where-Object { $_.name -eq 'service_role' })
  if ($anon.Count -ne 1 -or $serviceRole.Count -ne 1 -or
      [string]::IsNullOrWhiteSpace($anon[0].api_key) -or
      [string]::IsNullOrWhiteSpace($serviceRole[0].api_key)) {
    throw 'Hosted API key response must contain one anon and one service_role key.'
  }
  return [pscustomobject]@{
    AnonKey = [string]$anon[0].api_key
    ServiceRoleKey = [string]$serviceRole[0].api_key
  }
}

function Get-HostedApiKeys {
  param(
    [Parameter(Mandatory = $true)][string]$SupabaseCommand,
    [Parameter(Mandatory = $true)][string]$ProjectRef
  )

  $json = & $SupabaseCommand projects api-keys --project-ref $ProjectRef `
    --reveal --output json 2>$null | Out-String
  if ($LASTEXITCODE -ne 0) {
    throw 'Unable to fetch hosted API keys.'
  }
  return ConvertFrom-HostedApiKeyJson -Json $json
}

function Get-HostedLegalFixtureMetadata {
  param(
    [Parameter(Mandatory = $true)][string]$ProjectUrl,
    [Parameter(Mandatory = $true)][hashtable]$AdminHeaders
  )

  $path = 'legal_release_policies?select=region_code,eligibility_version,' +
    'terms_version,privacy_version,ai_disclosure_version' +
    '&region_code=eq.JP&active=eq.true'
  $response = Invoke-RestMethod -Uri "$ProjectUrl/rest/v1/$path" `
    -Method Get -Headers $AdminHeaders
  $policies = @($response | Where-Object { $null -ne $_ })
  if ($policies.Count -ne 1) {
    throw 'Exactly one active JP legal policy is required for hosted fixtures.'
  }
  $policy = $policies[0]
  foreach ($field in @(
    'region_code', 'eligibility_version', 'terms_version',
    'privacy_version', 'ai_disclosure_version'
  )) {
    if ([string]::IsNullOrWhiteSpace([string]$policy.$field)) {
      throw "Active JP legal policy is missing $field."
    }
  }
  return @{
    region_code = [string]$policy.region_code
    minimum_age_confirmed = $true
    eligibility_version = [string]$policy.eligibility_version
    terms_version = [string]$policy.terms_version
    privacy_version = [string]$policy.privacy_version
    ai_disclosure_version = [string]$policy.ai_disclosure_version
  }
}
