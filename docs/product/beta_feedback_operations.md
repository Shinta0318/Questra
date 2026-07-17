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

## Triage Rhythm

- Daily during internal beta: review S0 and S1 feedback.
- Twice weekly: batch S2 usability issues into polish QSTs.
- Weekly: review repeated S3 suggestions.

## Conversion To QST

Create a QST when one of these is true:

- A feedback item is S0 or S1.
- Three testers independently report the same S2 issue.
- A suggestion directly improves the Quest -> Mission -> Trail loop.
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
