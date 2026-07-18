# Real Device Beta Validation

## Purpose

Before expanding internal beta, Questra needs one repeatable real-device pass.
This checklist focuses on the core Quest -> Mission -> Trail loop and the
surfaces most likely to break outside desktop web.

## Required Devices

- Android phone, physical device preferred.
- Small phone viewport, either physical compact device or emulator.
- Large phone viewport, either physical large-screen phone or emulator.
- Tablet viewport, Android tablet, iPad simulator, or tablet-sized emulator.
- iOS physical device or simulator when available.
- Web sanity check in Edge or Chrome.

## Device Classes

| Class | Target | Minimum Coverage | Notes |
| --- | --- | --- | --- |
| Android phone | 390 x 844 or common Android portrait | Full Quest -> Mission -> Trail loop | Physical device preferred for keyboard, camera, and media behavior. |
| Small phone | 320-360 px logical width | Navigation, text scale, keyboard, create flows | Focus on overflow, clipped buttons, and bottom sheet usability. |
| Large phone | 430-480 px logical width | Home, Quest Detail, Trail, Arc Chat, Profile | Confirm spacing does not become sparse and CTAs remain reachable. |
| Tablet | 800+ px logical width | Navigation rail, centered content, scrolling, Arc entry | Confirm medium/expanded behavior and no stretched reading columns. |
| Web sanity | 1280 x 900 or browser default | Core navigation and Arc Chat | Edge is acceptable when Chrome is unavailable. |

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

## Cross Device Pass

Run the following checks once per required device class.

| Device Class | Required Checks | Expected Evidence |
| --- | --- | --- |
| Android phone | Install or run debug build, open Home, create Quest, complete Mission, create Trail, open Arc Chat | Screenshot of Home and Trail, short note with device model and OS |
| Small phone | Enable large text if possible, open Home, Quest, Trail, Guild, Arc Chat, Profile, open Trail create sheet and keyboard | No clipped primary buttons, no horizontal overflow, keyboard does not hide active input |
| Large phone | Open Home, Quest Detail, Trail Timeline, Guild, Arc Chat, Profile | Layout remains dense enough for scanning and does not leave key content floating awkwardly |
| Tablet | Confirm navigation rail, open every primary destination, scroll long Quest Detail and Trail Timeline | Navigation rail is reachable, content width remains readable, no stretched cards |
| Web sanity | Run in Edge or Chrome, resize to compact, medium, expanded, send one Arc Chat message | App remains navigable and Arc thinking/fallback states do not break layout |

## Result Log Template

Copy this block once per device class during beta validation.

```markdown
### Device Class:
- Device / emulator:
- OS / browser:
- Build commit:
- Tester:
- Date:
- Result: Pass / Fail
- Screens checked:
- Quest -> Mission -> Trail loop: Pass / Fail / Not applicable
- Arc Chat: Pass / Fail / Not applicable
- Media flow: Pass / Fail / Not applicable
- Issues:
- Evidence path:
```

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
- One result log entry for Android phone, small phone, large phone, and tablet.

## Structured Evidence Gate

結果は`docs/qst/BETA_DEVICE_VALIDATION.yaml`へ記録する。各端末クラスには同じcandidateの40文字SHA、
機種、OSまたはbrowser、実行時刻、tester role、必須check、スクリーンショット等のevidence pathを含める。
メール、認証情報、private journey本文は記録しない。

```powershell
dart run tools/qst/verify_real_device_validation_readiness.dart
dart run tools/qst/verify_real_device_validation_readiness.dart --require-devices
```

最初のコマンドは証跡契約だけを検査する。`--require-devices`はAndroid phone、small phone、large phone、
tablet、web sanityの全結果が`passed`になるまで失敗する。iOSはruntimeが利用可能な環境では必須とし、
Windows hostで利用できない場合は理由を記録する。Browser resize、widget test、mock serverは実端末結果を
代替しない。
