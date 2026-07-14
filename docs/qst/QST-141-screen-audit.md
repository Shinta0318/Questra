# QST-141 Screen Audit

> Backlog mapping: 添付仕様のQST-141は、既存QST履歴との衝突を避けるため実装BacklogではQST-151として扱う。

## 監査範囲

- Flutter主要画面とRoute
- 下部ナビゲーションと共通Shell
- 主要ボタンと画面遷移
- Supabaseテーブル
- ダミーデータとローカルfallback
- 未完成機能、重複導線、UIルールの差

この監査ではコード、DB、既存ユーザーデータを削除していない。

## 画面と分類

| 画面 | Route | 分類 | 現状 | Simplification方針 |
| --- | --- | --- | --- | --- |
| Splash | `/splash` | A | 起動入口 | 維持 |
| Login | `/login` | A | 認証 | 維持 |
| Signup | `/signup` | A | 認証・Profile作成 | 維持 |
| Onboarding | `/onboarding` | B | 初期設定 | Arc→Quest中心の説明へ短縮 |
| Home | `/home` | B | Arc、Mission、Quest、Trail、Guild、Horizonなどを集約 | Arc短文、主要CTA、今日のMission、進行中Questへ限定 |
| Arc | `/arc` | B | Chat、Guide、Reflection等の入口 | 自然文入力とQuest候補確認を中心化 |
| Quest一覧 | `/quest` | B | Questカード、統計、補助導線 | Quest、進捗、次Missionへ限定 |
| Quest作成 | `/quest/create` | D | 独立フォームから直接作成可能 | Arc起点を主導線にし、手動fallbackとして保持 |
| Quest詳細 | `/quest/:questId` | B | Guide、Milestone、Trail等を含む大画面 | 説明、進捗、Mission一覧、追加、編集へ限定 |
| Quest編集 | `/quest/:questId/edit` | A | Quest編集 | 維持 |
| Mission | `/mission` | D | 独立画面 | Quest詳細とHomeを主入口にし、直接メニューには出さない |
| Trail | `/trail` | C | Timeline、投稿、画像、Reflectionを実装中 | Routeとコードを保持し、Coming Soon表示へ切替 |
| Guild | `/guild` | C | マッチング、安全確認、相談カードを実装中 | Routeとコードを保持し、Coming Soon表示へ切替 |
| Profile | `/profile` | A | Profile、成長情報、Settings入口 | 維持。将来Trail入口候補 |
| Settings | `/settings` | A | Tutorial、Trust、Arc Memory、Data Request、Consent | Profile配下の補助画面として維持 |

分類: A=そのまま使用、B=簡素化、C=Coming Soon、D=主要導線から一時的に隠す。

## 現在のナビゲーション

現在のShellは6ブランチを持つ。

1. Home
2. Arc
3. Quest
4. Trail
5. Guild
6. Profile

Compactでは下部ナビゲーション、Tablet/DesktopではNavigationRailを使う。さらにArc Floating EntryとQuick Action Menuが重なり、Quest作成・Trail作成・Guild・Arcへの入口が重複している。

### 問題

- 添付仕様の優先順`Home / Quest / Arc / Guild / Profile`と異なる。
- Trailが主要タブに残っている。
- ArcはタブとFloating Entryの二重入口になっている。
- Quest作成はQuick Action、Quest画面、Home、Arcなど複数入口がある。
- Quick Actionから未完成のTrail/Guildへ直接移動できる。

## 主要ボタンと遷移

| Surface | 主な操作 | 問題 |
| --- | --- | --- |
| Home | Arc、Quest、Mission、Trail、Guild、Horizonへの複数CTA | 主要操作が1つに絞られていない |
| Arc | Chat送信、Quick Action、Guide、Reflection | Quest候補作成フローとの境界が曖昧 |
| Quest一覧 | Quest作成、詳細、テンプレート等 | Arc起点と独立フォーム起点が競合 |
| Quest詳細 | Mission、Guide、Milestone、Trail、編集 | 中心行動より補助機能が多い |
| AppShell | Arc Floating Entry、Quick Action Menu | 下部タブと機能が重複 |
| Guild | Quest作成、相談、安全確認、マッチング | Betaで完成していない機能が通常画面に見える |
| Trail | 投稿、編集、画像、Reflection、削除 | Simplificationフェーズの対象外機能が通常画面に見える |

## データと永続化

### 中心フローで使用

- `user_profiles`
- `quests`
- `missions`
- `arc_memories`
- `generation_logs`
- `analytics_events`

### 保持するが今回の通常導線から外す

- `trails`
- `trail_events`
- `media`
- `guilds`
- `guild_members`
- `tags`
- `entity_tags`
- `quest_guides`
- `quest_milestones`
- `arc_emotion_events`

### 将来領域として保持

- `business_accounts`
- `subscriptions`
- `notifications`
- `journal_entries`
- `arc_letters`
- `reports`
- `user_blocks`

Migration、テーブル、RLS、既存データは削除しない。

## ダミーデータとfallback

| 場所 | 内容 | 対応 |
| --- | --- | --- |
| `quest_controller.dart` | 英語の初期Quest 3件と固定進捗 | 未認証fallbackから除去し、空状態へ変更 |
| `trail_controller.dart` | `mock-quest-arc`に紐づくTrail 2件 | 通常表示から除去。Coming Soon化後もControllerは保持 |
| Home | Quest/Trail/Guild/Horizonのpreview表示 | 中心4要素以外を非表示 |
| Guild | ローカルQuest/Mission/Trailから相談・マッチングを組み立てる | Coming Soonへ変更 |

## 進捗計算監査

現状のHome、Quest一覧、Quest詳細は主に`Quest.progress`を表示する。一方、Quest詳細では完了Mission数も別計算しており、Mission完了数と保存済み進捗がずれる可能性がある。

統一式:

```text
Quest進捗 = 完了Mission数 / 全Mission数
Missionが0件なら0%
```

必要な対応:

- 進捗計算を単一Serviceへ集約する。
- Home、Quest一覧、Quest詳細が同じ結果を参照する。
- Mission完了後にQuestの永続化された進捗も更新する。
- `完了数 / 全数`と進捗バーを同じ計算結果から表示する。

## UIルール監査

### 共通化済み

- `QuestraBottomNavigation` / `QuestraNavigationRail`
- `QuestraCard`
- Responsive ListView
- Design tokensとダークテーマ
- Arc Empty State

### 未統一

- Homeは独自カードが多く、他画面より情報密度が高い。
- GuildとTrailに独自の複雑なカード群がある。
- AppBar、画面padding、主要CTA位置が画面ごとに異なる。
- 空・読込・エラー・Coming Soonの共通Surfaceが揃っていない。
- 一部Trailダイアログに英語表示が残る。

## 未完成・重複機能

- Guild投稿、コメント、フォローは中心フロー外。
- Trail投稿、画像、Reflectionは中心フロー外。
- Star Map、Horizon、Quest DNA、Milestone、Dream Boardは通常導線では優先度が低い。
- Arc Floating EntryとArcタブが重複する。
- Quick Actionと各画面CTAが重複する。
- Quest作成フォームとArc起点作成が競合する。

## 後続QST

| 実装ID | 添付ID | 内容 |
| --- | --- | --- |
| QST-152 | QST-142 | 5画面ナビゲーション整理 |
| QST-153 | QST-143 | 共通UI統一 |
| QST-154 | QST-144 | Home簡素化 |
| QST-155 | QST-145 | ArcからQuest候補作成 |
| QST-156 | QST-146 | QuestからMission作成 |
| QST-157 | QST-147 | 進捗計算統一 |
| QST-158 | QST-148 | Guild/Trail Coming Soon化と統合レビュー |

最初の実装対象はQST-152。Routeと機能コードを削除せず、主要導線だけを`Home / Quest / Arc / Guild / Profile`へ整理する。
