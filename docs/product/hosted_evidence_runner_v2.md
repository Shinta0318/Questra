# Hosted Evidence Runner V2

Status: QST-373 implementation complete; cloud execution pending.

## Purpose

`tools/qst/run_hosted_evidence_gate.ps1` is the only supported entry point for
deploying and validating the Beta Supabase candidate. It refuses a dirty
worktree, records the source SHA, deploys every migration and Edge Function,
runs transactional RLS tests, creates ephemeral two-account fixtures, sanitizes
evidence, and removes test accounts.

## V2 Coverage

The core run proves deployment parity, baseline RLS behavior, and the existing
Quest/Mission/Task/Trail/Memory/Route/Guild persistence journey. QST-373 extends
the RLS suite to Data Rights requests and runtime evidence, including denial of
direct mutation and denial of operator tables.

Extended evidence remains explicitly separated:

- QST-374: Data Rights fulfillment and retention.
- QST-375: observability alerts and retention.
- QST-376: physical Android accessibility and Japanese IME.
- QST-377: exact dependency license approval.
- QST-378: Arc chain of title.
- QST-379: feedback/incident operations.
- QST-380: provider-backed AI quality/cost.

The runner writes these as pending rather than treating deployment success as
behavioral proof.

## Execution

Preflight makes no remote changes:

```powershell
./tools/qst/run_hosted_evidence_gate.ps1 `
  -ProjectRef <ref> -Region ap-northeast-1 -Owner <owner> `
  -DashboardEvidence <sanitized-description>
```

After reviewing the candidate and local secret file, repeat with `-Apply`.
Never place secret values, test account identifiers, private journey content, or
database URLs in committed evidence.

## Failure Policy

Any migration mismatch, RLS failure, cleanup failure, or candidate SHA mismatch
stops the run. Do not mark a later step passed manually. Use a forward migration
or function fix and rerun from a new clean candidate; do not use destructive
database down migrations.
