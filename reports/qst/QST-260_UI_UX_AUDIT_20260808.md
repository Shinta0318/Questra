# Questra UI/UX全体監査レポート

- 監査日: 2026-08-08
- 対象: Questra Flutterアプリ
- 対象ブランチ: `codex/initial-questra-structure-pr`
- 対象コミット: `a5e0cad266e1dd8b5e9fae65414c988c4342d409`
- 監査方式: Flutter Web実操作、静的コード照合、既存QST・テスト証跡照合
- 変更方針: アプリコード、DB、設定、デザイン、アセットは変更していない

## 1. エグゼクティブサマリー

### 総合評価

**52 / 100**

Questraは、Arcのキャラクター、スプラッシュ、認証画面、Questの世界観に強い独自性がある。特にスプラッシュから認証までの第一印象は、一般的なToDoアプリとの差別化に成功している。

一方、中心導線は現時点で完遂できない。安全なローカル環境で実際に `Quest作成 -> Mission 4件確定 -> Mission詳細` まで進めたが、Taskを生成または追加する操作が存在せず、Mission達成ボタンも無効のままになった。コード上でも `TaskController.addTask` の呼び出し元は存在しない。このため、要求される `Arc -> Quest -> Mission -> Task -> Trail` のうち、MissionからTaskへ進む地点で停止する。

### 現在の完成度

- ビジュアルと世界観: Beta候補に近い
- Quest作成・Mission候補確認: 操作可能
- Mission / Task実行: 主要導線が未完成
- Trail: 機能はあるが入口とコピーが整理不足
- Guild: Coming Soonとして安全に閉じている
- Android / iOS実機、読み上げ: 未検証

### 最大の強み

Arcと宇宙・航海の世界観が、スプラッシュ、認証、オンボーディング、Quest作成まで一貫している。Arc画像は装飾ではなく、案内役として認識できる。

### 最大の問題

MissionからTaskを作れず、ユーザーが実行段階へ進めない。加えて、Quest詳細の新Missionカードと `/mission` の旧Missionカードが異なる進捗・完了ルールを持ち、同じMissionが画面によって別物に見える。

### Beta公開判断

**No-Go**

Criticalが1件あり、中心導線を完遂できない。QST-260もWeb/Android E2Eと視覚証跡が未完了であり、正式完了にはできない。

### 最優先領域

1. Task生成・追加・保存導線の完成
2. Mission進捗と完了ルールの一本化
3. `/mission` とQuest詳細の画面責務統一
4. Task依存関係を考慮した開始制御
5. MissionからArc・支援情報へ文脈付きで遷移

## 2. Git・実行環境情報

| 項目 | 結果 |
|---|---|
| Repository | `https://github.com/Shinta0318/Questra.git` |
| Branch | `codex/initial-questra-structure-pr` |
| SHA | `a5e0cad266e1dd8b5e9fae65414c988c4342d409` |
| 開始時Git状態 | clean |
| Flutter | 3.44.2 stable |
| Dart | 3.12.2 stable |
| 対象画面ファイル | 26 |
| `GoRoute` | 22 |
| 実行プラットフォーム | Flutter Web Release |
| 実行幅 | 320x568、390x844、768x1024、1280x720 |
| Android / iOS | 未確認 |
| Supabase / Gemini | `--dart-define`なし。実サービス未接続の安全なローカル経路 |
| Test account | 未使用 |

### 起動と検証

- 開発用 `flutter run -d web-server` はDDCスクリプト読込に失敗した。
- `flutter build web --release` はコマンド監視時間を超過したが、対象コミットのRelease成果物生成は完了した。
- Release成果物をローカル静的サーバーで配信し、Flutter Viewの生成と主要画面の表示・操作を確認した。
- 現行ターンの `dart analyze` は実行環境でタイムアウトしたため、今回の監査結果として成功扱いにはしていない。
- `reports/qst/QST-260.md` には `flutter analyze` 成功、376テスト成功、QST-260重点6テスト成功が記録されている。この記録はDocumentation evidenceとして扱う。

### 実行上の制約

- SupabaseとGeminiの実接続を使っていないため、AI成功、通信失敗、RLS、再ログイン後復元は未検証。
- Android / iOS実機、VoiceOver、TalkBack、ハプティクスは未検証。
- CanvasKit描画のためDOMベースのアクセシビリティツリー取得はできず、見た目・操作とコード上のSemanticsを照合した。

### 証跡

スクリーンショットは `reports/qst/evidence/QST-260-ui-audit/` に24枚保存した。

代表例:

- `01_splash_mobile.png`
- `02_home_mobile_390.png`
- `03_home_small_320.png`
- `05_arc_mobile.png`
- `11_quest_detail_mobile.png`
- `12_mission_cards_mobile.png`
- `13_mission_detail_no_tasks.png`
- `17_mission_list_legacy.png`
- `18_trail_mobile.png`
- `19_profile_mobile.png`

## 3. カテゴリ別評価

| カテゴリ | 点数 | 根拠 |
|---|---:|---|
| 初見理解 | 78 | スプラッシュと認証で「Arcと挑戦する」価値が伝わる |
| 情報設計 | 52 | Quest/Mission/Taskのラベルはあるが、進捗正本と画面責務が競合 |
| ナビゲーション | 58 | 5タブは明快だが、Missionルートがデータ状態でTask画面へ変わる |
| 視覚デザイン | 68 | 世界観は強いが、小画面クリップ、低コントラスト、英語混在が残る |
| 操作性 | 49 | 主要CTAは見えるが、Task作成不能、no-op、過密Moreメニューがある |
| Arc体験 | 65 | 相棒感は強いが、Mission相談の文脈が渡らず、Quick Actionが意図を誤解する |
| Quest管理 | 60 | 作成・詳細・Route・編集入口がある。詳細が長く、内部用語が多い |
| Mission / Task管理 | 30 | Task生成経路なし。新旧Mission UIと完了ルールが競合 |
| 継続体験 | 61 | Homeに今日のTask、Horizon、Trailがあるが、小画面では理由が読み切れない |
| 達成感 | 52 | Arc祝福やStardustがあるが、Task導線停止により実達成へ到達できない |
| アクセシビリティ | 45 | Semanticsと44px方針はあるが、低コントラストと実機読み上げ未検証 |
| レスポンシブ | 54 | 768pxは良好。390px以下でArc文・Quick Action・Homeカードが過剰に省略される |
| 実装一貫性 | 43 | Design Tokenはあるが、旧カード、英語コピー、到達不能画面が併存 |
| Beta公開品質 | 32 | Critical導線停止、実サービスE2E未確認、QST-260正式ゲート未達 |

## 4. 全画面インベントリ

| 画面 | Route | 主要ファイル | 到達・実装状態 | 主な問題 | 重大度 |
|---|---|---|---|---|---|
| Splash | `/splash` | `splash_screen.dart` | Executed | 強い第一印象。CTA後の認証分岐は実サービス未確認 | Low |
| Login | `/login` | `login_screen.dart` | Executed | 英語eyebrowが日本語UIに混在 | Low |
| Signup | `/signup` | `signup_screen.dart` | Executed | 長い縦フォーム。キーボード実機未確認 | Medium |
| Forgot password | `/forgot-password` | `forgot_password_screen.dart` | Executed | 英語eyebrow混在 | Low |
| Reset password | `/reset-password` | `reset_password_screen.dart` | Executed | 実メール遷移未確認 | Medium |
| Onboarding | `/onboarding` | `onboarding_screen.dart` | Executed（Step 1-2） | 5ステップ完遂・復元は未確認 | Medium |
| Home | `/home` | `home_screen.dart` | Executed | 320/390pxで文言省略、低コントラスト、英語混在 | High |
| Arc | `/arc` | `arc_screen.dart` | Executed | Quick Action横切れ、相談ラベルを願いとして誤処理 | High |
| Quest list | `/quest` | `quest_screen.dart` | Executed | 作成アイコンとHero CTAが重複、英語Dashboardコピー | Medium |
| Quest create | `/quest/create` | `quest_form_screen.dart` | Executed | 長いフォーム、Bottom Navと入力領域が競合しやすい | Medium |
| Quest edit | `/quest/:id/edit` | `quest_form_screen.dart` | Code-confirmed | 未保存離脱警告を確認できない | Medium |
| Quest detail | `/quest/:id` | `quest_detail_screen.dart` | Executed | 長大。低コントラストカード、新旧概念の混在 | High |
| Quest Route | `/quest/:id/route` | `quest_route_screen.dart` | Executed | `Arcと航路を見直す` がno-op | High |
| Mission list | `/mission` | `mission_screen.dart` | Executed | QST-260の新カードでなく旧カード。直接完了可能 | High |
| Mission detail | `/quest/:qid/mission/:mid` | `mission_detail_screen.dart` | Executed | Task生成・追加なし。Taskなしでは達成不能 | Critical |
| Task list | `/mission` 条件分岐 | `task_screen.dart` | Code-confirmed | Task有無で同一Routeの画面名・責務が変わる | High |
| Task detail | `/quest/:qid/mission/:mid/task/:tid` | `task_detail_screen.dart` | Code-confirmed | Task生成不能で通常導線から到達不能 | Critical連鎖 |
| Mission support | `/quest/:qid/mission/:mid/support` | `mission_support_screen.dart` | Code-confirmed | Routeはあるが現行UIから到達不能 | High |
| Trail | `/trail` | `trail_screen.dart` | Executed | CTAがbelow foldかつ重複。英語コピー多数 | High |
| Profile | `/profile` | `profile_screen.dart` | Executed | Guest、Not logged in、First Light等が未翻訳 | Medium |
| Settings | `/settings` | `settings_screen.dart` | Executed | 説明過多。英語状態ラベルが多い | Medium |
| Beta feedback | `/feedback` | `beta_feedback_screen.dart` | Executed | 未接続時はコピー運用。送信完遂未確認 | Medium |
| Guild Coming Soon | `/guild` | `questra_coming_soon_screen.dart` | Executed | 未完成を隠す判断は妥当。英語Coming Soon | Low |
| Guild community | なし | `guild_screen.dart` | 到達不能 | 実装がRouteから切り離されている | Medium |
| Guild discovery | なし | `guild_discovery_screen.dart` | 到達不能 | 公開Questライブラリをユーザーが開けない | High |
| Guild discovery detail | なし | `guild_discovery_detail_screen.dart` | 到達不能 | Discovery導線未接続 | High |
| Placeholder | なし | `placeholder_screen.dart` | 到達不能 | 本番画面として不要か用途明示が必要 | Low |

補足:

- Dream Boardは独立画面ではなくQuest詳細内セクションで、RepositoryはIn-memory実装。
- SignalはHome/Mission内にあり、通知専用Routeはない。
- 公開Quest/Missionライブラリの画面実装はあるが、Routerへ接続されていない。

## 5. 導線別評価

| 導線 | 結果 | 停止・迷い | 離脱リスク | 推奨 |
|---|---|---|---|---|
| Splash -> Login | 成功 | 1タップ。価値は明確 | Low | 現状維持、コピー言語だけ統一 |
| Signup -> Onboarding | 部分確認 | 実Supabase未接続 | Medium | 実環境E2EをRelease Gate化 |
| Onboarding -> Arc | 部分確認 | Step 2以降と再訪状態未確認 | Medium | 5 Step通しテストを追加 |
| Arc相談 -> Quest化 | Partial | Quick Actionのラベル自体が願いとして扱われる | High | Quick Actionは入力モードを開き、確認後に送信 |
| Quest作成 -> Mission候補 | 成功 | 4 Missionをローカル生成。フォームが長い | Medium | 必須情報と高度設定を分離 |
| Mission候補 -> Mission確定 | 成功 | 4枚の大型編集カードを長距離スクロール | Medium | 一覧要約 + 1件編集へ変更 |
| Mission -> Task | **失敗** | Task生成・追加操作がない | **Critical** | Task Pass、手動追加、再試行を実装 |
| Task -> 進捗 -> Mission達成 | 未到達 | Taskが存在しない | Critical連鎖 | QST-261完了後にE2E |
| Quest達成 -> Trail | 未到達 | 中心導線停止 | High | 達成後CTAを統合テスト |
| 再訪 -> 今日のTask | 表示成功 | 320pxで案内が省略、補助操作のコントラスト不足 | High | Task 1件と主CTAを最優先表示 |
| Quest編集・延期・削除 | Code-confirmed | 低頻度操作が9件Moreメニューへ集中 | Medium | 頻度別にBottom Sheetを分割 |
| 公開Quest -> 取り込み | 失敗 | Discovery画面がRouter未接続 | High | Beta対象外ならComing Soonに明示 |

## 6. 問題一覧

### UX-001: MissionからTaskを作成できず中心導線が停止する

- 対象: Mission詳細
- Route: `/quest/:questId/mission/:missionId`
- 現象: Task未作成メッセージだけが表示され、Task生成・追加・再試行の操作がない。Mission達成ボタンは無効。
- 再現: Quest作成 -> 4 Mission確定 -> 最初のMissionで `Taskを見る`
- 影響: ユーザーは行動開始、進捗更新、Mission達成、Trail記録へ進めない。
- 原因: `mission_detail_screen.dart` にTask作成CTAがない。`TaskController.addTask` のアプリ内呼び出し元もない。
- 推奨: Gemini Task Pass、手動Task追加、失敗時再試行、Task保存後のController reloadを一つの導線として実装。
- 重大度: **Critical**
- 難易度: L
- 証拠: Executed / Visual / Code-confirmed

### UX-002: `/mission` の画面責務がTask有無で変わる

- 対象: Mission一覧、Task一覧
- 現象: Taskが1件でも存在すると `MissionScreen` は `TaskScreen` を返す。
- 影響: 同じRouteがデータ状態によって別画面になり、現在地と戻り先を予測できない。
- 原因: `mission_screen.dart:47-48`
- 推奨: `/mission` と `/task` を分離するか、Quest配下のMission画面へ一本化する。
- 重大度: High
- 難易度: M
- 証拠: Code-confirmed

### UX-003: 新旧Missionカードで進捗と完了ルールが競合する

- 対象: Quest詳細、`/mission`
- 現象: Quest詳細はTask由来の新カードだが、`/mission` は旧カードのままで、手動0/25/50/75/100%更新と直接完了を提供する。
- 影響: 同じMissionの進捗正本が画面によって変わる。
- 原因: QST-260の共有`MissionCard`がQuest詳細にのみ導入された。
- 推奨: Mission表示を共有コンポーネントへ統一し、Task由来進捗を唯一の正本にする。
- 重大度: High
- 難易度: M
- 証拠: Executed / Visual / Code-confirmed

### UX-004: Mission Support画面へ到達できない

- 対象: Missionカード、Mission Support
- 現象: Routeと画面はあるが、Mission MoreメニューとMission詳細に入口がない。
- 影響: AI検索情報・企業支援候補という実装済み価値が利用できない。
- 原因: QST-260で旧カード操作を整理した際、Support入口が新メニューへ移植されていない。
- 推奨: Mission詳細に `参考情報・支援` セクションを置き、文脈付きRouteへ接続。
- 重大度: High
- 難易度: S
- 証拠: Code-confirmed

### UX-005: Missionカードから前提未完了Taskを開始できる可能性がある

- 対象: `MissionCardPresentation`
- 現象: 次Task選択はTask自身の`dependencyIds`を検証せず、readyまたは最初のopen Taskを採用する。
- 影響: 本来開始できないTaskを開始し、航路順序を壊す。
- 原因: Mission依存は確認するがTask依存の完了集合をResolverへ渡していない。
- 推奨: Task依存を含む単一Availability ServiceをCardとTask画面で共有。
- 重大度: High
- 難易度: M
- 証拠: Code-confirmed

### UX-006: Arc Quick Actionが相談開始でなく、その文言をQuest候補にする

- 対象: Arc
- 現象: `やりたいことを相談` を押すと、その文言がユーザー発言として送信され、`この航路をQuestにする` が表示される。
- 影響: 意図しないQuestを作成しそうになり、Arcへの信頼を損なう。
- 推奨: Quick Actionは入力欄へフォーカスし、質問例または入力モードを表示する。
- 重大度: High
- 難易度: S
- 証拠: Executed / Visual

### UX-007: MissionからArcへ相談してもMission文脈が表示されない

- 対象: Mission More -> Arc
- 現象: `Arcに相談` は単に `/arc` へ遷移し、対象Quest/Missionや相談starterを渡さない。
- 影響: ユーザーはMission名と悩みを再入力する必要がある。
- 原因: `quest_detail_screen.dart:3120-3128`
- 推奨: Navigation payloadまたはConversation DraftへMission contextを渡す。
- 重大度: High
- 難易度: M
- 証拠: Executed / Visual / Code-confirmed

### UX-008: Quest Routeの主要ボタンが動作しない

- 対象: Quest Route
- 現象: `Arcと航路を見直す` の`onPressed`が空。
- 影響: ユーザーは航路見直しを開始できず、未接続ボタンへの不信が生じる。
- 原因: `quest_route_screen.dart:63-66`
- 推奨: Route Replanning reviewへ接続。未完成なら無効理由またはComing Soonを明示。
- 重大度: High
- 難易度: M
- 証拠: Visual / Code-confirmed

### UX-009: 小型スマートフォンで主要コピーが読み切れない

- 対象: Home、Arc
- 現象: 320pxでArc挨拶が単語途中、390pxでHomeカード説明とQuick Actionが途中で切れる。
- 影響: 初見で価値や次の行動理由を理解できない。
- 推奨: 小画面ではコピーを短文化し、カード高さではなく内容優先のレスポンシブ構造にする。
- 重大度: High
- 難易度: M
- 証拠: Executed / Visual

### UX-010: 画面内の日本語と英語が不規則に混在する

- 対象: Home、Quest、Trail、Profile、Settings、Guild、認証
- 例: `Recent Trail`、`Low readiness`、`Quest Dashboard`、`Trails`、`Training Guide`、`Guest`、`Not logged in`、`Settings Map`、`Coming Soon`。
- 影響: 自動生成・開発途中の印象を強める。
- 推奨: 固有語以外は日本語へ統一し、用語辞書とl10n lintを導入。
- 重大度: Medium
- 難易度: M
- 証拠: Executed / Visual / Code-confirmed

### UX-011: Trail作成CTAが遅く、同じ操作が重複する

- 対象: Trail
- 現象: 初期表示では作成CTAが見えず、スクロール後に同じ`Trailを残す`ボタンが連続して現れる。
- 影響: 0件ユーザーが最初のTrailを作りにくい。
- 推奨: AppBarまたは空状態に主CTAを1つだけ固定し、説明カードを削減。
- 重大度: High
- 難易度: S
- 証拠: Executed / Visual

### UX-012: Quest詳細に低コントラスト状態がある

- 対象: Quest詳細、Home Task補助操作
- 現象: 白に近いカード上の白文字、暗背景上の低彩度青文字が読みづらい。
- 影響: 視力・明るい環境により情報を認識できない。
- 推奨: WCAG AAを基準にGolden + contrast testを追加。
- 重大度: High
- 難易度: S
- 証拠: Executed / Visual

### UX-013: Mission完了表示と成功確認がずれる

- 対象: Missionカード、Mission詳細
- 現象: 必須Taskがすべて完了するとカードは`完了`扱いになるが、Mission詳細には別途`中間成果を確認してMission達成`がある。
- 影響: Task完了とMission成果確認の違いが伝わらない。
- 推奨: `Task完了`、`成果確認待ち`、`Mission達成`を別状態として定義。
- 重大度: Medium
- 難易度: M
- 証拠: Code-confirmed

### UX-014: 任意Taskのみ・TaskなしMissionに達成経路がない

- 対象: Mission詳細
- 現象: `canConfirm`は必須Taskが1件以上かつ全完了の場合だけtrue。
- 影響: 任意TaskだけのMissionや手動Missionが永続的に完了不能になる。
- 推奨: Success evidenceの明示確認またはTask生成を必須化するDomain ruleを定義。
- 重大度: High
- 難易度: M
- 証拠: Code-confirmed

### UX-015: ArchiveにUndoがない

- 対象: Mission More
- 現象: 即時アーカイブ後、SnackBarは通知だけでUndo actionがない。
- 影響: 誤操作から復帰しづらい。
- 推奨: SnackBar Undo、または確認 + Archive一覧を提供。
- 重大度: Medium
- 難易度: S
- 証拠: Code-confirmed

### UX-016: QST-260の実機・視覚完了条件が未達

- 対象: QST-260
- 現象: Statusは`ImplementedE2EVisualProofPending`。Android/Web E2E、Before/After、読み上げが残る。
- 影響: 新カードの見た目と実操作回帰を正式に保証できない。
- 推奨: 修正後にQST-260 release gatesをQST-269で完遂。
- 重大度: High
- 難易度: M
- 証拠: Documentation

## 7. UI不統一一覧

| 領域 | 不統一 | 推奨 |
|---|---|---|
| 色 | Dark glassと白Materialカードが急に切り替わる。低コントラスト状態あり | surface roleを3種類以内に定義しcontrast gateを追加 |
| 文字 | 日本語と英語状態名が混在 | 固有語以外は日本語。l10nキーへ集約 |
| 余白 | Mission候補、Trail、Settingsが縦に長い | Summary first、詳細は展開式 |
| カード | Quest詳細新MissionCardとMission一覧旧カードが別構造 | shared MissionCardへ統一 |
| ボタン | Filled/Outlinedは概ね良いが、no-opと重複CTAがある | 画面ごとに主CTA 1つ |
| アイコン | Mission候補の上・下・削除アイコンは文脈説明が弱い | Tooltip、ラベル付きmenu、drag handleを統一 |
| Dialog/Sheet | 編集、作成、候補確認が複数方式 | Form shellと保存状態を共通化 |
| AppBar | 認証外は概ね一貫。作成アイコンとHero CTAが重複 | Add actionはArc CTAへ一本化 |
| Bottom Nav | 5項目は明快。小画面でコンテンツの下端を覆う場面あり | scroll bottom insetを共通保証 |
| 入力欄 | 外部ラベルは改善済み。長いフォームで保存まで遠い | 必須・任意を段階化 |
| 空状態 | Arcを使った空状態は良いが、説明カードが多い | 次の一歩 + 理由1行に削減 |
| Error | Mission save errorで英語prefixが混ざる | 日本語の行動可能なエラーへ統一 |
| Loading | Thinking UI実装はあるが実Gemini未確認 | 実サービスE2Eとtimeout/fallbackを検証 |

## 8. 削除・統合・再配置の提案

### 削除・非表示

- no-opの`Arcと航路を見直す`は接続まで非表示または開発中表示。
- Profileの内部状態風英語ラベルをユーザー画面から削除。
- Mission旧カードの手動進捗popupと直接完了を廃止。
- Trailの重複`Trailを残す` CTAを1つ削除。

### 統合

- Quest詳細とMission一覧のMissionCardを統合。
- Task availability判定をCard、Home、Task detailで共通化。
- Arc相談入口をContextual Conversation Draftへ統合。

### 分割

- Settingsを`体験`、`通知`、`プライバシー`、`データ`の下位画面へ分割。
- Mission候補確認は一覧要約と1件編集を分離。

### 一時的に隠す

- Guild実装画面とDiscovery画面はRouterへ出さず、現行Coming Soonを維持。
- 公開Quest取り込みをBeta対象にしない場合、存在を主要導線で示さない。

## 9. 共通コンポーネント化案

| 優先度 | 共通化対象 | 推奨コンポーネント | 対象 |
|---|---|---|---|
| P0 | Mission表示 | `MissionCard` + `MissionPresentation` | Quest detail、Mission list、Home |
| P0 | Task開始可否 | `TaskAvailabilityService` | Mission card、Task list/detail、Home |
| P0 | Task空状態 | `TaskCreationEmptyState` | Mission detail、Route review |
| P1 | 文脈付きArc遷移 | `ArcConversationDraft` | Mission、Quest、Trail、Horizon |
| P1 | 保存状態 | `PersistenceActionState` | Quest/Mission/Task/Trail forms |
| P1 | ページ下端 | `QuestraScrollableScaffold` | Bottom Nav配下全画面 |
| P1 | 画面コピー | l10n + Terminology map | 全画面 |
| P2 | 空状態 | `ArcActionEmptyState` variants | Home、Quest、Trail、Guild |
| P2 | フォーム | `QuestraLabeledField` | Auth、Quest、Mission、Trail |

## 10. 改善後の推奨導線

```text
Splash
  -> 認証 / セッション復元
  -> Arcが願いを聞く
  -> Quest候補を最大3案で確認
  -> Quest成功条件を確認
  -> Mission航路を要約表示
  -> Missionを承認
  -> 最初のMissionだけTaskを詳細生成
  -> 今日のTaskを1件表示
  -> Task実行・完了
  -> Mission成果確認
  -> Arcが次Task / 航路変更を提案
  -> Quest進捗
  -> Trailを1タップで記録
```

重要な設計原則:

- Homeでは今日のTaskを1件、次に進む理由を1行、主CTAを1つにする。
- Questは目的地、Missionは中間成果、Taskは今すぐ行う行動として、状態と動詞を分ける。
- Arc相談は必ず対象Quest/Missionを表示し、何を反映するかユーザー承認を得る。
- 長期航路の全Taskを先に作らず、直近Missionだけ詳細化する。

## 11. 実装順序

### Phase 1: 主要導線を止める問題

1. Task生成・追加・保存・reload
2. Mission / Task進捗正本の統一
3. Task依存関係とMission成果確認状態

### Phase 2: 情報設計とナビゲーション

1. `/mission` とTask routeの責務分離
2. Mission Support入口復帰
3. Mission -> Arc文脈付き遷移
4. Quest Route no-op解消

### Phase 3: デザインシステム統一

1. 新MissionCard全画面適用
2. 日本語コピー統一
3. contrast、320/390px、Bottom insetの修正

### Phase 4: Arc体験と継続体験

1. Quick Actionの会話開始化
2. Homeの今日のTask最適化
3. Trail作成入口の一本化

### Phase 5: 細部

1. Animation / haptics実機確認
2. VoiceOver / TalkBack
3. Before/After Golden、E2E動画

## 12. 修正用QST案

既存ドキュメントの最高番号はQST-260で、QST-261以降が未使用であることを確認した。

### QST-261 Task Creation and Generation Completion Path

- 背景: Mission確定後にTaskを作れず中心導線が停止する。
- 目的: AI Task Pass、手動追加、失敗時再試行をMission詳細へ統合する。
- 対象: `mission_detail_screen.dart`、`task_controller.dart`、Planning API、Repository/RPC
- 実装: Task preview、承認保存、手動追加、reload、empty/error/loading state
- Acceptance: 新規QuestからTaskを1件以上作成し、Task詳細へ進める。重複保存なし。
- Test: Widget、Repository、RPC、Web/Android E2E
- Depends: QST-258、QST-259
- 重大度: Critical
- 難易度: L

### QST-262 Mission Progress Single Source and Route Identity

- 背景: `/mission` の画面責務と進捗ルールがTask有無で変わる。
- 目的: Mission進捗をTask由来へ統一し、Routeを安定させる。
- 対象: `mission_screen.dart`、`task_screen.dart`、Router、shared MissionCard
- Acceptance: `/mission`は常にMission、Task一覧は別Route。直接Mission進捗編集を廃止。
- Test: Route matrix、progress contract、back navigation
- Depends: QST-261
- 重大度: Critical相当
- 難易度: M

### QST-263 Task Dependency and Mission Completion Integrity

- 背景: CardがTask依存を見ず、Task完了とMission達成が混同される。
- 目的: Availabilityと成果確認状態をDomain ruleとして一本化する。
- 対象: `mission_card_presentation.dart`、Task service、Mission model/detail
- Acceptance: 前提未完了Taskは開始不可。`成果確認待ち`を経てMission達成。
- Test: dependency chain、optional-only、no-task、rollback
- Depends: QST-261、QST-262
- 重大度: High
- 難易度: M

### QST-264 Mission Support and Contextual Arc Navigation Restoration

- 背景: Support画面が到達不能、Arc相談に文脈がない。
- 目的: Missionの参考情報・支援・相談を同じ文脈で利用可能にする。
- 対象: MissionCard、Mission detail、Mission support、Arc conversation draft
- Acceptance: Mission名・Quest名を保持してArc/Supportへ遷移し、戻れる。
- Test: navigation payload、deep link、back stack
- Depends: QST-262
- 重大度: High
- 難易度: M

### QST-265 Quest Route Action Completion and Dead Control Removal

- 背景: Route見直しCTAがno-op。
- 目的: Dynamic Route Reviewへ接続し、未接続操作をゼロにする。
- 対象: `quest_route_screen.dart`、Route replanning UI
- Acceptance: CTAが提案生成または明示的Coming Soonへ遷移。空handlerなし。
- Test: tap action、loading/error、approval gate
- Depends: QST-185〜188
- 重大度: High
- 難易度: M

### QST-266 Mobile Copy, Contrast, and Responsive Polish

- 背景: 320/390pxで主コピーが切れ、低コントラストがある。
- 目的: compact viewportで主要情報を読み切れるようにする。
- 対象: Home、Arc、Quest detail、Bottom Nav、Theme
- Acceptance: 320/390/430px、textScale 1.0/1.3/2.0でoverflowなし。AA contrast。
- Test: Golden matrix、semantics、contrast checklist
- Depends: QST-262
- 重大度: High
- 難易度: M

### QST-267 Japanese UI Terminology and Copy Consistency

- 背景: 内部英語と日本語が不規則に混在する。
- 目的: Questra固有語を維持しつつ、状態・説明を自然な日本語へ統一する。
- 対象: Home、Quest、Mission、Trail、Profile、Settings、Auth、Guild
- Acceptance: 許可した固有語以外の未翻訳表示ゼロ。l10n test追加。
- Test: visible-string scan、widget snapshots
- Depends: なし
- 重大度: Medium
- 難易度: M

### QST-268 Trail First Record UX and CTA Consolidation

- 背景: 0件時の作成CTAがbelow foldで重複する。
- 目的: 最初のTrailを1つの明確なCTAから作成できるようにする。
- 対象: `trail_screen.dart`、empty state、create sheet
- Acceptance: 初期viewport内にCTAが1つ。保存後にTimelineへ反映。
- Test: empty/create/success/error/keyboard
- Depends: QST-267
- 重大度: High
- 難易度: S

### QST-269 QST-260 Visual, Accessibility, and E2E Release Gate

- 背景: QST-260の正式完了ゲートが未達。
- 目的: 修正後のMission/Task導線をAndroid/Web/読み上げで証明する。
- 対象: integration tests、Golden、evidence、QST-260 report
- Acceptance: compact/medium/wide、Android実機、TalkBack/VoiceOver、Before/Afterが合格。
- Test: full core journey、back/cancel/retry/offline
- Depends: QST-261〜268
- 重大度: High
- 難易度: L

### QST-270 Master Spec Task Domain Alignment

- 背景: Master Spec v2はMissionを具体行動と定義し、QST-258/260はMissionを中間成果、Taskを具体行動と定義する。
- 目的: 最上位仕様と実装用語を一致させる。
- 対象: `docs/QUESTRA_MASTER_SPEC_V2.md`、Terminology、Domain model、Design Bible
- Acceptance: Taskを正式用語へ追加し、Quest/Mission/Task/Trailの責務と移行規則を一意化。
- Test: terminology verifier
- Depends: Product decision
- 重大度: High
- 難易度: S

## 13. 最終結論

### 1. 最も離脱しやすい5地点

1. Mission確定後、Taskを作れず停止する地点
2. Arc Quick Actionが意図しないQuest候補を出す地点
3. `/mission` で新旧ルールが変わり、進捗の意味が分からなくなる地点
4. 320/390px HomeでArcの説明が切れ、次の理由を読めない地点
5. Trail 0件時に作成CTAがすぐ見つからない地点

### 2. 最初に直すべき10項目

1. Task生成・追加CTA
2. Task保存とreload
3. Mission進捗正本の統一
4. Mission成果確認待ち状態
5. Task dependency判定
6. `/mission` Route責務固定
7. Mission Support入口
8. Mission -> Arc context引継ぎ
9. Quest Route no-op解消
10. compact viewportのクリップとコントラスト

### 3. Beta公開前に必須

- QST-261〜266
- TaskからMission達成、Trail記録までのWeb/Android E2E
- Supabase接続時の保存・再起動復元
- Gemini成功、失敗、再試行の実環境検証
- QST-260のVisual / Accessibility Gate

### 4. Beta公開後でもよい

- Settingsの完全分割
- 高度なアニメーションとハプティクス調整
- Guild Discoveryの公開
- Dream Boardの独立画面化

### 5. 現状公開した場合の最大リスク

ユーザーが期待を持ってQuestとMissionを作った直後に、Taskへ進めず行動開始できないこと。Questraの核である「Arcが達成まで伴走する」という約束を最も重要な地点で破る。

### 6. 残すべきQuestra固有UI

- Arcが大きく見えるSplashと認証Hero
- Arcの優しい短文案内
- Questを航路として扱うRoute表現
- 今日のTaskとQuestの親子関係
- Gold Accentと深い宇宙背景
- Trailを過程の記録として扱う言葉

### 7. 次に実施するQST順序

`QST-261 -> QST-262 -> QST-263 -> QST-264 -> QST-265 -> QST-266 -> QST-267 -> QST-268 -> QST-269 -> QST-270`

最初のRelease GateはQST-263完了時、正式Beta GateはQST-269完了時に置く。
