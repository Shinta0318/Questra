param([string]$PgRestorePath = '')

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/hosted_backup_attestation.ps1"

$id = [guid]::NewGuid().ToString('N')
$archive = Join-Path $env:TEMP "questra-backup-gate-$id.dump.dpapi"
$evidencePath = Join-Path $env:TEMP "questra-backup-gate-$id.json"
$projectRef = 'dhbmgwarnrtelrcrmmfk'
$head = '202608080006_route_proposal_stale_conflict_guard.sql'

function Assert-Rejected([string]$Label) {
  try {
    Assert-HostedBackupAttestation -EvidencePath $evidencePath `
      -ProjectRef $projectRef -RemoteHead $head | Out-Null
  } catch {
    Write-Output "PASS: $Label"
    return
  }
  throw "Backup gate accepted $Label."
}

try {
  Assert-Rejected 'missing evidence'
  [IO.File]::WriteAllBytes($archive, [byte[]](1, 2, 3, 4))
  $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $archive).Hash
  $evidence = @{
    project_ref = $projectRef
    remote_head = $head
    encrypted_archive_path = $archive
    encrypted_archive_sha256 = $hash
    backup_created_at_utc = [DateTimeOffset]::UtcNow.AddMinutes(-20).ToString('o')
    restore_tested_at_utc = [DateTimeOffset]::UtcNow.AddMinutes(-10).ToString('o')
    restore_result = 'passed'
    restore_target_ref = 'tpynzjjqajpkzivgapfq'
  }
  $evidence | ConvertTo-Json | Set-Content -LiteralPath $evidencePath -Encoding UTF8
  $result = Assert-HostedBackupAttestation -EvidencePath $evidencePath `
    -ProjectRef $projectRef -RemoteHead $head
  if ($result.ArchiveSha256 -cne $hash.ToLowerInvariant()) {
    throw 'Valid backup attestation returned the wrong archive hash.'
  }
  Write-Output 'PASS: matching local attestation'

  try {
    Assert-HostedBackupArchive -ArchivePath $archive `
      -PgRestorePath (Get-Process -Id $PID).Path
    throw 'Archive probe accepted non-DPAPI bytes.'
  } catch {
    if ($_.Exception.Message -eq 'Archive probe accepted non-DPAPI bytes.') { throw }
    Write-Output 'PASS: non-DPAPI archive rejected'
  }

  if ($PgRestorePath) {
    $cipher = [Security.Cryptography.ProtectedData]::Protect(
      [Text.Encoding]::UTF8.GetBytes('not a PostgreSQL archive'), $null,
      [Security.Cryptography.DataProtectionScope]::CurrentUser
    )
    [IO.File]::WriteAllBytes($archive, $cipher)
    try {
      Assert-HostedBackupArchive -ArchivePath $archive `
        -PgRestorePath $PgRestorePath
      throw 'Archive probe accepted invalid PostgreSQL content.'
    } catch {
      if ($_.Exception.Message -eq 'Archive probe accepted invalid PostgreSQL content.') { throw }
      Write-Output 'PASS: decrypted non-archive rejected'
    }
    [IO.File]::WriteAllBytes($archive, [byte[]](1, 2, 3, 4))
  }

  $evidence.encrypted_archive_sha256 = '0' * 64
  $evidence | ConvertTo-Json | Set-Content -LiteralPath $evidencePath -Encoding UTF8
  Assert-Rejected 'archive hash mismatch'
  $evidence.encrypted_archive_sha256 = $hash

  $evidence.restore_result = 'pending'
  $evidence | ConvertTo-Json | Set-Content -LiteralPath $evidencePath -Encoding UTF8
  Assert-Rejected 'restore not verified'
  $evidence.restore_result = 'passed'

  $evidence.restore_target_ref = $projectRef
  $evidence | ConvertTo-Json | Set-Content -LiteralPath $evidencePath -Encoding UTF8
  Assert-Rejected 'restore targeted Beta'
  $evidence.restore_target_ref = 'tpynzjjqajpkzivgapfq'

  $evidence.backup_created_at_utc = [DateTimeOffset]::UtcNow.AddHours(-25).ToString('o')
  $evidence | ConvertTo-Json | Set-Content -LiteralPath $evidencePath -Encoding UTF8
  Assert-Rejected 'stale backup'
} finally {
  foreach ($path in @($archive, $evidencePath)) {
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
  }
}
