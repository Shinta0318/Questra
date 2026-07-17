# Beta Issue Labeling Rules

## Purpose

Questra Betaの報告を担当者ごとの感覚に依存させず、同じ入力から同じIssue label、優先度、Beta停止判断、QST候補を生成する。

## Base Labels

すべての報告に以下を付与する。

- `beta`
- `severity:S0`から`severity:S3`
- `surface:<surface_key>`
- `type:<feedback_type_key>`
- 判定されたcategory label

## Category Matrix

| Category | Primary triggers |
| --- | --- |
| `bug` | `crash`, `broken_flow` |
| `ux` | `confusing_copy`, `visual_polish`, `missing_state`, `idea` |
| `data` | `data_loss`, `trust_or_safety`, RLS surface |
| `ai` | Arc ChatまたはArc Memory surface |
| `guild` | Guild surface |
| `arc` | Arc ChatまたはArc Memory surface |
| `performance` | `slow_response`またはPerformance surface |

複数categoryは併用する。たとえばArc Chatの分かりにくい表現は`ux`, `ai`, `arc`を持つ。

## Priority Rules

| Condition | Priority | QST | Beta expansion |
| --- | --- | --- | --- |
| S0 | P0 | 即時作成 | 停止 |
| crash | P0 | 即時作成 | 停止 |
| data loss / trust or safety / RLS | P0 | 1件で作成 | 停止 |
| S1 | P0 | 24時間以内に作成 | Ownerと期限を設定 |
| S2 | P1 | 同種3件で作成 | 継続可 |
| S3 | P2 | 同種3件または戦略整合時に候補化 | 継続可 |

## QST Candidate Output

QSTへ変換する場合は以下を必須とする。

- Title: severity、surface、summary
- Problem: actual result
- Evidence: report ID、build、reproduction steps
- Scope: 対象surfaceと中心フローを壊さない修正境界
- Acceptance: expected result
- Validation: 回帰テストと静的解析

QST IDは`docs/qst/BACKLOG.yaml`の次の空き番号をRelease Managerが割り当てる。

## Implementation Boundary

- 判定実装: `apps/mobile/lib/features/feedback/beta_feedback_triage_service.dart`
- 入力: `BetaFeedbackReport`
- 出力: `BetaFeedbackTriage`と必要時の`BetaQstCandidate`
- 判定はローカルかつ決定論的に行う。
- 報告本文を分類目的で外部AIへ送信しない。
- 将来Issue trackerへ接続しても、このルールを監査可能な単一境界として維持する。
