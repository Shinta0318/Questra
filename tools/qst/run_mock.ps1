param(
  [ValidateRange(1024, 65535)]
  [int] $Port = 5268,
  [string] $ConfigPath = $(if ($env:QUESTRA_PREVIEW_CONFIG) {
    $env:QUESTRA_PREVIEW_CONFIG
  } else {
    Join-Path $HOME '.questra/beta-preview.env'
  }),
  [switch] $ValidateOnly,
  [switch] $Offline,
  [switch] $RequireCurrentAuthContract
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Offline) {
  if ($RequireCurrentAuthContract) {
    throw '-RequireCurrentAuthContract applies to the connected preview only.'
  }
  if ($ValidateOnly) {
    throw '-ValidateOnly applies to the connected preview only.'
  }
  $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
  Write-Host 'Starting offline UI mock: Supabase and Gemini are disabled.'
  Push-Location (Join-Path $repoRoot 'apps\mobile')
  try {
    & flutter run -d web-server --profile `
      --web-hostname=127.0.0.1 "--web-port=$Port" `
      --dart-define=APP_ENVIRONMENT=development `
      --dart-define=ALLOW_MOCK_PERSISTENCE=true `
      --dart-define=AUTO_ENTER_LOCAL_MOCK=true
    if ($LASTEXITCODE -ne 0) {
      throw "Offline mock exited with code $LASTEXITCODE."
    }
  } finally {
    Pop-Location
  }
  return
}

if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
  throw "Connected preview configuration is missing: $ConfigPath. Use -Offline only for a disconnected UI mock."
}

& (Join-Path $PSScriptRoot 'run_connected_preview.ps1') `
  -ConfigPath $ConfigPath -Port $Port -ValidateOnly:$ValidateOnly `
  -RequireCurrentAuthContract:$RequireCurrentAuthContract
