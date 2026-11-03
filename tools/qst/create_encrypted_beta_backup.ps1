[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[a-z0-9]{20}$')]
  [string]$ProjectRef,

  [Parameter(Mandatory = $true)]
  [string]$SupabaseCliPath,

  [Parameter(Mandatory = $true)]
  [string]$PgBinDirectory,

  [string]$BackupDirectory = (Join-Path $env:LOCALAPPDATA 'Questra\Backups'),
  [switch]$TemporaryAccess,
  [switch]$CliLoginRole
)

$ErrorActionPreference = 'Stop'
if ($TemporaryAccess -and $CliLoginRole) {
  throw 'Choose either TemporaryAccess or CliLoginRole.'
}
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$linkedRefPath = Join-Path $repoRoot 'supabase/.temp/project-ref'
if (-not (Test-Path -LiteralPath $linkedRefPath) -or
    (Get-Content -Raw -LiteralPath $linkedRefPath).Trim() -cne $ProjectRef) {
  throw 'Linked Supabase project does not match ProjectRef.'
}

$pgDump = Join-Path $PgBinDirectory 'pg_dump.exe'
$pgRestore = Join-Path $PgBinDirectory 'pg_restore.exe'
foreach ($path in @($SupabaseCliPath, $pgDump, $pgRestore)) {
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Required executable is missing: $path"
  }
}

# The placeholder selects the admin connection without putting the real password
# in a command line, log, or file.
Push-Location $repoRoot
try {
  $dryRun = if ($CliLoginRole) {
    & $SupabaseCliPath db dump --dry-run --linked 2>&1 | Out-String
  } else {
    & $SupabaseCliPath db dump --dry-run --linked --password 'placeholder' 2>&1 | Out-String
  }
  if ($LASTEXITCODE -ne 0) { throw 'Supabase connection dry-run failed.' }
} finally {
  Pop-Location
}
$connection = @{}
foreach ($line in ($dryRun -split "`n")) {
  if ($line -match '^export\s+(PGHOST|PGPORT|PGUSER|PGDATABASE|PGPASSWORD)=(".*")\s*$') {
    if ($Matches[1] -ceq 'PGPASSWORD' -and -not $CliLoginRole) { continue }
    $connection[$Matches[1]] = ConvertFrom-Json -InputObject $Matches[2]
  }
}
$expectedConnectionValues = if ($CliLoginRole) { 5 } else { 4 }
if ($connection.Count -ne $expectedConnectionValues -or
    $connection['PGUSER'] -cne "$(if ($CliLoginRole) { 'cli_login_postgres' } else { 'postgres' }).$ProjectRef" -or
    $connection['PGHOST'] -cnotmatch '^[a-z0-9-]+\.pooler\.supabase\.com$' -or
    $connection['PGPORT'] -cne '5432' -or
    $connection['PGDATABASE'] -cne 'postgres' -or
    ($CliLoginRole -and [string]::IsNullOrWhiteSpace($connection['PGPASSWORD']))) {
  throw 'Supabase admin connection could not be verified.'
}

New-Item -ItemType Directory -Force -Path $BackupDirectory | Out-Null
$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$name = "questra-$ProjectRef-$stamp-$([guid]::NewGuid().ToString('N'))"
$plain = Join-Path $env:TEMP "$name.dump"
$encrypted = Join-Path $BackupDirectory "$name.dump.dpapi"
$bstr = [IntPtr]::Zero
$verified = $false
$bytes = $null
$cipher = $null
$roundTrip = $null
$pgEnvironmentKeys = @('PGHOST', 'PGPORT', 'PGUSER', 'PGDATABASE', 'PGPASSWORD', 'PGSSLMODE', 'PGOPTIONS')
$previousEnvironment = @{}
foreach ($key in $pgEnvironmentKeys) {
  $previousEnvironment[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
}
try {
  if (-not $CliLoginRole) {
    $prompt = if ($TemporaryAccess) {
      'Supabase temporary access token (hidden input)'
    } else {
      'Beta database password (hidden input)'
    }
    $securePassword = Read-Host $prompt -AsSecureString
    if ($securePassword.Length -eq 0) { throw 'Database credential was not entered.' }
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
  }
  foreach ($key in @('PGHOST', 'PGPORT', 'PGUSER', 'PGDATABASE')) {
    [Environment]::SetEnvironmentVariable($key, $connection[$key], 'Process')
  }
  $env:PGPASSWORD = if ($CliLoginRole) {
    $connection['PGPASSWORD']
  } else {
    [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  }
  $env:PGSSLMODE = 'require'
  $env:PGOPTIONS = if ($TemporaryAccess) { '-c jit=true' } else { $null }

  $dumpOutput = (& $pgDump --format=custom `
    --schema=public --schema=auth --schema=storage `
    --schema=supabase_migrations --file=$plain 2>&1 | Out-String)
  if ($LASTEXITCODE -ne 0) {
    $failureKind = if ($dumpOutput -match 'password authentication failed|SASL') {
      'authentication'
    } elseif ($dumpOutput -match 'permission denied|must be owner') {
      'insufficient privileges'
    } elseif ($dumpOutput -match 'SSL|pg_hba') {
      'SSL policy'
    } elseif ($dumpOutput -match 'server version mismatch') {
      'PostgreSQL client version'
    } elseif ($dumpOutput -match 'could not connect|connection to server|timeout') {
      'network or connection'
    } else {
      'unclassified'
    }
    throw "pg_dump failed ($failureKind); no backup was saved."
  }
  $toc = & $pgRestore --list $plain 2>&1
  if ($LASTEXITCODE -ne 0 -or @($toc).Count -lt 20) {
    throw 'pg_restore could not read the backup archive.'
  }
  $bytes = [IO.File]::ReadAllBytes($plain)
  $digest = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))
  $cipher = [Security.Cryptography.ProtectedData]::Protect(
    $bytes, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser
  )
  [IO.File]::WriteAllBytes($encrypted, $cipher)
  $roundTrip = [Security.Cryptography.ProtectedData]::Unprotect(
    [IO.File]::ReadAllBytes($encrypted), $null,
    [Security.Cryptography.DataProtectionScope]::CurrentUser
  )
  if ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($roundTrip)) -cne $digest) {
    throw 'Encrypted backup round-trip failed.'
  }
  $verified = $true
  Write-Output "Encrypted backup: $encrypted"
  Write-Output "Archive SHA-256: $digest"
  Write-Output "Archive bytes: $($bytes.Length)"
  Write-Output "Archive TOC entries: $(@($toc).Count)"
} finally {
  foreach ($buffer in @($bytes, $cipher, $roundTrip)) {
    if ($null -ne $buffer) { [Array]::Clear($buffer, 0, $buffer.Length) }
  }
  foreach ($key in $pgEnvironmentKeys) {
    [Environment]::SetEnvironmentVariable($key, $previousEnvironment[$key], 'Process')
  }
  if ($bstr -ne [IntPtr]::Zero) {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }
  $connection['PGPASSWORD'] = $null
  $dryRun = $null
  if (Test-Path -LiteralPath $plain) {
    Remove-Item -LiteralPath $plain -Force
  }
  if (-not $verified -and (Test-Path -LiteralPath $encrypted)) {
    Remove-Item -LiteralPath $encrypted -Force
  }
}
