param(
  [string] $ConfigPath = $env:QUESTRA_PREVIEW_CONFIG,
  [ValidateRange(1024, 65535)]
  [int] $Port = 5268,
  [string] $Device = 'web-server',
  [switch] $ValidateOnly,
  [switch] $SkipRemoteProbe
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

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
    [string] $Key
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
    -Uri ([uri]::new($BaseUri, '/rest/v1/')) `
    -Headers $headers `
    -Method Get `
    -TimeoutSec 20
  if ($rest.StatusCode -ne 200) {
    throw 'Supabase Data API public probe failed.'
  }

  Write-Host 'Public probes: Auth PASS / Data API PASS'
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
  Invoke-PublicProbe -BaseUri $baseUri -Key $anonKey
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
      $arguments += @('--web-hostname=127.0.0.1', "--web-port=$Port")
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
