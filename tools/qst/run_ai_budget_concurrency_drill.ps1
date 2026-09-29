[CmdletBinding()]
param(
  [string]$DatabaseUrl = $env:SUPABASE_DB_URL,
  [string]$ProbeReservationId = $env:QST453_PROBE_RESERVATION_ID,
  [string]$ReviewerAuthUserA = $env:QST453_REVIEWER_AUTH_USER_A,
  [string]$ReviewerAuthUserB = $env:QST453_REVIEWER_AUTH_USER_B,
  [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'
$uuidPattern = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$'

foreach ($value in @($ProbeReservationId, $ReviewerAuthUserA, $ReviewerAuthUserB)) {
  if ($value -notmatch $uuidPattern) {
    throw 'QST-453 requires a probe reservation and two valid reviewer Auth UUIDs.'
  }
}
if ($ReviewerAuthUserA -eq $ReviewerAuthUserB) {
  throw 'QST-453 reviewers must be different Auth users.'
}
if ([string]::IsNullOrWhiteSpace($DatabaseUrl)) {
  if ($ValidateOnly) {
    Write-Output 'QST-453 concurrency runner structure is valid; database execution was skipped.'
    return
  }
  throw 'Set SUPABASE_DB_URL for the isolated candidate database.'
}

try { $uri = [Uri]$DatabaseUrl } catch { throw 'SUPABASE_DB_URL is invalid.' }
if ($uri.Scheme -notin @('postgres', 'postgresql') -or [string]::IsNullOrWhiteSpace($uri.Host)) {
  throw 'SUPABASE_DB_URL must be a PostgreSQL URL with a host.'
}
$userInfo = $uri.UserInfo.Split(':', 2)
if ($userInfo.Count -ne 2) { throw 'SUPABASE_DB_URL must include credentials.' }
$databaseUser = [Uri]::UnescapeDataString($userInfo[0])
$databasePassword = [Uri]::UnescapeDataString($userInfo[1])
$databaseName = [Uri]::UnescapeDataString($uri.AbsolutePath.TrimStart('/'))
if ([string]::IsNullOrWhiteSpace($databaseName)) { $databaseName = 'postgres' }
$databasePort = if ($uri.Port -gt 0) { $uri.Port } else { 5432 }
$isLocal = $uri.Host -in @('127.0.0.1', 'localhost', '::1')

if ($ValidateOnly) {
  Write-Output 'QST-453 concurrency runner inputs are valid; identifiers were not printed.'
  return
}
if (-not (Get-Command psql -ErrorAction SilentlyContinue)) {
  throw 'psql is required for the QST-453 concurrency drill.'
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "questra-qst453-$([Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $tempRoot | Out-Null
$previousPassword = $env:PGPASSWORD
$previousSsl = $env:PGSSLMODE
$previousTimeout = $env:PGCONNECTTIMEOUT

function New-ReviewerSql([string]$authUser, [string]$path) {
  $claims = ('{"sub":"' + $authUser + '","role":"authenticated"}').Replace("'", "''")
  $sql = @"
\set ON_ERROR_STOP on
begin;
select set_config('request.jwt.claims', '$claims', true) as claims \gset
set local role authenticated;
select count(*) from public.claim_my_ai_budget_reconciliation_cases(1, interval '5 minutes')
where reservation_id = '$ProbeReservationId'::uuid;
commit;
"@
  Set-Content -LiteralPath $path -Value $sql -Encoding UTF8
}

function PsqlArguments([string]$file) {
  return @(
    '--host', $uri.Host,
    '--port', $databasePort,
    '--username', $databaseUser,
    '--dbname', $databaseName,
    '-Atq', '-v', 'ON_ERROR_STOP=1', '-f', $file
  )
}

try {
  $env:PGPASSWORD = $databasePassword
  $env:PGSSLMODE = if ($isLocal) { 'prefer' } else { 'require' }
  $env:PGCONNECTTIMEOUT = '15'

  $preflight = Join-Path $tempRoot 'preflight.sql'
  Set-Content -LiteralPath $preflight -Encoding UTF8 -Value @"
\set ON_ERROR_STOP on
select case when count(*) = 1 and bool_and(reservation_id = '$ProbeReservationId'::uuid)
  then 'ready' else 'not_ready' end
from public.ai_budget_reconciliation_cases
where status = 'open' and (claimed_by is null or claim_expires_at <= now());
"@
  $preflightArguments = PsqlArguments $preflight
  $preflightResult = (& psql @preflightArguments 2>&1 | Out-String).Trim()
  if ($LASTEXITCODE -ne 0 -or $preflightResult -ne 'ready') {
    throw 'The candidate must contain exactly one claimable dedicated probe case.'
  }

  $sqlA = Join-Path $tempRoot 'reviewer-a.sql'
  $sqlB = Join-Path $tempRoot 'reviewer-b.sql'
  $outA = Join-Path $tempRoot 'reviewer-a.out'
  $outB = Join-Path $tempRoot 'reviewer-b.out'
  $errA = Join-Path $tempRoot 'reviewer-a.err'
  $errB = Join-Path $tempRoot 'reviewer-b.err'
  New-ReviewerSql $ReviewerAuthUserA $sqlA
  New-ReviewerSql $ReviewerAuthUserB $sqlB

  $processA = Start-Process -FilePath 'psql' -ArgumentList (PsqlArguments $sqlA) `
    -WindowStyle Hidden -PassThru -RedirectStandardOutput $outA -RedirectStandardError $errA
  $processB = Start-Process -FilePath 'psql' -ArgumentList (PsqlArguments $sqlB) `
    -WindowStyle Hidden -PassThru -RedirectStandardOutput $outB -RedirectStandardError $errB
  $processA.WaitForExit()
  $processB.WaitForExit()
  if ($processA.ExitCode -ne 0 -or $processB.ExitCode -ne 0) {
    throw 'A concurrent reviewer session failed.'
  }
  $claimCount = [int](Get-Content -Raw $outA).Trim() + [int](Get-Content -Raw $outB).Trim()
  if ($claimCount -ne 1) { throw 'Exactly one reviewer must claim the probe case.' }

  $release = Join-Path $tempRoot 'release.sql'
  Set-Content -LiteralPath $release -Encoding UTF8 -Value @"
\set ON_ERROR_STOP on
begin;
select set_config('request.jwt.claims', '{"role":"service_role"}', true)
  as claims \gset
set local role service_role;
select case when claimed_by is not null then 'claimed' else 'missing' end
from public.ai_budget_reconciliation_cases
where reservation_id = '$ProbeReservationId'::uuid;
select public.release_ai_budget_reconciliation_claim(
  '$ProbeReservationId'::uuid,
  (select claimed_by from public.ai_budget_reconciliation_cases
   where reservation_id = '$ProbeReservationId'::uuid)
);
commit;
"@
  $releaseArguments = PsqlArguments $release
  $releaseOutput = (& psql @releaseArguments 2>&1 | Out-String)
  if ($LASTEXITCODE -ne 0 -or -not $releaseOutput.Contains('claimed')) {
    throw 'Probe claim cleanup failed.'
  }
  Write-Output 'QST-453 concurrent claim drill: PASS (one winner, claim released, audit retained).'
} finally {
  $env:PGPASSWORD = $previousPassword
  $env:PGSSLMODE = $previousSsl
  $env:PGCONNECTTIMEOUT = $previousTimeout
  if (Test-Path -LiteralPath $tempRoot) {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
  }
}
