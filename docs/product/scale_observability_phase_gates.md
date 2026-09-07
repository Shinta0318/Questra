# Scale Observability and Phase Gates

QST: QST-357  
Status: Foundation implemented; runtime evidence pending

## Source of Truth

`docs/qst/BACKLOG.yaml` is the only active QST backlog. Historical Markdown and legacy YAML files are evidence and planning context only. New QST status values must follow `docs/qst/QST_STATUS_TAXONOMY.yaml`.

## Runtime Evidence Contract

Every runtime incident and critical request must be traceable without storing Quest, Mission, Task, Trail, Arc Memory, chat text, credentials, or signed URLs.

Required fields:

- build and candidate SHA;
- environment, platform, surface, and operation;
- random correlation/trace ID;
- normalized error code, severity, handled state, and fallback state;
- model, prompt, schema, thinking, token, latency, and cost bands for AI calls;
- owner-safe tenant hash only when approved for the environment.

Raw prompt, generated response, user content, email, phone, token, and database row payloads are prohibited. Runtime collection remains disabled until privacy and provider review approves the sink.

## SLO and Stop Conditions

| Area | Initial target | Automatic NO-GO |
| --- | --- | --- |
| Authenticated core journey | 99.9% successful operations | cross-account access, owner mismatch, or repeated data loss |
| Quest/Mission/Task mutation | p95 under 500 ms excluding AI | idempotency or durable recovery failure |
| Core list read | p95 under 1 s | missing pagination, unbounded query, or stale-owner data |
| AI planning | pass-specific budget; visible waiting state | schema/safety/critic bypass or fixed-template fallback |
| Crash-free sessions | 99.5% or higher in measured beta | any reproducible S0 or launch crash |
| Accessibility | automated gate plus physical evidence | blocked core action with TalkBack, keyboard, IME, or text scaling |

Targets are hypotheses until hosted measurements exist. Static verifiers cannot satisfy runtime evidence.

## Scale Stages

### 10K Registered Users

- Hosted p95/p99 for core reads, writes, auth, AI, and media.
- Two-account RLS evidence and S0/S1 alert drill.
- Cursor pagination and AI budget admission enabled.
- Support, moderation, and incident owners named.

### 100K Registered Users

- Queue/backpressure and retry capacity measured.
- Guild moderation liquidity and SLA measured before expansion.
- Storage lifecycle, backup restore, and deletion jobs rehearsed.
- Cost alerting segmented by AI role, platform, and cohort.

### 1M Registered Users

- Query/index growth model validated with production-shaped data.
- Archival/partitioning is introduced only where evidence shows need.
- Regional legal, support, and incident coverage approved before rollout.
- Recommendation and Graph workloads have privacy-safe offline boundaries.

### 10M Registered Users

- Multi-region strategy follows legal residency and measured latency needs.
- Capacity, failover, disaster recovery, abuse, moderation, and support exercises pass at target load.
- No single AI provider, database hot key, or manual operation is an untested critical dependency.

The stage number is not a forecast or readiness claim. Advancement requires evidence from the preceding stage.

## Fixed Phase Gate

The next phase remains NO-GO while any of these are pending:

- candidate SHA deployment and hosted migration parity;
- two-account RLS and media isolation;
- Web/Android physical journey and accessibility evidence;
- external legal/privacy approval and data-request operations;
- Arc asset provenance and dependency notices;
- measured AI quality/cost and Premium cohort evidence;
- S0/S1 runtime alert and rollback drill.

Review occurs every ten QSTs and before any external distribution. Scores never override a Critical blocker.
