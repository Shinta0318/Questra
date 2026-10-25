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
Write-Host 'Hosted migration dry-run contract tests passed.'
