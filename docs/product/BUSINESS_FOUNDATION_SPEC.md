# Questra Business Foundation Specification

Status: Foundation only / Enterprise delivery disabled

## Purpose

Business Foundationは、Quest達成支援の品質を先に高め、その結果を将来の企業支援へ安全に接続するための基盤である。広告配信、企業Dashboard、請求、CRM連携は対象外とする。

## Data Boundary

- Quest本文、Mission本文、Arc会話、Arc Memory、氏名、メール、電話、住所をBusiness派生データへ格納しない。
- 個人向けQuest DNA原本とBusiness派生Signalを別テーブル・別RLS境界に置く。
- センシティブなQuest/MissionはBusiness利用を禁止する。
- 支援情報はMission生成後に分類し、商業性をMission生成プロンプトへ混入させない。
- 同意拒否によってQuest、Mission、Task、Trail、Arcの基本機能を制限しない。

## Event Catalog

Quest: `quest_created`, `quest_updated`, `quest_deleted`, `quest_started`, `quest_paused`, `quest_resumed`, `quest_completed`, `quest_abandoned`, `quest_stage_changed`, `quest_plan_generated`, `quest_plan_approved`, `quest_plan_rejected`, `quest_plan_regenerated`, `quest_proposal_viewed`, `quest_proposal_selected`.

Mission: `mission_created`, `mission_updated`, `mission_started`, `mission_completed`, `mission_skipped`, `mission_deleted`, `mission_rescheduled`, `mission_regenerated`, `mission_reordered`, `mission_support_requested`.

Route: `route_created`, `route_updated`, `route_replanned`, `route_approved`, `route_rejected`, `route_rolled_back`.

Future Business eventは型定義だけを保持し、企業機能が無効な間は生成しない。

## Event Rules

- `quest_progress_events`はappend-onlyであり、クライアント直接INSERTを禁止する。
- `record_quest_progress_event` RPCは`auth.uid()`から所有者を確定する。
- metadataはDBとFlutterのホワイトリストを二重適用する。
- `(user_id, idempotency_key)`で重複を防ぐ。
- 記録障害は主要操作を失敗させない。
- `app_environment`でdevelopment、test、productionを分離する。

## Lifecycle Stages

`dreaming`, `exploring`, `planning`, `preparing`, `acting`, `near_completion`, `completed`, `paused`, `abandoned`を標準とする。長期未使用だけを理由に`abandoned`へ移行しない。`paused`と`abandoned`はユーザーの明示操作を必要とする。

## Consent Purposes

`arc_personalization`, `product_improvement`, `anonymous_analytics`, `business_recommendations`, `business_segment_analysis`, `personal_data_sharing`を独立管理する。`personal_data_sharing`は共有先、共有項目、目的、保存期間を示す文脈確認以外では許可できない。

## Segment Rules

- 許可済み派生属性だけを集計する。
- 10人未満のSegmentは生成・公開しない。
- センシティブQuestを除外する。
- Snapshotは有効期限を持ち、生データへの企業クエリを許可しない。
- 企業アクセスは監査対象とする。

## Inspection Queries

```sql
select event_name, occurred_at, quest_id, mission_id, metadata
from public.quest_progress_events
where user_id = auth.uid()
order by occurred_at;

select current_stage, count(*)
from public.quest_stage_state
group by current_stage;

select dimension_values, cohort_size, metrics, expires_at
from public.segment_snapshots
where cohort_size >= 10 and expires_at > now();
```

## Release Gate

企業向け提供は、二アカウントRLS、同意撤回、ユーザー削除、センシティブ除外、k=10、Android/Web E2E、プライバシー文書レビューがすべて完了するまで無効とする。
