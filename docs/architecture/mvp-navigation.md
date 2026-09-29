# MVP Navigation

QuestraのBeta Navigationは、Arcと共にQuestを進め、その一歩をTrailへ残す
journey loopを迷わず往復できることを優先する。

## Primary Navigation

Primary NavigationはBottom NavigationとNavigation Railで同じ順序を使う。

1. Home
2. Quest
3. Arc
4. Trail
5. Profile

Arcは中央に置く。MissionとTaskは独立したPrimary tabではなく、Quest配下の
文脈画面として扱う。Guildはcontrolled pilotであり、BetaのPrimary Navigationには
含めない。

## Journey Hierarchy

- Home: 今日の次の一歩と現在地を確認する。
- Quest: Questの作成、航路、Mission、Taskを管理する。
- Arc: 願いの言語化、Quest化、航路の相談を行う。
- Trail: QuestとMissionに紐づく旅の記録を残し、振り返る。
- Profile: 本人情報、成長、設定への入口をまとめる。
- Mission: Questを実現する中間成果としてQuest branch内に置く。
- Task: Missionを進める実行単位としてQuest branch内に置く。
- Guild: 公開範囲と安全性を検証中のDiscovery pilotとしてHome等から開く。

## Return Contract

詳細画面は、同じ操作から開いた場合はnavigation stackを戻る。URL直入力、
deep link、refresh後などstackがない場合は、安全な親画面へ戻す。

| Destination | Empty-stack fallback |
| --- | --- |
| Settings | Profile |
| Settings section | Settings |
| Data Rights | Settings |
| Arc Memory | Settings |
| Beta Feedback | Profile |
| Guild pilot | Home |

戻る操作は共通Widgetで提供し、tooltipと44px以上のtap targetを維持する。
存在しないrouteはRoute Recoveryを表示し、HomeまたはQuestへの明示操作を出す。

## Route Policy

- Quest DetailがQuest -> Mission -> Task -> Trailの深いjourney loopを所有する。
- Trailは一時的な投稿ではなく、QuestとMissionへ紐づく旅の記録である。
- ProfileからSettingsへ進み、Settings配下で権利・同意・Arc Memoryを管理する。
- direct routeでもユーザーを行き止まりにしない。
- route復帰で別ユーザーのdraftや選択entityを引き継がない。
- Storyという旧名称を使用しない。
- Arcをユーザー向けにAI assistantと表現しない。

## MVP Scope Check

この構造はcore journey loopを常時表示しながら、Guild、企業支援、Marketplace等を
準備未完了のままPrimary Navigationへ混在させない。Guild pilotの範囲は
`docs/product/guild_prototype_plan.md`で管理する。
