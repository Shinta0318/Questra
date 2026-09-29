# AI Budget Property and Concurrency Testing

## Purpose

AI予算台帳のreservation、settlement、receipt、reconciliation、claim、correctionが、順序や再送が変わっても同じ不変条件を守ることを実PostgreSQLで検証する。

## Invariants

- `usage_count`はreleasedを除く受理済みreservation数と一致する。
- `reserved_count`と`reserved_cost_micros`は現在reservedの行だけを表す。
- `settled_count`と`actual_cost_micros`は現在settledの行だけを表す。
- 同じowner、operation、idempotency keyは一つのreservationだけを持つ。
- provider interaction IDは別reservationへ再利用できない。
- reconciliation caseのownerとtraceはreservationから外れない。
- 数量と費用は常に非負である。
- claimは`FOR UPDATE SKIP LOCKED`により一つのcaseを一人だけが取得する。
- correctionは申請時snapshotが変化していれば、counter、reservation、request、auditの全変更をrollbackする。

## Local and hosted split

`supabase/tests/qst_453_ai_budget_properties.sql`は、永続台帳の読み取り専用不変条件と、TEMP table上の500回の決定的ランダム状態遷移を実行する。全体をtransactionで囲み、最後にrollbackする。

`tools/qst/run_ai_budget_concurrency_drill.ps1`は隔離されたcandidate DBでのみ使用する。専用のopen probe caseが唯一のclaim候補であることを確認してから、異なるAuth reviewerを2セッション同時に実行する。winnerは1人だけでなければ失敗し、終了時にclaimを解放する。claim／releaseのauditは削除しない。

## Hosted procedure

1. candidate SHAと最新Migration headを固定する。
2. 内容を持たない専用reservation／open caseと、別Auth userへ結合したreviewerを2人用意する。
3. `supabase/tests/qst_453_ai_budget_properties.sql`を`ON_ERROR_STOP=1`で実行する。
4. `SUPABASE_DB_URL`、`QST453_PROBE_RESERVATION_ID`、`QST453_REVIEWER_AUTH_USER_A/B`を一時環境変数へ設定する。
5. `tools/qst/run_ai_budget_concurrency_drill.ps1`を実行する。
6. 同じidempotency keyのreserve／settle再送でcounterが一度だけ変わることを確認する。
7. correction申請後にreservation snapshotを別transactionで変化させ、applyが`budget_correction_stale_snapshot`で失敗し、counter、reservation、request、audit件数がすべて不変であることを確認する。
8. ephemeral fixtureを削除し、監査eventはretention policyに従って保持する。

## Evidence boundary

証拠にはcandidate SHA、Migration head、実行時刻、PostgreSQL version、property回数、claim winner数、PASS／FAILだけを保存する。DB URL、password、Service Role Key、Auth UUID、reservation ID、trace、provider interaction、Quest、prompt、responseを記録しない。

## Rollback

property SQLは常にrollbackする。同時claim drillは特定probe caseだけをreleaseし、既存caseを変更しない。preflightでclaim可能caseが一つでない場合は実行しない。途中失敗時は専用probeのclaim期限を待つか、認証済みoperator手順で解放し、直接auditを削除しない。
