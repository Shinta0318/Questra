# QST Backlog

This backlog mirrors the Questra Project Planner source in
`C:\Users\shint\OneDrive\ドキュメント\Questra` and should follow the Master Spec
there before new QSTs are created or reordered.

| QST ID | Status | Title | Scope | Acceptance |
| --- | --- | --- | --- | --- |
| QST-020 | Done | Quest/Mission/Trail terminology foundation | Align the app around Quest, Mission, and Trail. | Legacy Story naming is removed and the core loop language is coherent. |
| QST-021 | Done | Arc UI foundation | Establish reusable Arc presentation and naming patterns. | Arc UI uses consistent components and Master Spec compliant language. |
| QST-022 | Done | Quest/Mission/Trail review pass | Verify terminology consistency across app and docs. | App-facing code and docs use Quest, Mission, Trail, Arc, Guild, Horizon, Signal, Stardust, Bond, and Navigator Rank consistently. |
| QST-023 | Done | Mission completion flow | Tighten the core Mission completion experience. | Completing a Mission leaves a clear Trail and updates the user's journey state. |
| QST-024 | Done | Trail progress overview | Add a Trail overview once Arc UI and Mission completion foundations are stable. | Users can scan recent progress and understand how Trails connect to Quests and Missions. |
| QST-025 | Done | Guild prototype planning | Plan the Guild prototype after core journey features are stable. | Guild scope is documented without expanding beyond the MVP core loop. |
| QST-026 | Done | Animation polish pass | Polish Arc and core loop motion after UI foundations are stable. | Motion improves clarity without decorative excess. |
| QST-027 | Done | Arc Chat MVP completion | Prioritize MVP Arc Chat gaps from Release Manager. | Arc Chat supports the core Quest -> Mission -> Trail loop and respects Arc expression rules. |
| QST-028 | Done | Profile and User MVP pass | Address Profile/User MVP gaps from Release Manager. | User profile state is coherent with onboarding and core journey ownership. |
| QST-029 | Done | Arc Memory MVP pass | Cover Quest, Mission, and Trail memory surfaces required before MVP. | Arc Memory can store and surface core journey memories transparently. |
| QST-030 | Done | MVP release readiness pass | Resolve release-blocking MVP gaps and checklist items. | Release Manager readiness improves and blockers are explicitly tracked. |
| QST-031 | Done | RLS verification coverage | Add release-blocking RLS verification for owner-only data boundaries. | Quest, Mission, Trail, Arc Memory, and media access rules are covered by repeatable checks. |
| QST-032 | Done | Trail media upload readiness | Represent and implement MVP Trail image/media upload readiness. | Trail media has a storage, policy, and UI path that can be tested before release. |
| QST-033 | Done | Planner release sync | Sync OneDrive planner/release state with completed StudioProjects QST work. | Release Manager no longer lists completed Arc Chat/Profile/Arc Memory work as missing. |
| QST-034 | Done | Basic Trail posting | Add the MVP path for users to leave a manual Trail without starting from Quest detail. | Users can create a private manual Trail from the Trail screen and see it in the journey list. |
| QST-035 | Done | Better Trail reflection flows | Add an MVP reflection step so Trails can capture learning and the next small Mission. | Users can add a reflection to an existing Trail and keep the next step visible. |

## Selection Rules

- Treat the OneDrive Master Spec and Planner as the source of truth.
- Pick the first `Ready` QST unless the user names a specific QST.
- Prioritize Release Manager blockers before expansion work.
- Keep generated implementation reports in `reports/qst`.
- Do not use `Story` for product concepts, UI, docs, QSTs, or new code.
- Do not call Arc an AI assistant in user-facing product language.
