# QST-221〜236 横断再レビュー

Status: In Progress

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

## Remaining work

- QST-222: Success Contractの編集・再確認UI。
- QST-223: Gemini無料枠回復後のCritic成功応答と修復前後の品質差分証跡。
- QST-225: Gemini生成の選択肢、案の統合、自由編集。
- QST-226: 明示的な同伴形態、過去の停滞理由、承認済みMission履歴の反映。
- QST-236: 可用時間変更後の既存Mission所要時間再計算。
- QST-227: 長期航路をMilestoneへ集約する表示。
- QST-228: 単一Mission再生成の差分確認・承認UIとEdge Function接続。
- QST-230: 停滞検知Triggerと回復提案UIへの接続。
- QST-231: Gemini実呼出しの200件評価、品質採点、Latency/Cost記録、Release Gate。
- QST-232/235: Feedbackと情報源のRepository/UI接続および実Supabase検証。
- QST-233: 初回Quest生成後のMission previewと最初の一歩確認。

## Verification

- Focused Flutter tests: passed, including the 200-case local planning contract.
- QST-226/236 focused contract tests: 12 passed.
- Responsive Settings regression tests: 20 passed after correcting compact-width layout and Material boundaries.
- The most recent full `flutter analyze --no-pub` invocation timed out without diagnostics in this environment; an earlier full run after the main patch reported no issues.
- Migrations `202608010001` through `202608010007` were applied to the hosted Supabase project.
- `arc-quest-guide` was redeployed and its hosted fallback returned four Missions with Quest Understanding and complete Mission contracts.
- The hosted response still reports `local_arc_quest_guide`. The latest Edge log reports Gemini HTTP `429` after the API revision fix, so free-tier quota recovery is the remaining provider-side blocker.
