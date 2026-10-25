$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/hosted_auth_fixture.ps1"

$rows = '[{"name":"anon","api_key":"public-test"},' +
  '{"name":"service_role","api_key":"service-test"}]'
foreach ($payload in @($rows, ('{"keys":' + $rows + '}'))) {
  $keys = ConvertFrom-HostedApiKeyJson -Json $payload
  if ($keys.AnonKey -ne 'public-test' -or
      $keys.ServiceRoleKey -ne 'service-test') {
    throw 'Hosted API key parser rejected a supported CLI response.'
  }
}

foreach ($payload in @(
  '[]',
  '[{"name":"anon","api_key":"public-test"}]',
  '[{"name":"anon","api_key":"public-test"},' +
    '{"name":"anon","api_key":"duplicate"},' +
    '{"name":"service_role","api_key":"service-test"}]'
)) {
  $rejected = $false
  try {
    ConvertFrom-HostedApiKeyJson -Json $payload | Out-Null
  } catch {
    $rejected = $true
  }
  if (-not $rejected) {
    throw 'Hosted API key parser accepted missing or ambiguous keys.'
  }
}

function Invoke-RestMethod {
  return @([pscustomobject]@{
    region_code = 'JP'
    eligibility_version = 'eligibility-v1'
    terms_version = 'terms-v1'
    privacy_version = 'privacy-v1'
    ai_disclosure_version = 'ai-v1'
  })
}
$metadata = Get-HostedLegalFixtureMetadata `
  -ProjectUrl 'https://example.invalid' -AdminHeaders @{ apikey = 'test' }
if ($metadata.Count -ne 6 -or $metadata.region_code -ne 'JP' -or
    $metadata.minimum_age_confirmed -ne $true) {
  throw 'Hosted fixture metadata did not match the active legal policy.'
}

function Invoke-RestMethod { return @() }
$rejected = $false
try {
  Get-HostedLegalFixtureMetadata `
    -ProjectUrl 'https://example.invalid' -AdminHeaders @{ apikey = 'test' } |
    Out-Null
} catch {
  $rejected = $true
}
if (-not $rejected) {
  throw 'Hosted fixture metadata accepted a missing active legal policy.'
}

Write-Output 'Hosted auth fixture contract passed.'
