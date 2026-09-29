# Tool Continuation Cost Attribution

## 目的

Gemini Function Callingを複数turnで継続するとき、各provider実行のtoken、grounding query、model route、費用を欠落や二重計上なく一つの実行へ帰属させる。Quest、会話、tool resultの本文を費用証拠へ保存しない。

## 実行契約

- 一つの利用者操作とoperation、idempotency keyから一つのcontinuation runを作る。
- provider呼び出しごとに独立したbudget reservationとprovider receiptを確定してからturnを記録する。
- turn番号は0から始まり、最大5 turnを`0..4`として保存する。
- fallback時は試行したmodelを順番付きで保持し、最後のmodelがprovider receiptのsettled modelと一致しなければ拒否する。
- 最終化時はturn合計とorchestrator集計のinput token、output token、grounding queryが完全一致する場合だけcompletedにする。
- timeout、cancel、tool失敗、provider失敗、attribution失敗は、それまでに確定したturnだけを残してrunを閉じる。
- 同じturnの再送はreservation、idempotency digest、model routeが一致する場合だけ冪等成功とする。

## Privacy boundary

費用証拠には識別に必要なdigest、model名、thinking level、token数、query数、費用だけを保存する。prompt、response、interaction history、Quest、Arc Memory、tool引数、tool result本文を保存しない。tool resultは次のstateless provider requestへ一時的に渡すが、cost ledgerへ本文を保存しない。

## Rollout

初期値は`AI_TOOL_CONTINUATION_ATTRIBUTION_ENABLED=false`とする。Migration配備、SQL contract test、provider-backed mock、Hosted drillが通った候補環境だけで`true`へ切り替える。attributionが有効なのにrun開始、turn記録、最終化のいずれかを確認できない場合、AI結果を成功扱いにしない。

## Hosted drill

候補SHAへMigrationと`quest-planning-v2`を配備した後、内容を証拠ファイルへ記録せず次を実施する。

1. `AI_TOOL_CONTINUATION_ATTRIBUTION_ENABLED=true`を候補環境だけへ設定する。
2. read toolを1回使い、primary modelで開始してfallback modelで完了するprovider-backed requestを実行する。
3. runがcompleted、turnが連番、turn合計とrun合計が一致し、各turnの最後のattempted modelがsettled modelと一致することをservice-roleの集計だけで確認する。
4. tool resultに一意な検査文字列を含め、run／turnのcolumnと取得可能な値に検査文字列が存在しないことを確認する。
5. timeoutを発生させ、runがfailedかcancelledで一度だけ閉じ、再送してもturnと合計が増えないことを確認する。
6. 同じturnを同じidempotency keyで再送して冪等成功し、異なるmodel routeで再送するとconflictになることを確認する。
7. `supabase/tests/qst_452_tool_continuation_cost_attribution.sql`を実行する。
8. trace ID、user ID、tool本文、credentialを保存せず、候補SHA、時刻、PASS/FAIL、turn数、合計一致だけをQST Reportへ追記する。

## ロールバック

異常時は`AI_TOOL_CONTINUATION_ATTRIBUTION_ENABLED=false`へ戻す。既存run／turnを削除せず、失敗runは監査証拠としてretention期限まで保持する。機能停止は費用帰属だけを無効化し、provider keyや利用者データをクライアントへ移さない。
