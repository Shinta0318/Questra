# Questra UI/UX全体監査

実画面操作・全画面・全導線・QST-260再検証版  
監査日: 2026-08-09

## 1. エグゼクティブサマリー

### Findings first

1. **High: Arcの質問とQuest確定CTAが同時に現れ、対話の順序が競合する。** 「シンガポールに行きたい」への返答で「いつ頃までに叶えたい？」と聞きながら、同時に「この航路をQuestにする」を表示した。ユーザーは質問へ答えるべきか、確定すべきか判断できない。
2. **High: Arcの会話が画面移動後に復元されない。** ArcからQuest確認シートを開いた後、別routeへ移動してArcへ戻ると、会話本文とQuest提案カードが消え、Emotion Timelineだけが残った。相談途中の離脱に弱い。
3. **High: 設定とBetaフィードバックが通常導線から到達不能。** `/settings` と `/feedback` はrouteとして存在するが、Profile、Navigation Rail、Bottom Navigationからリンクされていない。チュートリアル再表示、プライバシー確認、体験設定、フィードバックが事実上使えない。
4. **High: ダークUIとライトUIが機能単位で分断されている。** Home、Arc、Quest一覧はダーク、Mission、Task、Trail、Onboarding、Questフォームは白基調で、同一航路の連続画面に見えない。
5. **High: スマートフォン空状態で文章が省略され、Bottom Navigationが本文へ重なる。** 390px証跡ではHomeのArcメッセージ、今日のTask、Quest、Trailが複数箇所で `...` になり、Horizonカードの下部がNavigationに隠れる。
6. **High: βの中心導線を実Supabase/Geminiと実機で完走した証跡が不足する。** 今回のWeb起動は設定なしのlocal fallbackで、認証、永続化、再ログイン復元、Gemini、通信障害、Android実機、スクリーンリーダーは未検証。
7. **Medium: 空状態が説明カードの重複になっている。** Quest、Mission、TrailでArc画像、説明吹き出し、空状態文、CTAが重複し、最初の一手より説明量と余白が勝つ。
8. **Medium: Arcクイック操作は意図コマンドではなく表示文言をそのままユーザー発話として送信する。** 「Questを作る」「計画を見直す」がチャット履歴へ入り、ローカル推論では意図を構造化できない。
9. **Medium: QST-260のMission Card本体は改善済みだが、実画面のデータ状態証跡が不足する。** Task由来進捗、状態別CTA、前提、成果確認、MoreメニューはコードとWidget testでPass。Android/Webで0%、途中、100%、Undoを連続操作した証跡は未完了。
10. **Medium: 主要画面が巨大化し、UI規則が局所実装されている。** `quest_detail_screen.dart` 4,452行、`arc_screen.dart` 2,731行、`home_screen.dart` 1,579行で、表示状態と導線の回帰リスクが高い。

### 総合評価

**57 / 100**

- 現在の完成度: 機能豊富な内部Beta候補。主要概念とArcの世界観は成立しているが、導線・状態保持・モバイル密度・実環境証跡が未完成。
- 最大の強み: Splash、Arc画像、Quest -> Mission -> Taskのドメイン分離、Task由来のMission進捗、穏やかな日本語。
- 最大の問題: 「相談から今日の一歩まで」を一度も迷わず完走できる単一導線が、実環境で証明されていない。
- β公開可能性: **限定された社内UX評価はGo。外部Beta配布はNo-Go。**
- 最優先領域: Arc相談状態機械、相談の永続化、Settings到達性、スマホ密度、実Supabase/Gemini E2E。

## 2. Git・実行環境情報

| 項目 | 結果 |
|---|---|
| Repository | `Shinta0318/Questra` / `C:\Users\shint\StudioProjects\Questra` |
| Branch | `codex/initial-questra-structure-pr` |
| HEAD | `a5e0cad266e1dd8b5e9fae65414c988c4342d409` |
| Git status | 203 entries: tracked changes 126、untracked 77。ユーザー作業として保護 |
| 起動 | `flutter run -d web-server --web-hostname 127.0.0.1 --web-port 5272 --no-pub` |
| 静的解析 | `flutter analyze --no-pub`: No issues found |
| テスト | `flutter test --no-pub`: 490 tests passed |
| 実画面 | Flutter Web 1280x720、local fallback |
| 新規画面証跡 | `reports/qst/evidence/QST-296-ui-audit/` に16枚 |
| 補助証跡 | 既存390x844/320/768 screenshots、390x844 golden、responsive Widget tests |
| ビルド証跡 | Android debug APK build成功は同一作業ツリーの直前検証で確認 |
| 未確認 | Android実機操作、iOS、横画面実操作、VoiceOver、TalkBack、文字拡大実操作 |
| 外部接続 | 今回は `SUPABASE_URL` / `SUPABASE_ANON_KEY` を付与せず、Gemini Edge Functionも未実行 |
| 画面抽出 | 27 screen/page/view files。実質25画面 + layout helper 2 |
| route抽出 | 23 `GoRoute` |
| QST-260原文 | 単独の会話原文は未収録。`BACKLOG.yaml` と `reports/qst/QST-260.md` を正とした |
| QST-260 commit | `git log --all --grep=QST-260` では専用commitを特定できず。現行dirty treeで検証 |

監査中にアプリコード、データ、設定、デザインは変更していない。本ファイルだけが監査成果物である。

## 3. QST-260再検証

### 目的と対象

Questを最終目的、Missionを確認可能な中間成果、Taskを具体行動として視覚・操作の両面で分離し、Mission Cardから次のTaskへ進める状態を作る。

主要ファイル:

- `apps/mobile/lib/features/mission/widgets/mission_card.dart`
- `apps/mobile/lib/features/mission/widgets/mission_card_presentation.dart`
- `apps/mobile/lib/features/mission/mission_screen.dart`
- `apps/mobile/lib/features/mission/mission_detail_screen.dart`
- `apps/mobile/lib/features/quest/quest_detail_screen.dart`
- `apps/mobile/lib/features/task/task_screen.dart`
- `apps/mobile/lib/features/task/task_detail_screen.dart`
- `apps/mobile/test/features/mission/widgets/mission_card_test.dart`
- `apps/mobile/test/features/mission/widgets/mission_card_presentation_test.dart`
- `apps/mobile/test/qst_269_visual_evidence_test.dart`

### 受け入れ条件判定

| 要件 | 判定 | 根拠 |
|---|---|---|
| Quest/Missionで共通Mission Cardを使う | Pass | `MissionCard` をQuest詳細とMission一覧から利用 |
| Mission進捗をTaskから算出 | Pass | `MissionCardPresentation.resolve` と7状態テスト |
| Task未作成は0% | Pass | test `Task未作成のMission進捗は0から始まる` |
| 次のTaskを1件だけ表示 | Pass | `_NextTask` と `nextTask` |
| 残りTaskを展開可能 | Pass | `残りのTaskを見る` |
| 未着手/進行中/成果確認/完了/前提待ちでCTA変更 | Pass | presentation switchとWidget tests |
| Mission/Task依存関係を反映 | Pass | `TaskAvailabilityService`、`completedMissionIds` |
| その他操作をMoreへ集約 | Pass | Arc、Support、編集、再生成、期限、順番、任意、Archive、削除 |
| confidenceを直接表示しない | Pass | Widget testで `確度` が存在しないことを確認 |
| Mission Supportへ到達 | Pass | Moreメニューと詳細画面の両方からrouteあり |
| ArcへMission context付きで相談 | Pass | `arcForMission(questId, missionId, prompt, returnTo)` |
| Task生成と手動追加 | Pass | `TaskGenerationService`、承認Dialog、`addTasks`、手動Dialog |
| Mission完了はTask 100%だけでなく成果確認を要求 | Pass | `successConfirmedAt` と `reviewOutcome` |
| 44px、Tooltip、Semantics | Partial | コード上は確認。VoiceOver/TalkBack実機は未確認 |
| Web/Androidで0%→途中→100%を実操作 | Unverified | データ変更禁止と実Supabase未接続のため未実施 |
| Before/After screenshot | Partial | 390px goldenと過去監査画像あり。Android実機証跡なし |
| Analyze/Test | Pass | 0 issues、490 tests passed |

### 残課題・回帰

- QST-260のCard内部ロジックは合格水準。ただしMission/Taskの周辺画面はライトテーマで、Home/Arc/Questから視覚的に分断される。
- 390px goldenはFont fallbackの四角化があり、実際の日本語可読性の証跡として弱い。
- 実データのTask 0件、1件、複数件、任意のみ、前提待ち、完了確認、Undoを一続きで操作した録画がない。
- QST-260の正式完了表現は `ImplementedE2EVisualProofPending` のままが妥当。

## 4. カテゴリ別100点評価

| 評価軸 | 点 | 根拠 |
|---|---:|---|
| 初見理解 | 74 | SplashでArc・Quest・Mission・Trailを提示。独自用語は初見負荷あり |
| 情報設計 | 56 | ドメイン階層は改善したが、空状態と設定導線が散在 |
| ナビゲーション | 58 | 5 destinationは安定。Settings/Feedbackは到達不能 |
| 視覚デザイン | 61 | Arcと宇宙表現は強い。ダーク/ライト分断と白カード過多 |
| 操作性 | 58 | Enter送信と主要CTAは良い。Arcの質問と確定CTAが競合 |
| Arc体験 | 64 | 世界観と相談導線は強い。会話消失とQuick Actionの不自然さ |
| Quest管理 | 67 | 1カラムフォーム、期限、AI分析役割は明確。入口が二重 |
| Mission・Task管理 | 72 | QST-260の状態設計は強い。実機E2E証跡不足 |
| 継続体験 | 46 | Homeに今日のTaskはあるが、再訪データ復元を未証明 |
| 進捗実感 | 58 | Task由来進捗あり。空データでは価値を体感できない |
| 達成感 | 43 | Celebration実装はあるが実画面完走を確認できない |
| アクセシビリティ | 55 | Semantics/44px/IME testsあり。低contrastと実機読上げ未確認 |
| レスポンシブ | 51 | matrix testsはPass。390px証跡で省略・Bottom Nav重なり |
| 実装一貫性 | 50 | shared widgetは増えたが主要3画面が1,500〜4,452行 |
| エラー・空状態 | 47 | fallbackとvalidationはある。空状態が冗長、通信復元は未実証 |
| β公開品質 | 54 | Local UX評価は可能。Cloud、実機、主要E2E、Feedbackが不足 |

## 5. 全画面インベントリ

| 画面 | route | ファイル | 到達/実装 | 実画面 | 主問題 | 対応 |
|---|---|---|---|---|---|---|
| Splash | `/splash` | `splash_screen.dart` | 起動 | Yes | 価値は明確、独自用語密度 | 維持し補足を短縮 |
| Login | `/login` | `login_screen.dart` | Splash | Yes | local環境では認証完走不可 | 実Supabase E2E |
| Signup | `/signup` | `signup_screen.dart` | Login | Yes | 長いフォームのスマホ確認不足 | 390px実機証跡 |
| Forgot Password | `/forgot-password` | `forgot_password_screen.dart` | Login | Yes | メール送信実環境未確認 | Auth E2E |
| Reset Password | `/reset-password` | `reset_password_screen.dart` | deep link | Yes | token deep link未確認 | Auth E2E |
| Onboarding | `/onboarding` | `onboarding_screen.dart` | 初回認証後 | Yes | Back/Skip/step表示なし、ライト分断 | flow controls追加 |
| Home | `/home` | `home_screen.dart` | Primary nav | Yes | mobile省略、空状態説明過多 | compact再設計 |
| Arc | `/arc` | `arc_screen.dart` | Primary nav | Yes | 質問/確定競合、会話消失 | state machine/persistence |
| Quest list | `/quest` | `quest_screen.dart` | Primary nav | Yes | 空状態CTA重複、0件で詳細CTA | empty state統合 |
| Quest create | `/quest/create` | `quest_form_screen.dart` | AppBar + /Quest | Yes | Arc-firstとtemplate/manual入口が競合 | 入口役割整理 |
| Quest detail | `/quest/:id` | `quest_detail_screen.dart` | Quest card | Prior/golden | 4,452行、情報密度、実データ未検証 | feature分割 |
| Quest route | `/quest/:id/route` | `quest_route_screen.dart` | Quest detail | Prior | 差分/Undoの実操作不足 | E2E証跡 |
| Quest edit | `/quest/:id/edit` | `quest_form_screen.dart` | Quest detail | Code | 保存/延期/削除連続操作未確認 | E2E |
| Mission list | `/mission` | `mission_screen.dart` | Quest branch icon | Yes | 空カード二重、ライト分断 | empty state統合 |
| Mission detail | `/quest/:q/mission/:m` | `mission_detail_screen.dart` | Mission card | Golden/code | QST-260 logic良好、実機証跡不足 | QST-260 proof |
| Mission Support | `/quest/:q/mission/:m/support` | `mission_support_screen.dart` | More/detail | Prior/code | Grounding/Offer実接続未確認 | server E2E |
| Task list | `/task` | `task_screen.dart` | Mission AppBar | Yes | Primary nav外、ライト分断 | Mission内サブview化検討 |
| Task detail | `/quest/:q/mission/:m/task/:t` | `task_detail_screen.dart` | Task card | Code/golden | 実完了→Trail未確認 | E2E |
| Trail | `/trail` | `trail_screen.dart` | Primary nav | Yes | metrics改行、巨大空状態 | compact empty state |
| Profile | `/profile` | `profile_screen.dart` | Primary nav | Yes | Settingsへの導線なし | settings action追加 |
| Settings | `/settings` | `settings_screen.dart` | routeのみ | Yes/direct | 通常導線から到達不能、情報過多 | Profileへ統合入口 |
| Beta Feedback | `/feedback` | `beta_feedback_screen.dart` | Settingsのみ | Yes/direct | Settingsが到達不能、送信は準備中 | 実送信+常設入口 |
| Guild Coming Soon | `/guild` | `questra_coming_soon_screen.dart` | direct only | Yes | Beta延期は明記済み | 現状維持 |
| Guild legacy | none | `guild_screen.dart` | Unreachable | No | router未接続の旧実装 | 保持場所明示/隔離 |
| Guild Discovery | none | `guild_discovery_screen.dart` | Unreachable | No | router未接続 | Beta対象外維持 |
| Guild Discovery detail | none | `guild_discovery_detail_screen.dart` | Unreachable | No | router未接続 | Beta対象外維持 |
| Placeholder | none | `placeholder_screen.dart` | Unreachable | No | Settings linkを持つが未使用 | 削除候補 |

`questra_responsive_list_view.dart` は抽出対象名に該当するが画面ではなくlayout helper。

## 6. 主要導線評価

| 導線 | 結果 | タップ/操作 | 停止・迷い | 離脱リスク | 推奨 |
|---|---|---:|---|---|---|
| 初回起動→認証→Onboarding→Arc | Partial | 約7〜10 + 入力 | 実認証不可、Onboardingに戻る/Skipなし | High | Supabase実環境E2E、step/back/skip |
| 願い→Quest提案→確認 | Partial | 入力+Enter+2〜3 | Arcの質問前に確定CTAが出る | High | clarification state machine |
| Quest→Mission生成→保存 | Unverified | 推定3〜5 | データ変更禁止、Gemini未接続 | Critical gate | seed付きE2E |
| Mission→Task 0%→途中→100% | Code/Test Pass | 推定2/Task | 実画面連続証跡なし | Medium | QST-260 state matrix E2E |
| 再訪→今日のTask→再開 | Partial | 1〜2 | Homeはあるが永続化復元未確認 | High | restart/relogin test |
| Quest達成→Trail | Code only | 推定2〜4 | 達成演出と保存を未操作 | High | completion journey E2E |
| Quest編集・延期・削除 | Code only | 推定3〜5 | Undo/rollback実画面未確認 | Medium | destructive action E2E |
| 公開Quest→取り込み | Fail/Beta out | 不可 | Guild Discoveryはrouteなし | Low for initial Beta | 対象外表示維持 |
| 通信失敗→再試行→復元 | Unverified | 不明 | local fallbackは動くが通信復元未実証 | High | fault injection test |
| Logout→Login→復元 | Unverified | 約4 + 入力 | Supabase未接続 | Critical gate | 2-account persistence E2E |

## 7. Quest・Mission・Task重点監査

- **親子関係:** Mission Cardの親Mission表示、TaskのQuest/Mission参照、詳細routeは改善済み。Task一覧単独画面は親文脈が弱く、Mission内のサブviewとして見せる方が自然。
- **次の行動:** HomeとMission Cardは状態別CTAを持つ。空状態では説明とCTAが複数あり、3秒以内の判断を妨げる。
- **情報密度:** Quest詳細は機能を抱えすぎる。概要、航路、Mission、AI評価、DNA、route updateをprogressive disclosureへ分けるべき。
- **CTA:** Mission Cardは一意。Arcでは相談継続とQuest確定が競合。Quest空状態では同義CTAが重複。
- **進捗:** Task由来は正しい。Quest一覧の0件dashboardで「Quest詳細へ」が残る点は不自然。
- **完了:** Task完了とMission成果確認を分けた設計は良い。Quest達成からTrail、Celebration、Horizonへの実画面接続は未証明。
- **編集・削除:** Moreメニューへ危険操作を退避した点は良い。Undo、二重保存防止、再起動後rollbackは実環境確認が必要。
- **再訪:** Homeの「今日のTask」はNorth Starに合う。永続化と空状態の圧縮が揃えば強い再訪理由になる。

## 8. Arc体験監査

- **役割:** SplashとHome Heroで星の航海士として明確。単なるAI assistant表現は見つからない。
- **相談開始:** 入力欄、Enter送信、日本語IME、Thinking UIは良好。実画面でも日本語入力成功。
- **会話品質:** local fallbackは文脈を参照するが、質問とQuest提案の生成タイミングが同期していない。
- **Quest化:** 編集可能な確認sheet、1カラム長文、希望年月、AI評価の読み取り専用分離は良い。
- **Mission化:** Geminiなしではlocal planning。Missionと直近Task候補の保存コードは存在するが、今回の実API証跡なし。
- **信頼:** safety、同意済みMemory制限、企業Offerとの区別方針はコード/仕様にある。実画面でスポンサー表示を確認できない。
- **感情価値:** Arc画像は固有性が高い。一方で空状態の同じArc画像と吹き出し反復は装飾化している。
- **再訪理由:** Emotion Timelineはあるが、会話本文がroute移動で消えるため「覚えている」感覚を損なう。

## 9. 問題一覧

| ID | 画面/ファイル | 現象・再現 | 影響/原因 | 推奨修正 | 重大度 | 難度 | 根拠 | SS |
|---|---|---|---|---|---|---|---|---|
| UXA-001 | Arc / `arc_screen.dart:475-493`, `arc_chat_service.dart:119-135` | 旅行願望送信で質問とQuest CTAが同時表示 | 回答順序不明。messageとsuggestionを独立表示 | clarification完了までsuggestion CTAを抑止 | High | L | Confirmed | Yes |
| UXA-002 | Arc / `arc_screen.dart` | 別route後に会話・提案が消える | 相談を中断すると復帰不能。Stateがscreen-local | draft conversation provider/session store | High | L | Confirmed | Yes |
| UXA-003 | Profile/Settings / `profile_screen.dart:55-150`, router | ProfileにSettings actionなし | tutorial/privacy/experience設定不能 | Profile AppBarへ設定icon、戻り先保証 | High | S | Confirmed | Yes |
| UXA-004 | Feedback / `settings_screen.dart`, `beta_feedback_screen.dart` | routeはあるが通常導線なし、送信窓口は準備中 | Beta学習ループが閉じない | Profile/Helpから到達、送信Repository実装 | High | M | Confirmed | Yes |
| UXA-005 | Home/Quest/Mission/Task/Trail | darkとlight surfaceが連続画面で切替 | ブランド一貫性と位置感覚低下 | semantic surface tokenと画面shell統一 | High | L | Visual | Yes |
| UXA-006 | Home compact / evidence `02_home_mobile_390.png` | 主要文が複数 `...`、navがHorizonへ重なる | 次の一歩を読めない | copy短縮、maxLines再定義、bottom inset | High | M | Visual | Yes |
| UXA-007 | Arc quick actions / `arc_screen.dart:225-233,950-958` | 表示labelをそのまま `_send` | 意図と発話が混在、履歴が不自然 | typed intent actionとuser-visible messageを分離 | Medium | M | Code | No |
| UXA-008 | Quest empty / `quest_screen.dart:330-369` | 0件でもdashboard詳細CTA、同義CTA重複 | no-op/迷い | empty stateを1 CTAに統合 | Medium | S | Confirmed | Yes |
| UXA-009 | Mission empty / `mission_screen.dart` | 大きな白カードが二段 | 説明過多、scroll増 | 1 compact empty state + Quest CTA | Medium | S | Visual | Yes |
| UXA-010 | Trail / `trail_screen.dart` | `Questとの紐づき` が不自然に改行、巨大空状態 | 数値理解を阻害 | metric幅/labelを短縮、card統合 | Medium | S | Visual | Yes |
| UXA-011 | Onboarding / `onboarding_screen.dart` | Back/Skip/step indicatorなし | 初回拘束感、誤入力復帰不可 | 3-step indicator、Back、Skip/後で | Medium | M | Confirmed | Yes |
| UXA-012 | Quest create / `quest_form_screen.dart` | Arc-first、manual form、category templateの3入口 | どれが正式航路か曖昧 | Arc-firstをprimary、manualをsecondary、templateはlibraryへ | Medium | M | Confirmed | Yes |
| UXA-013 | Core files | 4,452/2,731/1,579行のscreen | 回帰、golden差分、責務分離困難 | feature sections/controllersへ分割 | Medium | XL | Code | No |
| UXA-014 | Mission Card visual evidence | 390 goldenで日本語glyphが四角 | screenshot証拠として判読不能 | test font登録、日本語golden再生成 | Medium | S | Visual | Yes |
| UXA-015 | Copy | `MISSION`, `TASK`, `Arc Bond`, `Low readiness` 等 | 日本語画面の語調が不統一 | 用語辞書/l10nへ集約 | Low | S | Code/Visual | Yes |
| UXA-016 | Accessibility | 44px/Semantics testsあり、実機読上げなし | 合格根拠不足 | TalkBack/VoiceOver matrixをRelease Gateへ | High | M | Unverified | No |
| UXA-017 | External services | local fallback起動 | Gemini/永続化品質を誤認し得る | visible environment badgeはdev only、candidate E2E | Critical gate | L | Confirmed | No |
| UXA-018 | Guild legacy | 3 screensがrouter未接続 | dead codeと完成状況誤認 | deferred moduleとして隔離しREADME明記 | Low | S | Code | No |

## 10. UI不統一一覧

| 要素 | 現在の差分 | 影響 | 統一案 |
|---|---|---|---|
| Surface | dark cosmicとlight greyが機能単位で分断 | 全主要導線 | `journey`, `form`, `focus` semantic surfaceを定義 |
| Card | dark glass、white elevated、outlinedが混在 | Home〜Trail | Card用途をsummary/action/formに限定 |
| CTA | gold filledは一貫するが同義CTA重複 | Quest/Mission empty | 画面ごとにprimary 1個 |
| AppBar | shell内、単独画面、戻るなしが混在 | Settings/Onboarding | route種別別AppBar policy |
| Input | Auth dark、Quest white、Arc bottom fixed | 認証/相談/form | shared label-helper-field-counter states |
| Empty state | Arc画像+吹き出し+説明+CTAの反復 | Quest/Mission/Task/Trail | `QuestraEmptyState`をcompact/immersive 2種に限定 |
| Progress | dashboard、bar、chips、metrics | Quest/Mission/Trail | outcome/task progress semanticsを明示 |
| Copy | 日本語と英語termの混在 | 全画面 | 固有語以外は日本語、l10n key化 |
| Feedback | Snackbar/Dialog/inline errorが混在 | save/generate/delete | mutation state componentを共通化 |
| Arc | hero、tiny icon、empty decorationが混在 | 全画面 | hero/guide/avatar/navの4 size role |

## 11. 削除・統合・再配置案

- 削除: 0件dashboardの「Quest詳細へ」、重複する空状態CTA、未使用`PlaceholderScreen`。
- 統合: Mission一覧とTask一覧をQuest配下の「航路」内タブへ統合検討。
- 分割: Quest DetailをOverview、Route、Mission、IntelligenceへWidget分割。ArcをConversation、Proposal、Memory、Composerへ分割。
- 再配置: SettingsをProfile AppBarへ、FeedbackをSettingsとProfile footerへ、Task listをMission header actionから明示。
- 一時非表示: 未接続Guild実装、公開Quest/Mission library、Dream Board、通知はBetaでrouteを公開しない。
- 開発中表示: Guildは現行Coming Soonを維持。Feedbackは「準備中」ではなく機能提供まで隠すか実送信を完成する。
- β対象外: Guild Discovery、公開Quest取り込み、Dream Board、企業Offerの購入導線。

## 12. 共通コンポーネント化案

| 対象 | 重複 | 推奨component | 影響 | 優先 |
|---|---|---|---|---|
| 空状態 | Quest/Mission/Task/Trail | `QuestraEmptyStateV2` | 4画面 | P0 |
| 画面surface | dark/light分岐 | `QuestraJourneyScaffold` | 全主要画面 | P0 |
| 状態CTA | Home/Mission/Task | `JourneyNextAction` | 3画面 | P0 |
| Form field | Auth/Quest/Task dialogs | `QuestraFormField` variants | 7画面 | P1 |
| Arc proposal | Chat/Quest create/Route update | `ArcProposalCard<T>` | 3機能 | P1 |
| mutation feedback | controllersごと | `QuestraMutationBanner` | 保存系全般 | P1 |
| metric | Quest/Trail/Profile | `JourneyMetric` | 3画面 | P2 |
| section header | 各巨大screen | `JourneySectionHeader` | 全画面 | P2 |

## 13. 改善後の推奨導線

```text
Splash
  -> Sign up / Login
  -> 3-step onboarding (Back / Skip / progress)
  -> Arc: wish input
  -> Arc clarification (必要な質問だけ、1つずつ)
  -> Quest preview (目的・成功条件・希望期限)
  -> User approval
  -> Mission plan preview
  -> User approval + transactional save
  -> Quest detail / Route
  -> Today's Task
  -> Task completion
  -> Mission outcome confirmation
  -> Quest progress / completion
  -> Trail prompt
  -> Celebration
  -> Horizon next Quest
```

常に画面上部に `Quest > Mission > Task` の短いbreadcrumbを置き、最下部のprimary CTAは1つにする。Arcの質問中はQuest確定CTAを出さず、ユーザーが「この内容でまとめる」を選んだ時だけpreviewへ進める。

## 14. 実装ロードマップ

1. **Phase 1:** 実Supabase/Gemini seed E2E、Arc clarification state、会話draft保持、Settings到達性。
2. **Phase 2:** QST-260の実機state matrix、Quest/Mission/Task breadcrumb、空状態1 CTA化。
3. **Phase 3:** Arc-first/manual/templateの入口整理、Task listの配置、戻る/キャンセル方針。
4. **Phase 4:** dark/light semantic surface統一、空状態/Form/CTA共通化、日本語copy整理。
5. **Phase 5:** 再訪Home、完了→Trail→Celebration→Horizon、会話履歴とMemoryの見せ方。
6. **Phase 6:** TalkBack/VoiceOver、text scale、横画面、motion reduction、haptics、golden polish。

## 15. 修正用QST案

既存BacklogにQST-296以降は見つからなかった。以下を候補とする。

### QST-296 Core Journey Seeded E2E Release Gate
- 背景/問題: 実Supabase/Geminiで主要航路の完走証跡がない。
- 目的: 認証からTrail/再ログイン復元までをAndroid/Webで自動・録画検証。
- 対象: integration tests、Edge Functions、seed、RLS。
- 実装: 専用2 account seed、fault injection、artifact保存。
- Acceptance: 10主要導線Pass、二重保存0、RLS越境0、動画/スクリーンショット。
- Test: Android/Web E2E、offline/retry、relogin。
- Depends: QST-260、Supabase candidate。Severity Critical、Difficulty XL。

### QST-297 Settings and Feedback Reachability
- 背景/問題: Settings/Feedbackが通常導線から到達不能。
- 目的: Profileから設定、feedback、戻り先を一貫させる。
- 対象: profile、settings、feedback、router。
- Acceptance: 2 tap以内、戻る正常、tutorial再表示、feedback送信または非表示。
- Test: router/widget/semantics。Depends: none。High、S-M。

### QST-298 Arc Clarification State Machine
- 背景/問題: 質問とQuest CTAが競合。
- 目的: understand -> clarify -> summarize -> approveを明示状態化。
- 対象: Arc service/screen、Quest suggestion contract。
- Acceptance: 未回答質問中に確定CTAなし、最大3問、明確な意図はskip。
- Test: travel/learning/habit/ambiguous corpus。Depends: planning pipeline。High、L。

### QST-299 Arc Conversation Draft Persistence
- 背景/問題: route移動で相談が消える。
- 目的: 未確定相談、回答、提案をsession内復元。
- 対象: Arc state/provider/repository/router。
- Acceptance: Quest form往復、reload、error後も入力とproposal復元。明示破棄可能。
- Test: navigation/restart/offline。Depends: QST-298。High、L。

### QST-300 Mobile Density and Safe-Area Pass
- 背景/問題: 390pxで省略とnav重なり。
- 目的: 320/360/390/430pxで次の一歩を全文理解可能にする。
- 対象: Home、Arc、Quest、Mission、Trail、bottom nav。
- Acceptance: primary copy省略0、content overlap 0、44px、golden。
- Test: viewport/textScale 1.0/1.3/2.0。Depends: none。High、M。

### QST-301 Unified Journey Surface and Empty States
- 背景/問題: dark/light分断と説明カード重複。
- 目的: semantic surfaceとcompact empty stateを共通化。
- 対象: Theme、Scaffold、Quest/Mission/Task/Trail/Onboarding。
- Acceptance: 1 empty state/画面、1 primary CTA、token外色を削減。
- Test: golden/theme contract。Depends: QST-300。High、L。

### QST-302 Quest Entry Strategy Consolidation
- 背景/問題: Arc-first/manual/template入口が競合。
- 目的: Arc-firstをprimary、manualをfallback、templateをLibraryへ分離。
- 対象: Quest list/form、Arc、template library。
- Acceptance: suffix変換なし、単一明確intentは候補なし、manual path維持。
- Test: intent/copy/navigation。Depends: QST-298。Medium、M。

### QST-303 Arc Quick Action Intent Contract
- 背景/問題: chip labelを生の発話として送信。
- 目的: `actionId`, `displayLabel`, `prompt`, `navigation` を分離。
- 対象: Arc response schema、screen、analytics。
- Acceptance: Quick Actionが不自然なuser bubbleを作らず、適切な処理へ接続。
- Test: 5 default actions、Gemini/local parity。Depends: QST-298。Medium、M。

### QST-304 Onboarding Control and Progress
- 背景/問題: Back/Skip/step表示なし。
- 目的: 心理的負担を抑えた3-step onboarding。
- 対象: onboarding、profile settings、tour controller。
- Acceptance: Back/Skip/再表示、progress、IME、state保存。
- Test: first/second launch、guest/auth。Depends: QST-297。Medium、M。

### QST-305 QST-260 Physical Accessibility Proof
- 背景/問題: Mission Cardの実機・読上げ証跡不足。
- 目的: 0/途中/100/blocked/optional/no-taskを実機で検証。
- 対象: Mission/Task screens、golden font、test evidence。
- Acceptance: Android/Web screenshots、TalkBack結果、日本語golden、Undo。
- Test: state matrix。Depends: QST-296。High、M。

### QST-306 Completion to Trail and Horizon Loop
- 背景/問題: 達成感と次Quest接続が未証明。
- 目的: Mission outcome -> Quest complete -> Trail -> Celebration -> Horizonを一導線化。
- 対象: Task/Mission/Quest/Trail/Home。
- Acceptance: 二重完了なし、Trail context保持、次の提案、戻る正常。
- Test: completion E2E。Depends: QST-296、QST-305。High、L。

### QST-307 Feature Screen Decomposition and Token Enforcement
- 背景/問題: 巨大screenと局所style。
- 目的: Quest Detail、Arc、Homeをfeature widget/controllerへ分割。
- 対象: 3 screen、Theme、lint/tests。
- Acceptance: behavior不変、主要section単体test、token外値を監査可能。
- Test: golden/regression/analyze。Depends: QST-301。Medium、XL。

## 16. 最終結論

### 1. 最も離脱しやすい5地点

1. Arcが質問中なのにQuest確定CTAを出す地点。
2. 相談sheetから離れ、Arcへ戻ると会話が消える地点。
3. 認証・Gemini・永続化がlocal fallbackと実環境で異なる地点。
4. スマホHomeで重要文が省略され、次の一歩を読めない地点。
5. Mission完了後からTrail/次Questまでの実証されていない地点。

### 2. 最初に直すべき10項目

QST-296、298、299、297、300、305、301、303、304、306の順。

### 3. β公開前に必須

実Supabase/Gemini E2E、二アカウントRLS、Arc相談復元、clarification整合、Settings到達、compact overlap 0、QST-260実機matrix、Feedback実送信または明確な代替窓口。

### 4. β公開後でもよい

Guild Discovery、公開Quest/Mission Library、Dream Board、企業Offer、全画面animation polish、screen完全分割。

### 5. 現状公開の最大リスク

ユーザーはArcに大切な願いを話した直後、質問と確定のどちらを選ぶか迷い、画面移動で相談を失う。Questra固有の信頼価値を最初の数分で損なう。

### 6. 残すべき強み

Arcの正式画像、穏やかな航海表現、今日のTask、Task由来進捗、Mission成果確認、Quest/Mission/Task/Trailの意味分離、企業支援よりArc中立性を優先する姿勢。

### 7. 削除・統合

重複空状態CTA、0件時Quest詳細CTA、未使用Placeholderを削除候補とし、Mission/Task一覧を航路サブviewへ統合検討する。

### 8. QST-260で解決済み

Mission Card共通化、Task由来進捗、状態別CTA、次Task、Task展開、依存関係、Moreメニュー、confidence非表示、Support/Arc context、成果確認。

### 9. QST-260で未解決・回帰

Android/Web実データE2E、VoiceOver/TalkBack、日本語golden、全状態Before/After、周辺画面のdark/light統一、compact密度。

### 10. 次QST推奨順

`QST-296 -> 298 -> 299 -> 297 -> 300 -> 305 -> 301 -> 303 -> 304 -> 306 -> 302 -> 307`

### 11. 修正後の回帰テスト

初回/再訪、Arc質問状態、route往復、Quest/Mission/Task state matrix、完了/Undo、Trail、offline/retry、2-account RLS、320〜840px、textScale 2.0、TalkBack/VoiceOver、日本語IME、golden。

### 12. β公開可否

**外部Beta: No-Go。限定社内UX評価: Go。** 主要機能の存在ではなく、実Supabase/Gemini環境で「相談からTrail、再ログイン復元」まで壊れず完走した証拠を公開条件とする。
