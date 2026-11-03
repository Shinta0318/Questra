function Get-PlanningEvalVersionPolicy {
  [CmdletBinding()]
  param([Parameter(Mandatory = $true)][object[]]$PlanningRows)

  $configurations = @{}
  $promptVersions = @{}
  $promptConflicts = 0
  $missingEvidence = 0
  foreach ($row in $PlanningRows) {
    $versions = $row.versions
    $pipeline = [string]$versions.pipeline
    $schema = [string]$versions.schema
    $models = @($row.model_versions | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    $thinking = @($row.thinking_levels | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    if ([string]::IsNullOrWhiteSpace($pipeline) -or
        [string]::IsNullOrWhiteSpace($schema) -or
        $models.Count -eq 0 -or $thinking.Count -eq 0 -or
        @($models | Where-Object {
          [string]$_ -notmatch '^[^@\s]+@[^@\s]+$' -or
          [string]$_ -match '@unresolved$'
        }).Count -gt 0 -or
        $null -eq $versions.prompts) {
      $missingEvidence++
      continue
    }
    $configurations["$pipeline|$schema"] = $true
    $prompts = @($versions.prompts.PSObject.Properties)
    if ($prompts.Count -eq 0) {
      $missingEvidence++
      continue
    }
    foreach ($prompt in $prompts) {
      $version = 0
      if (-not [int]::TryParse([string]$prompt.Value, [ref]$version) -or
          $version -le 0) {
        $missingEvidence++
        continue
      }
      if ($promptVersions.ContainsKey($prompt.Name) -and
          $promptVersions[$prompt.Name] -ne $version) {
        $promptConflicts++
      } else {
        $promptVersions[$prompt.Name] = $version
      }
    }
  }

  return [pscustomobject]@{
    configuration_count = $configurations.Count
    prompt_version_conflict_count = $promptConflicts
    missing_version_evidence_count = $missingEvidence
  }
}
