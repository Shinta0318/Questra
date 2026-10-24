# QST-261 追加受入条件: AI失敗後の最初の行動

- ID: QST-261（新番号ではない）
- Priority: P0 / Critical
- Finding: LA-04
- Status: 既存`ImplementedDeploymentE2EPending`の追加検証提案。完了扱いに変更しない。
- 上位原則: Master Spec v2.1、Design Bible v2 First Value / Today Focus

## 背景・ユーザー問題・目的

ローカルプレビューでArc相談からQuestだけ保存した際、Mission 0件、Task 0件になる。TrailはMission選択必須で、記録まで進めない。既存QST-261の「空MissionからTaskを生成」は重要だが、「Mission自体がない」経路を明示的に受け入れる必要がある。AIが失敗しても本人が最初の実行可能な一歩を作れるようにする。

## 対象・非対象・依存

対象: Quest詳細の0 Mission状態、手動Mission→Taskの最短導線、Quest/Trail間の下書き復帰、保存結果表示。想定ファイル: `quest_detail_screen.dart`、`mission_controller.dart`、`mission_detail_screen.dart`、`task_controller.dart`、`trail_screen.dart`、関連E2E。非対象: AI品質改善、Guild、課金、TrailをMissionから切り離す仕様変更。依存: QST-261本体、QST-508保存回復、QST-524状態証拠、QST-527の文脈引継ぎ。

## UI/UX・日本語・Accessibility・データ・AI・Security

- 0 MissionのQuest詳細はdisabledな「航路を見直す」を主CTAにせず、「最初のMissionを作る」を表示する。Taskまでの操作と戻り先を明示する。
- Arc不調を「失敗したあなたのQuest」と表現しない。Questだけ保存済み、Mission未作成、再試行可能の状態を分ける。
- Trail下書きはQuest/Mission作成の往復で失わない。MissionなしではTrailを保存しない現行ドメイン制約を維持する。
- 保存済み/未保存/同期待ちを区別する。本人の明示承認なしにAI候補を永続化しない。owner越境・二重作成を拒否する。
- キーボード/TalkBackで主CTAと回復先が読め、320〜430pxと200%文字で画面外に隠れない。

## Analytics

`quest_without_mission_shown`、`manual_mission_started/completed`、`first_task_started/completed`を本文なしで計測する。分母はAI失敗後にQuestを保存したユニークowner/Quest、同じ保存操作IDで重複除外。モックとHostedを分ける。

## 受入条件・Negative Test

- 正常系: AI失敗後にQuestだけ保存→0 Missionの主CTA→手動Mission→最初のTask→開始まで到達。Trailの下書きは往復後も保つ。
- 失敗系: Mission/Task保存失敗時に保存成功を表示せず、入力を残して再試行できる。再起動後に重複せず状態が復元する。
- Negative: 0 Missionで「再計画」だけを見せる、架空のTask/Trailを生成する、別ownerへ下書きを見せる、二重tapで複製する、AI失敗を成功通知にすることを拒否。
- Responsive/Localization: 320/360/390/430px、英語/日本語、200%文字、IMEでCTAと戻り先が可読。
- 性能: 0件状態は外部AIを待たずに描画し、既存Home/Quest表示予算を悪化させない。

## 段階公開・Rollback・証拠・残余リスク

内部モック→Hosted二アカウント→物理Android/Webの順。問題時は手動作成の主CTAを安全なQuest編集導線へ戻し、保存データは消さない。完了証跡はcurrent-SHA E2E、0 Mission/AI失敗/再起動/owner switchのテスト、before/after画像、Trail下書き検証。残余リスクは外部AI停止の長期化と旧Questの欠損Mission。手動導線を常時利用可能にして軽減する。
