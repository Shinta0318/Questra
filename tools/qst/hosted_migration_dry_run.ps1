function Assert-HostedMigrationDryRun {
  param(
    [Parameter(Mandatory = $true)][string]$Output,
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$ExpectedMigrationFiles
  )

  $jsonLines = @($Output -split "`r?`n" | Where-Object { $_.TrimStart().StartsWith('{') })
  if ($jsonLines.Count -ne 1) {
    throw 'Supabase dry-run must return exactly one JSON plan.'
  }
  try {
    $plan = $jsonLines[0] | ConvertFrom-Json -ErrorAction Stop
  } catch {
    throw 'Supabase dry-run returned invalid JSON.'
  }
  if ($plan.dryRun -cne $true -or $null -eq $plan.migrations) {
    throw 'Supabase did not return a dry-run migration plan.'
  }
  if (@($plan.roles).Count -ne 0 -or @($plan.seeds).Count -ne 0) {
    throw 'Supabase dry-run includes unreviewed role or seed operations.'
  }

  $actual = @($plan.migrations)
  if ($actual.Count -ne $ExpectedMigrationFiles.Count) {
    throw "Supabase dry-run migration count differs: expected $($ExpectedMigrationFiles.Count), got $($actual.Count)."
  }
  for ($index = 0; $index -lt $actual.Count; $index++) {
    if ($actual[$index] -cne $ExpectedMigrationFiles[$index]) {
      throw "Supabase dry-run migration differs at position $($index + 1)."
    }
  }
}
