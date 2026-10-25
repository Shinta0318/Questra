function Assert-LoginEntryResponse {
  param(
    [int] $StatusCode,
    [string] $Content,
    [string] $AllowedOrigin,
    [string] $ExpectedOrigin
  )

  $code = $null
  try { $code = ($Content | ConvertFrom-Json).code } catch { }
  if ($StatusCode -ne 401 -or $code -ne 'invalid_credentials') {
    throw 'Supabase login function entry probe failed.'
  }
  if ($AllowedOrigin -ne $ExpectedOrigin) {
    throw 'Supabase login function CORS probe failed.'
  }
}

function Assert-LoginContractVersion {
  param(
    [string] $ActualVersion,
    [switch] $RequireCurrentContract
  )

  $expectedVersion = '2026-10-18.1'
  if ($ActualVersion -eq $expectedVersion) { return $true }
  if ($RequireCurrentContract) {
    throw 'Hosted auth-login contract is older than the local candidate.'
  }
  Write-Warning 'Hosted auth-login contract is older or unverified. Real login behavior is not validated by the entry probe.'
  return $false
}

function Invoke-LoginEntryProbe {
  param(
    [uri] $BaseUri,
    [string] $Key,
    [int] $Port,
    [switch] $RequireCurrentContract
  )

  $origin = "http://127.0.0.1:$Port"
  $response = Invoke-WebRequest `
    -Uri ([uri]::new($BaseUri, '/functions/v1/auth-login')) `
    -Method Post `
    -Headers @{ apikey = $Key; Origin = $origin } `
    -ContentType 'application/json' `
    -Body '{"identifier":"","password":""}' `
    -SkipHttpErrorCheck `
    -TimeoutSec 20
  Assert-LoginEntryResponse -StatusCode $response.StatusCode `
    -Content $response.Content `
    -AllowedOrigin ([string]$response.Headers['Access-Control-Allow-Origin']) `
    -ExpectedOrigin $origin
  $contractCurrent = Assert-LoginContractVersion `
    -ActualVersion ([string]$response.Headers['x-questra-auth-contract']) `
    -RequireCurrentContract:$RequireCurrentContract
  if ($contractCurrent) {
    Write-Host 'Public probe: login entry and source contract PASS (real credentials not tested)'
  } else {
    Write-Host 'Public probe: login entry PASS; source contract UNVERIFIED (real credentials not tested)'
  }
}
