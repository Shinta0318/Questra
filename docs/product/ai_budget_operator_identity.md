# AI Budget Operator Identity

## 目的

AI予算のreconciliation操作をSupabase Auth主体へ結合し、RPCへ任意のoperator IDを渡すなりすましを防ぐ。補正の申請、承認、適用、case解決は人間のoperatorだけが行い、自動workerと監査上明確に分離する。

この境界はQuestra内部のAI利用量meterを保全するためのもので、利用者の請求、返金、Subscription、Premium権利を変更しない。

## Identity model

- `human`: `auth_user_id`と`identity_bound_at`が必要で、1つのAuth userを複数operatorへ登録できない。
- `service_worker`: Auth userへ結合せず、roleは`reviewer`に限定する。Service Role経路からqueueのclaimとreleaseだけを行う。
- `legacy_unbound`: 過去の監査eventにだけ使用する。operator registryの新規actor種別としては利用できない。
- Migration適用時にAuth未結合の既存human operatorは履歴を残したまま無効化する。

Operator key、Auth user ID、メールアドレス、氏名をQST Report、アプリログ、監視通知へ出力しない。operator registryはsecure admin SQLまたは承認済みIAM provisioningからだけ変更し、Flutterや一般管理画面から登録しない。

## Human RPC boundary

人間operatorはSupabaseの認証済みsessionで次のRPCを呼ぶ。いずれもoperator IDを引数に取らず、DBが`auth.uid()`から有効なoperatorを解決する。

- `claim_my_ai_budget_reconciliation_cases`
- `release_my_ai_budget_reconciliation_claim`
- `request_my_ai_budget_correction`
- `review_my_ai_budget_correction`
- `apply_my_ai_budget_correction`
- `resolve_my_ai_budget_reconciliation_case`
- `get_my_ai_budget_reconciliation_queue_metrics`

一般のauthenticated userにもRPCの呼び出し権限自体は存在するが、registryに一致する有効なhuman operatorがなければ、データ取得前に`reconciliation_operator_required`で拒否する。基礎となるoperator ID付きRPCはauthenticated roleへ公開しない。

補正申請者と承認者は異なるoperator IDだけでなく、同じAuth userでは実行できない。承認したapproverだけが適用できる。caseを人間判断で閉じる場合も、有効なAuth結合済みhuman operatorを必須とする。

## Service worker boundary

Service Roleは`actor_kind = service_worker`の登録済みoperatorを使い、queueのclaimとreleaseだけを実行できる。補正申請、承認、適用、人間判断によるcase解決の基礎RPCはService Roleからrevokeする。自動照合による解決は、既存の冪等reconciliation関数が`resolved_by = null`で記録する。

Event triggerは呼び出し側が渡した値を信用せず、operator registryから`human`または`service_worker`を監査eventへ設定する。

## Secure provisioning

実値はリポジトリへ保存しない。承認済みsecure admin sessionで、対象Auth userと社内IAM対応を別経路で確認してから登録する。

```sql
insert into public.ai_budget_reconciliation_operators (
  operator_key,
  operator_role,
  auth_user_id,
  actor_kind,
  identity_bound_at
) values (
  'opaque-reviewer-key',
  'reviewer',
  '<verified-auth-user-id>'::uuid,
  'human',
  now()
);
```

退職、権限変更、Auth user削除時は、先にoperatorを無効化して進行中claimを解放する。その後にAuth userを削除すると`auth_user_id`だけがnullになり、operator eventと補正証跡は保持される。operator rowや監査eventを先に削除しない。

## Hosted two-operator drill

Candidate SHAとmigration headを固定したStagingまたは内部Beta環境で実施する。

1. `202609130005_auth_bound_reconciliation_operator_identity.sql`の適用を確認する。
2. `supabase/tests/qst_445_auth_bound_reconciliation_operator.sql`を実行する。
3. Secure admin経路で専用reviewerとapproverを別のAuth userへ結合する。
4. 一般authenticated userが`claim_my_ai_budget_reconciliation_cases`で拒否されることを確認する。
5. Reviewer sessionで合成test caseをclaimし、補正requestを作る。
6. Reviewer sessionから承認が拒否されることを確認する。
7. 別Auth userのApprover sessionで承認、適用する。
8. Reviewer sessionでcaseを解決し、eventのactor kindがすべて`human`であることを確認する。
9. Service workerでclaimとreleaseが成功し、補正requestとcase解決が拒否されることを確認する。
10. 証跡には集計値とPASS/FAILだけを残し、ID、メールアドレス、Quest、会話、receipt内容を記録しない。

## Rollback

破壊的なdown migrationは実行しない。異常時はhuman wrapperとworker RPCのexecute権限をrevokeし、operatorを無効化するforward migrationを使う。Open case、補正request、operator eventは保持する。旧来の任意operator ID付きRPCをauthenticatedまたはService Roleへ戻してはならない。

再開前にAuth binding、自己承認拒否、worker制限、既存open caseの保持をhosted drillで再確認する。
