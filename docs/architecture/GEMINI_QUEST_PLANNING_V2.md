# Gemini Quest Planning V2

## 位置づけ

Quest Planning V2は、Geminiを一括生成器ではなく、願いを理解し、成功条件を定義し、航路を設計し、Missionを検証・部分修復するEngineとして扱う。新規経路はInteractions APIを使用し、`generateContent`互換処理は移行中のLegacy Adapterに限定する。

## 実行順序

1. Quest Understanding
2. Clarification Decision
3. Success Contract
4. Strategic Plan
5. Mission Generation
6. Domain / Semantic Validation
7. Mission Critic
8. Targeted Repair（最大1回）
9. Final Validation
10. Preview保存
11. ユーザー承認後のTransaction保存

QuestとMissionを一つの応答で同時確定しない。長期Questは将来工程をMilestoneとして保持し、Mission数を固定しない。

## Provider方針

- 新規処理: Gemini Interactions API `v1`
- 本番: 明示的なStableモデルのみ
- Preview: `AI_ALLOW_PREVIEW_MODELS=true`の評価環境のみ
- Latest / Experimental: 本番経路では拒否
- API Key: Supabase Edge FunctionのSecretのみ。Flutterへ含めない
- State: `store: false`を既定とし、Questra側で必要最小限のPass結果を管理

モデル、Prompt、Schema、Thinking Levelは各実行へ記録する。モデル廃止時はRegistryと環境設定だけを変更し、Quest / Missionドメインを変更しない。

## 障害時

同一モデル再試行、文脈削減、Stable Fallback、Schema Repair、部分結果保持、ユーザー再試行、手動作成の順に扱う。固定カテゴリのMissionテンプレートへ退避しない。Grounding失敗時は最新情報を断定しない。

## Legacy削除条件

次をすべて満たした後にLegacy Adapterを削除する。

- 200件評価でRelease Gate合格
- Android / Webの主要フロー合格
- 二アカウントRLS合格
- Interactions APIの成功率、遅延、コストが許容範囲
- `arc-quest-guide`利用箇所がQuest Planning V2へ移行済み
- 一つ前のStableモデルへ戻せる運用手順を確認済み

## ロールバック

`quest-planning-v2`のクライアントFeature Flagを停止し、既存のQuest作成と手動Mission作成を維持する。Previewは期限切れにでき、未承認データはMissionへ反映されない。モデル変更はStable Registry設定を前バージョンへ戻す。
