# Questra UI/UX Review Protocol V5

## 目的

Questraの画面を「きれいか」だけでなく、利用者が迷わず次の一歩を選び、Arcとの旅を信頼して続けられるかで評価する。実画面、コード、テスト、未確認事項を分け、推測を実証として扱わない。

## 5回の自己レビュー

### Review 1: Visual Quality

初稿は色、余白、カード、角丸、文字、画像、整列を中心にした。しかし見た目だけでは、Quest作成や再開の迷い、架空データによる不信を検出できないため不十分と判定した。

### Review 2: Journey and Action

主要導線、タップ数、Primary CTA、戻り先、入力保持を追加した。操作性は測れるが、一般的なタスク管理アプリとの差とArcの役割を評価できないため改訂した。

### Review 3: Questra Identity

Master Spec、QuestからTrailまでの階層、Arcの伴走、静かな継続、80%明快さ・15%感情・5%世界観を追加した。プロダクトらしさは測れるが、Loading、Empty、Error、Offlineの誠実さと外部接続状態が不足していた。

### Review 4: Trust and Inclusion

実データとDemoの識別、AI提案と確定情報の差、Accessibility、Responsive、日本語IME、200%文字を追加した。監査としては十分だが、修正順と回帰防止が曖昧だった。

### Review 5: Evidence and Execution

証拠区分、重大度、共通原因、最小変更、受入条件、Negative Test、Rollbackまで追加した。これを正式版とする。

## Final Review Prompt

あなたはQuestraのSenior Product Designer、UX Researcher、Flutter Accessibility Engineerである。Master SpecのDesign North Star「迷いを減らし、次の一歩を自然に選べること」を最上位基準として、実装済みUI/UXを監査する。

1. 実画面、コード、テスト、推測、未確認を明確に分ける。
2. 各画面を3秒で現在地、状態、次の行動、Primary CTAが分かるか評価する。
3. Primary CTAは原則1つとし、説明、補助操作、危険操作との視覚優先度を確認する。
4. Arcが装飾ではなく、願いの言語化、判断、再開、振り返りを助けているか確認する。
5. Quest、Mission、Task、Trailの責務と親子関係が言葉と配置で理解できるか確認する。
6. Initial、Loading、Empty、Content、Saving、Success、Error、Offline、Retry、Permission deniedを確認する。
7. 実データ、Demo、AI提案、ユーザー入力、企業支援、確定情報を誤認させないか確認する。
8. 320、390、430、768、1280px、200%文字、日本語IME、キーボード、44px tap target、Semantics、focus順を確認する。
9. 巨大カード、過剰な角丸、意味のない余白、説明過多、英語混在、内部用語、0件統計、重複CTA、テンプレート感を検出する。
10. 80%明快さ、15%感情・達成感、5%宇宙・航海表現の比率を守る。
11. 問題を共通原因と画面固有原因に分け、Critical、High、Medium、Lowで順位付けする。
12. 改善は既存Design Tokenと共通Widgetを優先し、UIからDomain、DB、AIの境界を不必要に変更しない。
13. 各改善に正常系、失敗系、Negative Test、Responsive、Accessibility、Rollback、証跡を定義する。
14. 未確認の実機、Hosted Backend、外部AIをPASSと書かない。

出力は、総合点、証拠と信頼度、主要導線、画面別所見、共通問題、優先改善、実装対象、検証結果、未確認事項の順とする。
