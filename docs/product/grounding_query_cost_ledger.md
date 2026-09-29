# Gemini Grounding Query Cost Ledger

## 目的

最新情報が必要なQuest PlanningでGoogle Search groundingを使った場合に、token費用とは異なる検索query単位の原価を予約、精算、監査する。検索語やURLを保存しないまま、providerが実際に実行した検証済み件数だけを記録する。

## 課金単位

Gemini 3系のGoogle Search groundingは、モデルが実行した検索queryごとに課金される。1回のAPI requestで複数queryが実行された場合は個別に数え、空queryは数えない。QuestraではInteractions APIの`google_search_call`に含まれる一意な非空query数を`unique_non_empty_query`として扱う。

初期rateはGoogle公式価格表に基づく14 USD / 1,000 query、すなわち14,000 USD micros / queryである。月5,000件の共有無料枠は個人へ恣意的に配賦せず、台帳では保守的なgross rateを使う。rate、source、effective dateはversion付きで保持し、価格が不明または有効期間外なら推測せずfail closedする。

## 処理境界

1. `google_search` toolを明示したrequestだけ、token予算と同時に最大query数を予約する。
2. Provider応答から`google_search_call`のqueryを抽出し、trim、空文字除外、一意化を行う。
3. 申告件数と抽出件数が一致したprovider metadataだけreceiptへ記録する。
4. Token利用量とgrounding利用量を同じDB transactionで精算する。
5. 応答失敗、予約解放、予約期限切れではgrounding予約も解放する。
6. Provider receiptがない場合、query件数を推測しない。
7. Grounding予約がある場合は、件数とevidence versionを持つv2 receiptを必須とし、旧receiptによる0件精算を拒否する。

検索なしの処理ではgrounding予約を作らず、receipt件数は0としてtoken費用だけを精算する。Grounding予約なしで正のquery件数が届いた場合は精算を拒否し、reconciliation対象として扱う。

## Privacy

Cost ledgerへ保存するのはprovider、tool、rate version、予約件数、実績件数、金額、時刻、provider evidence digestだけである。検索語、検索結果、URL、Quest、Mission、prompt、response、利用者IDは保存しない。日次viewも件数と金額だけを集計する。

Mission Reference用のURLと取得日は既存のGrounded Fact境界で管理し、原価台帳とは分離する。

## 設定

`AI_GROUNDING_MAX_QUERIES_PER_REQUEST`で1 requestあたりの予約上限を1から20の範囲で設定する。既定値は8。これは検索実行数を強制する値ではなく、Admission時に確保する上限である。

## 運用

`ai_grounding_cost_daily`はService Roleだけが参照でき、日、provider、tool、rate version単位でsettled calls、query数、実原価を返す。QST-449の異常検知はこの集計だけを利用し、個人の行動やQuest内容を監視しない。

## Hosted検証

Migrationをcandidate SHAからHosted Supabaseへ配備し、`supabase/tests/qst_448_grounding_query_cost_ledger.sql`を実行する。実provider smokeでは次を確認する。

- Groundingなしの処理が0 queryである。
- Groundingありの処理がprovider metadataの件数と一致する。
- 同一idempotency keyの再送で予約・精算が二重計上されない。
- Receiptなしのstale予約が推測精算されない。
- 解放、期限切れ、reconciliationでcounterが負にならない。

Hosted SupabaseでのMigration replayと実provider receipt確認が終わるまで、ローカル契約テストを外部課金証跡として扱わない。
