# QST Backlog

This backlog follows
[`QUESTRA_MASTER_SPEC_V2.md`](../QUESTRA_MASTER_SPEC_V2.md) as Questra's
highest-level product constitution. The Project Planner and legacy Master Spec
under `C:\Users\shint\OneDrive\ドキュメント\Questra` remain subordinate planning
references where they do not conflict with v2.

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
| QST-078 | Done | Trail Highlight System | Let Arc identify meaningful Trails and mark them as Star Memory candidates. | Trail highlights are deterministic and include visible reasons. |
| QST-079 | Done | Guild Quest Matching | Improve Guild usefulness by connecting users with similar Quest tags and nearby goals. | Matching ranks related Quests by tags without exposing private content. |
| QST-080 | Done | Guild Safe Posting Review | Add a lightweight Arc review before Guild posting to reduce personal information and unsafe sharing. | Review flags obvious personal information and allows revision. |
| QST-081 | Done | Star Map Recommendation Foundation | Build a foundation for recommending the next Quest using Quest, Mission, Trail, and Tag context. | Service returns ranked Quest recommendation candidates with reasons. |
| QST-082 | Done | Horizon Next Challenge MVP | Let Arc suggest the next challenge based on user achievement and readiness. | Arc can suggest one next challenge without paid gating. |
| QST-083 | Done | Arc 3D Readiness Architecture | Prepare Arc expression architecture for future PNG, Rive, and GLB/3D implementations. | Arc expression decisions return a renderer-agnostic asset descriptor. |
| QST-084 | Done | Arc Animation Event Layer | Add a renderer-neutral animation event interface for Arc reactions. | Animation events are centralized and testable. |
| QST-085 | Done | Dream Board V1 | Let users collect visual inspiration for each Quest without disrupting the core loop. | Quest Detail can show a Dream Board section with existing media constraints. |
| QST-086 | Done | Quest Template Library | Help users start faster with Quest templates for common life areas. | Quest creation can start from editable templates. |
| QST-087 | Done | Premium Readiness Flags | Prepare future Premium feature switches without enforcing payments or harming MVP UX. | MVP/Beta core features remain enabled and no paywall is introduced. |
| QST-088 | Done | Onboarding Personalization | Personalize first-run experience with Arc name preference, Quest tendencies, and Signal frequency. | Preferences persist and Arc copy reflects them. |
| QST-089 | Done | Beta Analytics Events | Define and implement privacy-conscious event tracking boundaries for beta learning. | Analytics event names and payload rules are documented with safe defaults. |
| QST-090 | Done | Feature Expansion Review | Review QST-073 through QST-089 for coherence, UX quality, MVP stability, and launch direction. | MVP/Beta stability is preserved and QST-101 through QST-130 roadmap is connected. |
| QST-101 | Done | Responsive Design Audit | Audit all major Questra screens for responsive layout issues. | Home, Quest, Mission, Trail, Guild, Arc Chat, Profile, and onboarding have documented layout risks. |
| QST-102 | Done | Responsive Layout System | Introduce shared responsive layout helpers. | Core screens use common breakpoint rules. |
| QST-103 | Done | Safe Area and Overflow Fix | Fix overflow, keyboard overlap, and unsafe edge spacing. | No known RenderFlex overflow remains on major MVP screens. |
| QST-104 | Done | Global Scroll Behavior | Standardize scroll physics, scroll containers, and refresh rules. | Major list screens scroll consistently. |
| QST-105 | Done | Visible Scrollbar System | Add visible scrollbars where content length is not obvious. | Long Quest, Trail, Guild, and Arc Chat surfaces clearly show scrollability. |
| QST-106 | Done | Menu Widget Refactor | Create shared Questra menu/list action components. | Repeated menu/action/navigation widgets are reusable. |
| QST-107 | Done | Bottom Navigation V2 | Improve primary navigation for Home, Quest, Trail, Guild, and Arc. | Main sections are reachable from persistent navigation. |
| QST-108 | Done | Adaptive Navigation Rail | Add tablet/expanded layout navigation behavior. | Wider screens can use navigation rail without breakage. |
| QST-109 | Done | Quick Action Menu | Add Questra-style quick creation/action entry point. | Core creation actions are reachable quickly. |
| QST-110 | Done | Home Information Hierarchy Polish | Improve Home layout priority and spacing. | Home content is visually ordered and not cramped. |
| QST-111 | Done | Quest Dashboard UX Polish | Improve Quest detail/dashboard navigation. | Mission, Trail, Arc Guide, progress, and next action are easy to find. |
| QST-112 | Done | Trail Timeline UX Polish | Improve DB-backed Trail browsing. | Trails are easier to scan chronologically and visually. |
| QST-113 | Done | Guild Feed UX Polish | Improve Guild feed readability and action clarity. | Draft question, safe review, and feed reading feel coherent. |
| QST-114 | Done | Arc Floating Companion Entry | Add optional Arc shortcut across key screens. | Users can reach Arc from major screens without crowding UI. |
| QST-115 | Done | Accessibility Pass | Improve text scaling, touch targets, labels, and contrast. | Major screens remain usable with larger text and accessible targets. |
| QST-116 | Done | Design System V2 Application | Apply updated spacing, radius, typography, and component rules. | UI feels consistent across major surfaces. |
| QST-117 | Done | Interaction Animation Pass | Polish transitions, feedback, card interactions, and Arc reactions. | Motion improves clarity without decorative excess. |
| QST-118 | Done | Responsive QA Automation | Add repeatable viewport validation. | Compact, medium, and expanded viewport checks are repeatable. |
| QST-119 | Done | Cross Device UX Validation | Create beta device validation checklist. | Android phone, small phone, large phone, and tablet checks are documented. |
| QST-120 | Done | UX Foundation Review | Review QST-101 through QST-119. | Responsive, scrolling, navigation, menu, and accessibility risks are summarized. |
| QST-121 | Done | Beta Account Setup Flow | Prepare beta tester account setup and first-run verification. | Beta users can sign in, create first Quest, and confirm persistence. |
| QST-122 | Done | Beta First Quest Experience | Polish first Quest creation and Arc guidance. | New beta users understand what to do within the first few minutes. |
| QST-123 | Planned | Beta Empty State Verification | Verify empty DB state across beta accounts. | No mock content appears as user-owned data. |
| QST-124 | Planned | Beta Feedback Entry Point | Add or document feedback route. | Beta testers can report screen, severity, and reproduction steps. |
| QST-125 | Planned | Beta Issue Labeling Rules | Create beta issue labels and QST conversion rules. | Feedback converts into bug, UX, data, AI, Guild, Arc, or performance QSTs. |
| QST-126 | Planned | Beta Crash and Error Capture Plan | Plan crash/error evidence collection. | Errors, failed Supabase calls, and AI fallback events have capture strategy. |
| QST-127 | Planned | Beta Privacy and Legal Copy Check | Review beta privacy, terms, and AI/data explanations. | Beta users receive clear data and AI usage copy. |
| QST-128 | Planned | Beta Release Notes Draft | Create beta release notes and known limitations. | Beta testers know what is ready, experimental, and how to give feedback. |
| QST-129 | Planned | Beta Go/No-Go Checklist | Create final beta launch checklist. | Launch blockers, evidence, device checks, and rollback conditions are explicit. |
| QST-130 | Planned | Beta Launch Readiness Review | Produce final beta readiness report. | Questra has beta readiness score, open blockers, and QST-131+ recommendations. |
| QST-131 | Done | Navigation and Creative UI Refresh | Reframe the primary product flow around Home -> Arc -> Quest and reduce generated UI feel. | Navigation, Home, Arc, Quest, and replayable first-use tour support an Arc-centered beta experience. |
| QST-132 | Done | Onboarding Tour Polish | Harden the Arc onboarding tour state machine after the creative navigation refresh. | First-use guidance appears after profile restore, stays dismissed within a session, and remains replayable. |
| QST-133 | Done | Quest Theme Card Redesign | Make Quest cards category-aware and reusable through theme metadata. | Quest cards show theme identity, Quest DNA labels, Arc hints, and tested theme resolution. |
| QST-134 | Done | Quest Detail Theme Application | Apply Quest theme metadata to the detail header and journey overview. | Quest detail shares the same theme identity, Quest DNA label, and Arc hint as Quest cards. |
| QST-135 | Done | Quest DNA Snapshot | Display an MVP-safe Quest DNA snapshot derived from existing Quest fields. | Quest detail distinguishes user input from inferred context without collecting sensitive new attributes. |
| QST-136 | Done | Quest DNA Review Controls | Add review controls for Quest DNA input and inferred values. | Users can inspect inferred values, see that they are not separately persisted, and jump to Quest editing. |
| QST-137 | Done | Challenge Graph Preview Foundation | Preview Challenge Graph nodes and edges from existing Quest context. | Quest detail shows MVP-safe graph counts for Quest, Mission, Trail, Theme, and Interest without graph database complexity. |
| QST-138 | Done | Challenge Graph Insight Layer | Add Arc-facing insights from Challenge Graph gaps. | Quest detail surfaces prioritized Mission, Trail, and Reflection guidance from existing Quest context. |
| QST-139 | Done | Star Map Graph Bridge | Connect Challenge Graph insights to Star Map recommendation candidates. | Home can surface explainable Star Map candidates from active Quest graph gaps without backend or graph DB changes. |
| QST-140 | Done | Horizon Graph Readiness | Use Challenge Graph insights in Horizon readiness. | Home can keep Horizon suggestions focused on active Quest graph gaps before proposing unrelated next challenges. |
| QST-141 | Done | Challenge Graph Visual Polish | Make the Quest detail graph preview feel like a lightweight star-map surface. | Quest detail visually distinguishes Quest, Theme, Interest, Mission, and Trail nodes while keeping metrics and Arc insight visible. |
| QST-142 | Done | Enterprise Support Boundary UI | Add an MVP-safe transparency boundary for future Quest Support. | Quest detail states Enterprise support is inactive in Beta and lists required transparency and guardrails before any future sponsor data exists. |
| QST-143 | Done | Trust and Privacy Review Surface | Add a Settings surface for Master Spec trust and privacy principles. | Settings explains Quest data, Arc Memory, Arc generation, Quest Support, and owner-boundary rules plus future user controls. |
| QST-144 | Done | Arc Memory Management Preview | Preview future Arc Memory review and control actions in Settings. | Settings explains Arc Memory categories and planned review, delete, sensitivity, and export controls without mutating stored memory data. |
| QST-145 | Done | Data Export and Deletion Request Copy | Add Settings copy for future data request controls. | Settings explains export, deletion, correction, and consent review requests without mutating data or persisting consent. |
| QST-146 | Done | Consent Purpose Registry | Define purpose-specific consent categories before persistence. | Settings separates Quest Support, analytics, Arc quality review, and external connection consent purposes without storing opt-in state. |
| QST-147 | Done | Trust Settings Information Architecture | Add a Settings Map for trust-related areas. | Settings now orients beta users across Arc tutorial, Trust & Privacy, Arc Memory, data requests, and consent without adding new mutations. |
| QST-148 | Done | Settings Component Extraction | Separate Settings presentation from orchestration incrementally. | Arc tutorial presentation now lives in a reusable widget while SettingsScreen retains state and routing ownership. |
| QST-149 | Done | Trust Settings Card Extraction | Extract Trust & Privacy presentation from Settings incrementally. | The Trust & Privacy review card is now reusable while the Settings screen retains review creation and screen composition. |
| QST-150 | Done | Arc Memory Settings Card Extraction | Extract Arc Memory management presentation from Settings incrementally. | The Arc Memory preview is now reusable while the Settings screen retains preview creation and screen composition. |
| QST-151 | Done | Current Screen and Flow Audit | Audit the app before simplification without deleting implementation or data. | Screens, routes, navigation, persistence, mock data, duplicated flows, and progress gaps are documented in `docs/qst/QST-141-screen-audit.md`. |
| QST-152 | Done | Navigation Simplification | Reduce primary navigation to Home, Quest, Arc, Guild, and Profile. | Compact and wide navigation now share five destinations; Trail remains a hidden route and duplicate Shell actions are removed. |
| QST-153 | Done | Common UI Simplification | Unify the five primary screens around shared layout and state rules. | Home, Quest, Arc, Guild, and Profile now share one background/SafeArea surface, with a reusable Coming Soon state ready for deferred features. |
| QST-154 | Ready | Home Simplification | Make today's next action obvious. | Show only Arc message/CTA, current Missions, and active Quests. |
| QST-155 | Planned | Arc-led Quest Creation | Make Arc the primary Quest creation entry. | Generate editable Quest candidates and persist only after explicit confirmation. |
| QST-156 | Planned | Quest Mission Decomposition Simplification | Focus Quest detail on actionable Missions. | Generate and edit Mission candidates before persistence using existing models. |
| QST-157 | Planned | Unified Quest Progress | Derive Quest progress from Mission completion everywhere. | Home, Quest list, and detail share one calculation and persisted result. |
| QST-158 | Planned | Guild and Trail Coming Soon Review | Hide unfinished community and Trail interactions during simplification. | Preserve code/data while presenting shared Coming Soon surfaces and running the end-to-end review. |

## Selection Rules

- Treat the OneDrive Master Spec and Planner as the source of truth.
- Pick the first `Ready` QST unless the user names a specific QST.
- Prioritize Release Manager blockers before expansion work.
- Prioritize the Arc Experience Epic (`QST-046` through `QST-059`) before deferred beta operations while Arc is being raised to an MVP differentiator.
- Keep generated implementation reports in `reports/qst`.
- Do not use `Story` for product concepts, UI, docs, QSTs, or new code.
- Do not call Arc an AI assistant in user-facing product language.
