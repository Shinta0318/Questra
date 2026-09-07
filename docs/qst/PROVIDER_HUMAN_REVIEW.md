# Provider評価の人手レビュー

## 前提

固定されたcandidate SHAと、リポジトリ内の200件の合成Planningケースおよび
Safetyケースに対応する実行結果を使う。現時点の実行ランナーには、Pass単位の
評価予算・再開処理・モデル別価格・設定fingerprintの残件がある。これらを解消し、
承認済み評価枠と配備済みcandidateを確認するまで実API評価を開始しない。
アカウント数を増やして利用枠を迂回しない。

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
