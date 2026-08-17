# Questra UI/UX全体監査・固定100点評価

- 監査日: 2026-08-09
- Repository: `Shinta0318/Questra`
- Branch: `codex/initial-questra-structure-pr`
- Candidate SHA: `c68abbf8d0c2e2fc585610f8cac695f7cef0132b`
- Master Spec: `docs/QUESTRA_MASTER_SPEC_V2.md` v2.1
- Evidence: `reports/qst/evidence/UI_UX_100_POINT_AUDIT_20260809/`
- 結論: **61 / 100、外部Beta No-Go、社内UX評価 Go**
- 検証信頼度: **78 / 100**

## 1. Executive Summary

QuestraはSplash、Arcの存在感、QuestからTaskまでの責務分離、穏やかな日本語、今日のTaskという中心価値をすでに持つ。一方、現在の候補は、実データと開発用fallbackの区別、認証route、Arc相談の再起動復元、320pxでの可読性、画面間surface、状態完全性、実環境証跡がBeta品質へ達していない。

最も重大な問題は見た目ではない。必須Backend設定がないとInMemoryへ静かに切り替わり、認証guardがないため、未認証でも直接routeへ到達できる。ユーザーが保存できたと誤認する可能性があり、TrustとData integrityを損なう。Criticalを残したまま外部Beta公開可とは判定しない。

### 強み

- SplashとLoginはArcとQuestraの世界観を短時間で伝える。
- Arcは「AI Assistant」ではなく伴走者として表現されている。
- Quest、Mission、Task、Trailの階層はコードと主要UIで分離された。
- Arcのclarification stateは、回答中に確定CTAを出さない。
- Homeの今日のTaskは、再訪時の価値に近い。
- 同一SHAのWeb / Android emulator E2Eと514件の自動テストがPassしている。

### 最大リスク

1. 認証を迂回でき、配布構成でも永続化なしのlocal fallbackへ入り得る。
2. Local migrationとHosted Supabase headが一致せず、candidate資料も現行SHAへ固定されていない。
3. Arc相談はページ再読み込みで消え、Quest化の途中成果を失う。
4. 320px Homeと768px Navigation Railで文字が欠ける。
5. HomeのHorizonが実データなしでも個別推薦のような固定内容を表示する。

## 2. Initial Investigation

| 項目 | 結果 | 根拠 |
| --- | --- | --- |
| Git root | `C:/Users/shint/StudioProjects/Questra` | Executed |
| Branch | `codex/initial-questra-structure-pr` | Executed |
| HEAD | `c68abbf8d0c2e2fc585610f8cac695f7cef0132b` | Executed |
| 初期Git status | clean | Executed |
| AGENTS.md | なし | Code-confirmed |
| Flutter app | `apps/mobile` | Code-confirmed |
| 起動 | `flutter build web --release --no-pub`後、localhost静的配信 | Executed |
| 実画面環境 | Flutter Web、320 / 390 / 768 / 1280px | Executed / Visual |
| Android | GitHub Actions emulator E2E Pass | Test-confirmed |
| iOS / 物理Android | 未確認 | Unverified |
| 外部接続 | Supabase / Geminiの公開設定なしでlocal fallback | Executed / Code-confirmed |
| 不足環境 | `SUPABASE_URL`、`SUPABASE_ANON_KEY`、現行Hosted migration、物理端末 | Documentation / Unverified |
| Screen / Page files | 27 | Code-confirmed |
| GoRoute | 24 | Code-confirmed |
| 通常導線から到達しない画面実装 | 4: 旧Guild 3画面、Placeholder | Code-confirmed |
| Master Spec | `docs/QUESTRA_MASTER_SPEC_V2.md` v2.0からv2.1へ本監査で改定 | Documentation |
| Design Bible | `docs/product/DESIGN_BIBLE_V2.md` | Documentation |
| Screen Bible / UI Blueprint | 正式文書なし | Documentation |
| Backlog | `docs/qst/BACKLOG.yaml`、監査前最大QST-318 | Documentation |
| QST ID重複 | なし | Code-confirmed |
| QST-260原文 | Backlogと完了レポートを正として照合 | Documentation |
| QST-260証跡 | Report、Widget test、Web / Android CI、既存画像あり | Test-confirmed / Documentation |

### 監査制約

- 実Supabase認証、保存、再ログイン復元、RLS、Gemini応答は現行SHAで実行していない。
- iOS、物理Android、TalkBack、VoiceOver、200%文字、日本語IME実機は未確認。
- 大量データ、長時間offline、メールdeep link、課金は実画面未確認。
- 未確認項目をPassまたは満点として扱っていない。

## 3. Specification and QST Alignment

| 対象 | 状態 | 判定 |
| --- | --- | --- |
| Master Spec | Quest / Mission / Task / Trail、Arc、Phase Gateは明確 | Product Experience Constitutionが不足していたためv2.1へ追加 |
| Design Bible v2 | 320 / 600 / 840、44px、1カラム、主要CTAを定義 | Screen別状態とNavigation契約は不足 |
| Screen Bible | なし | QST-326で新設 |
| UI Blueprint | なし | Screen Bibleへ統合して管理 |
| Navigation spec | `mvp-navigation.md`が古い5面を記載 | QST-197のRelease Decisionと競合。QST-321で同期 |
| Beta Supabase | local headがremote headより先行 | QST-301 / 312で未完 |
| QST-207 | Home section復帰がIn Progress | 固定Horizon表示がAcceptanceと競合 |
| QST-260 | 自動Web / Android Pass | 物理a11y、現行visual evidence待ち |
| QST-299 | ProfileからSettings / Feedbackへ到達可能 | Settings系に見える戻る操作がなく回帰扱い |
| QST-300 | Completed | 320px Homeと768px Railで回帰を確認 |
| QST-308 | Planned | Arc draft再起動復元のCritical残件 |
| QST-310 / 311 | Planned | surface分断と巨大Screenを正しく対象化 |

## 4. QST-260 Revalidation

### 目的

Questを到達状態、Missionを主要行動・成果、Taskを具体的な小さな行動として分離し、Mission Cardから次のTaskへ進めること。

### 証跡

- `reports/qst/QST-260.md`
- `apps/mobile/lib/features/mission/widgets/mission_card.dart`
- `apps/mobile/lib/features/mission/widgets/mission_card_presentation.dart`
- Mission Card Widget / Presentation tests
- GitHub Actions run `31302540674`
- `reports/qst/evidence/QST-269/mission_detail_after_390.png`

| 要件 | 判定 | 根拠 |
| --- | --- | --- |
| Quest / Mission / Taskのラベルと責務分離 | Pass | Code / Test |
| Mission Cardに完了条件と次Taskを表示 | Pass | Code / Widget test |
| Task状態からPrimary CTAを決定 | Pass | Code / Widget test |
| 補助操作をMore menuへ集約 | Pass | Code / Widget test |
| 危険操作を確認付きで分離 | Pass | Code / Test |
| Web core journey | Pass | CI / Test-confirmed |
| Android emulator core journey | Pass | CI / Test-confirmed |
| 320 / 390 / medium / wideの現行状態別visual | Partial | 既存画像はあるが現行SHA全状態ではない |
| 日本語glyph | Partial | 既存画像の一部ボタン文字が欠ける |
| TalkBack / VoiceOver / 200%文字 / 物理端末 | Unverified | 外部端末証跡なし |
| 0% / 途中 / 完了 / Undo連続操作 | Partial | 自動テストあり、物理連続操作なし |

**再判定:** `AutomatedWebAndroidPassPhysicalAccessibilityPending`。QST-260本体の情報設計は成立しているが正式完了ではない。

## 5. Fixed 100-Point Scorecard

| 評価領域 | 配点 | 得点 | 主な根拠・減点 | 100点化条件 | 関連 |
| --- | ---: | ---: | --- | --- | --- |
| 初期理解 | 7 | 5.5 | Splashは強い。Home短文省略 | 3秒でArc・現在地・次の一歩が読める | UX-006, QST-300 |
| Onboarding | 6 | 3.5 | 案内は優しいが進捗・戻る・Skip・resume不明 | 3-5 step、進捗、Skip、resume、replay | UX-012, QST-323 |
| 情報設計 | 8 | 5.0 | 階層は改善。Navigation仕様が競合 | Screen Bibleとroute契約を統一 | UX-005, QST-321/326 |
| Navigation | 7 | 4.5 | Primary navは明快。Settings系の戻るが弱い | 全routeの到達・復帰契約 | UX-009, QST-321 |
| Quest管理 | 9 | 5.5 | Formは改善。Arc / manual / templateが競合 | Arc-first入口と承認状態を一意化 | UX-008, QST-322 |
| Mission / Task | 9 | 6.0 | QST-260主要設計Pass。物理証跡不足 | 状態別E2Eと達成loop | UX-014, QST-324 |
| Arc体験 | 10 | 6.0 | clarify良好。reloadでdraft消失 | 再起動復元、回復、Quest反映 | UX-003, QST-308 |
| 今日・再訪 | 7 | 4.5 | 今日Taskは有効。Home省略と固定Horizon | real state、一意CTA、優しい再開 | UX-006/007, QST-320 |
| 進捗・達成 | 6 | 3.5 | 構造はあるが達成後loopの実証不足 | Trail / Celebration / Horizonまで完走 | UX-015, QST-324 |
| Visual | 7 | 4.5 | Splash / Arcは強い。dark-light分断 | semantic surface統一 | UX-010, QST-310 |
| 操作・Feedback | 6 | 3.5 | 主要操作あり。保存・offline契約が画面横断で不統一 | mutation state contract | UX-011, QST-325 |
| Error / Empty / Network | 5 | 2.5 | Emptyはあるが重複。実network未検証 | 全主要状態と入力保持 | UX-011/013, QST-325 |
| Accessibility | 5 | 2.5 | Semantics testあり。物理読み上げ未検証 | 200%、TalkBack、IME、focus証跡 | UX-016, QST-316 |
| Responsive | 4 | 2.0 | 1280良好。320/768回帰 | core journey overflow 0 | UX-006, QST-315 |
| 実装一貫性 | 4 | 2.0 | test豊富。巨大Screenとtoken直接値 | Screen分割、共通state/component | UX-017, QST-311/326 |
| **Total** | **100** | **61** |  |  |  |

検証信頼度78点は、主要Web画面と現行CIを確認できた一方、実Backend、物理端末、iOS、Screen readerが未確認であることを反映する。

## 6. Screen and Route Inventory

| 画面 | route | 主要ファイル | 到達 | 状態 | 実画面 | 問題 / 推奨 |
| --- | --- | --- | --- | --- | --- | --- |
| Splash | `/` | `features/splash/splash_screen.dart` | 初期 | 実装 | Visual | 強い第一印象を維持 |
| Login | `/login` | `features/auth/login_screen.dart` | Splash | 実装 | Visual | route guardと接続 |
| Signup | `/signup` | `features/auth/signup_screen.dart` | Login | 実装 | Visual | 長いFormの実機Keyboard未確認 |
| Forgot password | `/forgot-password` | `features/auth/forgot_password_screen.dart` | Login | 実装 | Visual | email deep link未確認 |
| Reset password | `/reset-password` | `features/auth/reset_password_screen.dart` | deep link | 実装 | Visual | token失敗状態未確認 |
| Onboarding | `/onboarding` | `features/onboarding/onboarding_screen.dart` | 初回 | 実装 | Visual | 進捗、戻る、Skip、resume不足 |
| Settings | `/settings` | `features/settings/settings_screen.dart` | Profile | 実装 | Visual | 見える戻る操作不足 |
| Data Rights | `/settings/data-rights` | `features/trust/data_rights_screen.dart` | Settings | 一部 | Visual | export / Task削除以外は未完、戻る不足 |
| Beta Feedback | `/feedback` | `features/feedback/beta_feedback_screen.dart` | Profile | 一部 | Visual | Clipboard fallback、戻る不足 |
| Guild Coming Soon | `/guild` | `widgets/layout/questra_coming_soon_screen.dart` | direct only | Beta除外 | Visual | 正直なComing Soon。通常navへ戻さない |
| Home | `/home` | `features/home/home_screen.dart` | Primary nav | 実装 | Visual | 320省略、固定Horizon、bottom inset |
| Quest list | `/quest` | `features/quest/quest_screen.dart` | Primary nav | 実装 | Visual | 空状態CTA重複、0件で詳細CTA |
| Quest create | `/quest/create` | `features/quest/quest_form_screen.dart` | Quest / Arc | 実装 | Visual | 入口が3系統で競合 |
| Quest detail | `/quest/:questId` | `features/quest/quest_detail_screen.dart` | Quest | 実装 | 既存証跡 | 4,469行、状態の局所実装 |
| Quest route | `/quest/:questId/route` | `features/quest/quest_route_screen.dart` | Quest detail | 実装 | 既存証跡 | hosted差分承認未検証 |
| Quest edit | `/quest/:questId/edit` | `features/quest/quest_form_screen.dart` | Quest detail | 実装 | Code | 作成と編集の状態差を明示 |
| Mission detail | `/quest/:questId/mission/:missionId` | `features/mission/mission_detail_screen.dart` | Quest detail | 実装 | 既存証跡 | QST-260 physical gate待ち |
| Task detail | `/quest/:questId/mission/:missionId/task/:taskId` | `features/task/task_detail_screen.dart` | Mission detail | 実装 | 既存証跡 | 達成loop物理証跡待ち |
| Mission support | `/quest/:questId/mission/:missionId/support` | `features/mission/mission_support_screen.dart` | Mission detail | 実装 | Code | Grounding / sponsor識別を実環境検証 |
| Mission list | `/mission` | `features/mission/mission_screen.dart` | 内部branch | 実装 | Visual | light surface、説明過多 |
| Task list | `/task` | `features/task/task_screen.dart` | 内部branch | 実装 | Visual | hierarchyは良好、surface差 |
| Arc | `/arc` | `features/arc/arc_screen.dart` | Primary nav | 実装 | Executed | reloadでdraft消失、320 quick action欠け |
| Trail | `/trail` | `features/trail/trail_screen.dart` | Primary nav | 実装 | Visual | metric折返し、light surface |
| Profile | `/profile` | `features/profile/profile_screen.dart` | Primary nav | 実装 | Visual | Settings / Feedback到達は改善済み |

### Routeを持たない、または通常導線から到達しない実装

| 実装 | 判定 | 対応 |
| --- | --- | --- |
| 旧Guild screen | Beta対象外 | historical実装として隔離、通常routeへ接続しない |
| Guild discovery | Future | Guild Release Decisionまで非表示 |
| Guild discovery detail | Future | 同上 |
| Placeholder screen | 開発補助 | Production routeへ接続しない |
| Dream Board | MVP routeなし | Future扱い。今回の100点必須QSTへ入れない |
| 課金 | MVP routeなし | Premium readinessのみ。Beta UX監査対象外 |

## 7. Core Journey Evaluation

| 導線 | 判定 | 停止 / 迷い | 状態復元 | 推奨 |
| --- | --- | --- | --- | --- |
| 初回起動 → 認証 → Onboarding → Arc | Partial | direct routeで認証を迂回可能 | 実Backend未検証 | QST-319/323 |
| Wish → clarification → Quest提案 | Partial | clarifyは自然 | reloadで全消失 | QST-308 |
| Quest提案 → 修正 → 承認 → 保存 | Unverified | local fallbackのみ | 実保存未証明 | QST-312/319 |
| Quest → Mission生成 → 承認 | Partial | UI / testあり | hosted AI未確認 | QST-312 |
| Mission → Task → 進捗 → Mission完了 | Partial | QST-260設計Pass | 物理端末未確認 | QST-260/324 |
| 再訪 → 今日のTask | Partial | Taskは分かるがcopy省略 | local状態のみ | QST-300/320 |
| Quest達成 → Trail | Partial | route / codeあり | E2E完走不足 | QST-324 |
| Quest延期 → 再開 | Code-confirmed | gentle restartの画面横断証跡不足 | 未確認 | QST-324 |
| Quest / Mission / Task削除 | Test-confirmed | confirmationあり | hosted/RLS未確認 | QST-312 |
| 公開Quest → 取り込み | Beta対象外 | Guild deferred | 対象外 | 将来Guild Release Decision |
| Arc再相談 → Route変更 | Partial | proposal基盤あり | hosted承認・rollback未確認 | QST-312 |
| 通信失敗 → retry | Partial | 機能別実装 | 統一契約なし | QST-325 |
| logout → login → data restore | Unverified | 実Backendなし | 未確認 | QST-312/319 |
| 複数Quest → 優先行動 | Code-confirmed | Home priorityの実データ未確認 | 未確認 | QST-320 |
| 達成 → Horizon | Fail | 固定fallbackが個別提案に見える | 実履歴で未検証 | QST-320/324 |

## 8. Quest, Mission and Task Audit

- 親子関係: QST-260以降の階層ラベル、breadcrumb、Task進捗は良好。
- 次の行動: HomeのToday TaskとMission Card CTAは方向性が正しい。ただし320pxではArc guidanceが省略される。
- CTA: Quest空状態、Quest作成入口、Home補助面で競合が残る。
- 進捗: Task由来Mission進捗は成立。一般難易度と個人ペースの実画面分離は未確認。
- 編集: Quest Formは1カラム化済み。作成・編集・Arc提案・templateの役割が同一画面で競合する。
- 危険操作: Mission削除等はMore menuと確認へ分離済み。account deletionは未完。
- 達成: Mission完了条件は強化済み。TrailとHorizonへ続く感情的・操作的loopの証跡が不足する。

## 9. Arc Experience Audit

- 役割理解: Splash、Home Hero、Arc画面から星のナビゲーターとして理解できる。
- 相談開始: 入力欄とquick actionsは見つけやすい。320pxではquick actionsが欠け、横スクロールが伝わりにくい。
- 会話からQuest化: 日本語入力とEnter送信を実行。曖昧なWishでは適切に質問し、確定CTAは出ない。
- 継続性: route移動中は保持するが、reloadで会話、回答、Quest draftが消える。
- 信頼: 表現は優しい。実Backend失敗とlocal fallbackの差をユーザーが判断できない。
- 中立性: user-facingでAI Assistant表現なし。企業支援との識別はMission supportの実環境証跡が必要。

## 10. Findings

| ID | 重大度 | 対象 | 現象 / 影響 | 原因 | 根拠 | 対応 |
| --- | --- | --- | --- | --- | --- | --- |
| UX-001 | Critical | 全protected route | 未認証でdirect URLへ到達可能 | Router redirectなし | Code | QST-319 |
| UX-002 | Critical | Persistence全体 | 必須設定なしでInMemoryへ静かにfallbackし保存誤認 | production fail-closedなし | Code / Executed | QST-319 |
| UX-003 | Critical | Arc `/arc` | reloadで相談、回答、Quest draft消失 | draft foundation未接続 | Executed / Visual | QST-308 |
| UX-004 | Critical | Hosted candidate | local / remote migration不一致、現行SHA証跡なし | external execution未完 | Documentation | QST-301/312 |
| UX-005 | High | Navigation | active navと古いarchitecture specが競合 | Release Decision未同期 | Documentation | QST-321 |
| UX-006 | High | Home / Rail | 320pxでArc copy省略、768pxでProfile label欠け | compact layout回帰 | Visual | QST-300再開 / 315 |
| UX-007 | High | Home Horizon | 実履歴なしでも`Low readiness`等を個別提案風に表示 | hardcoded fallback | Visual / Code | QST-207拡張 / 320 |
| UX-008 | High | Quest create | Arc相談、manual、templateのPrimary入口が競合 | entry hierarchy未確定 | Visual | QST-322 |
| UX-009 | High | Settings / Feedback / Data Rights | 見える戻る操作がない | top-level shell契約不足 | Visual / Code | QST-299再開 / 321 |
| UX-010 | High | Mission / Task / Trail / Onboarding | darkからplain lightへ分断 | semantic surface移行未完 | Visual | QST-310 |
| UX-011 | High | Mutation全体 | saving / offline / retry / duplicate防止が画面横断で不統一 | 共通state contractなし | Code / Unverified | QST-325 |
| UX-012 | High | Onboarding | 進捗、戻る、Skip、resumeが初見で不明 | linear control不足 | Visual | QST-323 |
| UX-013 | Medium | Quest / Mission empty | Arc説明とCTAが重複し、次の一手より文章が強い | empty component不統一 | Visual | QST-320/326 |
| UX-014 | Medium | Mission / Task | QST-260物理a11yと現行状態別visual未完 | external evidence待ち | Test / Unverified | QST-260/316 |
| UX-015 | High | Completion loop | Mission完了からTrail、Horizonまで一続きで未証明 | feature別テスト中心 | Code / Unverified | QST-324 |
| UX-016 | High | Accessibility | glyph欠け、TalkBack / 200% / physical IME未証明 | deterministic font / device gate未完 | Visual / Unverified | QST-304/316 |
| UX-017 | Medium | Core screens | Quest detail 4,469行、Arc 2,850行、Home 1,606行 | presentationとstate責務集中 | Code | QST-311 |
| UX-018 | Medium | UI system | 色、余白、radiusの直接指定が残る | Screen Bibleとcomponent state不足 | Code | QST-208/326 |
| UX-019 | High | Feedback | clipboard/manual投稿のみで受付状態を追えない | persistence未接続 | Visual / Code | QST-313 |
| UX-020 | High | Data Rights | correction、consent withdrawal、account deletionが完了していない | UI / worker / reauth未完 | Visual / Code | QST-309/317 |

## 11. UI Consistency

| 領域 | 現状 | 方針 |
| --- | --- | --- |
| Color / Surface | dark cosmicとplain lightが混在 | semantic surfaceをQST-310で統一 |
| Typography | displayは良好、compact copyが省略 | role別max linesとlarge-text matrix |
| Spacing | Home / Arcは良好、emptyで余白過多 | Screen state componentで統一 |
| Card | Arc / Quest / Missionで表現が別 | domain cardは責務を維持しsurface stateのみ共通化 |
| Button / CTA | 一部画面で複数Primary | 1画面1主要CTA |
| AppBar / Back | Settings系に戻るaffordance不足 | Navigation contract |
| Bottom nav / Rail | mobile insetとmedium label回帰 | width別navigation golden |
| Input | Quest Form改善済み、Arc entryと競合 | assisted / manual role分離 |
| Empty / Error | emptyあり、error/offlineの実証不足 | state matrixをScreen Bibleへ |
| Arc表示 | 世界観は強い、compactで説明欠け | shorter contextual message / expandable detail |
| Animation / Haptics |基盤あり、物理体験未証明 | QST-316以降でdevice evidence |

## 12. Remove, Integrate, Relocate

- 旧Guild 3画面はBeta Primary Navigationへ戻さず、将来機能として隔離する。
- 固定Horizon内容は削除し、real / empty / unavailableを表示する。
- Quest空状態の複数作成CTAは1つへ統合する。
- Quest createのcategory templateはArc-first flowと同じ初期面に並べず、独立libraryまたはsecondary pathへ移す。
- Mission / Task / Trailのlight shellはQST-310で共通Journey surfaceへ統合する。
- Dream Board、課金、公開Quest libraryは今回のBeta 100点必須範囲に入れない。

## 13. Shared Component Candidates

- `QuestraJourneyScaffold`: surface、safe inset、responsive nav、back contract。
- `JourneyStateView`: Loading / Empty / Error / Offline / Retry / Permission denied。
- `PrimaryJourneyAction`: 1つのPrimary CTAと補助actionの優先制御。
- `HierarchyBreadcrumb`: Quest / Mission / Task / Trail文脈。
- `ArcContextMessage`: compact / expanded、由来、感情、accessibility label。
- `PersistenceStatus`: saving / saved / failed / queued / retry。
- `ScreenEvidenceHarness`: 320 / 390 / 768 / 1280 / 200% matrix。

## 14. Ideal Journey

1. SplashでArcとQuestraの価値を理解する。
2. 認証と短いOnboardingを完了し、ArcへWishを話す。
3. Arcは必要な場合だけ1-3問を聞き、Quest案と前提を示す。
4. ユーザーの承認後にQuestをTransaction保存する。
5. Success ContractからMission、Taskを段階生成し、承認前previewを示す。
6. Homeは親文脈付きの今日の最小Taskを1つ示す。
7. 完了、延期、offlineを優しく処理し、入力と進捗を復元する。
8. Mission達成を確認し、Trailへ記録してArcが祝う。
9. 実履歴とQuest DNAに基づくHorizonを示す。根拠がなければ空状態にする。

## 15. 100-Point Gap Matrix

| Gap | 現在 | 100点条件 | 分類 | 対応 |
| --- | ---: | --- | --- | --- |
| GAP-01 Auth / persistence truth | 2/8 | route guard、fail-closed、実保存 | New-QST | QST-319 |
| GAP-02 Hosted candidate | 2/7 | migration / RLS / Gemini / artifact同一SHA | Existing-Covered | QST-301/312 |
| GAP-03 Arc continuity | 3/7 | restart restore / discard / owner isolation | Existing-Covered | QST-308/314 |
| GAP-04 Home truth and focus | 4/8 | real state、一意CTA、320可読 | Existing-Partial | QST-207/300/320 |
| GAP-05 Navigation contract | 4/7 | spec同期、戻る、rail | Existing-Partial | QST-299/321 |
| GAP-06 Quest entry | 4/7 | Arc-first、manual secondary | New-QST | QST-322 |
| GAP-07 Onboarding | 3/6 | progress / Back / Skip / resume | New-QST | QST-323 |
| GAP-08 Completion loop | 3/7 | TaskからTrail / Horizonまで完走 | New-QST | QST-324 |
| GAP-09 Mutation recovery | 3/6 | 全mutationの状態契約 | New-QST | QST-325 |
| GAP-10 Journey surfaces | 4/6 | 一貫したsemantic surface | Existing-Covered | QST-310 |
| GAP-11 Screen architecture | 2/4 | Screen Bibleと分割 | Existing-Partial / Spec | QST-311/326 |
| GAP-12 Accessibility / responsive | 3/7 | physical TalkBack、200%、IME、overflow 0 | Existing-Covered | QST-304/315/316 |
| GAP-13 Trust operations | 2/5 | Feedback / Data Rights / legal | Existing-Covered | QST-309/313/317 |
| GAP-14 Final evidence | 1/5 | Critical 0、90+、current SHA | New-QST | QST-327 |

## 16. Existing QST Evaluation

| QST | 分類 | 変更 |
| --- | --- | --- |
| QST-123 | Existing-Partial / Regression | mockを実データに見せない原則をQST-320へ継承 |
| QST-132 | Existing-Partial | replay stateは有効。Onboarding controlはQST-323 |
| QST-155 | Existing-Partial / Regression | Arc-led entryをQST-322で再統合 |
| QST-197 | Existing-Covered | current Beta navの正本。QST-321で下位仕様同期 |
| QST-207 | Existing-Partial | fixed Horizon禁止とstate matrixを追加 |
| QST-208 | Existing-Partial | Design Bibleは維持。Screen BibleをQST-326へ分離 |
| QST-260 | Test-Only remaining | automated Pass、physical a11y pending |
| QST-269 / 274 | Test-Only remaining | emulator Pass、physical evidence pending |
| QST-294 / 295 | Existing-Covered | Formとlegacy suffix removalは維持 |
| QST-297 | Existing-Covered | clarification exclusivityを実画面Pass |
| QST-298 | Existing-Partial | foundationのみ。QST-308で接続 |
| QST-299 | Existing-Partial / Reopened | reachability Pass、return affordance Fail |
| QST-300 | Existing-Partial / Reopened | 320 / 768 regression |
| QST-301 / 312 | Unverified | hosted execution待ち |
| QST-302 / 305 | Existing-Partial | review済み、implementationを310 / 311へ |
| QST-303 | Existing-Covered | typed quick actionを維持 |
| QST-304 / 315 / 316 | Test-Only | physical accessibility evidence待ち |
| QST-306 / 309 / 317 | Existing-Partial | data rights / legal operation未完 |
| QST-308 / 310 / 311 / 313 / 314 | Existing-Covered planned | そのまま実施 |
| QST-318 | Existing-Covered review | QST-308-317のreview boundaryとして維持 |

廃止QSTは0件。競合する古い`mvp-navigation.md`は削除せず、QST-321でRelease Decisionへ同期する。

## 17. Roadmap to 100

| Phase | 目的 | QST | 完了条件 | 見込み点 |
| --- | --- | --- | --- | ---: |
| 0 | 証跡基盤 | 301, 312, 319 | current SHA、auth、hosted実証 | 66 |
| 1 | Critical / data flow | 308, 309, 319 | data loss、route bypass、権利処理を閉じる | 72 |
| 2 | 情報設計 | 320, 322, 324 | 今日の一歩と達成loop | 79 |
| 3 | Home / Nav / Arc | 321, 323 | 一意CTA、戻る、Onboarding | 84 |
| 4 | 状態と信頼性 | 313, 314, 325 | 保存 / offline / feedback | 88 |
| 5 | Design System | 310, 311, 326 | surface、screen責務、分割 | 92 |
| 6 | 継続・達成 | 320, 324 | Trail / Horizon / gentle restart | 95 |
| 7 | A11y / responsive | 315, 316 | 320、200%、TalkBack、IME | 98 |
| 8 | 最終品質 | 317, 327 | Critical 0、実ユーザー評価、全証跡 | 100判定 |

点数はQSTの完了申告ではなく、同一candidate SHAの実画面と実環境証跡で再採点する。

## 18. Final Assessment

### 離脱しやすい5地点

1. direct URLでHomeへ入り、認証・保存状態が理解できない。
2. Arcへ相談した後にreloadし、途中内容が消える。
3. Quest作成でArc、manual、templateのどれを選ぶか迷う。
4. 320px HomeでArc説明と次sectionが欠ける。
5. Mission完了後、Trailと次の挑戦へ進む一意なloopが分からない。

### 最初に直す10項目

1. QST-319 authenticated release entry。
2. QST-301 / 312 hosted candidate evidence。
3. QST-308 Arc draft integration。
4. QST-320 truthful Home / Horizon。
5. QST-321 Navigation / return contract。
6. QST-322 Arc-first Quest entry。
7. QST-300 / 315 compact regression。
8. QST-323 Onboarding controls。
9. QST-325 mutation recovery contract。
10. QST-324 achievement loop closure。

### Beta公開前必須

QST-308、309、312、313、315、316、317、319、320、321、322、323、324、325。QST-310 / 311 / 326は90点到達の重要項目だが、Criticalを閉じた限定Betaでは段階導入できる。

### Beta公開後でもよい

高度なmotion polish、Guild discovery、Dream Board、Premium、公開Quest library、大規模Creator機能。

### QST集計

- 新規QST: 9件、QST-319からQST-327。
- 更新または再開する既存QST: 7件（207、260、269、274、299、300、312）。
- そのまま利用する主要既存QST: 10件（301、308-311、313-317）。
- 統合・廃止候補QST: 0件。古いNavigation文書は同期対象。

### β公開可否

**外部Beta: No-Go。** Critical 4件があり、実Backendとphysical accessibilityが未証明である。**社内local UI評価: Go。** local fallbackであることを評価者へ明示する必要がある。

### 100点判定に必要な未確認事項

- 現行migrationとFunctionsを使う実Supabase / Gemini。
- 二アカウントRLS、logout / login復元、email deep link。
- 物理Android、iOS、TalkBack、VoiceOver、日本語IME、200%文字。
- 長文、大量データ、offline、rate limit、permission denied。
- 実ユーザーによる初回理解、Quest作成完了率、今日Task再開率。

### Questra固有の強みとして残すもの

- Arcを中心とする温かい相談体験。
- QuestからMission、Task、Trailへつながる人生の旅の構造。
- 未達を責めないDynamic Routeと優しい再開。
- 成果だけでなく過程を資産にするTrail。
- 企業支援よりArcの中立性を優先するTrust原則。

## 19. Evidence Index

主要画像:

- [Splash 390](evidence/UI_UX_100_POINT_AUDIT_20260809/01_splash_390.png)
- [Home 320](evidence/UI_UX_100_POINT_AUDIT_20260809/02_home_320.png)
- [Home 768](evidence/UI_UX_100_POINT_AUDIT_20260809/04_home_768.png)
- [Arc 320](evidence/UI_UX_100_POINT_AUDIT_20260809/06_arc_320.png)
- [Arc clarification](evidence/UI_UX_100_POINT_AUDIT_20260809/07_arc_clarification_390.png)
- [Arc after reload](evidence/UI_UX_100_POINT_AUDIT_20260809/08_arc_after_reload_390.png)
- [Quest create](evidence/UI_UX_100_POINT_AUDIT_20260809/09_quest_create_390.png)
- [Onboarding](evidence/UI_UX_100_POINT_AUDIT_20260809/18_onboarding_390.png)
- [Feedback](evidence/UI_UX_100_POINT_AUDIT_20260809/19_feedback_390.png)
- [Data Rights](evidence/UI_UX_100_POINT_AUDIT_20260809/20_data_rights_390.png)

全22枚はEvidence directoryを参照する。

## 20. Change Scope

本監査で変更したのはMaster Spec、Decision Record、Backlog、QST-260再検証記録、監査・Traceability文書、監査画像だけである。Flutter source、test、Supabase、migration、Edge Function、設定、assetは変更していない。commit、push、PRも実施していない。
