# Data Rights Fulfillment and Retention Runbook

Status: QST-368 local implementation complete; hosted and human evidence pending.

## Service Levels

| Request | Product SLA | Handling |
| --- | --- | --- |
| Consent withdrawal | 24 hours | Service-role worker revokes consent and removes derived business signals transactionally. |
| Account deletion | 72-hour cancellation window, then worker processing | Recent authentication and explicit confirmation are required. Failed provider calls retry with classified error codes. |
| Correction | 30 days | A service-role operator claims the request, applies the correction through the owning domain workflow, then records an allowlisted resolution code. |

These are Questra operational targets, not statements of statutory deadlines.
Legal review may impose shorter or region-specific requirements.

## Privacy Boundary

- User request content remains in the owner-scoped request row and is never
  copied into drill evidence, metrics, logs, or fulfillment receipts.
- Receipts contain request ID, request type, outcome, resolution code, policy
  version, and completion time. They do not contain owner ID, email, phone,
  Quest/Trail content, or correction text.
- Worker responses expose aggregate counts only.
- Raw provider errors are classified before persistence.
- Service-role functions cannot be invoked by anonymous or authenticated app
  clients.

## Hosted Drill

Run only from a clean candidate SHA in the designated Beta project:

The automated operations drill is:

```powershell
./tools/qst/run_data_rights_hosted_drill.ps1 -ProjectRef <ref>
```

It uses three ephemeral fixture accounts, exact request-ID operator RPCs, and
hard cleanup. It stops without admissible evidence if cleanup fails. Provider
retention and backup restoration still require separate human/isolated review.

1. Deploy all migrations and `process-data-rights-requests`.
2. Create two ephemeral accounts without recording their identifiers.
3. Confirm account B cannot read, claim, cancel, or resolve account A requests.
4. Submit and fulfill a consent withdrawal; verify derived signals are removed.
5. Submit a correction, claim it as an operator, apply a fixture-safe change,
   resolve it, and verify only the owner sees the request state.
6. Submit an account deletion, verify cancellation within 72 hours, resubmit,
   execute the worker, and verify session/data access is denied afterwards.
7. Verify one content-free receipt per completed request and aggregate metrics.
8. Review provider primary, storage, backup, and Gemini retention terms. Record
   dates and reviewer decisions in the retention register without credentials.
9. Perform a backup restoration exclusion drill in an isolated environment;
   deleted accounts must not be repopulated into the active service.
10. Remove all ephemeral data and verify cleanup.

The hosted verifier must be run with `--require-hosted`. A local contract pass
cannot approve external Beta.

## Incident Handling

- Stop the worker if cross-account access, duplicate fulfillment, unclassified
  errors, or restored deleted data is observed.
- Preserve metadata-only evidence and page Privacy/Security owners.
- Do not perform destructive database rollback. Disable the worker and deploy a
  forward fix from the last approved candidate.
