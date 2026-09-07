# International Format Matrix

Status: QST-352 foundation

## Purpose

Questra must not claim English product readiness while visible UI, generated
Arc copy, dates, currency, legal copy, or AI prompts remain Japanese-only.

## Supported Baseline

| Locale | Product Status | Notes |
| --- | --- | --- |
| ja-JP | Primary Beta locale | Japan wedge validation remains the launch default. |
| en-US | Foundation only | UI strings and AI prompt locale still need full review. |
| en-GB | Foundation only | Date, week-start, currency, and legal copy require separate review. |
| RTL smoke | Not launched | Used only to test directionality and focus assumptions. |

## Format Rules

| Format | ja-JP | en-US | en-GB |
| --- | --- | --- | --- |
| Month | `yyyy / MM` | `MMM yyyy` | `MMM yyyy` |
| Short date | `yyyy/MM/dd` | locale `yMd` | locale `yMd` |
| Time | 24-hour `HH:mm` | 12-hour locale time | 12-hour locale time |
| Week start | Monday | Sunday | Monday |
| Currency default | JPY | USD | GBP when pricing is validated |
| Mission plural | `Mission 3件` | `3 Missions` | `3 Missions` |

## AI Locale Rules

- Arc response language must match the UI locale unless the user explicitly asks
  for another language.
- Prompt registry entries must include locale and region.
- Safety and refusal copy must be human-reviewed per locale.
- Generated Mission plans must not mix Japanese helper text into English UI.

## Release Gate

English Beta is blocked until:

- en-US and en-GB core journey pass localized E2E.
- No shipped screen has unreviewed Japanese-only visible copy in English mode.
- Date, month, week, currency, and plural formats pass automated tests.
- Regional privacy and store copy are reviewed.
- RTL smoke test passes for navigation, focus, and clipped text.

## Known Local Gaps

The app still contains direct `DateFormat(..., 'ja')` and Japanese literals in
feature screens. This QST adds the shared format service and release matrix; it
does not claim full English productization.
