# Provider評価の人手レビュー

## 前提

固定されたcandidate SHAと、リポジトリ内の200件の合成Planningケースおよび
Safetyケースに対応する実行結果を使う。実行ランナーにはPass単位の評価予算と
同一計画の上限付き継続処理を追加済み。計画Passの全利用量は
`ai_budget_reservations` の所有者別・試行別記録から照合し、欠落時は停止する。
モデル別価格の確定、Safety呼び出しを含む全実行の費用上限、
配備済みモデル設定の固定証跡は残件である。これらを解消し、
承認済み評価枠と配備済みcandidateを確認するまで実API評価を開始しない。
アカウント数を増やして利用枠を迂回しない。

ランナーは合成アカウントの同意、provider利用、計画の推定リスト費用上限を
明示しない限りネットワークアクセス前に停止する。1アカウントのみを使用し、
429・利用記録の欠落・上限超過・Safety APIエラーでは全体を中断する。
この上限は各計画ケースの完了後に照合する見積もりであり、課金のハードキャップではない。
Safety判定、検索、失敗したprovider呼び出しの請求額は含まれない。
Free tierの残枠や日次・短時間の制限種別は未確認であり、無料実行は保証できない。
現在の無料アカウント向けQuest計画枠は月30予約だが、200件の成功プレビューには
最低2,000 Pass予約が必要。ランナーはHostedの該当ポリシーをアカウント作成前に
確認し、不足時は停止する。このガードは評価用の正規の予算枠を設ける代わりにはならない。

## レビュー資料の準備

リポジトリルートで次を実行する。

```powershell
dart tools/qst/prepare_provider_human_review.dart
```

`artifacts/provider-review/<run-id>/` に、未採点の `review-template.json` と
`review-material.md` を出力する。採点済みファイルは上書きしない。
合成入力、Mission、Task、Critic、出典を確認し、実際にレビューした人が
reviewer参照・UTC時刻・各次元1〜5点・判定を記入する。
自動開発の包括承認を人手品質評価の代用にしてはならない。

## サンプルと合否

- コーパスだけから事前選択した40件以上を必須とし、結果を見て差し替えない。
- 10カテゴリ・10ペルソナ以上を含み、Safetyケースは全件をレビューする。
- 追加レビューは可能。ただし事前選択集合と全レビュー集合の両方で85%以上を要する。
- 各Planningケースは正方向の全次元4以上、template_likenessは2以下、
  reviewer判定pass、正常な実provider出力である場合にのみ合格へ数える。
- Safetyの誤判定やfallbackをレビューのフラグで合格に変更できない。
- 結果・Planningコーパス・SafetyコーパスのSHA-256が変わった場合は再レビューする。

## 記録と検証

```powershell
dart tools/qst/record_provider_eval_human_review.dart --input=artifacts/provider-review/<run-id>/review-template.json
dart tools/qst/verify_provider_human_review.dart
```

記録処理とリリースゲートは個別採点から集計を再計算する。reviewerが確認した本文と
現在の結果ハッシュが一致しない場合は停止する。ツールはreviewer本人の身元や
実際に閲覧した行為を独立認証するものではなく、レビューシステムの参照が別途必要。
実行テストの合格は実Geminiの品質合格ではない。
