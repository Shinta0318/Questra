[CmdletBinding()]
param(
  [string]$DatabaseUrl = $env:SUPABASE_DB_URL,
  [string]$TestFile = 'supabase/tests/rls_behavior.sql',
  [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($DatabaseUrl)) {
  throw 'Set SUPABASE_DB_URL or pass -DatabaseUrl to run database-backed RLS behavior tests.'
}
if (-not (Test-Path -LiteralPath $TestFile)) {
  throw "RLS behavior test file was not found: $TestFile"
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
