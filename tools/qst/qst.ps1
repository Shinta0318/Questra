param(
  [Parameter(Position = 0)]
  [ValidateSet("next", "prompt", "report", "list")]
  [string]$Command = "next",

  [Parameter(Position = 1)]
  [string]$QstId
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$backlogPath = Join-Path $repoRoot "docs\product\qst_backlog.md"

if (-not (Test-Path $backlogPath)) {
  throw "QST backlog not found: $backlogPath"
}

function Get-QstItems {
  $rows = Get-Content -Encoding UTF8 $backlogPath |
    Where-Object { $_ -match '^\|\s*QST-\d+\s*\|' }

  foreach ($row in $rows) {
    $columns = $row.Trim("|").Split("|") | ForEach-Object { $_.Trim() }
    if ($columns.Count -lt 5) {
      continue
    }

    [pscustomobject]@{
      Id = $columns[0]
      Status = $columns[1]
      Title = $columns[2]
      Scope = $columns[3]
      Acceptance = $columns[4]
    }
  }
}

function Get-SelectedQst {
  param([string]$Id)

  $items = @(Get-QstItems)
  if ($Id) {
    $match = $items | Where-Object { $_.Id -eq $Id } | Select-Object -First 1
  } else {
    $match = $items | Where-Object { $_.Status -eq "Ready" } | Select-Object -First 1
  }

  if (-not $match) {
    throw "No matching QST found."
  }

  $match
}

function Write-QstSummary {
  param($Item)

  @"
$($Item.Id): $($Item.Title)
Status: $($Item.Status)
Scope: $($Item.Scope)
Acceptance: $($Item.Acceptance)
"@
}

function Write-QstPrompt {
  param($Item)

  @"
Use DEV-QST to implement $($Item.Id): $($Item.Title).

Scope:
$($Item.Scope)

Acceptance:
$($Item.Acceptance)

Working rules:
- Use branch codex/initial-questra-structure-pr.
- Keep the change focused to this QST.
- Run formatting, static analysis, and tests when applicable.
- Add or update reports/qst/$($Item.Id).md with changed files, test results, known issues, and next QST candidates.
"@
}

function Write-QstReportTemplate {
  param($Item)

  @"
# Questra Standard QST Report v1.0

## QST ID

$($Item.Id)

## Title

$($Item.Title)

## Changed files

- TBD

## Implementation summary

- TBD

## Test results

- TBD

## Known issues

- TBD

## Next QST candidates

- TBD

## Master Spec compliance notes

- TBD
"@
}

$selected = Get-SelectedQst -Id $QstId

switch ($Command) {
  "list" {
    Get-QstItems | ForEach-Object { Write-QstSummary $_; "" }
  }
  "next" {
    Write-QstSummary $selected
  }
  "prompt" {
    Write-QstPrompt $selected
  }
  "report" {
    Write-QstReportTemplate $selected
  }
}
