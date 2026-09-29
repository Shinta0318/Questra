# AI Budget Incident Export

## 目的

AI予算や精算の障害をサポート・監査担当者と共有する際に、利用者や会話内容を持ち出さず、原因調査に必要な集計値だけを期限付きで提供する。

## Export contract

共有本文はschema version、対象期間、最小集団閾値、集計件数、次の4項目だけを持つ。

- reason
- count
- latency p95 milliseconds
- cost micros

prompt、response、Quest、利用者ID、trace ID、reservation ID、provider interaction IDは含めない。モデル名や個別operationも共有本文へ出さず、reasonはallowlistされた台帳状態・精算outcome・worker結果・異常検知結果だけから作る。自由入力の精算reasonは共有本文へ転記しない。

## Small-group suppression

初期policyは5件未満の集計群を本文へ出力しない。閾値判定はJSON作成前にDB内で行い、payload triggerでも各集計のcountがpolicy閾値以上であることを再検証する。抑止された群の件数や内容は共有本文へ含めない。

## Operator boundary

生成・閲覧・削除は、Supabase Authへ結合された認証済み運用者だけがRPC経由で実施できる。テーブルへの直接SELECTは許可しない。生成者、期間、schema version、生成・閲覧・失効・削除イベントは内容を持たない監査ログへ残す。

## Retention and deletion

初期保存期間は7日、対象期間は最大31日、参照可能な履歴は直近90日に制限する。期限到来時はservice workerの`expire_ai_budget_incident_exports()`を実行し、本文をNULLへ置き換える。生成者またはapproverは`delete_my_ai_budget_incident_export()`で期限前にも本文を削除できる。digestと最小監査メタデータは改ざん確認用のtombstoneとして残す。

## Safety boundary

このexportは読み取り専用の運用証拠であり、AI機能停止、利用者課金、Premium、権利、Quest、Missionを変更しない。障害封じ込めは別の明示的な運用者操作と監査を必要とする。

## Hosted verification

候補SHAのMigration適用後、二つの運用者アカウントと非運用者アカウントで次を確認する。

1. 非運用者が生成・閲覧・削除RPCを実行できない。
2. 5件未満の群が本文に現れない。
3. 5件以上の群は許可された4項目だけを返す。
4. 期限後の閲覧で本文が消去される。
5. 生成者と別のreviewerは削除できず、approverは削除できる。
6. export操作で課金やPremium状態を変更しない。
