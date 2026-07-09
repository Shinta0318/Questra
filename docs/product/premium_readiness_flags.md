# Premium Readiness Flags

QST: QST-087
Status: Ready for future monetization planning

## Principle

Questra Beta keeps MVP and Beta core experiences open. Premium flags exist only to identify future candidates and prevent accidental paywall work before the product experience is stable.

## Default Beta Behavior

- Quest, Mission, Trail, Guild, Arc Chat, Arc Memory, Dream Board, Star Map, Bond, Stardust, and Navigator Rank remain enabled.
- No payment UI is introduced.
- No hard paywall is introduced.
- No core journey action is blocked by Premium readiness flags.

## Future Candidate Flags

| Capability | Beta Access | Future Candidate | Notes |
| --- | --- | --- | --- |
| Advanced Arc Memory | Open | Yes | Validate trust and memory quality before considering limits. |
| Extended Dream Board | Open | Yes | Keep Quest planning friction low during Beta. |
| Guild Boosts | Open | Yes | Do not distort community validation before launch. |
| Star Map Deep Recommendations | Open | Yes | Recommendation quality needs Beta learning. |
| 3D Arc | Open | Yes | Architecture readiness only; no paid gating. |
| Export Archive | Open | Yes | Data trust should not be blocked in Beta. |

## Prohibited Before Launch Readiness

- Blocking Quest creation, Mission completion, Trail posting, or Arc Chat behind payment.
- Showing upgrade pressure inside Reflection or concern states.
- Selling Stardust, Bond, Navigator Rank, or emotional progression.
- Reducing user data access or export because a user is not paid.

## Validation

The default implementation is covered by `apps/mobile/test/premium_feature_flags_test.dart`.
