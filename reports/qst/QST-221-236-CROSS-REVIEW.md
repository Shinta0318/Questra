# QST-221〜236 横断再レビュー

Status: Completed

## Review scope

- Flutter UI、domain model、Repository、Supabase migration、Edge Function、回帰テストを横断した。
- 「生成できる」だけでなく、確認、確定、保存、再読込、表示まで情報が失われないことを確認した。

## Fixed findings

1. QST-221: Supabase未接続時にカテゴリ固定Missionを生成していた経路を外し、Quest固有情報から安全な最小航路だけを作るフォールバックへ変更した。
2. QST-222: Quest UnderstandingをAI構造化出力、Flutter model、Quest保存、Quest詳細の成功条件表示まで接続した。
3. QST-223: 無効候補に依存するMissionと循環依存をEdge Functionの批評段階で除外するようにした。
4. QST-224: Missionの完了条件、成果物、確認方法が確定時に失われていたため、draft、controller、model、Repository、DB、Mission画面を接続した。
5. QST-224: Edge FunctionとDBで確認方法の許容値が不一致だったため、同じ列挙値へ統一した。
6. QST-225: 曖昧な願いに対する複数Quest案をArcの航路作成画面へ接続した。
7. QST-226: Quest説明中の文字列を暗黙の同意済みContextとして扱う処理を削除した。
8. QST-227: Quest詳細へ「今日・次・その先」の段階表示を追加し、依存Missionより後工程が先に推薦されないようにした。
9. QST-229: Homeの先頭3件表示を、依存関係、優先度、Today指定に基づく1件推薦へ変更した。
10. QST-231: 200件Corpusをローカルフォールバックへ実行し、件数、重複、Quest名流用、完了契約を検証するテストを追加した。
11. QST-226: 明示同意、計画条件、週間可用時間をSettings、端末内保存、Supabase、Arc航路生成まで接続した。
12. QST-226: Edge Functionで同意フラグと入力サイズを再検証し、未同意Contextを破棄するようにした。
13. QST-236: 今日の可用時間をHomeのMission推薦へ反映し、時間内に収まる一歩を優先するようにした。
14. QST-223: Planner/Generator出力とは別のGemini Critic/Repairを追加し、最大1回の部分修復後に決定論的Validatorを通す構造へ変更した。
15. QST-223: 品質スコア、生成版、Critic回数、修復Mission数をQuestへ保存し、内部採点理由は保存・表示しないようにした。
16. QST-222: Success Contractを版付きで編集・再確認できるUIを追加した。
17. QST-225: Geminiによる2〜5件のQuest候補、複数案の統合、生成前の自由編集を接続した。
18. QST-226: 明示同意された同伴形態、停滞理由、承認済みMission履歴の要約を計画Contextへ追加した。
19. QST-227: 長期航路を4件単位のMilestoneへ集約し、必要時だけ展開できる表示にした。
20. QST-228: 単一Mission再生成をEdge Function、差分提案、明示承認、Transaction、Rollbackへ接続した。
21. QST-230: 完了、未着手、期限超過、手動見直しから回復提案を作り、構造変更は必ず承認制にした。
22. QST-232: Mission計画Feedbackを版付きで保存し、10件未満の集団を返さない匿名集計へ接続した。
23. QST-233: 初回Quest生成後に最初のMissionを明示選択し、Quest詳細へ直接遷移する導線にした。
24. QST-235: Mission参考情報をHTTPS限定、確認日、再確認期限、公式区分付きで保存・表示するRepository/UIを追加した。
25. QST-236: 週間可用時間の変更時に未完了Missionだけ所要時間を再計算し、完了済みMissionは固定するようにした。

## Completion decision

- QST-221〜236は、実装、回帰検証、Report、Backlog、Supabase migration、Edge Function配備まで完了したため正式にCompletedとする。
- QST-231のRelease Gateは意図どおり動作し、実プローブがGemini応答ではなくローカルフォールバックになった場合は昇格を停止する。
- Gemini無料枠の回復後に200件の実評価を再実行する運用課題は残るが、評価基盤の実装漏れではない。

## Verification

- `flutter analyze --no-pub`: no issues.
- Full `flutter test --no-pub`: 349 passed.
- Focused Flutter tests: 45 passed, including regeneration, availability recalculation, Mission sources, Today preference, and the 200-case local planning contract.
- `tools/qst/quest_planning_eval_200.json`: 200 cases generated and validated.
- Migrations `202608010008` through `202608010011` were applied to the hosted Supabase project in addition to the existing schema.
- `arc-quest-guide` was redeployed successfully.
- Hosted provider probe completed in approximately 7.1 seconds and correctly recorded `local_arc_quest_guide`; therefore QST-231のRelease GateはGemini実応答確認まで昇格を停止している。
