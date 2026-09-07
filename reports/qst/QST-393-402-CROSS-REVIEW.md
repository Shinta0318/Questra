# QST-393〜402 横断レビュー

## 状態

2026-09-04時点で **InProgress / External Beta NO-GO**。全領域のレビュー完了ではない。まず候補の整合性と障害訓練の状態管理を実装・再現テストで検証した。

前の作業ではローカルモックのログインからHomeへの遷移を実画面で確認し、関連Widget Test 2件が通過した。これはSupabase認証、Gemini応答、実機Beta品質の証明には使わない。

## 修正済み

### High: ステージ済み変更の見落とし

`verify_clean_candidate_evidence.dart` は未ステージ差分だけを取得しており、ステージ済みの実装変更を見落とした。`verify_candidate_scope_partition.dart` のHEADとの差分も、indexの変更とworktreeの逆変更が相殺される場合に不十分だった。

両検証で `candidate_git_state.dart` を利用し、index、worktree、untrackedを個別に取得する。NUL区切り・UTF-8で日本語や空白を含むパスを保持し、renameの変更元と先の両方を検査する。期待SHAと現在HEADの一致も必須にした。

実際の一時Gitリポジトリを使う10ケースが通過。ステージ済み変更を本体の検証コマンドが拒否することも確認した。

### High: 障害訓練が他の担当者の停止設定を解除する

`run_incident_live_drill.ps1` は `finally` で無条件に再開し、停止理由をnullへ戻していた。訓練中に別の担当者が停止設定を更新すると、その判断を上書きしていた。

停止・復元とも `enabled / disabled_reason / updated_at` の条件付き更新へ変更。訓練固有の停止マーカーを保持し、所有状態が変われば追加書き込みせず失敗する。元の停止理由も保持する。更新後のreadback不一致は成功にしない。

16ケースのPowerShell実行テストが通過。正常復元、既存停止、停止前・復元前の競合、時刻のみの変更、応答喪失、復元失敗、readback競合、クエリ値のエスケープを含む。実Supabaseへの操作は実行していない。

### High: 停止連絡のSLAをスクリプト所要時間で代用

同ランナーは開始時刻を停止時刻、終了時刻を連絡時刻としていた。実際の連絡に時間がかかっていても短い実行で合格する状態だった。

検知・配布停止・受領時刻を必須のUTC入力にし、順序、未来日時、検知から1時間以内を検査する。記録は `operator_attested_receipts` と明記し、外部受領票を自動的に照合したとは表現しない。厳格verifierも時間差を再計算する。

### High: 個別の厳格証跡検証が最終ゲートに接続されていない

最終ゲートへlegal、asset decision、Web、Android、hosted migration、provider evidence hash、incidentの厳格verifierを接続した。外部Beta判定の生成コマンドが失敗した場合も停止する。

## 未解決のレビュー指摘

### QST-400で追加修正・検証した事項

実レスポンスの `preview.routeMissionPlan.missions` へ抽出先を修正した。
旧契約の `preview.missions` は現行のMission証跡として受け付けない。
Mission本文・Task・成功条件・Critic・出典を許可フィールドだけ記録する。
Criticの実行回数ではなく最終判定を確認し、repair後に2回実行されても誤って失敗させない。

人手採点は結果と両コーパスのハッシュに結び付け、合否・coverageを再計算する。
事前選択サンプルの差し替えを拒否し、追加の高評価で必須サンプルの低評価を薄めることも防止した。
生のprovider応答、承認token、自由記述の個人情報を評価資料へそのまま保存しない。

合成fixtureによるPowerShell 12ケース、Dart 20ケース、既存Flutter契約テスト5件が合格。
7個のDartツールの静的解析と4個のPowerShell構文検証が通過した。実Gemini呼び出しは未実施。
人手評価の手順は `docs/qst/PROVIDER_HUMAN_REVIEW.md` に記載した。

1. **High / QST-400**: 8アカウント分割では評価200件の実行予算を保証しない。Interactions AdapterはPassごとに予約し、freeのQuest Planning枠は月30予約。予算を迂回するアカウント追加ではなく、明示承認された上限付き評価枠、再開可能な実行、実際のPass消費量を設計する必要がある。
2. **High / QST-400**: 本文・出典保存とハッシュ結合はローカル修正・検証済み。ただし実出力による人手評価は未実施。keyword hitをspecificityやnon-template率として扱う代理指標の妥当性も未確認で、次元別評価との対応を見直す必要がある。
3. **High / QST-400**: 実行されたPassの組合せと設定versionの固定を混同している。条件付きrepairやfallbackを正しく扱うfingerprint、モデル別価格、実行したthinkingの記録が未検証。
4. **High / QST-399**: finalizerが更新する `ARC_ASSET_PROVENANCE.yaml` がpost-candidate許可集合にない。単に許可を広げず、候補確定前の権利情報と確定後の生成証跡の境界を整理する必要がある。
5. **High / QST-401**: 実演の前提がapproved candidateであり、実演証跡が承認の前提になる運用では循環する。build candidate、evidence collection、distribution approvalを区別する必要がある。

QST-400は「外部証跡を待つだけ」ではないため `ImplementedValidationPending` へ修正した。QST-402は未完了のままとする。

## 検証範囲と不足

- コード・運用: 上記2系統の実行テスト、修正Dartファイルの静的解析を実施。
- UI/UX: モックログインからHomeのみ確認済み。全画面・実機レビューは未実施。
- AI: 200件の実Gemini評価は未実施。静的コーパス検証を品質合格とは扱わない。
- DB・RLS: 今回はmigration配備、二アカウント検証、実PostgRESTでの競合検証を行っていない。
- セキュリティ: 候補差分の見落としと制御状態の競合に限定。全体スキャン完了ではない。
- Master Spec: 承認なしの状態変更を避け、証跡がないものを完成扱いにしない方針へ修正。仕様全章との照合は継続中。

## 次の作業

QST-400の実行・採点・人手評価の契約を修正し、QST-399/401の候補確定手順を整理する。その後に残りの領域をレビューし、確定した指摘を次の10件へ反映する。未解決事項を残したまま10件分の完了や公開可能状態を宣言しない。

commit、push、PR、外部配備はこのレビューでは行っていない。
