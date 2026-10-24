param(
  [string] $ConfigPath = $(if ($env:QUESTRA_PREVIEW_CONFIG) {
    $env:QUESTRA_PREVIEW_CONFIG
  } else {
    Join-Path $HOME '.questra/beta-preview.env'
  }),
  [ValidateRange(1024, 65535)]
  [int] $Port = 5268,
  [string] $Device = 'web-server',
  [switch] $ValidateOnly,
  [switch] $SkipRemoteProbe,
  [switch] $RequireCurrentAuthContract
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($RequireCurrentAuthContract -and $SkipRemoteProbe) {
  throw 'Current auth contract cannot be required while the remote probe is skipped.'
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $PSScriptRoot 'connected_preview_login_probe.ps1')

function Read-PreviewConfig {
  param([string] $Path)

  $values = @{}
  if ([string]::IsNullOrWhiteSpace($Path)) {
    return $values
  }

  $resolved = (Resolve-Path -LiteralPath $Path).Path
  $repoPrefix = $repoRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) +
    [IO.Path]::DirectorySeparatorChar
  if ($resolved.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Preview configuration must be stored outside the repository.'
  }

  foreach ($line in Get-Content -LiteralPath $resolved -Encoding UTF8) {
    $trimmed = $line.Trim()
    if ($trimmed.Length -eq 0 -or $trimmed.StartsWith('#')) { continue }
    if ($trimmed -notmatch '^(?<name>[A-Z0-9_]+)=(?<value>.*)$') {
      throw 'Preview configuration contains an invalid line.'
    }
    $name = $Matches.name
    if ($name -notin @('SUPABASE_URL', 'SUPABASE_ANON_KEY')) {
      throw "Preview configuration contains prohibited key name: $name"
    }
    $values[$name] = $Matches.value.Trim()
  }
  return $values
}

function ConvertFrom-Base64Url {
  param([string] $Value)

  $normalized = $Value.Replace('-', '+').Replace('_', '/')
  while ($normalized.Length % 4 -ne 0) { $normalized += '=' }
  return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($normalized))
}

function Assert-PublishableKey {
  param(
    [string] $Key,
    [string] $ProjectRef
  )

  if ([string]::IsNullOrWhiteSpace($Key)) {
    throw 'SUPABASE_ANON_KEY is required.'
  }
  if ($Key.StartsWith('sb_secret_', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'A Supabase secret key must never be used by the Flutter client.'
  }
  if ($Key -match '^sb_publishable_[A-Za-z0-9_-]{20,}$') { return }

  $segments = $Key.Split('.')
  if ($segments.Count -ne 3) {
    throw 'SUPABASE_ANON_KEY must be a publishable key or legacy anon JWT.'
  }
  try {
    $payload = ConvertFrom-Base64Url $segments[1] | ConvertFrom-Json
  } catch {
    throw 'SUPABASE_ANON_KEY is not a valid legacy anon JWT.'
  }
  if ($payload.PSObject.Properties.Name -notcontains 'role' -or
      $payload.role -ne 'anon') {
    throw 'Only a Supabase anon client key is allowed.'
  }
  if ($payload.PSObject.Properties.Name -contains 'ref' -and
      $null -ne $payload.ref -and $payload.ref -ne $ProjectRef) {
    throw 'The legacy anon key belongs to a different Supabase project.'
  }
}

function Invoke-PublicProbe {
  param(
    [uri] $BaseUri,
    [string] $Key,
    [int] $Port,
    [switch] $RequireCurrentContract
  )

  $headers = @{ apikey = $Key }
  $auth = Invoke-WebRequest `
    -Uri ([uri]::new($BaseUri, '/auth/v1/settings')) `
    -Headers $headers `
    -Method Get `
    -TimeoutSec 20
  if ($auth.StatusCode -ne 200) {
    throw 'Supabase Auth public probe failed.'
  }

  $rest = Invoke-WebRequest `
    -Uri ([uri]::new($BaseUri, '/rest/v1/quests?select=id&limit=0')) `
    -Headers $headers `
    -Method Get `
    -TimeoutSec 20 `
    -SkipHttpErrorCheck
  if ($rest.StatusCode -eq 200) {
    Write-Host 'Public probes: Auth PASS / Data API PASS'
  } elseif ($rest.StatusCode -eq 401 -and
      ($rest.Content | ConvertFrom-Json).code -eq '42501') {
    Write-Host 'Public probes: Auth PASS / Data API reachable (anonymous Quest access denied)'
  } else {
    throw 'Supabase Data API public probe failed.'
  }
  Invoke-LoginEntryProbe -BaseUri $BaseUri -Key $Key -Port $Port `
    -RequireCurrentContract:$RequireCurrentContract
  Write-Host 'Authenticated data access still requires an in-app smoke test.'
  Write-Host 'Gemini route: server-side Edge Function (authenticated smoke test required in app)'
}

$fileValues = Read-PreviewConfig $ConfigPath
$supabaseUrl = if ($env:SUPABASE_URL) {
  $env:SUPABASE_URL.Trim()
} else {
  [string]$fileValues['SUPABASE_URL']
}
$anonKey = if ($env:SUPABASE_ANON_KEY) {
  $env:SUPABASE_ANON_KEY.Trim()
} else {
  [string]$fileValues['SUPABASE_ANON_KEY']
}

$baseUri = $null
if (-not [uri]::TryCreate($supabaseUrl, [UriKind]::Absolute, [ref]$baseUri) -or
    $baseUri.Scheme -ne 'https') {
  throw 'SUPABASE_URL must be a hosted HTTPS Supabase project URL.'
}
if ($baseUri.Host -notmatch '^(?<ref>[a-z0-9]+)\.supabase\.co$') {
  throw 'SUPABASE_URL must be a hosted HTTPS Supabase project URL.'
}
$projectRef = $Matches.ref
Assert-PublishableKey -Key $anonKey -ProjectRef $projectRef

Write-Host "Connected preview target: $($baseUri.Host)"
Write-Host 'Client credentials: publishable/anon only (validated; value not printed)'
if (-not $SkipRemoteProbe) {
  Invoke-PublicProbe -BaseUri $baseUri -Key $anonKey -Port $Port `
    -RequireCurrentContract:$RequireCurrentAuthContract
}
if ($ValidateOnly) {
  Write-Host 'Connected preview configuration: PASS'
  exit 0
}

$mobileRoot = Join-Path $repoRoot 'apps\mobile'
$defineFile = Join-Path ([IO.Path]::GetTempPath()) (
  'questra-connected-preview-' + [guid]::NewGuid().ToString('N') + '.json'
)
$defines = @{
  SUPABASE_URL = $supabaseUrl
  SUPABASE_ANON_KEY = $anonKey
  APP_ENVIRONMENT = 'production'
  ALLOW_MOCK_PERSISTENCE = $false
  QUESTRA_BUILD_VERSION = 'connected-preview'
}

try {
  $defines | ConvertTo-Json | Set-Content -LiteralPath $defineFile -Encoding UTF8
  Push-Location $mobileRoot
  try {
    $arguments = @('run', '-d', $Device, "--dart-define-from-file=$defineFile")
    if ($Device -eq 'web-server') {
      $arguments += @('--profile', '--web-hostname=127.0.0.1', "--web-port=$Port")
    }
    Write-Host "Starting Questra connected preview on http://127.0.0.1:$Port/"
    & flutter @arguments
    if ($LASTEXITCODE -ne 0) {
      throw "Flutter preview exited with code $LASTEXITCODE."
    }
  } finally {
    Pop-Location
  }
} finally {
  Remove-Item -LiteralPath $defineFile -Force -ErrorAction SilentlyContinue
}
