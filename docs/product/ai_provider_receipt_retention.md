# AI Provider Receipt Retention

Status: QST-442 local implementation complete; hosted and legal evidence pending.

## Purpose

Gemini実行後の課金再照合に必要な最小限のmetadataだけを、目的に応じた期限で保持する。
Prompt、会話本文、Quest内容、provider outputはこの証跡へ保存しない。

## Policy v2026-09-13.v1

- Receipt: 90日。provider interaction ID、model、token数、finish reason、digestを保持する。
- Reconciliation attempt: 180日。結果コード、理由、digestだけを保持する。
- Resolved or dismissed case: 解決から365日。
- Retention run summary: 730日。許可された実行理由と削除・保留件数だけを保持し、利用者IDやreservation IDを持たない。
- Open case: 解決まで期限削除しない。
- Explicit hold: billing dispute、security incident、legal requestに限定し、最大10年かつ終了日時必須。

## Data Rights Boundary

アカウント削除では既存の`auth.users`起点のcascadeを優先し、AI証跡だけを個人識別可能な形で
残さない。法令上の保存義務が必要な地域では、別の不可逆化・法務承認済み保管設計が必要であり、
この実装から法務承認を推測しない。Provider側やBackup側の保持期間は別途外部確認を要する。

## Hosted Drill

1. clean candidate SHAからQST-441、QST-442 migrationを順番に配備する。
2. fixture reservation、receipt、attempt、resolved caseを作成する。
3. retention日時を過去へ設定し、`manual_privacy_drill`を実行理由としてservice roleでpurge RPCを実行する。
4. unheld rowが削除され、open caseと期限内holdが残ることを確認する。
5. hold解除後の再実行で対象が削除され、二重削除や例外がないことを確認する。
6. audit summaryがallowlist済み理由と件数だけを持ち、識別子や本文を持たないことを確認する。
7. `supabase/tests/qst_442_ai_provider_receipt_retention.sql`を実行する。
8. fixtureを削除し、External Beta evidenceを同じSHAへ紐付ける。

Local testやmigrationの存在だけをhosted証拠として扱わない。hosted実行前はExternal BetaをGOにしない。

## Rollback

緊急時はschedulerからretention RPC呼び出しを停止する。削除済み証跡は復元を前提にしないため、
DB schemaの破壊的rollbackは行わない。保持期間の変更は新しいpolicy versionとforward migrationで行う。
