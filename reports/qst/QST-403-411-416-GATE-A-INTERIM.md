# QST-403〜411 / 416 Gate A 暫定横断レビュー

更新日: 2026-09-06 / 判定: **暫定レビュー完了、正式Gate AはNO-GO**

対象は実装順の10件、QST-403、404、405、406、416、410、411、407、408、409。各QSTはローカル実装とWidget検証の区切りへ到達したが、実Web/Android、実Gemini、hosted Supabase、二アカウントRLSの必要証跡が揃っていないため正式Completedではない。

## 再検証結果

```text
flutter test --no-pub -r compact \
  test/qst_403_mission_dialog_lifecycle_test.dart \
  test/qst_404_surface_contrast_test.dart \
  test/qst_405_modal_sheet_test.dart \
  test/qst_406_onboarding_replay_test.dart \
  test/qst_407_trail_single_timeline_test.dart \
  test/qst_408_home_next_step_test.dart \
  test/qst_409_quest_header_density_test.dart \
  test/qst_410_arc_quest_handoff_recovery_test.dart \
  test/qst_411_action_hierarchy_test.dart \
  test/qst_416_height_aware_navigation_test.dart
  PASS: 57 tests

flutter analyze --no-pub
  PASS: No issues found (76.0s)

dart run tools/qst/verify_backlog_ssot.dart
  PASS: 358 QST IDs

audit/2026-09-04/verify_resumed_scope.ps1
  PASS: unexpected existing 0 / unexpected added 0
```

## レビュー中に修正した問題

1. **Home V2のSignal型不整合**: 非表示分岐の空リストが`MissionSignal`で、旧`TaskSignalCard`分岐が`Object`推論となりコンパイル不能だった。`TaskSignal`へ明示して修正し、24画面・導線テストを再通過。
2. **Navigationの古い固定高さ契約**: QST-416で大文字時に安全に高さを伸ばした後も、QST-266が常に58pxを要求して6件失敗していた。最小58px、最大72pxのアクセシブルな契約へ更新し、横断58テストを再通過。

## 六領域判定

| 領域 | 判定 | 根拠と残件 |
|---|---|---|
| コード | Local Pass | 専用57件、関連回帰、analyze通過。大量dirty worktree全体の正式Candidate検証は未実施 |
| UI/UX | Partial | controller寿命、Surface、Modal、Tour、Navigation、階層、Trail、Home、Quest密度をWidgetで検証。全変更画面のWeb/Android実寸・失敗・大文字証跡は不足 |
| AI | Not Verified | QST-410で失敗時に固定Missionを作らない契約はテスト済み。実Gemini応答、schema failure、timeout、再試行の実環境証跡なし |
| DB | Not Verified | 本群はDB/Migrationを変更していない。保存後再起動、hosted DB、二アカウントRLSの非退行証跡なし |
| セキュリティ | Partial | 新規秘密情報・外部通信・DB権限変更なし。共通永続化エラーが生例外を利用者へ露出する問題をQST-412へ繰越 |
| Master Spec | Local Pass | Quest→Mission→Task→Trail、Arcの伴走、Story禁止、AI失敗時の非捏造、企業支援非優先を維持。外部運用の透明性は未検証 |

## 次QSTへ反映するFinding

### High: 通知の所有と失敗表示が未統一

- `QuestController.loadForUser`と`MissionController.loadForQuests`は通常読込成功を`PersistenceSyncBanner`へ残す。
- `PersistenceSyncController.failed`は`$error`を連結し、内部例外・接続情報・英語メッセージをUIへ露出し得る。
- 保存成功Bannerは共通Widget上で自動消去されず、画面内容を占有し続ける。

QST-412へ、Quest/Mission/Trailの読込成功抑止、保存成功の短時間消去、失敗の安全な日本語、再試行操作、連続通知・画面遷移・二重読み上げのNegative Testを追加する。

### Critical: 外部β証跡不足

全10件で実Web/Android、実Gemini、hosted Supabase/RLSの一部または全部が未確認。ローカルUI改善を公開可否の証拠に代用しない。候補SHA固定前に本群を正式Completedへ変更しない。

## 結論

ローカルで再現可能なCriticalコード回帰は0件。QST-412以降の安全なUI改善は続行可能。ただし正式Gate AとExternal BetaはNO-GOを維持する。commit、push、PR、DB配備、本番操作は行っていない。
