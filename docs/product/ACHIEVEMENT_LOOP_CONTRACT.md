# Achievement Loop Contract

## Purpose

Task完了を一覧から項目が消えるだけの操作にしない。Arcが前進そのものを祝い、利用者が
成果をTrailへ残すか、次のTaskまたはMission成果確認へ進める状態を一つのモーメントで示す。

## Flow

```text
Task完了
  -> Remote保存成功
  -> Arcが前進を祝う
  -> Trailへ記録（利用者が選択）
  -> 同じMissionの次Task
     または Mission成果確認
     または Quest航路確認
```

## Rules

- 保存成功前に祝福や次画面を表示しない。
- Trailを自動生成しない。本文は利用者が確認・編集して保存する。
- Trail作成にはQuest、Mission、Taskの親情報を渡す。
- 同じMission内の依存関係を満たすTaskを、別Missionより先に提示する。
- 必須Taskが全て完了した場合は、Task追加ではなくMission成果確認を優先する。
- MissionはTask完了だけで自動完了しない。成果条件の明示確認を維持する。
- 完了取り消しを同じモーメントから実行できる。
- 200%文字拡大では縦スクロールを許可し、CTAを画面外へ失わない。

## Surfaces

- Task一覧: 完了保存後に共通モーメントを表示する。
- Task詳細: 完了後も共通カードを表示し、再訪時にTrailと次の一歩へ進める。
- Quest Journey Workspace: checkbox完了後に共通モーメントを表示する。
- Home: 既存のToday Task完了状態からTrail CTAを維持する。

## Evidence Boundary

Widget Testは選択規則、親付きTrail route、文字拡大時の到達性を証明する。触覚、音、
物理端末の読み上げ順、Remote応答遅延中の体感は物理Android証跡で別途確認する。
