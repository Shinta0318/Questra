# Real Device Beta Validation

## Purpose

Before expanding internal beta, Questra needs one repeatable real-device pass.
This checklist focuses on the core Quest -> Mission -> Trail loop and the
surfaces most likely to break outside desktop web.

## Required Devices

- Android physical device or emulator.
- iOS physical device or simulator when available.
- Web sanity check in Edge or Chrome.

## Preflight

- `flutter analyze`
- `flutter test`
- `dart run tools/qst/verify_rls_readiness.dart`
- `dart run tools/qst/verify_performance_readiness.dart`
- `dart run tools/qst/verify_beta_feedback_readiness.dart`
- `dart run tools/qst/verify_beta_readiness_report.dart`

## Manual Pass

| Surface | Check | Expected |
| --- | --- | --- |
| Home | Open app and view Home | Arc appears, daily greeting is Japanese, no overflow on small screen |
| Quest | Create a Quest | Quest saves or shows a clear persistence failure |
| Quest Detail | Open Quest detail | Arc Guide area renders and Mission candidates are visible when generated |
| Mission | Create or adopt a Mission | Mission appears in list and can be completed |
| Trail | Complete a Mission and create a Trail | Trail appears with Quest/Mission context |
| Trail Reflection | Add reflection | Reflection saves or shows a clear failure |
| Media | Attach, replace, and remove Trail image | Image is compressed before upload and lifecycle actions do not crash |
| Guild | Draft a Guild question | Draft uses Quest/Mission context and safe Trail framing |
| Arc Chat | Send message | Thinking UI appears, response is Arc-native, fallback does not break UX |
| Arc Memory | Trigger memory-worthy action | Memory appears in visible memory surface when available |
| Profile | Open Profile | Bond, Stardust, Navigator Rank, and owner state render |
| Auth | Login/logout or local fallback | User state changes are visible and no private data crosses profiles |
| Performance | Scroll Quest/Trail lists | Scrolling remains smooth enough for beta and no obvious jank blocks usage |

## Stop Conditions

- Crash in Home, Quest creation, Mission completion, Trail creation, Arc Chat, or Profile.
- Data loss after a save appears successful.
- Private user data appears under the wrong profile.
- Arc is described as an AI assistant in user-facing UI.
- Story appears as a product concept in user-facing UI.
- Media upload, replace, or delete leaves the UI in a broken state.

## Evidence To Capture

- Device model and OS.
- Build commit.
- Screenshots for Home, Quest Detail, Trail, Arc Chat, and Profile.
- Screen recording for one full Quest -> Mission -> Trail loop.
- List of S0/S1 feedback items created from the pass.
