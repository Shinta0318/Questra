$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/hosted_migration_dry_run.ps1"

function Expect-Rejected {
  param([string]$Plan, [string[]]$Expected)
  try {
    Assert-HostedMigrationDryRun -Output $Plan -ExpectedMigrationFiles $Expected
  } catch {
    return
  }
  throw 'Unsafe dry-run plan was accepted.'
}

$expected = @('202608090001_first.sql', '202608090002_second.sql')
$valid = '{"dryRun":true,"migrations":["202608090001_first.sql","202608090002_second.sql"],"roles":[],"seeds":[]}'
Assert-HostedMigrationDryRun -Output "Connecting to remote database...`n$valid" -ExpectedMigrationFiles $expected
Expect-Rejected -Plan '{"dryRun":false,"migrations":["202608090001_first.sql","202608090002_second.sql"]}' -Expected $expected
Expect-Rejected -Plan '{"dryRun":true,"migrations":["202608090001_first.sql"]}' -Expected $expected
Expect-Rejected -Plan '{"dryRun":true,"migrations":["202608090002_second.sql","202608090001_first.sql"]}' -Expected $expected
Expect-Rejected -Plan '{"dryRun":true,"migrations":["202608090001_first.sql","202608090002_second.sql","202608090003_extra.sql"]}' -Expected $expected
Expect-Rejected -Plan '{"dryRun":true,"migrations":["202608090001_first.sql","202608090002_second.sql"],"seeds":["seed.sql"]}' -Expected $expected
Expect-Rejected -Plan '{"dryRun":true,"migrations":["202608090001_first.sql","202608090002_second.sql"],"roles":["roles.sql"]}' -Expected $expected
Expect-Rejected -Plan '{not-json}' -Expected $expected

Assert-HostedMigrationDryRun -Output '{"dryRun":true,"migrations":[],"roles":[],"seeds":[]}' -ExpectedMigrationFiles @()
$migrationList = '{"migrations":[{"local":"202608080006","remote":"202608080006"},{"local":"202608090001","remote":""}],"message":"Migrations listed"}'
$versions = @(Get-HostedRemoteVersions -Output "Connecting to remote database...`n$migrationList")
if ($versions.Count -ne 1 -or $versions[0] -cne '202608080006') {
  throw 'Hosted migration history was not parsed correctly.'
}
Expect-Rejected -Plan '{"dryRun":true,"migrations":[]}' -Expected @('missing.sql')
foreach ($invalidList in @(
  '{"migrations":[{"local":"202608080006","remote":"202608080007"}],"message":"Migrations listed"}',
  '{"migrations":[{"local":"202608090001","remote":""},{"local":"202608080006","remote":"202608080006"}],"message":"Migrations listed"}',
  '{"migrations":[{"local":"202608080006","remote":"202608080006"},{"local":"202608080005","remote":"202608080005"}],"message":"Migrations listed"}',
  '{"migrations":[{"local":"202608080006","remote":"bad"}],"message":"Migrations listed"}'
)) {
  try {
    Get-HostedRemoteVersions -Output $invalidList | Out-Null
  } catch {
    continue
  }
  throw 'Unsafe migration history was accepted.'
}
Write-Host 'Hosted migration dry-run contract tests passed.'
