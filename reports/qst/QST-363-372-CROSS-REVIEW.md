# QST-363 to QST-372 Cross-Functional Review

Date: 2026-08-25

## Decision

Local implementation quality is acceptable to continue development. External
Beta remains **NO-GO**: all 12 external evidence gates are still blocked because
the current worktree is not a clean candidate and hosted, physical, legal,
ownership, operations, and provider-backed evidence is incomplete.

## Review Matrix

| QST | Area | Local result | External state |
| --- | --- | --- | --- |
| 363 | Guild pilot safety/metrics | Pass | Hosted pilot evidence pending |
| 364 | Trail recipient sharing/abuse | Pass | Hosted two-account and abuse drill pending |
| 365 | Runtime SLO policy/drill | Pass | Hosted alert/rollback pending |
| 366 | Dependency notices | Inventory pass | Exact server pin and Legal approval pending |
| 367 | Go/No-Go refresh | Honest fail-closed NO-GO | 12 gates blocked |
| 368 | Data Rights fulfillment | Pass after review fixes | Hosted worker/retention pending |
| 369 | Candidate asset package | Package hygiene pass | Chain of title pending |
| 370 | Observability sink | Pass after review fixes | Sink remains default-off; hosted drill pending |
| 371 | Physical accessibility evidence | Strong evidence contract pass | Physical Android execution pending |

## Findings Fixed

### P0

- Fixed the Data Rights worker secret comparison so a missing header cannot
  trigger modulo-by-zero instead of a controlled unauthorized response.
- Closed direct anonymous/authenticated insert, update, and delete access to
  `data_rights_requests`; all mutations now go through validated RPCs.

### P1

- Added per-owner observability limits: 120 events and 10 S0/S1 events per
  10-minute window. Direct table writes remain denied.
- Bound candidate asset package verification to the current Git HEAD, not only
  file paths and hashes.
- Replaced the physical accessibility token-presence gate with clean-SHA,
  privacy-review, file existence, size, and SHA-256 verification.

## Product and UX

- Guild remains an explicit pilot, not an implied public community.
- Trail sharing is authenticated, selective, expiring, revocable, and excludes
  sender/profile/Quest links and media by default.
- Arc fallback remains available when observability transport fails.
- No new user-facing text calls Arc an assistant or reintroduces the old Story
  term.

## AI

- Runtime evidence records only normalized Arc fallback metadata, never prompt,
  response, Quest, or Trail content.
- Provider-backed 200-case quality/cost evidence is still missing and cannot be
  replaced by local fallback output.

## Database and Security

- Migrations through
  `202608250008_privacy_safe_runtime_observability.sql` are local and remain
  undeployed on the Beta project.
- New operator/worker RPCs require `service_role`; app mutations derive ownership
  from `auth.uid()`.
- Data Rights receipts and alert payloads omit account identifiers and content.
- No credentials, ephemeral account IDs, private journey text, or human
  signatures were added to evidence.
- Destructive down migrations and automatic data rollback remain prohibited.

## Validation

- QST-360/361/363/364/365/368/369/370/371 focused tests: 29 passed.
- QST-370 and Arc Chat focused tests: 23 passed before the final review pass.
- Review regression tests after fixes: 13 passed.
- `flutter analyze --no-pub`: passed.
- Dart QST tools analyzed without issues.
- Backlog SSOT verifier: passed.
- `git diff --check`: no whitespace errors; line-ending warnings only.

## Next Batch

QST-373 through QST-381 close hosted deployment, Data Rights, observability,
physical accessibility, dependency, asset, operations, AI, and candidate-SHA
evidence in dependency order. QST-382 performs the next cross-functional review.
