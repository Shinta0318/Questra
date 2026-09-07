# QST-373 to QST-382 Cross-Functional Review

Date: 2026-09-03

## Decision

QST-373 through QST-381 are locally implemented with fail-closed evidence
contracts. QST-382 found and corrected five regressions in the combined suite.
Development may continue locally, but External Beta remains **NO-GO** until the
12 hosted, physical, legal, operational, and provider-backed gates are satisfied
against one clean candidate SHA.

## Review Matrix

| QST | Area | Local result | External state |
| --- | --- | --- | --- |
| 373 | Hosted evidence runner v2 | Contract pass | Clean hosted execution pending |
| 374 | Hosted Data Rights drill | Contract pass | Hosted export/correction/withdrawal/deletion evidence pending |
| 375 | Hosted observability drill | Contract pass | Real sink, alert, and rollback evidence pending |
| 376 | Physical Android session | Contract pass | Physical Android, TalkBack, text scale, and IME evidence pending |
| 377 | Dependency pinning/notices | 159 packages inventoried; exact server pin pass | Product/Legal license approval pending |
| 378 | Arc chain of title | Fail-closed intake and verifier pass | Rights records and Product/Legal approval pending |
| 379 | Feedback operations | Activation contract pass | Real channel, owner, and issue counts pending |
| 380 | Provider AI quality/cost | 200 planning + 10 safety-case gate implemented | Provider-backed execution pending |
| 381 | Clean candidate evidence | Same-SHA aggregate verifier pass | Clean candidate execution pending |
| 382 | Cross-functional review | Regressions corrected; local gates pass | External Beta remains blocked |

## Findings Fixed

### P0

- Added a deterministic safety boundary to `quest-planning-v2`; unsafe intent is
  rejected before planning or persistence.
- Extended the provider-backed evaluation contract with ten explicit safety
  cases and made zero critical safety violations a release condition.
- Raised the external AI gate from a stale 90% provider threshold to 100%, and
  added schema, usage, and safety checks.

### P1

- Updated the navigation contract to the controlled Guild Discovery pilot
  instead of the retired Coming Soon screen.
- Made Guild widget tests enter an explicit enabled pilot cohort and replaced
  unbounded settling around Arc's intentional loop animation with bounded pumps.
- Updated the Gemini modernization test to require 200 planning cases plus the
  safety corpus.
- Reworked the long-route performance check to use a warm-up and five-run
  median while preserving the 100 ms regression budget and one-pass invariant.
- Corrected a Dart interpolation issue in the QST-380 contract test.

## Product and UX

- Guild remains gated to an approved pilot cohort; local preview does not imply
  public availability.
- Continuous Arc motion is treated as intentional runtime behavior and no
  longer causes a false widget-test timeout.
- No new visible text introduces `Story` or describes Arc as an assistant.

## AI

- Planning cannot persist unsafe intent or schema-invalid output.
- Provider-backed quality evidence must cover 200 planning cases and ten safety
  cases with model, usage, latency, cost, schema, and safety metrics.
- Local fallback output remains ineligible as Gemini provider evidence.

## Database and Security

- Hosted evidence, RLS, Data Rights, observability, and AI runs must bind to the
  same clean candidate SHA.
- Dependency and Arc asset rights remain fail-closed until dated human approval
  and source evidence exist.
- No credentials, private prompts, personal contacts, or fabricated external
  evidence were written to the repository.

## Validation

- Initial full Flutter suite: 672 passed, 5 failed; all five failures reviewed
  and corrected.
- Focused QST-377 through QST-381 tests: 16 passed.
- Corrected regression set: 21 passed.
- Direct Dart analysis of `lib` and the QST-377 through QST-381 tests: passed.
- Dependency, Arc provenance, candidate asset, feedback, hosted runner,
  physical accessibility, Data Rights, observability, runtime SLO, and Backlog
  SSOT local verifiers: passed.
- Final post-fix Flutter suite: 682 passed, 0 failed.
- Final Dart analysis of `lib` and all corrected review tests: no issues.

## External Blockers

`docs/qst/EXTERNAL_BETA_GO_NO_GO.yaml` remains the authoritative decision. It
currently records 12 blocked gates and `distribution_ready: false`; local
implementation and static tests do not satisfy those external gates.

## Next Batch

After external evidence can be collected from a clean candidate, prioritize the
remaining gates in this order: immutable candidate and artifacts, hosted
deployment and two-account RLS, physical Android/Web accessibility, provider AI
evaluation, then Product/Legal and operations sign-off.
