# Provider Receipt Authenticity and Replay Guard

## 目的

Gemini応答の利用量receiptを、Questraのserverが発行した予約、trace、operation、model routeへ結合する。別予約の応答、古いinteraction、別model routeの応答を再利用して予算台帳を精算できないようにする。

## Binding

Edge Functionは32文字以上の`AI_RECEIPT_NONCE_SECRET`から、利用者、operation、idempotency key、trace、許可model集合を入力にHMAC-SHA256 nonceを導出する。nonceはprocess memoryとService Role RPCの間だけで利用し、DBにはSHA-256 hashだけを保存する。

予約には正規化した許可model集合とmodel route digestを保存する。Receipt v4は次をすべて照合する。

- nonce hash
- trace ID
- operation
- model route digest
- 実行modelが許可集合に含まれること
- provider interaction IDが別予約で使われていないこと

不一致は精算せず`execution_evidence_conflict`のoperator caseへ送り、allowlist reasonだけを監査する。Providerの生応答、prompt、API key、nonce、会話内容は台帳へ保存しない。

## Duplicate delivery

同一予約・同一evidenceの再送は既存receipt v3のdigest比較を再利用してidempotent successにする。異なるevidenceやthinking levelはoperator reviewへ送る。精算関数とcounter更新は従来どおり一つのDB transactionで行うため、duplicate deliveryで二重計上しない。

## Rollout

`AI_RECEIPT_BINDING_ENABLED`は既定OFFである。OFFでは現在のreceipt v3経路を維持し、既存Beta環境を停止しない。Hosted SupabaseへMigrationとEdge Functionを同一candidate SHAから配備し、QST-450 drillを通した後だけONにする。

ONにする前に以下を満たす。

1. 32文字以上のnonce secretをserver secretとして登録する。
2. Reservation v3とreceipt v4のService Role拒否境界を確認する。
3. 同一request再送、別nonce、別trace、別operation、別model route、interaction replayを試す。
4. Counterが一度だけ増えることを確認する。
5. FlagをOFFへ戻す復旧手順を確認する。

Feature FlagをOFFへ戻しても既に保存されたhashや監査証跡は削除しない。破壊的なdown migrationは実行しない。
