# AI Budget Operations Recovery

## Scope

AI予算予約、provider receipt、精算、reconciliation queue、operator correctionの障害対応を定める。これは利用者への請求やPremium entitlementを操作する手順ではない。

## Severity and SLO

### S0

Cross-owner参照、負数counter、二重精算、監査証拠の消失を対象とする。5分以内に確認し、15分以内に配布と影響operationを停止し、4時間以内のforward fixまたは既知のcandidateへの復帰を目標とする。破壊的down migrationや監査削除は行わない。

### S1

Provider障害、精算応答喪失、queue滞留、誤補正を対象とする。15分以内に確認し、30分以内にrollout拡大を止め、8時間以内に検証済み経路を復旧する。利用者入力は保持し、固定Missionを成功結果として返さない。

### S2

単発の再試行可能エラーやSLO未満の遅延を対象とする。4時間以内に確認し、2営業日以内に原因と再発防止を整理する。

## Stop decisions

- provider失敗率またはreceipt conflict率が閾値を超えたoperationだけを`ai_operation_controls`で停止する。
- Scheduler自身が異常な場合はworker kill switchをOFFにし、人間のAuth-bound claimへ切り替える。
- S0はExternal Beta配布を停止する。S1は拡大を止め、復旧canaryが通るまで再開しない。
- 停止判断で利用者のSubscription、Premium、Quest、Missionを変更しない。

## Recovery scenarios

### Provider outage

新規planningを停止し、入力を保持して再試行または手動作成へ案内する。primaryとfallbackを別々にcanaryし、model、prompt、schemaの候補versionを固定したまま復旧する。

### Settlement response loss

同じidempotency keyで再送し、server receiptを唯一の根拠としてreconcileする。provider実行やtoken数を推測しない。すでにsettledならcounterを再加算しない。

### Queue backlog

新規自動claimを止め、期限切れleaseを回収し、oldest-firstで処理する。通知payloadはseverity、件数、age bucketだけを持ち、利用者、Quest、費用明細を含めない。

### Incorrect correction

適用済みrequest、reservation履歴、operator eventを削除・書換えしない。現在のreservation snapshotをbefore値とする別requestを作り、元の値へ戻すcorrected値を指定する。新しいidempotency key、別requester／approver、通常のsnapshot guardを使って相殺する。staleなら全変更をrollbackし、さらに新しいsnapshotから再申請する。

## User communication

利用者には技術用語、内部費用、model、provider、reservation、traceを表示しない。推奨文言は次の二つに限定する。

- 「現在、Arcの航路づくりを一時停止しています。相談内容は保持されています。しばらくしてから再試行できます。」
- 「航路の処理状況を確認しています。内容を失わずに確認を続けます。」

復旧前に完了を約束せず、入力が保持できない場合は保持されていると表示しない。

## Evidence

記録するのはcandidate SHA、Migration head、scenario、severity、検知／停止／復旧時刻、件数、PASS／FAIL、再開判断だけとする。Service Role Key、DB URL、Auth UUID、user／reservation／trace、prompt、response、Quest本文を保存しない。

## External Beta boundary

TabletopはHosted実行証拠ではない。QST-447のcandidate-bound recovery drill、QST-453の実PostgreSQL property／concurrency test、webhook受信、named owner確認が終わるまでExternal BetaはNO-GOを維持する。
