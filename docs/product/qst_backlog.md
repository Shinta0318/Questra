# QST Backlog

This backlog is the source list for DEV-QST work selection. Keep items small
enough to implement, verify, and report in one focused development pass.

| QST ID | Status | Title | Scope | Acceptance |
| --- | --- | --- | --- | --- |
| QST-002 | Done | Migrate QST planner tooling | Add local QST backlog, planner, prompt, and report helpers. | A developer can run the QST helper to show the next task and generate a prompt from this backlog. |
| QST-003 | Done | Add formal Trail data model and posting flow | Add local Trail entry model/controller and a create flow in the Trail tab. | A user can create a Trail entry linked to the current journey state without Supabase wiring. |
| QST-004 | Done | Add Arc Chat MVP surface | Add a lightweight Arc chat screen and local conversation state. | A user can open Arc, exchange local messages, and see Arc respond with guided next-step copy. |
| QST-005 | Ready | Persist Trail entries to Supabase | Add schema and repository wiring for Trail entries. | Trail entries have a planned database table and app code has a clear adapter boundary for remote persistence. |
| QST-006 | Ready | Connect Arc Chat to persisted journey context | Use persisted Quest and Trail state to enrich Arc replies. | Arc replies can reference current Quest and Trail context through a repository boundary. |

## Selection Rules

- Pick the first `Ready` QST unless the user names a specific QST.
- Keep generated implementation reports in `reports/qst`.
- After finishing a QST, update its status to `Done` and add the next concrete
  candidates uncovered during implementation.
- Prefer changes that advance the app itself over process-only work, unless the
  process gap blocks repeatable DEV-QST operation.
