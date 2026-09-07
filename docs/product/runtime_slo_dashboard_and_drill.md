# Runtime SLO Dashboard and Alert Drill

Status: Local evaluator and drill complete; hosted sink pending.

## Dashboard Contract

Dashboardは本文、ユーザーID、email、token、Quest/Mission/Task/Trail/Arc Chatを表示しない。候補SHA、build、platform、surface、operation、固定error code、severity、handled/fallback、集計成功率、p95だけを扱う。

必須panel:

- Core journey success rate（target 99.9%）
- Crash-free sessions（target 99.5%）
- Quest/Mission/Task mutation p95（target 500ms以下、AI除外）
- Core list read p95（target 1,000ms以下）
- S0/S1 event count by build/platform/surface
- Rollout state、candidate SHA、rollback SHA

## Response Contract

### S0

Cross-account access、owner mismatch、repeated data loss、reproducible launch crashは即時S0。配布停止、候補rollback、Security/Incident Ownerへの通知を同時に行う。破壊的DB down migrationは自動実行しない。

### S1

SLO未達、反復する保存・認証障害、広範なAI/Media失敗はS1。rollout拡大を停止し、原因surfaceをfeature flagで隔離する。データ整合性が保たれている場合は自動rollbackを要求しない。

## Drill

`dart run tools/qst/run_runtime_slo_drill.dart`はHealthy、S1、S0の固定シナリオを評価し、`docs/qst/RUNTIME_SLO_DRILL.yaml`へ機密情報を含まない結果を出力する。これはalert deliveryの実証ではない。

Hosted Beta前にはclean candidate SHAでsink、page receipt、rollout停止、app rollbackを実行し、`dart run tools/qst/verify_runtime_slo_drill.dart --require-hosted`を通す。
