# Quest Journey Workspace

## Status

Version 1 / QST-331 through QST-337 implementation contract.

## Product intent

Quest詳細は設定値を読む画面ではなく、次の一歩を選び、航路を整え、進捗を理解する作業場所である。Primary experienceは `Focus` と `Plan` の2モードに限定する。

## Hierarchy

```text
Quest: 叶えたい成果
  Mission: Quest固有の意味ある中間成果
    Task: その成果へ進む具体行動
      Trail: 実行結果と振り返り
```

- MissionはTask件数ではなく確認可能な成果条件を持つ。
- 一度の行動で終わる内容はTaskでありMissionに昇格させない。
- Taskは必ず1つのQuestと1つのMissionへ所属する。
- Trailは可能な限りTaskへ結び、親MissionとQuestを追跡可能にする。

## Focus

- 表示件数は1件、最大3件。
- 進行中、今日または期限超過、依存関係を満たす順で選ぶ。
- deferred、skipped、blocked、cancelledと未解決依存Taskは除く。
- HomeとQuest詳細は同じ選定Serviceを利用する。
- Homeからの遷移はQuest、Mission、Task IDを保持したWorkspace deep linkとする。

## Plan

- Mission accordionの直下へ子Taskを表示する。
- 現在の未完了Missionを初期展開する。
- ユーザーは複数Missionを同時に展開できる。
- 完了Taskと完了Missionは初期状態で折りたたむ。
- Task完了、Undo、追加、詳細、並べ替え、今日から外すを航路上で実行できる。
- Arcへの相談は対象QuestとMissionを明示し、変更は承認後にのみ反映する。

## Progress contract

Quest進捗はrequiredかつactiveなoutcome Missionの重み付き完了率である。Task件数やTask細分化はQuest進捗へ直接影響しない。Mission完了はrequired Task完了に加えて成果確認を必要とする既存DB契約を維持する。

## Task state compatibility

| Domain state | Storage | Workspace behavior |
| --- | --- | --- |
| Proposed | `pending` | 依存を満たせばFocus候補 |
| Ready | `ready` | Focus候補 |
| In progress | `in_progress` | 最優先Focus候補 |
| Completed | `completed` | 折りたたみ、Undo可能 |
| Deferred | `deferred` | Focus対象外 |
| Skipped | `skipped` | 現航路では実行しない |
| Blocked | `blocked` | 理由確認が必要 |
| Cancelled | `cancelled` | 現航路から除外 |

## Task origin

`user`, `arc_suggestion`, `copied`, `enterprise_offer_accepted`, `system`, `migration`を保存する。Arc提案と企業支援は自動的にTaskへ変換しない。特に企業支援由来Taskは、承認済みproposal IDなしにDB保存できない。

## Atomicity and trust

- Supabase接続時のTask完了は`complete_task_journey` RPCを使用する。
- 所有者、親Quest/Mission、依存関係、versionを検証する。
- Task完了、進捗再計算、進捗イベント、Stardust付与を1 transactionに含める。
- operation IDとStardust ledgerで再送を冪等化する。
- 失敗時は楽観更新をrollbackし、既存offline queueから再試行できる。
- 並べ替えは同一Missionかつ同一所有者のTaskだけをtransactionで更新する。

## Enterprise boundary

企業支援はMissionの参考情報として別領域に表示する。支援を受ける、比較する、Taskへ追加する操作にはユーザーの明示承認が必要であり、Arcの中立的な航路や進捗へ広告都合で介入させない。

## Rollout

`--dart-define=QUEST_JOURNEY_WORKSPACE=false` でLegacy Mission一覧へ戻せる。Beta配布前にHosted migration、二アカウントRLS、Android/Web、320/390/768/1280px、200% text、TalkBack、日本語IME、300 Mission / 500 Taskの性能証跡をCandidate SHAへ固定する。
