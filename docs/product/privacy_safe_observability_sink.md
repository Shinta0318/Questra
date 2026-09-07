# Privacy-Safe Observability Sink

Status: QST-370 local implementation complete; hosted activation pending.

## Collection Boundary

The app emits only the normalized `RuntimeEvidence` contract. Raw exceptions,
stack text, account identifiers, email, phone, tokens, Quest/Mission/Task/Trail
content, Arc conversations, images, and URLs are not accepted fields. The
authenticated RPC assigns ownership from `auth.uid()` and rejects unknown keys,
missing keys, unsafe tokens, invalid classifications, and stale timestamps.

Direct table writes are denied. Owners may inspect only their own metadata.
Alert operators receive build, severity, surface, operation, and normalized
error code; they do not receive the event owner.

## Activation

The hosted sink is off by default. It requires all of:

1. Supabase configuration.
2. Migrations `202608250008_privacy_safe_runtime_observability.sql` through
   `202608250009_runtime_observability_exact_operator_drill.sql` deployed.
3. Privacy/Legal copy reviewed for the Beta channel.
4. `ENABLE_RUNTIME_EVIDENCE_SINK=true` on the approved candidate build.
5. A successful two-account, retention, alert delivery, and failure-continuity
   drill bound to the same clean candidate SHA.

The sink catches transport failures and cannot fail Arc fallback or another
primary user journey.

## Retention and Operations

- Raw metadata expires after 30 days.
- The service-role retention worker deletes expired rows in bounded batches.
- S0 and S1 events enter a metadata-only alert queue.
- S0 resolution requires distribution stop or an approved forward fix.
- S1 resolution requires rollout pause, false-positive review, or forward fix.
- SLO windows return aggregate counts only.
- Database rollback is forward-only; do not run destructive down migrations.

## Hosted Drill

Use two ephemeral accounts and synthetic codes only. Verify owner isolation,
idempotency, unknown-field rejection, expiration purge, S0/S1 alert delivery,
resolution policy, and continuity when the sink is unavailable. Do not put real
journey text or account identifiers into evidence. Then run:

```powershell
./tools/qst/run_observability_hosted_drill.ps1 -ProjectRef <project-ref>
```

The drill uses exact fixture-scoped claim and purge RPCs. It writes evidence
only after both ephemeral accounts have been removed successfully. Then run:

```bash
dart run tools/qst/verify_privacy_safe_observability.dart --require-hosted
dart run tools/qst/verify_runtime_slo_drill.dart --require-hosted
```
