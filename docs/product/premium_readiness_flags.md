# Premium Readiness and Progression Boundary

QST: QST-087, refined by QST-330
Status: Foundation implemented; billing intentionally absent

## Principle

Premium is the depth of Arc's accompaniment, never stronger progression. Questra Beta keeps the core journey open while server-side policy and usage boundaries are prepared for later validation.

## Free Core

- Basic Arc consultation
- Quest planning
- Initial Mission planning
- Quest, Mission, Task, Trail, Guild, Bond, Stardust, and Navigator Rank
- Safety, data access, export, deletion, and consent controls

## Future Premium Candidates

| Capability | Beta Access | Candidate | Boundary |
| --- | --- | --- | --- |
| Mission redesign | Open | Yes | Deeper repeated replanning, never stronger rewards |
| Detailed progress review | Open | Yes | Review depth and frequency only |
| Advanced Arc Memory | Open | Yes | More continuity with the same privacy controls |
| Extended Dream Board | Open | Yes | Additional creative capacity |
| Star Map deep recommendations | Open | Yes | More exploration, never paid ranking priority |
| 3D Arc | Open | Yes | Presentation depth only |

## Server Authority

- `user_entitlements` stores server-verified subscription state.
- `ai_usage_policies` stores configuration-driven limits; Beta values are unlimited.
- `ai_usage_counters` stores auditable monthly usage.
- `resolve_ai_entitlement` evaluates the current server policy.
- A client feature flag may open Beta access but cannot override a server-verified exhausted quota.

## Prohibited

- Selling or multiplying Stardust, Bond, Navigator Rank, completion probability, or recommendation priority.
- Blocking safety, consent, data access, export, or deletion.
- Upgrade pressure inside Reflection, concern, failure, or emotional states.
- Hardcoded plan limits spread across Flutter screens.
- Payment SDKs or pricing UI before a separate approved QST.

## Validation

- `apps/mobile/test/premium_feature_flags_test.dart`
- `apps/mobile/test/ai_entitlement_policy_test.dart`
- `apps/mobile/test/qst_330_progression_premium_contract_test.dart`
