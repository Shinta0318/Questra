# QST-269 Evidence Manifest

| Evidence | Environment | Result | Artifact |
|---|---|---|---|
| Core journey | Flutter host test | Pass | `test/qst_269_core_journey_test.dart` |
| Compact semantics | 320 x 900, text 1.3 | Pass | automated gate |
| Mobile semantics | 390 x 900, text 1.3 | Pass | automated gate |
| Wide semantics | 768 x 900, text 1.3 | Pass | automated gate |
| Mission after visual | Windows golden, 390 x 844 | Pass | `mission_detail_after_390.png` |
| Web browser E2E | Edge | Pending: runner timeout | none |
| Android device E2E | No connected device | Pending | none |
| TalkBack | No connected device | Pending | none |

## Candidate Commands

```powershell
cd apps/mobile
flutter test test/qst_269_core_journey_test.dart --no-pub
flutter test integration_test/qst_269_core_journey_test.dart -d <android-device-id> --no-pub
```

Android、Web、TalkBackの行は実行成功後にのみPassへ変更する。
