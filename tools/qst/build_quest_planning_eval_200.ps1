param(
  [string] $SeedPath = "tools/qst/arc_quest_guide_eval_cases.json",
  [string] $OutputPath = "tools/qst/quest_planning_eval_200.json"
)

$ErrorActionPreference = "Stop"
$personas = @(
  @{ id = "beginner"; weekly_minutes = 120; experience = "beginner"; budget = $null; preferences = @("guided steps") },
  @{ id = "experienced"; weekly_minutes = 300; experience = "experienced"; budget = $null; preferences = @("efficiency focused") },
  @{ id = "busy"; weekly_minutes = 135; experience = "some experience"; budget = $null; preferences = @("15 minute weekdays", "weekend focus") },
  @{ id = "low_budget"; weekly_minutes = 180; experience = "beginner"; budget = "minimal budget"; preferences = @("lower cost") },
  @{ id = "high_budget"; weekly_minutes = 240; experience = "some experience"; budget = "flexible budget"; preferences = @("quality first") },
  @{ id = "with_children"; weekly_minutes = 150; experience = "some experience"; budget = $null; preferences = @("child friendly", "family schedule") },
  @{ id = "solo"; weekly_minutes = 210; experience = "beginner"; budget = $null; preferences = @("solo safety", "independent pace") },
  @{ id = "group"; weekly_minutes = 180; experience = "some experience"; budget = $null; preferences = @("shared decisions", "group coordination") },
  @{ id = "short_deadline"; weekly_minutes = 360; experience = "some experience"; budget = $null; preferences = @("short deadline", "critical path") },
  @{ id = "long_deadline"; weekly_minutes = 120; experience = "beginner"; budget = $null; preferences = @("long horizon", "sustainable pace") },
  @{ id = "rural"; weekly_minutes = 180; experience = "beginner"; budget = $null; preferences = @("limited local access", "remote options") },
  @{ id = "overseas"; weekly_minutes = 210; experience = "some experience"; budget = $null; preferences = @("overseas resident", "timezone aware") },
  @{ id = "information_poor"; weekly_minutes = 150; experience = "unknown"; budget = $null; preferences = @("explicit assumptions", "clarify only critical unknowns") },
  @{ id = "multi_constraint"; weekly_minutes = 90; experience = "beginner"; budget = "minimal budget"; preferences = @("limited time", "limited budget", "accessible steps") }
)
$seeds = Get-Content -Raw -Encoding UTF8 $SeedPath | ConvertFrom-Json
$corpus = for ($seedIndex = 0; $seedIndex -lt $seeds.Count; $seedIndex++) {
  $seed = $seeds[$seedIndex]
  for ($offset = 0; $offset -lt 4; $offset++) {
    $persona = $personas[(($seedIndex * 4) + $offset) % $personas.Count]
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
if ($corpus.Count -ne 200) { throw "Expected exactly 200 evaluation cases." }
$corpus | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 $OutputPath
Write-Output "Generated $($corpus.Count) cases at $OutputPath"
