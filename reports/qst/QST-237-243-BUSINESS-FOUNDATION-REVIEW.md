# QST-237〜243 Business Foundation 横断レビュー

Status: Completed

## Implemented

- Quest、Mission、Routeのappend-only進行イベントとRPC-only記録。
- Quest Lifecycle Stage、履歴、安全な既存Quest backfill、ユーザー修正UI。
- 個人向けQuest DNA原本とBusiness派生Signalの物理分離。
- Mission支援分類、センシティブ除外、Mission単位の訂正・企業提案OFF。
- 6目的の版付き同意、設定UI、撤回時の派生Signal削除。
- 支援InteractionとMission/Quest Outcomeを分けた貢献測定基盤。
- k=10、許可属性、期限、監査境界を持つ匿名Segment基盤。

## Privacy Review

- Business派生テーブルにQuest/Mission本文、Arc会話、Arc Memory、PIIを保持しない。
- Business SignalとSegmentには`anon`/`authenticated`権限もRLS Policyも付与しない。
- イベントmetadataはFlutterとPostgreSQLの二重ホワイトリストを通す。
- 企業提案拒否はQuest、Mission、Trail、Arcの基本機能へ影響しない。
- `personal_data_sharing`は通常設定から許可できず、文脈確認を必須とする。

## Verification

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub`: 357 passed.
- Focused Business Foundation tests: 13 passed.
- RLS readiness: 32 tables and 51 required policies passed.
- Hosted Supabase migrations through `202608010020_progress_event_rpc_hardening.sql`: applied.
- Hosted two-account RLS behavior test: passed.
- Cloud migration/RLS evidence verification: passed.
- Supabase Beta bootstrap cloud verification: passed.

## Release Decision

QST-237〜243のFoundation実装は完了とする。ただし企業向けデータ提供、企業Dashboard、広告配信、請求、CRM連携は未実装かつ無効のままとする。Android/WebのBusiness導線E2E、同意撤回E2E、ユーザー削除E2E、プライバシー・利用目的文書の法務レビューが完了するまでEnterprise Release Gateを開かない。
