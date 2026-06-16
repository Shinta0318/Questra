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
| QST-036 | Done | Guild interaction improvements | Replace the Guild placeholder with MVP-safe interaction support. | Users can draft a Guild question from current Quest/Mission context and review safe Trail reflections. |
| QST-037 | Done | Home Screen V1 | Complete the MVP Home experience by aggregating Arc, Mission, Quest, Trail, and Guild surfaces. | Home shows Arc Welcome, Today's Mission, Active Quest Summary, Recent Trails, Guild Activity, and navigation to Quest, Trail, and Guild. |
| QST-038 | Done | Arc Contextual Guidance | Add Arc guidance that uses Quest, Mission, Trail, and Reflection context. | Arc can reference the latest Quest, Mission, Trail, and Reflection to suggest the next action without being framed as an AI assistant. |
| QST-039 | Done | Quest Progress Dashboard | Add a Quest dashboard so users can scan progress, Missions, Trails, recent activity, and Arc comments. | Dashboard shows Quest progress, Mission completion, Trail count, Arc comment, and links to Quest detail. |
| QST-040 | Done | Beta Readiness Pass | Review MVP surfaces and produce internal beta readiness outputs. | MVP major blockers are zero, terminology checks pass, and beta readiness report with remaining issues and beta QSTs is available. |
| QST-041 | Ready | RLS behavior test harness | Add database-backed RLS behavior tests for core private data boundaries. | Owner-only Quest, Mission, Trail, Arc Memory, and media access can be verified repeatably. |
| QST-042 | Ready | Trail media delete and replace management | Add lifecycle management for private Trail media. | Users can remove or replace an attached Trail image safely. |
| QST-043 | Ready | Release assets and legal copy readiness | Prepare beta-facing app assets and legal copy checklist. | Icon, splash, terms, privacy policy, and store text have tracked owners and draft artifacts. |
| QST-044 | Ready | Performance measurement pass | Add repeatable performance checks for beta targets. | App start, Home, and Quest list performance can be measured consistently. |
| QST-045 | Ready | Beta feedback operations | Define internal beta feedback intake and triage workflow. | Beta feedback has collection, labeling, and QST conversion rules. |

## Selection Rules

- Treat the OneDrive Master Spec and Planner as the source of truth.
- Pick the first `Ready` QST unless the user names a specific QST.
- Prioritize Release Manager blockers before expansion work.
- Keep generated implementation reports in `reports/qst`.
- Do not use `Story` for product concepts, UI, docs, QSTs, or new code.
- Do not call Arc an AI assistant in user-facing product language.
