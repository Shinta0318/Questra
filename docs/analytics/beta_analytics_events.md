# Beta Analytics Events

QST: QST-089
Status: Implemented as local-safe analytics boundary

## Principle

Beta analytics may help understand whether core flows are discoverable, but it must not collect raw Quest, Mission, Trail, Arc Chat, Guild, profile, URL, file path, or personal contact content.

## Event Taxonomy

| Event | Purpose | Allowed Payload |
| --- | --- | --- |
| `quest_created` | Understand Quest creation success | `category`, `difficulty`, `visibility` |
| `mission_completed` | Understand core loop progress | `difficulty`, `has_quest` |
| `trail_posted` | Understand Trail usage | `surface`, `has_quest`, `has_mission` |
| `arc_chat_sent` | Understand Arc Chat engagement | `has_quest`, `has_trail` |
| `guild_draft_created` | Understand Guild draft usage | `source` |
| `media_attached` | Understand media usage | `media_type`, `surface` |
| `onboarding_completed` | Understand first-run completion | `quest_interest`, `signal_frequency` |
| `activation_step_completed` | Understand first-ten-minute activation without raw wish text | `activation_stage`, `surface`, `outcome` |
| `meaningful_progress_recorded` | Measure weekly meaningful progress toward a Quest | `metric_key`, `surface`, `progress_band`, `outcome`, `has_trail` |
| `recovery_action_selected` | Measure whether gentle recovery choices help users return | `source`, `outcome`, `accepted` |
| `trust_feedback_submitted` | Track trust feedback without storing comments | `outcome`, `surface`, `consent_scope` |
| `wellbeing_guardrail_recorded` | Audit non-coercive, non-addictive UX guardrails | `guardrail`, `outcome`, `consent_scope` |
| `ai_cost_observed` | Track AI cost and latency bands without prompts | `guardrail`, `outcome`, `cost_band`, `latency_band` |

## Metric Tree

QST-347 defines the Beta metric tree around meaningful progress rather than raw
engagement.

| Metric | Definition | Guardrail |
| --- | --- | --- |
| Activation | User reaches the first actionable Quest/Task path | No raw wish, prompt, or Quest text |
| WMPU | Weekly meaningful progress user: at least one Task, Mission, Trail, or approved route step | No ranking pressure or streak shame |
| D7/D30 Retention | User returns and makes or reviews progress | Must preserve quiet/rest preferences |
| Trust | User accepts, edits, rejects, or reports Arc suggestions | Do not optimize toward forced acceptance |
| Wellbeing | Recovery choices and non-coercive copy pass guardrails | Do not store sensitive free text |
| AI Cost | Cost and latency bands by AI operation | No prompt, response, or memory content |

## Blocked Payload

The client-side sanitizer drops keys such as:

- `title`
- `description`
- `content`
- `summary`
- `message`
- `text`
- `email`
- `nickname`
- `name`
- `url`
- `path`
- `prompt`
- `chat`
- `memory`

## Default Implementation

The default app implementation uses `LocalSafeAnalyticsRepository`. It keeps events local and sanitized, and can be replaced by a future provider only after privacy and beta readiness review.

## Future Provider Requirements

- Preserve the same event names.
- Preserve the same allowlist and blocked content rules.
- Do not add raw Quest, Mission, Trail, Arc Chat, Guild, profile, URL, or file path fields.
- Treat failure to send analytics as non-blocking.
