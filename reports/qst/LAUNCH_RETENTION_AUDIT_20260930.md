# Questra ローンチ・定着品質監査（2026-09-30）

> 使用モデル: Codex（実行環境から正確なモデルIDは取得できず、未確認）
> 対象: `codex/initial-questra-structure-pr` / `a9d83bcb551e6c974b9c3fdf8a9d1a51a401c61c`
> 監査日時: 2026-09-30 06:48 JSTを含む実査
> 判定: **公開不可（External Beta NO-GO）**。実装量ではなく、同一SHAの外部証跡と最初の行動の成立で判断する。

## 1. Executive Summary と検証範囲

Arcに願いを話す→本人確認→Questだけ保存、という入口は実際に動いた。AIが利用できないローカルプレビューで固定Missionを作らなかった点と、Trail空状態にCTAがある点は良い。一方、旅行の確認が5問でDesign Bibleの最大3問と衝突し、保存されたQuest詳細には質問文の羅列と重複した「航路条件」が露出した。Missionが0件のままでは次のTaskもTrailも始められず、初回価値は完走できなかった。

`docs/qst/EXTERNAL_BETA_GO_NO_GO.yaml` は別SHAで評価された12/12ブロックのNO-GOであり、今回のSHAに対する新しい合格証跡は確認していない。ローカルモックの画面を、Gemini・Supabase・実アカウントの合格証拠として扱わない。

調査した規範: `README.md`、`docs/QUESTRA_MASTER_SPEC_V2.md`（v2.1）、`docs/product/DESIGN_BIBLE_V2.md`、`docs/qst/BACKLOG.yaml`、QST-260/261〜267/347/507〜526、Router、画面、分析、テスト、旧監査。`AGENTS.md` はリポジトリ内に見つからなかった。Routerは28 `GoRoute`、画面系Dartファイルは32、`apps/mobile/test` は297ファイル、`integration_test` は3ファイル。実機Androidはこの環境で起動できず、`adb` はPATH上にない。Flutter SDK cacheは3.44.2、Dartは3.12.2。`flutter --version` は起動中のSDKロックのため取得できず、SDK cacheを読んだ値である。

開始前から存在する変更は `route_snapshot_service.dart`、`qst_517_route_snapshot_schema_v2_test.dart`、`202609280001_route_snapshot_schema_v2.sql`。本監査では編集・退避・復元をしていない。認証用テストアカウントとHosted接続情報は利用できなかった。実操作は端末内モックのみ。実アカウント登録、課金、データ削除、企業取引、二アカウントRLSは未実施。

## 2. 採点と判定

現時点の**ローンチ・定着準備度は44/100、信頼度は中低**。これはUI美観の点数ではない。5領域を各20点とし、実画面で完走できないものと同一SHAの外部証跡がないものを加点しない。

| 領域 | 得点 | 根拠と減点 |
| --- | ---: | --- |
| 最初の意味ある行動 | 9/20 | 願い→Quest保存は成功。5問とAI失敗後0 MissionでTask未達。 |
| 継続・再開 | 7/20 | Task/再計画のコードはあるが、今回の0 Mission環境では実操作不能。 |
| 失敗からの回復 | 11/20 | AI失敗時の入力保持とQuest単独保存は有効。TrailはMission必須で止まる。 |
| 信頼・配布準備 | 7/20 | モック/オンラインの区別は明示。配布ゲートは別SHAのNO-GO、実接続未実証。 |
| UI・アクセシビリティ | 10/20 | 主要CTAとSemanticsあり。画面間の明暗差、質問の長さ、物理TalkBack/200%未確認。 |

停止条件は点数ではなくP0ゲート。`docs/qst/EXTERNAL_BETA_GO_NO_GO.yaml` の候補固定、Hosted Migration/Functions、同一SHA二アカウントRLS、実機、IME/アクセシビリティ、法務/データ権利、資産/ライセンス、運用、SLO、provider-backed AI品質が解除されるまで配布しない。古い `docs/product/beta_readiness_report.md` の70/100は別候補の記録で、今回の現在点に転用しない。

## 3. 10視点の独立レビュー

| 視点 | 良い点 | 問題・証拠 | 判断 |
| --- | --- | --- | --- |
| 初めて使う人 | Homeの「叶えたいことを一つ話す」で入口が分かる | Arc旅行相談が5問、保存後にTaskなし（[Arc提案](evidence/LAUNCH_RETENTION_AUDIT_20260930/arc-proposal-390.png)、[Quest](evidence/LAUNCH_RETENTION_AUDIT_20260930/quest-detail-390.png)） | 初回10分価値は未実証 |
| 継続利用者 | Quest→Mission→Task→Trailの概念と回復コードがある | 今回の0 Missionでは今日の一歩・Trailを試せない。停滞・翌週の実データ未確認 | 定着は仮説段階 |
| UI/UX | Home/Arc/Trailは静かな紺と金で一貫 | Quest作成は白い大カードでフォームが下、航路は明るい面に切替。[作成](evidence/LAUNCH_RETENTION_AUDIT_20260930/quest-create-css390.png)、[航路](evidence/LAUNCH_RETENTION_AUDIT_20260930/route-css390.png) | 情報階層の整理が必要 |
| PM | Quest単独保存でユーザーの願いを失わない | 0 Missionで価値循環が止まる。Guild/Premium拡張より初回Taskを優先 | 範囲を絞るべき |
| AI品質 | 失敗時に固定Missionを捏造しない | 実Gemini未接続、200件実評価が存在しない。5問固定旅行ロジックは`quest_clarification_service.dart` | provider品質は未確認 |
| QA | 297 testファイルと3 integration testファイル、過去の自動E2E | current-SHA Hosted/実機/再起動/競合の実証なし。QST-517〜525未了 | 外部証跡が不足 |
| Security/Privacy | 設定に保存/AIの区別、分析payload許可リスト、Arc Memory OFF | 同一SHA二アカウントRLSとデータ権利実履行が未実証（`EXTERNAL_BETA_GO_NO_GO.yaml`） | 公開停止 |
| Accessibility | 多くのCTAにSemantics名、Trailの段階ラベルあり | 物理TalkBack・日本語IME・200% text未確認。二次CTAの低コントラストが[確認ダイアログ](evidence/LAUNCH_RETENTION_AUDIT_20260930/quest-consent-390.png)で見える | 実機検証必須 |
| Growth/Business | Guildをコアナビから外し、Arcの中立性を守る設計 | Guildはローカルでpilot gate、Premiumは機能旗のみ、AI単価/転換の実測なし | 早期課金拡大は保留 |
| 懐疑的な人 | 同意付きQuestとTask/Trailの永続的な構造は一般チャットとの差になり得る | 実演はQuest止まり。Taskや再開を体験できず、チャット+ToDoとの差がまだ伝わらない | 差別化は実証待ち |

一致点: 「最初のTask完了」より前に機能を増やさず、失敗時の信頼と同一SHA証拠を優先。意見が分かれる点: Guild/Premiumの早期開放はGrowthには魅力があるが、PM・Trust・QAは現時点で延期を支持する。

## 4. Route・画面インベントリと画面別評価

評価は現行モックで見えた状態に限る。`実`=今回の実画面、`コード`=Route/実装のみ、`不可`=モックでは到達不能。数値はその画面の確認状態に対するUX暫定点であり、未確認には付けない。32画面ファイルのうちRoute以外は最後に記す。

| # | Route / 画面 | 確認 | 点 | 根拠・制約 |
| ---: | --- | --- | ---: | --- |
| 1 | `/splash` | コード | — | 初期遷移はあったが静止画を保存できず |
| 2 | `/login` | 実 | 72 | CTA・入力ラベル明確。実認証は未実施。[画像](evidence/LAUNCH_RETENTION_AUDIT_20260930/login-390.png) |
| 3 | `/signup` | 不可 | — | 既ログインモックではHomeへredirect。別origin試行は白画面で中止 |
| 4 | `/forgot-password` | コード | — | ログイン状態ではHomeへredirect |
| 5 | `/reset-password` | コード | — | 有効tokenなし |
| 6 | `/legal-consent` | コード | — | ログイン状態でredirect、同意は操作していない |
| 7 | `/onboarding` | コード | — | ログイン状態でHomeへredirect |
| 8 | `/settings` | 実 | 65 | 設定項目が狭い画面で高密度。[画像](evidence/LAUNCH_RETENTION_AUDIT_20260930/settings-390.png) |
| 9 | `/settings/section/:section` | 実（一部） | 70 | 接続状態を操作。プレビューとオンラインを明確に分離。[画像](evidence/LAUNCH_RETENTION_AUDIT_20260930/connection-preview-390.png) |
| 10 | `/settings/data-rights` | 実 | 67 | 操作入口を確認、履行は未実行。[画像](evidence/LAUNCH_RETENTION_AUDIT_20260930/data-rights-current.png) |
| 11 | `/settings/arc-memory` | 実 | 73 | OFFと記憶0件を確認。[画像](evidence/LAUNCH_RETENTION_AUDIT_20260930/arc-memory-current.png) |
| 12 | `/feedback` | 実 | 58 | 入力可能だが窓口準備中、コピーして手動共有。[画像](evidence/LAUNCH_RETENTION_AUDIT_20260930/feedback-current.png) |
| 13 | `/guild` | 実 | 45 | Pilot gateで発見/取り込みは不可。[画像](evidence/LAUNCH_RETENTION_AUDIT_20260930/guild-390.png) |
| 14 | `/share/trail/:token` | コード | — | 有効共有tokenなし |
| 15 | `/home` | 実 | 67 | 最初の10分CTAは明快。Task有り状態は未確認。[画像](evidence/LAUNCH_RETENTION_AUDIT_20260930/home-empty-390.png) |
| 16 | `/quest` | 実 | 69 | 空状態がArcへ接続。[画像](evidence/LAUNCH_RETENTION_AUDIT_20260930/quest-empty-390.png) |
| 17 | `/quest/create` | 実 | 52 | 白い導入カードが大きく、名前入力は初期画面下。[画像](evidence/LAUNCH_RETENTION_AUDIT_20260930/quest-create-css390.png) |
| 18 | `/quest/:questId` | 実 | 48 | 質問文羅列と重複条件、0/0 Mission。[画像](evidence/LAUNCH_RETENTION_AUDIT_20260930/quest-detail-390.png) |
| 19 | `/quest/:questId/route` | 実 | 51 | 0 Mission時は再計画不可、明るい画面が不統一。[画像](evidence/LAUNCH_RETENTION_AUDIT_20260930/route-css390.png) |
| 20 | `/quest/:questId/edit` | コード | — | 編集の実保存は未操作 |
| 21 | `/quest/:questId/mission/:missionId` | 不可 | — | Mission fixtureなし |
| 22 | `/quest/:questId/mission/:missionId/task/:taskId` | 不可 | — | Task fixtureなし |
| 23 | `/quest/:questId/mission/:missionId/support` | 不可 | — | Mission fixtureなし |
| 24 | `/mission` | 実 | 64 | 中間成果の説明とQuest CTA。[画像](evidence/LAUNCH_RETENTION_AUDIT_20260930/mission-empty-390.png) |
| 25 | `/task` | 実 | 65 | 具体行動の説明とMission CTA。[画像](evidence/LAUNCH_RETENTION_AUDIT_20260930/task-empty-390.png) |
| 26 | `/arc` | 実 | 61 | 会話と候補確認は動くが5問は長い。[画像](evidence/LAUNCH_RETENTION_AUDIT_20260930/arc-first-reply-390.png) |
| 27 | `/trail` | 実 | 70 | 空状態にCTA。0件統計/巨大な読込通知/Timelineは今回の空状態で再現しない。[画像](evidence/LAUNCH_RETENTION_AUDIT_20260930/trail-empty-390.png) |
| 28 | `/profile` | 実 | 70 | 設定が分かる。「Bond」等の固有語は説明が必要。[画像](evidence/LAUNCH_RETENTION_AUDIT_20260930/profile-390.png) |

Route以外: `RouteRecoveryScreen` は `errorBuilder`、`GuildDiscoveryDetailScreen` はGuild内、`GuildScreen` は現Router未使用、`PlaceholderScreen` と `QuestraComingSoonScreen` は汎用Widget。Today Focus、Dream Board、Star Map、Horizon、Signal、Premium、Quest Library、検索、通知、企業Offerに専用Routeはない。HomeやMission支援に埋め込まれた機能は専用画面として数えない。Dialog/BottomSheetはArcのQuest確認、Trail作成を実見した。Loading/Offline/Permission/AI生成中/長文/大量データ/完成済みの全画面マトリクスは未網羅で、QST-524が対象。

スクリーンショットは表示幅390px指定の取得群とCSS幅390px（倍率1.1、物理429px）の取得群が混在する。後者のブラウザ上で白余白が見えたが、表示倍率・viewport overrideの影響を分離できないためアプリ欠陥と断定しない。Android、タブレット、横画面、英語、Light、200%文字、Reduce Motionは今回未確認。

## 5. 中核導線の操作結果

| 導線 | 実操作 | タップ/待ち/迷い・回復 |
| --- | --- | --- |
| 初回起動→登録→Arc | 一部 | 実登録なし。ログインの「モックを開く」→Home→Arcは2操作。新規登録の実送信は未確認。 |
| 願い→確認→Quest | 実 | 「シンガポールに行きたい」送信後、期限・同行者・予算・体験・スタイルの5問。候補→確認→入力画面へ進んだ。HomeからQuest保存まで約12タップ（入力操作除く）。待ち時間の計測器なし。 |
| AI Mission/Task提案→承認 | 失敗系のみ実 | 「Arcと航路を描く」が失敗。入力保持と「Questだけ保存」を確認。Gemini生成/承認は未確認。 |
| Home→次Task→開始/完了 | 不可 | 0 Mission/0 Task。10秒発見・2操作完了は測れず。 |
| Mission完了→Trail | 一部 | Trail空状態→Quest選択を操作。Mission必須で保存不可、QuestでMission作成へのリンクあり。[画像](evidence/LAUNCH_RETENTION_AUDIT_20260930/trail-no-mission-390.png) |
| 延期→部分再計画→再開 | 不可 | 0 Missionで航路の見直しCTAがdisabled。コード/既存QSTだけ確認。 |
| Guild発見→取り込み | 不可 | ローカルPilot gate。オンライン許可ユーザーの実データが必要。 |
| Premium、企業支援、設定/権利 | 一部 | Premium専用Routeなし。Mission支援はMission fixtureなし。設定・Arc Memory・データ管理入口は実見、削除/輸出は実行しない。 |

初回Questは旅行の希望年月を`2027年3月頃`と答えたが、Quest詳細には月初日を含む期限行と「目標年月」が併存した。本人の希望は年月であり、特定日への確定と区別すべきである。

## 6. Finding一覧（重大度順）

### LA-01 Blocker: 同一SHAで配布ゲート未成立
対象: 全画面/配布。再現: `EXTERNAL_BETA_GO_NO_GO.yaml` とHEADを照合。期待: clean candidate、Hosted/実機/法務/AI品質の合格証跡。実際: manifestは別SHAで12 blocked、現在の作業ツリーにも既存QST-517変更。影響: 実ユーザーへ安全に配布できない。修正: QST-525、QST-428、QST-524と既存P0を同一SHAで閉じる。根拠: `docs/qst/EXTERNAL_BETA_GO_NO_GO.yaml`、`docs/qst/BETA_CANDIDATE.yaml`。

### LA-02 High: Arcの質問数が仕様上限を超える
対象: Arc→Quest。再現: モックで「シンガポールに行きたい」。期待: 航路が変わる必要な質問のみ最大3問。実際: 期限/同行者/予算/体験/スタイルの5問。影響: 初回離脱と「決めさせられる」負荷。修正: QST-527。根拠: `quest_clarification_service.dart` の `maxQuestions = 5` と `quest_clarification_service_test.dart` の5問期待、Design Bible最大3問、[画像](evidence/LAUNCH_RETENTION_AUDIT_20260930/arc-proposal-390.png)。

### LA-03 High: Quest詳細が生の質問・回答と重複条件を表示
対象: Arc→Quest詳細。再現: 5問回答後、AI失敗時にQuestだけ保存。期待: 条件を短いラベル/値で1回表示。実際: Quest説明に質問文が並び「航路条件」が2回。影響: Questの目的よりフォーム履歴が目立ち、本人の目標が読み取れない。修正: QST-527。根拠: `arc_quest_clarification_session.dart` の本文結合、`arc_screen.dart` の再結合、[画像](evidence/LAUNCH_RETENTION_AUDIT_20260930/quest-detail-390.png)。

### LA-04 Critical: AI不調時に意味ある初回行動へ到達できない
対象: Quest/Trail。再現: 航路生成失敗→Questだけ保存→Trail。期待: 本人が手動Mission/Taskを作る明快な回復経路、またはMissionなしで安全な下書きを保持。実際: 0/0 MissionでTaskなし、TrailはMission必須。Trailに「QuestでMissionを作る」リンクはあるが、Quest詳細の0件航路CTAは無効。影響: 最初の行動・記録が途切れる。修正: 既存QST-261の受入条件へ0 Missionの回復を追加し、QST-524で実画面検証。根拠: [AI失敗](evidence/LAUNCH_RETENTION_AUDIT_20260930/ai-fallback-390.png)、[Trail](evidence/LAUNCH_RETENTION_AUDIT_20260930/trail-no-mission-390.png)。

### LA-05 Blocker（証拠不足）: 実Gemini計画品質を判定できない
対象: AI Planning。再現: 設定→接続状態を開く。期待: provider-backed 200件評価と同一候補での安全/コスト結果。実際: 「固定のプレビュー応答」と明示、`QST-256-REGRESSION.json` は見つからない。影響: 非テンプレートMissionと安全性を保証できない。修正: 既存QST-256・外部AI gate。根拠: [接続状態](evidence/LAUNCH_RETENTION_AUDIT_20260930/connection-preview-390.png)、`EXTERNAL_BETA_GO_NO_GO.yaml`。

### LA-06 High: 定着指標はイベント定義に留まる
対象: Analytics。再現: `analytics_event.dart` と利用箇所を確認。期待: Task開始/完了、24h初回完了、D1/D7/D30、再計画後再開の分母と実測。実際: event enumとローカル実装はあるが、`meaningfulProgress()` 呼び出しやTaskの標準開始/完了イベント発火点は確認できない。`QST-347.md` 自身も画面発火点とdashboardをFollow-Upとしている。影響: 定着を改善したか判断できない。修正: 既存QST-347の未完作業として追加。根拠: `apps/mobile/lib/core/analytics/*`、`reports/qst/QST-347.md`。

### LA-07 High: Quest作成・航路の画面表現が中核UIと異なる
対象: `/quest/create`、`/quest/:id/route`。再現: 各Routeを開く。期待: 入力開始が上部で見え、Home/Arcと同じ静かな航路面。実際: 作成フォームの前に大きな白カード群、航路は明るい全面へ切り替わる。影響: 迷いとプロダクトの一貫性低下。修正: QST-524でGolden差分を記録してから、QST-266の回帰として小範囲のUI QST化。根拠: [作成](evidence/LAUNCH_RETENTION_AUDIT_20260930/quest-create-css390.png)、[航路](evidence/LAUNCH_RETENTION_AUDIT_20260930/route-css390.png)。

### LA-08 Critical: フィードバック受付の運用窓口が未稼働
対象: `/feedback`。再現: プロフィール→改善点を送る。期待: 送信・受領・トリアージの追跡。実際: 「Beta窓口は準備中」、内容をコピーして運営担当へ共有と表示。影響: β不具合を収束できない。修正: 既存外部Beta運用ゲート。根拠: [画像](evidence/LAUNCH_RETENTION_AUDIT_20260930/feedback-current.png)、`BETA_FEEDBACK_OPERATIONS.yaml`。

### LA-09 Critical: 実機アクセシビリティと日本語IMEが未実証
対象: 全主要画面。再現: 物理証跡と今回の環境を確認。期待: TalkBack、200%文字、IME、Android/Web実機で同一SHA検証。実際: QST-260も正式完了待ち、今回Android端末なし。影響: 操作不能の未発見リスク。修正: QST-260・524。根拠: `reports/qst/QST-260.md`、`PHYSICAL_ACCESSIBILITY_EVIDENCE.yaml`。

### LA-10 Critical: 航路Undoと遠隔Task競合の整合性が未完
対象: 再計画/Task。再現: BACKLOG状態確認。期待: 再起動後Undo、同時編集CASと二アカウント実証。実際: QST-517〜521/525がPlanned。影響: 進捗や計画の取り違え/消失。修正: 既存QST-517→518→519→521→525。根拠: `docs/qst/BACKLOG.yaml`。実データ競合は今回再現していない。

### LA-11 Medium: Guildは発見プラットフォームとして未実証
対象: `/guild`。再現: モックでGuild。期待: 許可された公開Questの発見と安全な取り込み。実際: pilot gateを表示し取り込み不能。影響: Growth仮説を測れないが、コア導線の公開停止理由ではない。修正: Guildは限定pilotで検証、コアβの主ナビへ戻さない。根拠: [画像](evidence/LAUNCH_RETENTION_AUDIT_20260930/guild-390.png)。

### LA-12 Medium: 副次CTAの視認性と過剰説明
対象: Arc Quest確認、設定。再現: Quest化確認ダイアログと設定メニューを開く。期待: 主/副CTAとも読め、画面の次行動を一目で判断。実際: 「Arcともう少し相談する」が暗色面上で弱く、設定は説明が高密度。影響: 本人確認の選択肢を見落とす。修正: QST-524のGolden/Contrast証拠に加え、局所的な共通token修正。根拠: [確認](evidence/LAUNCH_RETENTION_AUDIT_20260930/quest-consent-390.png)、[設定](evidence/LAUNCH_RETENTION_AUDIT_20260930/settings-390.png)。数値コントラストは未測定。

## 7. Design Bible差分・新デザイン方針

Keep: Arcと一つの次の行動、Deep Navy/Cosmic Blue/抑制したGold、同意付きQuest化、固定Missionを返さない失敗回復、Trail空状態のCTA。Improve: Arc質問最大3問、本人が答えた条件の型付き要約、Questを作った直後の最初のTask導線、主/副CTAの対比。Merge: Quest作成の大きな導入説明を短いArc導線へ統合。Remove: Quest詳細の質問文羅列と重複見出し、計画ゼロの無効CTA。Defer: Guild一般公開、Premium画面、Star Map演出、企業Offer拡大。

理想構成: Homeは次のTask 1件（未作成なら最短の作成導線）→Arcは短く相談→Questは成果/条件/進捗→Missionは中間成果→Taskは今日の一手→Trailは結果の記録→Guildは許可済み公開Questのみ。80%を明快さ、15%を感情、5%を宇宙/航海表現へ。Quest作成と航路の白面はtokenで統一し、カードを入れ子にしない。コピーは「Questを整理中 1/5」より「あと確認したいこと 2件」など、必要性が分かる表現へ。本人が選んだ年月とAI予測日を別ラベルにする。日本語・英語切替、320〜430px、200%文字、焦点、読み上げ、Reduce MotionはQST-524の実証対象。

Before→Afterの期待: 「5問→長い質問文のQuest→0 Mission」から「必要な0〜3問→目的と条件が一目で読めるQuest→手動/AIのどちらでも最初のTaskへ」。今回のAfterは提案であり、実装済みと書かない。

## 8. 定着の計測契約（未実測）

すべてowner単位で同意・匿名化したイベントIDを使い、同一操作のidempotency keyで重複を除く。分母にモック、内部QA、未承認生成を混ぜない。生のQuest/Arc/Memory本文は送らない。

| 指標 | 分母→分子/時点 | 必要イベント・重複防止 |
| --- | --- | --- |
| 作成後24h初回Task完了 | Quest作成ユーザー→24h以内に配下Taskを初完了 | `quest_created`、`task_completed`（現発火点要追加）、quest/userで初回のみ |
| 最初の行動までの時間 | Quest作成→配下Taskの初開始/完了 | user/questの最小時刻、タイムゾーン統一 |
| Weekly Meaningful Action Rate | 週に利用可能なQuest保有者→Task完了/成果確認/Trail/承認済み再計画のいずれか | 週/userで1回、画面閲覧は除外 |
| Mission/Quest完了率 | 期間内に開始した母集団→本人確認済み完了 | 状態遷移を正本にし、再開/削除/一時停止は別集計 |
| 停滞/再計画後の再開率 | 停滞と定義されたQuest/承認再計画→次のTask開始 | 同じQuestの再開まで、再計画拒否も分ける |
| D1/D7/D30継続 | 初回Quest作成コホート→指定日の意味ある行動 | 日境界、利用できた日、静かな通知設定を分ける |
| Arc提案の採用/編集/削除 | 提案を実際に見た人→各処理 | proposal IDで一意化、強制採用を成功とみなさない |
| Guild取り込み率 | 許可済みGuild候補を見た人→本人確認後取り込み | publication ID×ownerで重複排除 |
| Trail記録率 | Task/Missionを完了した人→対応するTrail作成 | parent IDと期間、任意利用を維持 |
| Premium転換/解約 | 対象案内を見た適格ユーザー→購入/解約 | 現在専用UIと課金実装は未確認、計測対象外 |
| AI原価/active user | provider請求額→意味ある行動ユーザー数 | model/pass/grounding別、モックを除外 |
| 品質/安全 | current-SHAセッション→crash/重大incident | 一意incidentと環境、秘密・本文の非記録 |

全指標を新規/既存、Web/Android、言語、Quest種別、低予算、利用可能時間、モック/Hosted、AI成功/失敗で分解する。ただし小規模コホートの再識別を防ぐ。数値目標は実測分布とユーザー検証の後に決める。現状は`QST-347`がlocal-safe taxonomyまでで、readoutは未実装。

## 9. QST整理と実施順

最新登録番号はQST-526。`rg`で527〜529の衝突なし。新規は**QST-527の1件だけ**。既存の完了宣言を今回のモックで覆さず、current-SHAの回帰証拠を追加する。

| 優先 | QST | 分類 | 解くFinding→主要受入条件→テスト |
| ---: | --- | --- | --- |
| 1 | QST-525 + Release Gate QST-428 | 既存 | LA-01/09/10→同一SHA Hosted二アカウント/失敗注入→SQL/実機 |
| 2 | QST-261 | 既存更新提案 | LA-04→AI失敗で0 Missionから手動Mission/Taskへ、Trail下書き回復→Web/Android E2E |
| 3 | QST-527 | 新規 | LA-02/03→0〜3問、条件重複なし、本人確認→Domain/Widget/E2E |
| 4 | QST-256 | 既存 | LA-05→200ケースprovider-backed、安全/品質/コスト判定→回帰runner |
| 5 | QST-517/518/519 | 既存 | LA-10→schema parity、awaitable Undo、途中復旧→競合/再起動test |
| 6 | QST-521 | 既存 | LA-10→遠隔Task CAS→二端末/owner越境test |
| 7 | QST-524 + QST-260 | 既存 | LA-07/09/12→current-SHA 320/390/430、200%、TalkBack→Golden/物理証跡 |
| 8 | QST-347 | 既存更新提案 | LA-06→標準Taskイベント、24h/D7/D30の分母/読出し→契約/集計test |
| 9 | Beta feedback/operations gate | 既存 | LA-08→実窓口、S0/S1 triage→受付訓練 |
| 10 | Guild pilot既存QST | 維持・一般公開延期 | LA-11→許可済みcohortのみ発見/取り込み→RLS/手動QA |

QST-261とQST-347の追加受入条件は `docs/qst/QST-261_LAUNCH_DELTA_20260930.md`、`docs/qst/QST-347_LAUNCH_DELTA_20260930.md` に記録した。QST-266の視覚回帰はQST-524のcurrent-SHA証跡後に対象を限定して再起票判断する。QST-260/261は未完状態のまま。QST-262〜267のCompletedは消さないが、今回の差分が受入条件に触れる場合は回帰として扱う。新しい巨大な「100点化」QSTは作らない。Premium/企業Offer/Guild一般公開は統合・延期候補で、コアβの阻害要因にしない。

β公開前: QST-261/527で初回Taskへ進める導線→QST-256/517〜525で実品質/権限/実機→Release Gate。公開後30日: QST-347の定着計測、Arc提案の編集率、Trail負荷、停止後再開の実測から改善。継続改善: Guild/企業支援/Premiumは利用者価値と中立性が実測で確認できてから段階公開。

## 10. 未確認事項・残余リスク・変更していないこと

未確認: 実登録/ログイン/復旧、Supabase保存と再起動、Gemini回答とMission/Task品質、完成済みQuest、延期/再計画Undo、Trail保存/メディア、Guild取り込み、Premium決済、企業Offer、Android物理端末、iOS、英語、Light、文字200%、TalkBack、オフライン・低速通信、権利請求の実履行、運用アラート、公開ストア審査。過去のスクリーンショットやテストがあっても今回のcurrent-SHA実操作と同一視しない。

今回の情報更新確認（2026-09-30）: [Flutter公式 integration test](https://docs.flutter.dev/testing/integration-tests) は実機/エミュレータ上の結合試験を説明する。[Supabase公式 RLS](https://supabase.com/docs/guides/database/postgres/row-level-security) はユーザーごとの行アクセス検証を説明する。両者は現行実装が合格した証拠ではない。App Store/Google Playのアカウント固有公開条件や競合価格は、この監査の判定根拠に使用せず未検証とする。

アプリコード、DB、Migration、設定、アセット、本番データは変更しない。stash/reset/checkout、commit/push/branch/PRも行わない。変更は本レポート、QST-527文書、QST-261/347の差分文書、BACKLOGへの登録、モックの証拠画像のみ。スクリーンショットには実アカウント・秘密・Arcの生会話を含めず、監査用の旅行例だけを使った。
