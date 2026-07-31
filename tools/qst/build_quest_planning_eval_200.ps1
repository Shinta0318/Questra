param(
  [string] $SeedPath = "tools/qst/arc_quest_guide_eval_cases.json",
  [string] $OutputPath = "tools/qst/quest_planning_eval_200.json"
)

$ErrorActionPreference = "Stop"
$personas = @(
  @{ id = "beginner"; context = "beginner; 2 hours per week" },
  @{ id = "busy"; context = "15 minutes weekdays; 1 hour weekend" },
  @{ id = "low_budget"; context = "minimal budget" },
  @{ id = "experienced"; context = "experienced; efficiency focused" }
)
$seeds = Get-Content -Raw -Encoding UTF8 $SeedPath | ConvertFrom-Json
$corpus = foreach ($seed in $seeds) {
  foreach ($persona in $personas) {
    [ordered]@{
      id = [string]($seed.id + "-" + $persona.id)
      title = $seed.title
      description = [string]($seed.description + " Planning context: " + $persona.context)
      category = $seed.category
      expected_keywords = @($seed.expected_keywords)
      persona = $persona.id
      planning_context = $persona.context
    }
  }
}
if ($corpus.Count -lt 200) { throw "Expected at least 200 evaluation cases." }
$corpus | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 $OutputPath
Write-Output "Generated $($corpus.Count) cases at $OutputPath"
