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

## Default Implementation

The default app implementation uses `LocalSafeAnalyticsRepository`. It keeps events local and sanitized, and can be replaced by a future provider only after privacy and beta readiness review.

## Future Provider Requirements

- Preserve the same event names.
- Preserve the same allowlist and blocked content rules.
- Do not add raw Quest, Mission, Trail, Arc Chat, Guild, profile, URL, or file path fields.
- Treat failure to send analytics as non-blocking.
