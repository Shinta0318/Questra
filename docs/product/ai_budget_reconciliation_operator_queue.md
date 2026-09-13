# AI Budget Reconciliation Operator Queue

> QST-445以降、人間operatorの実行経路は
> `ai_budget_operator_identity.md`のAuth結合済みRPCを正本とする。
> 本文のService Role経路は自動workerとQST-443時点の履歴仕様である。

## 目的

Geminiなどのprovider実行後に精算状態が不明になったcaseを、登録済みoperatorが競合なく調査し、証跡に基づいて解決する。一般利用者、Flutterクライアント、通常の認証済みroleはqueue・receipt・attempt・補正requestを参照または操作できない。

この仕組みはQuestra内部のAI利用量meterを整合させるものであり、利用者への請求を変更する機能ではない。Subscription、決済、返金、請求書は別の承認済み決済システムで扱う。

## 権限境界

- RPCは`service_role`からのみ実行する。
- RPCへ渡すoperator IDは、`ai_budget_reconciliation_operators`に登録され、`enabled = true`でなければならない。
- `reviewer`はclaim、調査、補正request作成、case解決を行える。
- `approver`はreviewer権限に加えて補正requestを承認・適用できる。
- 補正requestの作成者は同じrequestを承認できない。
- operator keyは個人名やメールアドレスではなく、社内IAMと対応付けた不透明な識別子を使う。
- Service Role KeyをFlutter、Web bundle、ログ、QST Reportへ保存しない。

## Queue lifecycle

1. `claim_ai_budget_reconciliation_cases(operator_id, limit, lease)`で古いopen caseからclaimする。
2. SQLの`FOR UPDATE SKIP LOCKED`により、並行workerは同じcaseを取得しない。
3. leaseは5分から2時間。期限切れclaimは別operatorが再claimできる。
4. claim、解放、解決はallowlistされたreason codeとoperator IDで監査する。
5. 自由文のresolution noteは保存しない。
6. `get_ai_budget_reconciliation_queue_metrics`は件数、最古経過秒、SLA違反件数だけを返し、user ID、reservation ID、provider interaction IDなどの識別子を返さない。

## Correction lifecycle

課金meterの変更はcase解決と分離する。以下の順序を省略しない。

1. Claim中のreviewerが`request_ai_budget_correction`でbefore snapshot、proposed usage、reason code、idempotency keyを保存する。
2. 別の`approver`が`review_ai_budget_correction`で証拠を確認し、approveまたはrejectする。
3. 承認したapproverが`apply_ai_budget_correction`を実行する。
4. Applyはrequest、reservation、counterを同一transactionでlockし、before snapshotが変わっていれば失敗する。
5. 適用後にreviewerが`correction_applied`でcaseを解決する。

ユーザーへの請求調整、返金、Premium権限変更をこのRPCから行ってはいけない。追加調整が必要な場合も、既存行を手で上書きせず新しい補正requestを作成する。

## Hosted operator drill

Stagingまたは内部Beta環境で、candidate SHAとmigration headを固定して実施する。

1. `supabase migration list --linked`で`202609130004_ai_budget_reconciliation_operator_queue.sql`適用を確認する。
2. `supabase/tests/qst_443_ai_budget_reconciliation_operator_queue.sql`を実行し、client拒否、RLS、自己承認不在を確認する。
3. Secure admin経路で個人情報を含まないreviewer/approverを1件ずつ登録する。
4. 合成provider receiptを使った専用test reservationからopen caseを作る。本番ユーザーのcaseをdrillに使用しない。
5. 2つのworkerから同時claimし、同一reservationが一度しか返らないことを確認する。
6. Reviewerが補正requestを作り、自己承認が拒否されることを確認する。
7. Approverが承認・適用し、reservationとdaily counterの差分が一致することを確認する。
8. Caseを解決し、aggregate metricsからopen件数が戻ることを確認する。
9. Secret値や識別子を含めず、件数とPASS/FAILだけをQST evidenceへ記録する。

## Rollback

破壊的なdown migrationは実行しない。異常時は次のforward-safe手順を使う。

1. Operator workerを停止する。
2. 新規RPCの`service_role` execute権限をrevokeするforward migrationを適用する。
3. Operator registryを`enabled = false, disabled_at = now()`へ変更する。
4. Open case、receipt、attempt、operator event、correction requestは保持し、調査前に削除しない。
5. 未適用の`pending_approval`または`approved` requestは適用せず、監査後にrejectする。
6. 適用済み補正を戻す場合、テーブルを直接編集せず、反対deltaとなる新しい補正requestを二者承認する。
7. 原因修正とhosted drill完了後にのみ権限を再付与する。

## Retention

Operator eventと完了済み補正requestは730日保持する。`purge_expired_ai_budget_operator_evidence`はservice role限定、batch上限付き、`SKIP LOCKED`で実行する。関連caseがopenの証跡、およびPendingまたはApprovedの補正requestは削除しない。
