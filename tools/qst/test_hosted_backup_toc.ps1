$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/hosted_backup_attestation.ps1"

$tables = @(
  'auth users',
  'public user_profiles',
  'public quests',
  'public missions',
  'public tasks',
  'public trails',
  'public media',
  'storage objects',
  'supabase_migrations schema_migrations'
)
$tocLines = @($tables | ForEach-Object { "1; 0 1 TABLE DATA $_ postgres" })
Assert-QuestraBackupToc -Toc ($tocLines -join "`n")
Write-Output 'PASS: all required backup table entries accepted'

foreach ($missing in $tables) {
  $incomplete = @($tocLines | Where-Object { $_ -cne "1; 0 1 TABLE DATA $missing postgres" })
  try {
    Assert-QuestraBackupToc -Toc ($incomplete -join "`n")
  } catch {
    if ($_.Exception.Message -cne "Encrypted backup is missing TABLE DATA for $missing.") {
      throw
    }
    continue
  }
  throw "Backup TOC gate accepted missing $missing."
}
Write-Output 'PASS: each missing required table entry rejected'

$renamed = @($tocLines | ForEach-Object { $_ -creplace 'TABLE DATA public quests ', 'TABLE DATA public quests_archive ' })
try {
  Assert-QuestraBackupToc -Toc ($renamed -join "`n")
} catch {
  if ($_.Exception.Message -cne 'Encrypted backup is missing TABLE DATA for public quests.') {
    throw
  }
  Write-Output 'PASS: similarly named table cannot satisfy Quest entry'
  exit 0
}
throw 'Backup TOC gate accepted a similarly named Quest table.'
