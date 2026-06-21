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
| QST-041 | Done | RLS behavior test harness | Add database-backed RLS behavior tests for core private data boundaries. | Owner-only Quest, Mission, Trail, Arc Memory, and media access can be verified repeatably. |
| QST-042 | Done | Trail media delete and replace management | Add lifecycle management for private Trail media. | Users can remove or replace an attached Trail image safely. |
| QST-043 | Done | Release assets and legal copy readiness | Prepare beta-facing app assets and legal copy checklist. | Icon, splash, terms, privacy policy, and store text have tracked owners and draft artifacts. |
| QST-044 | Deferred | Performance measurement pass | Add repeatable performance checks for beta targets. | App start, Home, and Quest list performance can be measured consistently. |
| QST-045 | Deferred | Beta feedback operations | Define internal beta feedback intake and triage workflow. | Beta feedback has collection, labeling, and QST conversion rules. |
| QST-046 | Done | Arc Expression Assets Integration | Move prepared Arc expression PNGs into Flutter assets and make them available from Arc UI. | Seven Arc PNGs are registered, centrally referenced, and rendered by existing Arc UI. |
| QST-047 | Done | Arc Expression Engine | Add expression resolution rules that map Arc state, guidance context, and events to image assets. | Arc expression selection is centralized and context-aware across Quest, Mission, Trail, Reflection, and Bond inputs. |
| QST-048 | Done | Arc Presence System | Make Arc presence consistent across Home, Arc Chat, Quest, Mission, Trail, and empty states. | Arc appears with consistent sizing, spacing, and expression behavior across MVP surfaces. |
| QST-049 | Done | Arc Contextual Guidance | Use Quest, Mission, Trail, and Reflection context to suggest the next action without assistant framing. | Arc references latest journey context and remains framed as a navigator/companion. |
| QST-050 | Done | Arc Celebration System | Add celebration moments for Mission completion, Trail reflection, Quest progress, and rank or bond milestones. | Celebration expression and copy appear for key progress events without blocking core flow. |
| QST-051 | Done | Questra MVP Performance and Asset Optimization | Optimize MVP display speed, Arc and Trail image handling, list reads, Arc Memory reads, and Supabase query payloads. | Core list reads are limited, image size rules are documented, and performance checks are repeatable. |
| QST-052 | Done | Arc Empty States | Replace generic empty states with Arc-guided empty states across MVP surfaces. | Empty states use Arc guidance, a clear next action, and matching emotional tone. |
| QST-053 | Done | Arc Concern System | Add concern expressions and copy for stalled Quests, overdue Missions, and low activity. | Arc can express concern without blame and offer a small next step. |
| QST-054 | Done | Arc Reflection Coach | Improve Trail Reflection with Arc coaching prompts and expression changes. | Reflection prompts adapt to Trail/Mission context and help identify learning and next Mission. |
| QST-055 | Done | Bond Foundation | Establish Bond as the foundation for Arc relationship progression. | Bond state is represented, visible, and framed without manipulative engagement loops. |
| QST-056 | Done | Bond Growth Rules | Define and implement MVP-safe Bond growth rules from meaningful journey actions. | Bond grows from deterministic Quest, Mission, Trail, Reflection, and Arc interaction signals. |
| QST-057 | Done | Stardust Foundation | Introduce Stardust as a lightweight progress resource tied to meaningful activity. | Stardust has an owner, display surface, and non-payment MVP award rules. |
| QST-058 | Done | Navigator Rank | Add Navigator Rank as a simple progression label based on journey depth. | Navigator Rank has deterministic thresholds and displays current rank. |
| QST-059 | Done | Arc Relationship Review | Review Arc Experience coherence across assets, expressions, presence, guidance, Bond, Stardust, and Navigator Rank. | Arc relationship systems have no major release blockers and remaining beta risks are documented. |
| QST-060 | Done | Arc Daily Greeting | Add daily Arc greeting rules for Home based on date, recent activity, and open Missions. | Home can display a context-aware daily Arc greeting. |
| QST-061 | Done | Questra Design System V1 | Create the formal Questra design system and apply it to Home and Arc UI surfaces. | App design tokens and theme are available, and Home/Arc use the refreshed premium adventure styling. |
| QST-062 | Done | Import Arc Assets and Rebuild UI Based on Reference Images | Import approved Arc/mock assets and rebuild Home and Arc Chat toward the reference images. | Arc assets render in-app, mock references are registered, and Home/Arc Chat use the approved visual direction. |
| QST-063 | Done | Supabase Persistence Hardening | Harden Quest, Mission, Trail, Trail Reflection, Arc Memory, and Profile persistence boundaries. | Save/load failures are surfaced, related Arc Memory is sequenced after persistence, and migration gaps are documented. |
| QST-064 | Done | Arc AI Chat Integration | Connect Arc Chat to an AI-capable service boundary with Quest, Mission, Trail, Reflection, and Arc Memory context. | Arc Chat shows thinking state, returns contextual responses, falls back gracefully, and can save exchanges as Arc Memory. |
| QST-065 | Done | AI Quest Guide Generation | Generate an Arc Guide after Quest creation with summary, path, cautions, encouragement, and adoptable Mission candidates. | Quest Detail shows Arc Guide, 3+ Mission candidates can be adopted into saved Missions, and guide history is recorded in Arc Memory when available. |
| QST-066 | Done | AI Tagging Foundation | Add AI-generated tags for Quest, Mission, Trail, and Arc Memory with persistence, search, and statistics APIs. | Tags and entity tags are saved with owner-scoped RLS, and future Guild/Star Map/recommendation flows can query tag data. |
| QST-067 | Done | Performance Measurement Pass | Add repeatable performance readiness budgets and verification for beta targets. | App start, Home, Quest/Trail list, route transition, scroll, asset, image, list, and Arc Memory checks are documented or machine-checkable. |
| QST-068 | Done | Arc Guidance Localization Pass | Replace remaining English Arc journey guidance with Japanese navigator copy and lock it with tests. | Arc Journey Context guidance uses Japanese Quest/Mission/Trail language and avoids assistant framing. |
| QST-069 | Done | Beta Feedback Operations | Define internal beta feedback intake, labels, triage workflow, stop conditions, and QST conversion rules. | Beta feedback has required fields, severity/surface labels, triage rules, and script-verifiable readiness. |
| QST-070 | Done | Beta Readiness Refresh | Refresh the beta readiness report after performance and beta feedback operations are in place. | Readiness score, completed beta foundations, and remaining launch blockers are current and script-verifiable. |
| QST-071 | Done | Real Device Beta Validation Checklist | Define the real-device manual validation pass required before expanding internal beta. | Required devices, preflight, manual checks, stop conditions, and evidence capture are documented and script-verifiable. |
| QST-072 | Done | Final Screenshot QA | Define final screenshot QA requirements for beta and store-readiness evidence. | Required screens, viewports, pass/stop criteria, and output naming are documented and script-verifiable. |
| QST-073 | Done | Arc Emotion Timeline | Store and display Arc emotional history based on user journey actions. | Arc emotion events can be created and shown with reason, source, and timestamp. |
| QST-074 | Done | Arc Action Trigger Rules | Automatically switch Arc expression and copy in response to key user states and actions. | Trigger rules are centralized and map major MVP actions to Arc emotion/copy. |
| QST-075 | Done | Quest Milestone System | Break Quests into visible Milestones so users can understand progress beyond a flat percentage. | Quest Detail shows Milestones with status and progress. |
| QST-076 | Done | Mission Reminder / Signal MVP | Introduce a lightweight Signal foundation for Mission due dates, stalled Missions, and gentle reminders. | Signals can be generated from Mission and Quest context without platform notifications. |
| QST-077 | Done | Trail Timeline V1 | Let users revisit Trails in a chronological timeline. | Trail Timeline renders recent Trails in order using Trail terminology. |
| QST-078 | Ready | Trail Highlight System | Let Arc identify meaningful Trails and mark them as Star Memory candidates. | Trail highlights are deterministic and include visible reasons. |
| QST-079 | Planned | Guild Quest Matching | Improve Guild usefulness by connecting users with similar Quest tags and nearby goals. | Matching ranks related Quests by tags without exposing private content. |
| QST-080 | Planned | Guild Safe Posting Review | Add a lightweight Arc review before Guild posting to reduce personal information and unsafe sharing. | Review flags obvious personal information and allows revision. |
| QST-081 | Planned | Star Map Recommendation Foundation | Build a foundation for recommending the next Quest using Quest, Mission, Trail, and Tag context. | Service returns ranked Quest recommendation candidates with reasons. |
| QST-082 | Planned | Horizon Next Challenge MVP | Let Arc suggest the next challenge based on user achievement and readiness. | Arc can suggest one next challenge without paid gating. |
| QST-083 | Planned | Arc 3D Readiness Architecture | Prepare Arc expression architecture for future PNG, Rive, and GLB/3D implementations. | Arc expression decisions return a renderer-agnostic asset descriptor. |
| QST-084 | Planned | Arc Animation Event Layer | Add a renderer-neutral animation event interface for Arc reactions. | Animation events are centralized and testable. |
| QST-085 | Planned | Dream Board V1 | Let users collect visual inspiration for each Quest without disrupting the core loop. | Quest Detail can show a Dream Board section with existing media constraints. |
| QST-086 | Planned | Quest Template Library | Help users start faster with Quest templates for common life areas. | Quest creation can start from editable templates. |
| QST-087 | Planned | Premium Readiness Flags | Prepare future Premium feature switches without enforcing payments or harming MVP UX. | MVP/Beta core features remain enabled and no paywall is introduced. |
| QST-088 | Planned | Onboarding Personalization | Personalize first-run experience with Arc name preference, Quest tendencies, and Signal frequency. | Preferences persist and Arc copy reflects them. |
| QST-089 | Planned | Beta Analytics Events | Define and implement privacy-conscious event tracking boundaries for beta learning. | Analytics event names and payload rules are documented with safe defaults. |
| QST-090 | Planned | Feature Expansion Review | Review QST-073 through QST-089 for coherence, UX quality, MVP stability, and launch direction. | MVP/Beta stability is preserved and QST-091 through QST-100 candidates are proposed. |

## Selection Rules

- Treat the OneDrive Master Spec and Planner as the source of truth.
- Pick the first `Ready` QST unless the user names a specific QST.
- Prioritize Release Manager blockers before expansion work.
- Prioritize the Arc Experience Epic (`QST-046` through `QST-059`) before deferred beta operations while Arc is being raised to an MVP differentiator.
- Keep generated implementation reports in `reports/qst`.
- Do not use `Story` for product concepts, UI, docs, QSTs, or new code.
- Do not call Arc an AI assistant in user-facing product language.
