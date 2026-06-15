# QST Tools

Local DEV-QST helpers live here. They use the repository backlog at
`docs/product/qst_backlog.md` and write no files by default.

## Commands

```powershell
.\tools\qst\qst.ps1 next
.\tools\qst\qst.ps1 prompt QST-003
.\tools\qst\qst.ps1 report QST-003
```

- `next`: prints the first `Ready` backlog item.
- `prompt`: prints an implementation prompt for a backlog item.
- `report`: prints a QST report template for a backlog item.

Reports produced from the template should be saved under `reports/qst`.
