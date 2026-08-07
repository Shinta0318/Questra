param(
  [Parameter(Mandatory = $true)] [string] $Url,
  [string] $PublishableKey = $env:SUPABASE_ANON_KEY,
  [string] $CasesPath = "tools/qst/quest_planning_eval_200.json",
  [string] $OutputPath = "reports/qst/evaluations/arc_quest_guide_results.json",
  [int] $Start = 0,
  [int] $Count = 200,
  [int] $DelayMilliseconds = 4500
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($PublishableKey)) {
  throw "PublishableKey or SUPABASE_ANON_KEY is required."
}

$cases = Get-Content -Raw -Encoding UTF8 $CasesPath | ConvertFrom-Json
$selected = @($cases | Select-Object -Skip $Start -First $Count)
$results = [System.Collections.Generic.List[object]]::new()

foreach ($case in $selected) {
  $started = Get-Date
  try {
    $headers = @{
      apikey = $PublishableKey
      Authorization = "Bearer $PublishableKey"
    }
    $body = @{
      quest = @{
        id = "eval-$($case.id)"
        title = $case.title
        description = $case.description
        difficulty = "normal"
        category = $case.category
        planning_context = $case.planning_context
      }
    } | ConvertTo-Json -Depth 6 -Compress
    $webResponse = Invoke-WebRequest -UseBasicParsing -Method Post -Uri $Url -Headers $headers `
      -ContentType "application/json; charset=utf-8" `
      -Body ([Text.Encoding]::UTF8.GetBytes($body))
    $responseText = [Text.Encoding]::UTF8.GetString(
      $webResponse.RawContentStream.ToArray()
    )
    $response = $responseText | ConvertFrom-Json
    $missions = @($response.mission_candidates)
    $titles = @($missions | ForEach-Object { [string]$_.title })
    $descriptions = @($missions | ForEach-Object { [string]$_.description })
    $combined = ($titles + $descriptions) -join " "
    $doneCount = @($descriptions | Where-Object {
      $_ -match "完了|できたら|終えたら|確認できたら|保存したら|記録したら"
    }).Count
    $domainHits = @($case.expected_keywords | Where-Object {
      $combined -match [regex]::Escape([string]$_)
    })
    $uniqueTitleCount = @($titles | Sort-Object -Unique).Count
    # QST-183 made Mission count adaptive: simple Quests need fewer steps,
    # while long journeys can legitimately require a deeper route.
    $countPass = $missions.Count -ge 3 -and $missions.Count -le 30
    $donePass = $missions.Count -gt 0 -and ($doneCount / $missions.Count) -ge 0.8
    $domainPass = $domainHits.Count -ge 2
    $uniquePass = $uniqueTitleCount -eq $missions.Count
    $sourcePass = [string]$response.source_type -like "gemini*"
    $qualityScore = if ($null -ne $response.plan_quality -and
      $null -ne $response.plan_quality.score) {
      [double]$response.plan_quality.score
    } else {
      0
    }
    $qualityPass = $qualityScore -ge 0.70
    $contractPass = @($missions | Where-Object {
      [string]::IsNullOrWhiteSpace([string]$_.action) -or
      [string]::IsNullOrWhiteSpace([string]$_.done_condition) -or
      $null -eq $_.confidence
    }).Count -eq 0
    $contentPass = $countPass -and $donePass -and $domainPass -and $uniquePass -and $qualityPass -and $contractPass
    $results.Add([pscustomobject]@{
      id = $case.id
      category = $case.category
      title = $case.title
      status = "ok"
      source_type = $response.source_type
      mission_count = $missions.Count
      done_condition_count = $doneCount
      domain_keyword_hits = @($domainHits)
      unique_title_count = $uniqueTitleCount
      duration_ms = [int]((Get-Date) - $started).TotalMilliseconds
      quality_score = $qualityScore
      estimated_output_tokens = [math]::Ceiling($responseText.Length / 4)
      estimated_cost_usd = 0
      content_passed = $contentPass
      passed = $contentPass -and $sourcePass
      checks = [ordered]@{
        mission_count = $countPass
        done_conditions = $donePass
        domain_specificity = $domainPass
        unique_titles = $uniquePass
        gemini_source = $sourcePass
        plan_quality = $qualityPass
        mission_contract = $contractPass
      }
      missions = @($missions | ForEach-Object {
        [ordered]@{ title = $_.title; description = $_.description }
      })
    })
  } catch {
    $results.Add([pscustomobject]@{
      id = $case.id
      category = $case.category
      title = $case.title
      status = "error"
      error = $_.Exception.Message
      duration_ms = [int]((Get-Date) - $started).TotalMilliseconds
      passed = $false
    })
  }
  if ($DelayMilliseconds -gt 0) {
    Start-Sleep -Milliseconds $DelayMilliseconds
  }
}

$existing = @()
if ($Start -gt 0 -and (Test-Path $OutputPath)) {
  $existing = Get-Content -Raw -Encoding UTF8 $OutputPath | ConvertFrom-Json
}
$merged = @($existing + $results)
$directory = Split-Path -Parent $OutputPath
if ($directory) {
  New-Item -ItemType Directory -Force $directory | Out-Null
}
$merged | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 $OutputPath

$passed = @($results | Where-Object passed).Count
$errors = @($results | Where-Object status -eq "error").Count
$gemini = @($results | Where-Object { [string]$_.source_type -like "gemini*" }).Count
$passRate = if ($results.Count -eq 0) { 0 } else { $passed / $results.Count }
$geminiRate = if ($results.Count -eq 0) { 0 } else { $gemini / $results.Count }
[pscustomobject]@{
  start = $Start
  evaluated = $results.Count
  passed = $passed
  errors = $errors
  pass_rate = [math]::Round($passRate, 4)
  gemini_rate = [math]::Round($geminiRate, 4)
  output = $OutputPath
} | ConvertTo-Json -Compress

if ($results.Count -gt 0 -and ($passRate -lt 0.90 -or $geminiRate -lt 0.90)) {
  throw "Quest planning quality gate failed: pass=$([math]::Round($passRate * 100, 1))% gemini=$([math]::Round($geminiRate * 100, 1))%"
}
