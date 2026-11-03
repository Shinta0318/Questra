[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$PgBinDirectory)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/hosted_backup_attestation.ps1"

$initdb = Join-Path $PgBinDirectory 'initdb.exe'
$pgCtl = Join-Path $PgBinDirectory 'pg_ctl.exe'
$postgres = Join-Path $PgBinDirectory 'postgres.exe'
$pgIsReady = Join-Path $PgBinDirectory 'pg_isready.exe'
$psql = Join-Path $PgBinDirectory 'psql.exe'
$pgDump = Join-Path $PgBinDirectory 'pg_dump.exe'
$pgRestore = Join-Path $PgBinDirectory 'pg_restore.exe'
$createdb = Join-Path $PgBinDirectory 'createdb.exe'
foreach ($exe in @($initdb, $pgCtl, $postgres, $pgIsReady, $psql, $pgDump, $pgRestore, $createdb)) {
  if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw "Missing PostgreSQL binary: $exe" }
}

$root = Join-Path $env:TEMP "questra-archive-roundtrip-$([guid]::NewGuid().ToString('N'))"
$data = Join-Path $root 'data'
$stdoutLog = Join-Path $root 'postgres.stdout.log'
$stderrLog = Join-Path $root 'postgres.stderr.log'
$plain = Join-Path $root 'probe.dump'
$encrypted = Join-Path $root 'probe.dump.dpapi'
$incompletePlain = Join-Path $root 'probe-incomplete.dump'
$incompleteEncrypted = Join-Path $root 'probe-incomplete.dump.dpapi'
$server = $null
New-Item -ItemType Directory -Path $root | Out-Null
$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$listener.Start()
$port = ([Net.IPEndPoint]$listener.LocalEndpoint).Port
$listener.Stop()

try {
  & $initdb -D $data -U postgres --auth=trust --encoding=UTF8 --no-instructions *> $null
  if ($LASTEXITCODE -ne 0) { throw 'Temporary PostgreSQL initdb failed.' }
  $server = Start-Process -FilePath $postgres `
    -ArgumentList "-D `"$data`" -h 127.0.0.1 -p $port" `
    -WorkingDirectory $root -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog
  $ready = $false
  for ($attempt = 0; $attempt -lt 60; $attempt++) {
    & $pgIsReady -h 127.0.0.1 -p $port -U postgres *> $null
    if ($LASTEXITCODE -eq 0) { $ready = $true; break }
    if ($server.HasExited) { break }
    Start-Sleep -Milliseconds 500
  }
  if (-not $ready) { throw 'Temporary PostgreSQL did not become ready.' }

  $sql = 'create schema auth; create schema storage; create schema supabase_migrations; ' +
    'create table auth.users (id integer); ' +
    'create table public.user_profiles (id integer); ' +
    'create table public.quests (id integer); ' +
    'create table public.missions (id integer); ' +
    'create table public.tasks (id integer); ' +
    'create table public.trails (id integer); ' +
    'create table public.media (id integer); ' +
    'create table storage.objects (id integer); ' +
    'create table supabase_migrations.schema_migrations (id integer); ' +
    'insert into auth.users values (1); ' +
    'insert into public.user_profiles values (1); ' +
    'insert into public.quests values (1); ' +
    'insert into public.missions values (1); ' +
    'insert into public.tasks values (1); ' +
    'insert into public.trails values (1); ' +
    'insert into public.media values (1); ' +
    'insert into storage.objects values (1); ' +
    'insert into supabase_migrations.schema_migrations values (1);'
  & $psql -h 127.0.0.1 -p $port -U postgres -d postgres -v ON_ERROR_STOP=1 -c $sql *> $null
  if ($LASTEXITCODE -ne 0) { throw 'Temporary PostgreSQL fixture failed.' }
  & $pgDump -h 127.0.0.1 -p $port -U postgres -d postgres `
    --format=custom --schema=auth --schema=public --schema=storage `
    --schema=supabase_migrations --file=$plain *> $null
  if ($LASTEXITCODE -ne 0) { throw 'Temporary PostgreSQL dump failed.' }

  $bytes = [IO.File]::ReadAllBytes($plain)
  try {
    $cipher = [Security.Cryptography.ProtectedData]::Protect(
      $bytes, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser
    )
    [IO.File]::WriteAllBytes($encrypted, $cipher)
    [Array]::Clear($cipher, 0, $cipher.Length)
  } finally {
    [Array]::Clear($bytes, 0, $bytes.Length)
  }
  Assert-HostedBackupArchive -ArchivePath $encrypted -PgRestorePath $pgRestore
  Write-Output 'PASS: valid DPAPI-encrypted Questra-shaped PostgreSQL archive accepted'

  & $pgDump -h 127.0.0.1 -p $port -U postgres -d postgres `
    --format=custom --schema=auth --schema=public --schema=storage `
    --schema=supabase_migrations --exclude-table=storage.objects `
    --file=$incompletePlain *> $null
  if ($LASTEXITCODE -ne 0) { throw 'Incomplete PostgreSQL fixture dump failed.' }
  $bytes = [IO.File]::ReadAllBytes($incompletePlain)
  try {
    $cipher = [Security.Cryptography.ProtectedData]::Protect(
      $bytes, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser
    )
    [IO.File]::WriteAllBytes($incompleteEncrypted, $cipher)
    [Array]::Clear($cipher, 0, $cipher.Length)
  } finally {
    [Array]::Clear($bytes, 0, $bytes.Length)
  }
  try {
    Assert-HostedBackupArchive -ArchivePath $incompleteEncrypted -PgRestorePath $pgRestore
    throw 'Incomplete archive was accepted.'
  } catch {
    if ($_.Exception.Message -cne 'Encrypted backup is missing TABLE DATA for storage objects.') {
      throw
    }
    Write-Output 'PASS: archive without Storage object metadata rejected'
  }

  & $createdb -h 127.0.0.1 -p $port -U postgres -T template0 archive_probe_restored *> $null
  if ($LASTEXITCODE -ne 0) { throw 'Temporary restore database creation failed.' }
  & $pgRestore -h 127.0.0.1 -p $port -U postgres -d archive_probe_restored `
    --clean --if-exists --no-owner --no-acl $plain *> $null
  if ($LASTEXITCODE -ne 0) { throw 'Temporary PostgreSQL restore failed.' }
  $counts = & $psql -h 127.0.0.1 -p $port -U postgres -d archive_probe_restored `
    -v ON_ERROR_STOP=1 -At -c ('select (select count(*) from auth.users), ' +
      '(select count(*) from public.user_profiles), (select count(*) from public.quests), ' +
      '(select count(*) from public.missions), (select count(*) from public.tasks), ' +
      '(select count(*) from public.trails), (select count(*) from public.media), ' +
      '(select count(*) from storage.objects), ' +
      '(select count(*) from supabase_migrations.schema_migrations);')
  if ($LASTEXITCODE -ne 0 -or ($counts -join '').Trim() -ne '1|1|1|1|1|1|1|1|1') {
    throw 'Temporary restored row counts do not match the source.'
  }
  Write-Output 'PASS: isolated synthetic PostgreSQL restore preserves all required table rows'
} finally {
  if ($server -and -not $server.HasExited) {
    & $pgCtl -D $data -m fast -w stop *> $null
    if (-not $server.WaitForExit(10000)) {
      throw "Temporary PostgreSQL did not stop: $root"
    }
  }
  $resolved = [IO.Path]::GetFullPath($root).TrimEnd('\')
  $tempRoot = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')
  if ($resolved.StartsWith($tempRoot + '\', [StringComparison]::OrdinalIgnoreCase) -and
      [IO.Path]::GetFileName($resolved) -match '^questra-archive-roundtrip-[a-f0-9]{32}$') {
    Remove-Item -LiteralPath $resolved -Recurse -Force
  } else {
    throw 'Temporary cleanup path verification failed.'
  }
}
