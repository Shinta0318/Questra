# Beta Feedback Operations

## Purpose

Questra internal beta feedback must turn into clear decisions: fix now, batch
for beta polish, defer, or convert into a future QST. This document defines the
minimum operating loop for the first private beta.

## Intake

Use `docs/qst/BETA_FEEDBACK.yaml` as the source of truth for required fields,
labels, severity, and QST conversion rules.

Every feedback item should include:

- Tester ID or source.
- Build version or commit.
- Surface: Home, Quest, Mission, Trail, Guild, Arc Chat, Arc Memory, Profile,
  Media, Auth, RLS, Performance, or Design.
- Severity: S0 through S3.
- Summary.
- Reproduction steps when relevant.
- Expected result.
- Actual result.
- Evidence, such as screenshot, short clip, log, or tester note.

## In-App Entry

Beta testers can open `設定` -> `フィードバックを報告` and record the surface,
feedback type, S0-S3 severity, summary, reproduction steps, expected result, and
actual result. Questra formats the report with tester and build identifiers,
then copies it for pasting into the beta channel provided by the operator.

The current clipboard handoff is intentional: no external destination is hidden
from the tester, and no new feedback table is required before the beta channel
is finalized. `BetaFeedbackSink` is the replacement boundary for a future
approved persistence or issue-tracker destination.

承認済み窓口名はcandidate buildへ`QUESTRA_BETA_FEEDBACK_CHANNEL`として渡す。未設定時はアプリに
「準備中」と表示し、存在しない窓口への送信完了を示さない。clipboardへのcopy成功はdelivery確認ではない。

Issue labels, priority, stop conditions, and QST conversion are defined in
`docs/product/beta_issue_labeling_rules.md`. The Flutter triage service applies
the same deterministic rules without sending feedback text to an external AI.

Crash、Supabase失敗、認証・Media失敗、Arc fallbackの証跡契約は
`docs/product/beta_crash_error_capture_plan.md`を参照する。外部collectorは
QST-127のPrivacy Review前には有効化せず、挑戦内容やArc会話本文を自動収集しない。

## Triage Rhythm

- Daily during internal beta: review S0 and S1 feedback.
- Twice weekly: batch S2 usability issues into polish QSTs.
- Weekly: review repeated S3 suggestions.

## Conversion To QST

Create a QST when one of these is true:

- A feedback item is S0 or S1.
- Three testers independently report the same S2 issue.
- A suggestion directly improves the Quest -> Mission -> Task -> Trail loop.
- A trust, safety, persistence, RLS, or data-loss concern appears once.

Each converted QST must include:

- Title.
- Problem.
- Evidence.
- Scope.
- Acceptance.
- Validation.

## Beta Stop Conditions

Pause beta expansion when:

- Any S0 issue is open.
- RLS behavior cannot be verified for owner-only data.
- Quest, Mission, Trail, Arc Memory, or Profile persistence loses user data.
- Arc wording breaks the navigator/companion framing in a user-facing surface.
- Performance readiness verification fails on the current beta candidate branch.

## Launch Readiness Signal

Internal beta can expand only when:

- Open S0 count is zero.
- Open S1 count is zero or has an explicit owner and fix QST.
- Performance readiness script passes.
- RLS readiness script passes.
- Latest feedback batch has been triaged into fix, defer, or QST candidate.
- Crash/error evidence follows the approved schema and contains no prohibited payload.

## Operations Evidence Gate

窓口、日次担当、SLAは`docs/qst/BETA_FEEDBACK_OPERATIONS.yaml`、S0/S1台帳は
`docs/qst/BETA_ISSUE_REGISTER.yaml`をsource of truthとする。

```powershell
dart run tools/qst/verify_beta_feedback_readiness.dart
dart run tools/qst/verify_beta_feedback_readiness.dart --require-operations
```

strict gateはtester-visible窓口、実名のtriage owner、SLA、台帳の集計時刻、open S0/S1件数の一致を要求する。
