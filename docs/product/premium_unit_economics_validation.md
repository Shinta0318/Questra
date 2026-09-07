# Premium Unit Economics Validation

QST: QST-355  
Status: Validation model only; no billing decision

## Decision Boundary

Questra may validate one Premium hypothesis: deeper accompaniment through repeated Mission redesign and detailed progress review. Basic Arc consultation, Quest planning, initial Mission planning, safety controls, and data export remain Free. Purchased Guild exposure, stronger progression, and recommendation priority are prohibited.

## Inputs

- monthly price hypothesis;
- app store fee rate;
- variable AI cost per paying user;
- variable infrastructure cost per paying user;
- monthly paid churn;
- customer acquisition cost.

No default price in this document is a commitment. Price candidates must come from the Japan wedge study and a consented cohort.

## Provisional Gates

| Metric | Gate |
| --- | ---: |
| Contribution margin | 70% or more |
| LTV / CAC | 3.0 or more |
| CAC payback | 12 months or less |

All gates are fail-closed. A non-positive contribution, invalid assumption, or missing cohort evidence keeps billing deferred.

## Trust Gate

Economic viability is necessary but not sufficient. Billing remains deferred if the package reduces meaningful weekly progress, increases pressure during emotional moments, obscures Free capabilities, or makes Arc appear to favor payment over the user's Quest.

## Implementation Evidence

- `apps/mobile/lib/core/feature_flags/premium_feature_flags.dart`
- `apps/mobile/lib/core/feature_flags/premium_unit_economics.dart`
- `apps/mobile/test/premium_feature_flags_test.dart`
- `apps/mobile/test/qst_355_premium_unit_economics_test.dart`

## Evidence Still Required

- price-page comprehension and willingness-to-pay study;
- measured variable AI and infrastructure cost from the atomic ledger;
- paid-intent retention and churn evidence;
- accessibility review of any future pricing surface;
- explicit product and legal approval before billing implementation.
