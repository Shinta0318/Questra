# QST-073-090 Report: Feature Expansion Backlog

## Summary

Created the next Questra feature-expansion backlog from QST-073 through QST-090. The backlog focuses on Arc as a living companion, Quest planning depth, richer Trail experiences, Guild usefulness, Star Map recommendations, future 3D Arc readiness, safe monetization preparation, onboarding personalization, beta analytics, and an expansion review.

## Changed Files

- `docs/qst/FEATURE_EXPANSION_BACKLOG.yaml`
- `docs/qst/BACKLOG.yaml`
- `docs/product/qst_backlog.md`
- `tools/qst/verify_feature_expansion_backlog.dart`
- `reports/qst/QST-073-090-feature-expansion-backlog.md`

## Implementation Notes

- Added detailed QST definitions with ID, title, goal, scope, acceptance criteria, likely files, priority, and dependencies.
- Set QST-073 Arc Emotion Timeline as the next `Ready` implementation item.
- Set QST-074 through QST-090 as `Planned`.
- Kept constraints explicit: no Story product concept, no user-facing Arc assistant framing, no complex paid features, and incremental Flutter/Supabase changes.
- Added verifier coverage so the feature expansion backlog cannot silently lose required fields.

## Validation

- Passed: `dart format tools\qst\verify_feature_expansion_backlog.dart`
- Passed: `dart run tools\qst\verify_feature_expansion_backlog.dart`

## Next

Begin QST-073 Arc Emotion Timeline.
