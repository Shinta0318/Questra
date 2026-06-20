# MVP Release Readiness

## Source Check

The OneDrive Release Manager report from 2026-06-16 still reports:

- Overall readiness: 41 / 100
- Status: Not Ready
- Blocking issues: 3

StudioProjects has since advanced the matching implementation QSTs through
QST-029. The OneDrive planner should be synced before using the score as a final
launch signal.

## Blocker Tracking

| Blocker | StudioProjects status | Next action |
| --- | --- | --- |
| RLS readiness is not represented in backlog | Covered by QST-031 static verification for MVP owner/public/Guild policy coverage | Add database-backed SQL tests when Supabase local test harness is introduced |
| Trail image/media upload readiness is not represented in backlog | Covered by QST-032 private Trail image upload path, storage policies, and media rows | Add delete/replace management before broader media sharing |
| Arc Experience readiness is below MVP threshold | Improved by QST-021, QST-027, QST-029, QST-038, and QST-046; promoted into Arc Experience Epic QST-046 through QST-059 | Complete Arc Expression Engine, Presence, Celebration, Greeting, Empty States, Concern, Reflection Coach, Bond, Stardust, Navigator Rank, and Relationship Review before broader beta positioning |

## Completed Readiness Work

- QST-021: Arc UI foundation.
- QST-022: Quest/Mission/Trail terminology review.
- QST-023: Mission completion creates a clear Trail.
- QST-024: Trail progress overview.
- QST-025: Guild prototype scope documented.
- QST-026: Motion polish with reduced-animation support.
- QST-027: Arc Chat MVP local loop.
- QST-028: Profile/User MVP state pass.
- QST-029: Arc Memory Quest/Mission/Trail connections.
- QST-038: Arc Contextual Guidance.
- QST-046: Arc Expression Assets Integration.

## Remaining Before MVP Release

1. Add database-backed RLS behavior tests once Supabase local test harness is
   introduced.
2. Add Trail media delete/replace management before broader sharing.
3. Complete the newly promoted Arc Experience Epic QST-047 through QST-059 or
   explicitly defer individual relationship systems before wider beta.
4. Sync the OneDrive planner so AUTO-QST blockers map to QST-027 through
   QST-029 and QST-046 completion.
5. Re-run Release Manager after planner sync, RLS/media readiness tasks, and Arc
   Experience Epic planning.

## Launch Judgment

Not ready for release. The core journey loop is stronger, and RLS/media
readiness now have repeatable implementation paths, but planner sync and
database-backed verification remain before release. Arc Experience is now
tracked as the primary MVP differentiation epic in `docs/qst/BACKLOG.yaml`.
