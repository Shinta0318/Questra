# Questra Standard QST Report v1.0

## QST ID

AUTO-QST-002

## Title

Migrate QST planner tooling

## Changed files

- docs/product/qst_backlog.md
- tools/qst/README.md
- tools/qst/qst.ps1
- reports/qst/AUTO-QST-002.md

## Implementation summary

- Added a repository-local DEV-QST backlog with concrete Ready candidates.
- Added a lightweight PowerShell QST helper for `next`, `list`, `prompt`, and
  `report` workflows.
- Added usage notes for the QST helper.
- Captured this migration in a QST report so future QST passes can select work
  from inside the repository.

## Test results

- `.\tools\qst\qst.ps1 next`
- `.\tools\qst\qst.ps1 prompt QST-003`
- `.\tools\qst\qst.ps1 report QST-003`
- `flutter analyze`
- `flutter test`

## Known issues

- The QST helper intentionally prints report templates to stdout; it does not
  write files automatically yet.
- Backlog status updates are manual.

## Next QST candidates

- Add formal Trail data model and posting flow.
- Add Arc Chat MVP surface.
- Add QST status update support to the helper.

## Master Spec compliance notes

- DEV-QST work selection now has a local source of truth.
- The helper preserves the selected branch rule:
  `codex/initial-questra-structure-pr`.
