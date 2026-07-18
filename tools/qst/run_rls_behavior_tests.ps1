[CmdletBinding()]
param(
  [string]$DatabaseUrl = $env:SUPABASE_DB_URL,
  [string]$TestFile = 'supabase/tests/rls_behavior.sql',
  [string]$SupabaseCommand = 'supabase',
  [switch]$LinkedCli,
  [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $TestFile)) {
  throw "RLS behavior test file was not found: $TestFile"
}

if ($LinkedCli) {
  if (-not (Get-Command $SupabaseCommand -ErrorAction SilentlyContinue)) {
    throw "Supabase CLI was not found: $SupabaseCommand"
  }

  $psqlSource = Get-Content -Raw -Encoding UTF8 -LiteralPath $TestFile
  $variables = @{}
  $variablePattern = "(?m)^\\set\s+([A-Za-z_][A-Za-z0-9_]*)\s+'([^']*)'\s*$"
  foreach ($match in [regex]::Matches($psqlSource, $variablePattern)) {
    $variables[$match.Groups[1].Value] = $match.Groups[2].Value
  }

  $linkedSql = [regex]::Replace(
    $psqlSource,
    '(?m)^\\set\s+.*\r?\n?',
    ''
  )
  $linkedSql = [regex]::Replace(
    $linkedSql,
    "(?m)^\\echo\s+'([^']*)'\s*$",
    { param($match) "select '$($match.Groups[1].Value)' as qst_message;" }
  )
  foreach ($name in $variables.Keys) {
    $escapedValue = $variables[$name].Replace("'", "''")
    $linkedSql = $linkedSql.Replace(":'$name'", "'$escapedValue'")
  }
  if ($linkedSql -match '(?m)^\\') {
    throw 'Unsupported psql metacommand remains after linked CLI conversion.'
  }
  if ($linkedSql -match ":'[A-Za-z_][A-Za-z0-9_]*'") {
    throw 'Unresolved psql variable remains after linked CLI conversion.'
  }

  Write-Output 'RLS database target: linked Supabase project via Management API'
  if ($ValidateOnly) {
    Write-Output 'RLS test converted for linked CLI execution without database credentials.'
    return
  }

  $temporarySql = Join-Path (
    [System.IO.Path]::GetTempPath()
  ) "questra-rls-$([Guid]::NewGuid().ToString('N')).sql"
  try {
    Set-Content -LiteralPath $temporarySql -Value $linkedSql -Encoding UTF8
    $previousErrorActionPreference = $ErrorActionPreference
    try {
      $ErrorActionPreference = 'Continue'
      $output = & $SupabaseCommand db query --linked --file $temporarySql 2>&1
      $exitCode = $LASTEXITCODE
    } finally {
      $ErrorActionPreference = $previousErrorActionPreference
    }
    $output | ForEach-Object {
      if ($_ -is [System.Management.Automation.ErrorRecord]) {
        Write-Output $_.Exception.Message
      } else {
        Write-Output $_
      }
    }
    if ($exitCode -ne 0) {
      throw "Linked CLI RLS behavior tests failed with exit code $exitCode."
    }
    if (-not (($output -join [Environment]::NewLine).Contains(
      'QST-041 RLS behavior tests passed'
    ))) {
      throw 'Linked CLI output did not contain the RLS pass marker.'
    }
  } finally {
    if (Test-Path -LiteralPath $temporarySql) {
      Remove-Item -LiteralPath $temporarySql -Force
    }
  }
  return
}

if ([string]::IsNullOrWhiteSpace($DatabaseUrl)) {
  throw 'Set SUPABASE_DB_URL or pass -DatabaseUrl to run database-backed RLS behavior tests.'
}

try {
  $uri = [Uri]$DatabaseUrl
} catch {
  throw 'SUPABASE_DB_URL must be a valid PostgreSQL connection URL.'
}
if ($uri.Scheme -notin @('postgres', 'postgresql')) {
  throw 'SUPABASE_DB_URL must use the postgres or postgresql scheme.'
}
if ([string]::IsNullOrWhiteSpace($uri.Host)) {
  throw 'SUPABASE_DB_URL must include a database host.'
}

$userInfo = $uri.UserInfo.Split(':', 2)
if ($userInfo.Count -ne 2 -or [string]::IsNullOrWhiteSpace($userInfo[0])) {
  throw 'SUPABASE_DB_URL must include an encoded username and password.'
}
$databaseUser = [Uri]::UnescapeDataString($userInfo[0])
$databasePassword = [Uri]::UnescapeDataString($userInfo[1])
if ([string]::IsNullOrWhiteSpace($databasePassword)) {
  throw 'SUPABASE_DB_URL password is empty.'
}
$databaseName = [Uri]::UnescapeDataString($uri.AbsolutePath.TrimStart('/'))
if ([string]::IsNullOrWhiteSpace($databaseName)) {
  $databaseName = 'postgres'
}
$databasePort = if ($uri.Port -gt 0) { $uri.Port } else { 5432 }
$isLocal = $uri.Host -in @('127.0.0.1', 'localhost', '::1')
$sslMode = if ($isLocal) { 'prefer' } else { 'require' }
$sanitizedTarget = "$($uri.Host):$databasePort/$databaseName as $databaseUser"

Write-Output "RLS database target: $sanitizedTarget"
if ($ValidateOnly) {
  Write-Output 'RLS connection URL validated without exposing its password.'
  return
}

if (-not (Get-Command psql -ErrorAction SilentlyContinue)) {
  throw 'psql was not found. Install PostgreSQL client tools or run inside an environment that provides psql.'
}

$previousPassword = $env:PGPASSWORD
$previousSslMode = $env:PGSSLMODE
$previousConnectTimeout = $env:PGCONNECT_TIMEOUT
try {
  $env:PGPASSWORD = $databasePassword
  $env:PGSSLMODE = $sslMode
  $env:PGCONNECT_TIMEOUT = '15'

  & psql `
    --host $uri.Host `
    --port $databasePort `
    --username $databaseUser `
    --dbname $databaseName `
    -v ON_ERROR_STOP=1 `
    -f $TestFile
  if ($LASTEXITCODE -ne 0) {
    throw "RLS behavior tests failed with exit code $LASTEXITCODE."
  }
} finally {
  $env:PGPASSWORD = $previousPassword
  $env:PGSSLMODE = $previousSslMode
  $env:PGCONNECT_TIMEOUT = $previousConnectTimeout
}
