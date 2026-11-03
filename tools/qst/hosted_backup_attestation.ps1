function Assert-HostedBackupAttestation {
  param(
    [string]$EvidencePath,
    [string]$ProjectRef,
    [string]$RemoteHead
  )

  if (-not $EvidencePath -or -not (Test-Path -LiteralPath $EvidencePath -PathType Leaf)) {
    throw 'A local backup and restore attestation is required before hosted migration deployment.'
  }
  try {
    $evidence = Get-Content -Raw -LiteralPath $EvidencePath | ConvertFrom-Json
  } catch {
    throw 'Backup attestation is not valid JSON.'
  }
  if ($evidence.project_ref -cne $ProjectRef -or
      $evidence.remote_head -cne $RemoteHead) {
    throw 'Backup attestation does not match the target project and migration head.'
  }
  $archive = [string]$evidence.encrypted_archive_path
  if (-not [IO.Path]::IsPathRooted($archive) -or
      -not $archive.EndsWith('.dump.dpapi', [StringComparison]::OrdinalIgnoreCase) -or
      -not (Test-Path -LiteralPath $archive -PathType Leaf)) {
    throw 'Encrypted backup archive is missing.'
  }
  $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $archive).Hash
  if ($evidence.encrypted_archive_sha256 -cnotmatch '^[a-fA-F0-9]{64}$' -or
      $actualHash -cne $evidence.encrypted_archive_sha256.ToUpperInvariant()) {
    throw 'Encrypted backup archive SHA-256 does not match the attestation.'
  }
  $backupAt = [DateTimeOffset]::MinValue
  $restoreAt = [DateTimeOffset]::MinValue
  if (-not [DateTimeOffset]::TryParse([string]$evidence.backup_created_at_utc, [ref]$backupAt) -or
      -not [DateTimeOffset]::TryParse([string]$evidence.restore_tested_at_utc, [ref]$restoreAt) -or
      $backupAt -gt $restoreAt -or
      $restoreAt -gt [DateTimeOffset]::UtcNow -or
      [DateTimeOffset]::UtcNow - $backupAt -gt [TimeSpan]::FromHours(24)) {
    throw 'Backup and restore timestamps are missing, inconsistent, or stale.'
  }
  if ($evidence.restore_result -cne 'passed' -or
      $evidence.restore_target_ref -cnotmatch '^[a-z0-9]{20}$' -or
      $evidence.restore_target_ref -ceq $ProjectRef) {
    throw 'An isolated restore rehearsal must be attested as passed.'
  }
  return [pscustomobject]@{
    ArchiveSha256 = $actualHash.ToLowerInvariant()
    RestoreTestedAtUtc = $restoreAt.ToString('o')
    EvidenceSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $EvidencePath).Hash.ToLowerInvariant()
  }
}

function Assert-QuestraBackupToc {
  param([string]$Toc)

  foreach ($table in @(
      'auth users',
      'public user_profiles',
      'public quests',
      'public missions',
      'public tasks',
      'public trails',
      'public media',
      'storage objects',
      'supabase_migrations schema_migrations'
  )) {
    $parts = $table.Split(' ')
    $pattern = '(?m)\bTABLE DATA\s+' + [regex]::Escape($parts[0]) +
      '\s+' + [regex]::Escape($parts[1]) + '\b'
    if ($Toc -cnotmatch $pattern) {
      throw "Encrypted backup is missing TABLE DATA for $table."
    }
  }
}

function Assert-HostedBackupArchive {
  param([string]$ArchivePath, [string]$PgRestorePath)

  if (-not $PgRestorePath -or -not (Test-Path -LiteralPath $PgRestorePath -PathType Leaf)) {
    throw 'pg_restore is required to inspect the encrypted backup archive.'
  }
  $plainPath = [IO.Path]::GetTempFileName()
  $cipher = $null
  $plain = $null
  try {
    $cipher = [IO.File]::ReadAllBytes($ArchivePath)
    try {
      $plain = [Security.Cryptography.ProtectedData]::Unprotect(
        $cipher, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser
      )
    } catch {
      throw 'Encrypted backup cannot be decrypted by the current operator.'
    }
    [IO.File]::WriteAllBytes($plainPath, $plain)
    $toc = & $PgRestorePath --list $plainPath 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
      throw 'Encrypted backup is not a readable Questra logical archive.'
    }
    Assert-QuestraBackupToc -Toc $toc
  } finally {
    if ($plain) { [Array]::Clear($plain, 0, $plain.Length) }
    if ($cipher) { [Array]::Clear($cipher, 0, $cipher.Length) }
    if (Test-Path -LiteralPath $plainPath) { Remove-Item -LiteralPath $plainPath -Force }
  }
}
