# Guild Discovery Platform

Status: Draft / QST-211 parent specification
Authority: `docs/QUESTRA_MASTER_SPEC_V2.md`

## 1. Purpose

Guildを交流量の最大化ではなく、次に挑戦したいQuest、役立つMission、
経験を持つNavigatorを安全に発見する場所として再定義する。

中心となる循環は次のとおりである。

1. Arcとの相談からQuestをつくる。
2. 必要なときだけGuildで似た航路を探す。
3. 公開QuestまたはMissionを選び、自分のQuestへコピーする。
4. Arcが本人の期限、予算、生活状況に合わせた最適化案を提示する。
5. ユーザーが確認してからMissionへ反映する。
6. 挑戦の所有者が希望した場合だけ、整理された航路を公開する。

## 2. Product Boundary

- GuildはHomeとArcを置き換えない。`Home -> Arc -> Quest`が主導線である。
- Questを始めるためにGuild参加を必須にしない。
- 公開前のQuest、Mission、Trail、Arc MemoryをDiscoveryへ混入させない。
- コピーは参照元と派生関係を記録し、原本を変更しない。
- Arcによる最適化は提案であり、明示承認前にユーザーの航路を変更しない。
- 企業支援は独立した透明な枠で扱い、人気Questに偽装しない。

## 3. Discovery Sections

| Section | Purpose | Main signals |
| --- | --- | --- |
| あなたへのおすすめ | Quest DNAとの近さから発見する | 関連度、品質、新しさ、難易度適合 |
| 注目のQuest | 最近役立った航路を発見する | 新しさ、達成状況、対数化したコピー数 |
| 新着Quest | 新しい挑戦を広く見つける | 公開日時、品質審査 |
| 仲間募集中 | 同じQuestを進める任意の導線 | 募集設定、関連度、安全性 |
| Missionライブラリ | 必要な工程だけ取り入れる | 関連度、目的、依存関係、品質 |
| Navigator Spotlight | 有用な公開航路の作者を知る | 品質、継続的な貢献、安全実績 |

`Navigator Spotlight`はフォロワー数ランキングにしない。コピー数や反応数は
発見の補助信号であり、人の価値やArcとの関係を評価する点数ではない。

## 4. Publication

QuestとMissionは個別に次の公開範囲を持つ。

- `private`: 本人のみ。
- `unlisted`: URLを知るユーザーのみ。Discovery対象外。
- `public`: 公開審査後にDiscovery対象となる。

公開物には、元の所有データから切り離した公開用概要を保存する。個人メモ、
非公開Trail、Arc Memory、正確な生活場所、連絡先をコピーしてはならない。

## 5. Ranking Constitution

- おすすめは選定理由を短く表示する。
- 人気順だけで情報を支配させない。
- コピー数は対数化し、関連度や有用性を上回らせない。
- 新規公開物にも発見機会を与える。
- センシティブ属性による推定や差別的な順位付けを行わない。
- 無限スクロール、閲覧ストリーク、反応数を煽る通知を導入しない。
- 推薦精度より公開範囲、安全審査、ブロックを優先する。

## 6. Copy Contract

コピー時にユーザーは次を選ぶ。

- Missionを含める。
- Arcの最適化案を受け取る。
- 保存前に編集する。

コピー後は新しい所有者のQuest ID、Mission IDを発行する。参照元には匿名化した
コピーイベントのみを加算し、コピー先の進捗や個人情報を作者へ共有しない。

## 7. Delivery Plan

- QST-214: ドメイン、順位付け、公開・コピー契約。
- QST-215: Supabase公開モデル、RLS、モデレーション境界。
- QST-216: Discovery HomeとQuest/Mission詳細。
- QST-217: Quest/Missionコピーと派生履歴。
- QST-218: Quest DNA推薦とランキング説明。
- QST-219: レビュー、Navigator Spotlight、通報・ブロック。
- QST-220: Arc個別最適化、E2E、Beta再公開判定。

GuildルートはQST-215のRLSおよびQST-216の空・読込・失敗状態が検証されるまで
Coming Soonを維持する。
