param(
  [string] $SeedPath = "tools/qst/arc_quest_guide_eval_cases.json",
  [string] $OutputPath = "tools/qst/quest_planning_eval_200.json"
)

$ErrorActionPreference = "Stop"
$personas = @(
  @{ id = "beginner"; weekly_minutes = 120; experience = "beginner"; budget = $null; preferences = @("guided steps") },
  @{ id = "busy"; weekly_minutes = 135; experience = "some experience"; budget = $null; preferences = @("15 minute weekdays", "weekend focus") },
  @{ id = "low_budget"; weekly_minutes = 180; experience = "beginner"; budget = "minimal budget"; preferences = @("lower cost") },
  @{ id = "experienced"; weekly_minutes = 300; experience = "experienced"; budget = $null; preferences = @("efficiency focused") }
)
$seeds = Get-Content -Raw -Encoding UTF8 $SeedPath | ConvertFrom-Json
$corpus = foreach ($seed in $seeds) {
  foreach ($persona in $personas) {
    [ordered]@{
      id = [string]($seed.id + "-" + $persona.id)
      title = $seed.title
      description = [string]$seed.description
      category = $seed.category
      expected_keywords = @($seed.expected_keywords)
      persona = $persona.id
      planning_context = [ordered]@{
        consent_granted = $true
        weekly_minutes = $persona.weekly_minutes
        budget_label = $persona.budget
        experience = $persona.experience
        preferences = @($persona.preferences)
      }
    }
  }
}
if ($corpus.Count -lt 200) { throw "Expected at least 200 evaluation cases." }
$corpus | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 $OutputPath
Write-Output "Generated $($corpus.Count) cases at $OutputPath"
