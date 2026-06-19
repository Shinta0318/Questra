param(
  [string]$DatabaseUrl = $env:SUPABASE_DB_URL,
  [string]$TestFile = "supabase/tests/rls_behavior.sql"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($DatabaseUrl)) {
  Write-Error "Set SUPABASE_DB_URL or pass -DatabaseUrl to run database-backed RLS behavior tests."
}

if (-not (Get-Command psql -ErrorAction SilentlyContinue)) {
  Write-Error "psql was not found. Install PostgreSQL client tools or run inside an environment that provides psql."
}

if (-not (Test-Path -LiteralPath $TestFile)) {
  Write-Error "RLS behavior test file was not found: $TestFile"
}

psql $DatabaseUrl -v ON_ERROR_STOP=1 -f $TestFile
