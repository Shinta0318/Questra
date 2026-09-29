# AI Cost Anomaly Detection

## 目的

Geminiのmodel、operation、thinking level、Google Search Grounding有無ごとの実原価を日次集計し、通常水準からの急増を内容や利用者識別子なしで検知する。異常検知は運用判断の材料であり、利用者の課金・Premium・権利を変更しない。

## 集計境界

`ai_cost_observations_daily`は精算済みreceiptだけを対象に、次のdimensionで集計する。

- operation
- provider / model
- thinking level
- Grounding利用有無
- token原価 / Grounding原価 / 合計原価

出力は日次の件数、token数、金額だけである。user ID、Quest、Mission、会話、prompt、response、検索語、URL、provider interaction IDは含めない。Viewと元の運用tableはService Roleだけが参照できる。

## 検知ルール

初期policy `ai_cost_anomaly_20260915_v1` は、直前7日中3日以上の同一dimensionをbaselineとする。観測日に3件以上の精算があり、平均の2倍以上かつ100,000 USD micros以上増加した場合だけalertを作る。90日より古い日や未来日は評価しない。同じ日・dimension・policyの再実行は重複alertを作らない。

履歴不足、baseline 0、閾値未満は異常と断定しない。価格変更、評価traffic、provider retryなどを誤検知理由として明示的に分類できる。

## 停止と復旧

検知処理は`ai_operation_controls`を自動停止しない。停止が必要な場合のみ、operatorが証拠を確認して`set_ai_operation_control`をService Roleから明示実行する。理由はallowlist codeに限定し、変更前後と関連alertを`ai_operation_control_audit`へ記録する。

復旧も同じRPCで明示的に行う。誤検知は`resolve_ai_cost_anomaly`で`false_positive`へ分類し、既に停止したoperationは別途`false_positive_recovery`で再開する。検知、判定、停止、復旧を一つの自動処理にまとめない。

## Thinking evidence

原価をthinking level別に集計するため、Provider responseの実行levelをv3 receiptへ保存する。`unknown`は過去行の移行値に限り、新規精算ではtriggerが拒否する。生のthinking summaryや内部推論は保存しない。

## Hosted検証

Hosted Supabaseへcandidate migrationを配備後、`supabase/tests/qst_449_ai_cost_anomaly_detection.sql`を実行する。最低4日分の合成aggregate evidenceで、閾値未満、急増、再送、誤検知解決、停止、復旧を確認し、transactionをrollbackする。実利用者のQuestや会話を検証fixtureへ使わない。

Hosted実行が終わるまではローカル契約テストを本番監視の証拠として扱わず、External BetaはNO-GOを維持する。
