# AI Budget Reconciliation Scheduler

## 目的

AI providerの応答喪失や精算中断でstaleになった予算予約を、receiptの有無に基づいて定期分類する。期限切れoperator claimを安全に回収し、queueのSLA違反を内容と利用者識別子なしで運用へ通知する。

このworkerはproviderを呼び出さず、provider実行や利用量を推測しない。検証済みreceiptがある予約だけを既存の精算関数へ渡し、証拠がない予約は人間operatorのreview queueへ残す。

## 安全な既定値

- Scheduler controlとservice worker identityの既定値はOFFである。
- `AI_RECONCILIATION_WORKER_SECRET`は32文字以上とし、Flutter、Web bundle、ログ、QST Reportへ保存しない。
- Edge FunctionはService Role Keyをserver環境からだけ取得する。
- 同じschedule slotはSHA-256 digestで一意化し、再送でcaseやattemptを二重作成しない。
- Caseとalertのclaimは`FOR UPDATE SKIP LOCKED`と期限付きleaseを使う。
- Mission、Quest、会話、prompt、response、user ID、reservation IDをalertへ保存しない。

## 有効化

Hosted migration、QST-445の二operator drill、QST-446 SQL contractをcandidate SHAへ結合した後に限り、secure admin sessionで次の順に有効化する。

1. `ai-budget-reconciliation-scheduler` operatorを`enabled = true`、`disabled_at = null`へ更新する。
2. `ai_budget_reconciliation_worker_control`の閾値を確認する。
3. 最後にcontrolの`enabled = true`へ更新する。
4. Edge Function schedulerから、8から100文字の一意なUTC slotを`{"schedule_key":"reconcile:YYYYMMDDTHHMMZ"}`としてPOSTする。
5. `x-worker-secret`へworker secretを設定する。

有効化操作、実行主体、candidate SHAは社内監査へ記録するが、secretや利用者識別子は記録しない。

## SLA alert

Webhookは任意であり、設定する場合はHTTPSと32文字以上の署名secretを必須とする。送信payloadは次のaggregateだけである。

- payload version
- alert kind
- severity
- open count
- SLA breached count
- oldest age bucket

`x-questra-signature`はpayloadのHMAC-SHA256である。通知失敗はreconciliation結果を巻き戻さず、alertだけを指数backoffで再試行する。送信途中でworkerが停止したclaimは15分後に再取得できる。

## 障害対応

- 同じslotの同時実行は一方だけが処理し、完了済みslotは集計済み結果を返す。
- timeout、rate limit、DB unavailable、permission、configuration errorをallowlistされたcodeへ分類する。
- Worker runは5分後から再試行可能とし、最大20 attemptで停止する。
- provider receiptがないstale予約を実行済みと推測しない。
- Alert本文へ生の例外、schedule key、URL、provider metadataを入れない。
- Edge Functionの503では利用者入力や内部識別子を返さない。

## Kill switchとrollback

異常時はscheduleを停止し、controlを`enabled = false`へ変更する。次にservice worker operatorを無効化し、必要ならEdge Function secretをrotateする。破壊的なdown migrationは実行しない。Worker run、open case、receipt、operator event、未送信alertは原因調査とQST-447のrecovery drillが終わるまで保持する。

既存の人間operator処理はschedulerの停止から独立している。SLA alert webhookだけを止める場合はWebhook設定を外し、queue処理を継続できる。

## Hosted検証

QST-447で以下を実施する。

1. Migration headとcandidate SHAを固定する。
2. Default OFFを確認する。
3. 合成予約だけを使い、同一slot二重実行、receiptあり・なし分類、期限切れclaim回収を確認する。
4. Webhook受信内容がaggregateだけであることを確認する。
5. Webhook failure、lease expiry、再送を確認する。
6. Kill switch後に新規runが実行されないことを確認する。
7. 証跡には件数、age bucket、PASS/FAILだけを残す。
