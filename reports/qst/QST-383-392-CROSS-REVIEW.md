# QST-383 to QST-392 Cross-Functional Review

## Decision

The implementation contracts for QST-383 through QST-391 are coherent and locally verifiable. External Beta remains NO-GO because hosted, physical-device, legal, ownership, operations, and provider-backed evidence is not current and SHA-bound.

## Review Findings

### Code and CI

- Finding: QST-383 to QST-391 verifiers were not connected to the release workflow.
- Fix: added all new gates to `.github/workflows/release-gate.yml`; candidate preflight uses strict clean mode in CI.

### UI and UX

- Finding: local mock login depended only on router refresh timing.
- Fix: authentication is awaited and the validated continuation is opened explicitly.
- Finding: release notes described Guild as Coming Soon while the UI exposes a controlled pilot gate.
- Fix: release surfaces now consistently describe approved snapshots, eligibility, moderation, and kill switch behavior.

### AI

- Finding: the 200-case corpus represented only four personas.
- Fix: exactly 200 cases now rotate across 14 personas while retaining 50 unique wishes and 13 categories.
- Remaining: a provider-backed run, human review, latency, token, and cost evidence are still required.

### Database and Security

- Finding: three server-only tables relied on implicit RLS deny without explicit client privilege revocation.
- Fix: migration `202609030001_explicit_server_only_table_grants.sql` revokes all client access and adds behavior assertions.
- Dynamic migration-derived RLS coverage now checks all 98 `public` tables.
- Remaining: apply 21 pending migrations and rerun hosted RLS/two-account evidence on a clean candidate SHA.

### Master Spec

- Arc remains user-aligned; no enterprise catalog is directly exposed as personalized promotion.
- Local mock data is not represented as persistence or external evidence.
- No automated destructive database rollback is allowed.
- Guild remains discovery/support oriented, controlled, and non-addictive rather than an unbounded social feed.

## Local Validation

- Backlog SSOT and release-note contracts pass.
- Candidate secret-hygiene development scan passes; strict candidate mode remains blocked by the dirty worktree.
- Migration drift, dynamic RLS, device preflight, legal version, Arc asset readiness, incident tabletop, and corpus integrity gates pass.
- Local mock authentication and route guard tests pass.

## External Beta Status

NO-GO. Local implementation and static checks are not substituted for external evidence or human approval.

## Next Batch Inputs

QST-393 onward must prioritize clean candidate scope, hosted migration execution, dynamic hosted RLS inventory, real device sessions, and provider-backed corpus execution before adding unrelated feature depth.
