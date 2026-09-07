# Premium Readiness and Progression Boundary

QST: QST-087, refined by QST-330 and QST-355
Status: Validation foundation implemented; billing intentionally absent

## Principle

Premium is the depth of Arc's accompaniment, never stronger progression. Questra Beta keeps the core journey open while server-side policy and usage boundaries are prepared for later validation.

## Free Core

- Basic Arc consultation
- Quest planning
- Initial Mission planning
- Quest, Mission, Task, Trail, Guild, Bond, Stardust, and Navigator Rank
- Safety, data access, export, deletion, and consent controls

## Single Validation Package

The only package currently permitted for validation is deeper accompaniment. It combines Mission redesign and detailed progress review. This is a validation hypothesis, not a product for sale.

| Capability | Beta Access | Candidate | Boundary |
| --- | --- | --- | --- |
| Mission redesign | Open | Yes | Deeper repeated replanning, never stronger rewards |
| Detailed progress review | Open | Yes | Review depth and frequency only |
| Advanced Arc Memory | Open | No | Privacy and trust validation precede monetization |
| Extended Dream Board | Open | No | Not part of the current package |
| Star Map deep recommendations | Open | No | Recommendation priority cannot be sold |
| 3D Arc | Open | No | Not part of the current package |
| Data export | Always open | No | A user data right, never an upsell |
| Guild boost | Disabled | No | Purchased discovery exposure is prohibited |

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

## Unit Economics Validation Gate

Billing remains deferred unless a measured cohort satisfies all provisional gates:

- contribution margin of at least 70 percent;
- LTV/CAC of at least 3.0;
- CAC payback within 12 months;
- no material decline in trust, meaningful progress, or wellbeing metrics.

The economic model uses net store revenue, variable AI cost, variable infrastructure cost, monthly churn, and CAC. Passing the arithmetic gate does not authorize billing; willingness-to-pay and retention evidence are still required.

## Validation

- `apps/mobile/test/premium_feature_flags_test.dart`
- `apps/mobile/test/ai_entitlement_policy_test.dart`
- `apps/mobile/test/qst_330_progression_premium_contract_test.dart`
- `apps/mobile/test/qst_355_premium_unit_economics_test.dart`
