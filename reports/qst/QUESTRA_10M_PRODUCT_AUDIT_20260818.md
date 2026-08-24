# Questra 国内外1,000万人プロダクト総合監査

> 監査日: 2026-08-18  
> 対象: `codex/initial-questra-structure-pr`  
> 対象SHA: `a058344524c4c1d33c97836e5cf15f16a9e3ab39`  
> 判定: **外部Beta NO-GO / 1,000万人プロダクト準備度 44点**  
> 変更範囲: 監査文書、QST、Backlog、恒久原則のみ。アプリ、DB、Migration、設定、Assetは変更していない。

## 1. Executive Summary

Questraには、`Quest -> Mission -> Task -> Trail`、Arc、ユーザー承認、非懲罰的な再計画という独自性の高い骨格がある。単なるToDoや汎用チャットへ退行しない思想も明確である。これは残すべき資産である。

一方、現時点で1,000万人を目指す最大の障害は機能不足ではない。**仕様上の理想、実装、実際に配布できる環境の三者が一致していないこと**である。未認証でも主要画面へ入れるRouter、同意境界が全経路で保証されないArc Memory、未計測のAIコスト、現在SHAと一致しないSupabase証跡、Coming SoonのGuildを含む訴求、英語対応を宣言しながら日本語が残るUIは、規模を拡大するほど信頼と運用コストを悪化させる。

したがって、次の開発は新機能の横展開ではなく、次の順で進める。

1. Release Truth、認証、同意、法務、RLS、AI失敗時のFail Closedを閉じる。
2. 最初の10分と「今日の一歩」を一つの体験契約へ統合する。
3. 意味のある前進とユーザーの健全性を測り、D7/D30の改善を証明する。
4. 日本の最初の狭い市場で価値と価格を検証する。
5. その後にTrail共有、Guild、英語圏、Premiumを段階的に開く。

## 2. 監査方法と証拠基準

### 2.1 調査対象

- Master Spec、Design Bible、Security/Privacy/Business仕様
- `docs/qst/BACKLOG.yaml`、QST Report、Beta Candidate/Launch Readiness
- Flutter Router、主要画面、Repository、Controller、Analytics、Localization
- Supabase Migration、RLS、RPC、Edge Functions、Gemini Provider、AI評価ツール
- Git状態、候補SHA、CI、配備証跡
- 現行SHAをrelease Web mock modeで起動した主要導線
- 14の独立した専門家視点
- 15以上の公式競合・制度一次情報

### 2.2 証拠ラベル

| ラベル | 意味 |
|---|---|
| Implemented | 対象SHAのコードまたはDB定義に存在する |
| Verified | 対象SHAに紐づく実環境・実機・自動試験証跡がある |
| Specified | 文書化されているが実装または検証が不足する |
| Unverified | 実装らしきものはあるが、対象SHAの実環境証拠がない |
| Hypothesis | 市場・価格・効果に関する未検証仮説 |

`Specified`、`Unverified`、過去SHAの証跡をPassとして採点していない。

## 3. Repository Reality

| 項目 | 結果 |
|---|---|
| 正式作業場所 | `C:\Users\shint\StudioProjects\Questra` |
| Branch | `codex/initial-questra-structure-pr` |
| SHA | `a058344524c4c1d33c97836e5cf15f16a9e3ab39` |
| 初期worktree | clean / originと同期 |
| Backlog最大ID | QST-337 |
| Candidate manifest | 過去SHA `a5e0cad` を参照 |
| Remote migration head | `202608080006_route_proposal_stale_conflict_guard.sql` |
| Local migration head | `202608170003_quest_journey_workspace.sql` |
| Launch readiness | `no_go` |
| Legal sign-off | 未完了 |

## 4. 実画面操作レビュー

release Web mock mode、390 x 844を中心に、Home、Arc、Quest、Quest作成、Mission、Task、Trail、Guild、Profile、Settings、Login、Onboardingを操作した。

| 画面 | 観察結果 | 重大度 |
|---|---|---|
| Home | Hero本文が省略され、Bottom Navigationが「次の航路」見出しへ重なる | High |
| Arc | Quick Actionが右端で切れる。一般会話はQuest化を強制しなかった | Medium / Keep |
| Arc Memory | 明示的なMemory同意を通過しない操作でも「最近の変化 1件」が見えた | Critical |
| Quest empty | 「Quest詳細へ」が同じ`/quest`へ戻る無効CTA | High |
| Quest create | Arc導線、カテゴリ、フォーム、Bottom Navigationが競合する | High |
| Mission empty | 大きなArcカードが重複し、次の行動が弱い | Medium |
| Task empty | 見出しと補助文のコントラストが不足する | High |
| Trail | 白いCardが宇宙系Themeから浮き、日本語の折返しが不自然 | Medium |
| Guild | Coming Soon単独画面でShell/Bottom Navigationと不整合 | High |
| Login/Profile | 未認証でもHome/Profileへ直接移動できる | Critical |
| Onboarding | Step 1の次に呼び名を経て最初のQuestへ飛び、宣言済みStep 2/3を迂回する | High |
| Settings | 「準備中」「今後選択可能」が多く、出荷済み設定と構想が混在する | Medium |

## 5. Master Spec準拠

| 領域 | 状態 | 評価 |
|---|---|---|
| Quest/Mission/Task/Trail階層 | Implemented | 強い。QST-331〜337で責務が改善された |
| Arcの一般対話とQuest化同意 | Partially implemented | 一般会話は改善。Memory同意と自動記録は未閉鎖 |
| AI Planning | Partially implemented | Multi-pass、schema、critic基盤あり。失敗時確定と選択後再検証に穴 |
| Quest DNA | Implemented foundation | 17属性、履歴、由来あり。成果改善の実証なし |
| Dynamic Route | Implemented foundation | 承認モデルあり。現行Supabaseへの配備証拠なし |
| Trail | Implemented private core | 安全な共有と獲得ループは未実装 |
| Guild | Specified / dormant | 公開・copy基盤はあるが出荷経路はComing Soon |
| Trust/Consent | Strong specification, partial enforcement | 全AI/Memory/Analytics経路のserver-side enforcementが未証明 |
| Premium | Foundation only | 境界文書はあるが、費用・quota・価格の実証なし |
| Global | Not ready | UI/AIの大半が日本語、地域法務と年齢境界が未完了 |

## 6. 固定100点評価

| 分野 | 配点 | 得点 | 根拠 |
|---|---:|---:|---|
| Product definition / differentiation | 10 | 7 | 独自の階層、Arc、非懲罰的原則は明確。最初の市場は未決定 |
| Activation | 8 | 3 | Onboarding分岐と未認証導線が不整合。最初の価値到達を実ユーザーで未検証 |
| Quest/Mission/Task/Trail core | 12 | 7 | 実装は厚いが、配備差分、保存競合、完全な一連E2Eが未閉鎖 |
| Arc Companion | 10 | 6 | 会話・表情・Memory基盤は強い。同意、非依存性、品質Gateが不足 |
| Retention / wellbeing | 10 | 4 | 継続機能はあるが、意味のある週次前進と健全性の計測がない |
| UI/UX | 10 | 5 | Design Bibleは良いが、実画面に重なり、切れ、無効CTA、過剰説明が残る |
| Guild / network | 7 | 1 | DB/Prototypeはあるがユーザーが使える閉ループがない |
| Growth | 8 | 1 | Share、Invite、Attribution、Referral retentionがない |
| Globalization | 6 | 2 | locale宣言のみで大半が日本語。法務・地域format未完了 |
| Monetization | 7 | 1 | 課金未実装は妥当だが、価格、WTP、AI原価、quotaが未検証 |
| Trust / safety / privacy | 5 | 3 | 原則とRLSは強い。年齢、法務、Memory、data rightsの運用証拠が不足 |
| Accessibility | 3 | 1 | 48dp/IMEテストあり。TalkBack、focus、text scale、motion設定に穴 |
| Technology / operations | 4 | 3 | Repository/Riverpod/CI/RLS基盤は良い。現在SHA配備とobservabilityが不足 |
| **合計** | **100** | **44** | **外部Beta NO-GO** |

この44点は「コード量」ではなく、国内外で安全に価値を届け、継続し、成長させる準備度である。リポジトリ内の技術Beta評価70点とは母集団と証拠基準が異なる。

## 7. 14独立レビューの統合

| 視点 | 主結論 |
|---|---|
| World consumer product | 差別化はあるが、Release Truthとfirst valueが壊れている |
| Mobile IA/UI | Home/Quest/Taskの次行動契約が分散し、空状態とShellが不整合 |
| Behavioral science | Onboarding完了が価値到達前。Arcの孤独表現と報酬は依存・罪悪感リスク |
| AI/LLM | Memory同意、critic fail-open、usage enforcement、V2評価に重大な穴 |
| Japan market | 最初のwedgeは働く25〜44歳の2〜16週の資格・学びが最も有望という仮説 |
| North America / Europe | 英語は未実装。AI表示、年齢、GDPR、DSA、formatがrelease blocker |
| Growth / UGC | Guildは閉ループでなく、Trail共有・Referral・creator learningがない |
| Monetization / Enterprise | AI原価が強制されず、export/Guild boostをPremiumにする案は原則違反 |
| Trust / Privacy | 18+、地域法務、Memory制御、実際のexport、current-SHA RLSがNO-GO |
| Scale / Reliability | 上限はpaginationでなく切捨て。Trail media N+1、outbox偏在、監視不足 |
| Accessibility | 物理TalkBack未検証、label縮小、focus 1.54:1、motion/haptic bypass |
| M&A / moat | Quest DNA/Arc/Graphは有望な資産だが、IP権利・効果・networkは未証明 |
| Asia / low-end | 30/100。Task以外のoffline継続、低RAM/低速回線実機、locale/currency/timezone、affordabilityが未証明 |
| Skeptical non-user | 29/100。10秒価値理解、silent fallback、自動Memory、default Questがtrustを壊す |

## 8. Keep / Improve / Merge / Remove / Defer / Validate

### Keep

- `Quest -> Mission -> Task -> Trail`の意味分離
- Arcを命令者や営業担当にしない原則
- 変更提案を承認後にのみ適用する境界
- Private by default、目的別同意、RLS
- 失敗や停滞をユーザーの失敗ではなく航路調整として扱う思想
- Repository/Riverpod、Schema、Prompt version、Task transactionの基盤

### Improve

- Routerの認証Guardとmock/remoteの由来表示
- Arc Memoryの作成・検索・修正・削除・保持期間を全経路で同意に拘束
- AI Criticをfail closedにし、選択・部分修正後もsemantic validation
- Today Focus、Completion、Trail、Horizonを一つの継続ループにする
- cursor pagination、batch media、durable mutation、current-SHA deployment gate
- 日本語の平易な補助語、年齢層に応じたArc tone、完全なi18n

### Merge

- QST-322/323/344相当の初回体験を「First 10 Minutes Activation」に統合
- QST-334 Today FocusとHome/Quest/Task deep linkを共通selector契約へ統合
- QST-327/337の外部証拠をcurrent-SHA Release Gateへ統合
- AI usage、Premium quota、Cost observabilityを一つのatomic ledgerへ統合

### Remove

- 未認証主要画面アクセス
- 無効CTA、同じ画面へ戻るCTA、出荷されていないGuildの訴求
- `FittedBox.scaleDown`でアクセシビリティ文字を縮小する設計
- 設定を無視する直接haptic呼び出し
- exportできない状態で「準備できた」と断言するcopy
- ExportやGuild ranking boostをPremium候補にすること
- 実証前のChallenge Graph moat、network effect、企業効果の現在形表現

### Defer

- Public Guild全面公開、Marketplace、Passport、Score、Enterprise insight
- 3D Arc、Dream Board拡張、広範なRecommendation
- EU/US一般公開、未成年対応、多地域write、sharding
- 課金SDK導入。先に価格と原価を検証する

### Validate

- 日本の最初のcohortと価格帯
- Arcが継続・自己効力感を上げ、罪悪感や依存を増やさないこと
- Quest DNAが計画品質や完了率を実際に改善すること
- Trail共有とQuest LibraryがD7/D30へ増分効果を持つこと
- Premium候補が無料Coreを損なわず、AI原価を回収できること

## 9. Red Team: 20の失敗シナリオ

| # | 失敗シナリオ | 予防Gate |
|---:|---|---|
| 1 | 未認証ユーザーがURL直打ちで個人画面へ入る | Router auth integration test |
| 2 | mockの成功をSupabase保存と誤認する | Source badge、production mock禁止 |
| 3 | Arc会話が同意なくMemoryへ残る | Server-side consent assertion |
| 4 | AIが不正JSONまたは低品質計画をDBへ保存する | Schema + semantic + critic fail closed |
| 5 | Fallback Missionがユーザー文脈と無関係 | 固定Mission fallback禁止 |
| 6 | 同一AI要求のretryで二重Questを作る | idempotency + transaction |
| 7 | 無制限AI利用で原価が急増する | atomic reserve/settle quota |
| 8 | global limitで古いMission/Taskが見えなくなる | cursor pagination + completeness |
| 9 | Trail 40件で40回media queryが走る | batch query |
| 10 | current appとremote DB schemaがずれる | exact-SHA migration manifest |
| 11 | 他人のQuest/Memory/Mediaが読める | two-account hosted RLS |
| 12 | 18歳未満が年齢確認なしで登録する | eligibility + terms version |
| 13 | AI利用を知らずに個人的な悩みを送信する | first-input layered disclosure |
| 14 | export UIがデータを実際に渡さない | downloadable artifact E2E |
| 15 | Arcの寂しさ表現が再訪を強要する | non-coercion corpus gate |
| 16 | 200% textでNavが縮小・重なる | actual rendered size test |
| 17 | 日本語IME確定前にEnter送信する | physical IME journey |
| 18 | Coming Soon機能をStoreで販売する | shipped-capability manifest |
| 19 | Guild開始時に安全運用とcontent supplyがない | controlled pilot + moderation SLA |
| 20 | IP・Asset権利不明で提携/M&Aが止まる | chain-of-title data room |

## 10. KPI Metric Tree

### 10.1 North Star

**Weekly Meaningful Progress Users (WMPU)**  
週に1回以上、ユーザー自身が承認したQuestに対して、次のいずれかを行ったユニークユーザー数。

- 必須Missionの成果を完了
- 具体的Taskを完了し、親Mission進捗が更新
- Trailで学び・証拠・再計画判断を記録
- 承認済み航路変更で実行可能性を改善

チャット回数、滞在時間、通知開封だけではWMPUに含めない。

### 10.2 Activation

`signup_started -> trust_understood -> first_wish -> quest_confirmed -> first_task_started -> first_meaningful_progress`

- Time to first meaningful Task
- First Quest confirmation rate
- First Task start/completion rate
- First Trail rate
- 初回体験の中断点と復帰率

### 10.3 Retention

- D1/D7/D30 WMPU retention
- Quest継続、完了、再挑戦
- 停滞後7日以内のgentle recovery
- Arc提案の採用/編集/拒否と、その後の前進
- 通知off、Arc無効化、Memory撤回後の継続可能性

### 10.4 Trust/Wellbeing Guardrail

- 同意撤回成功率、data rights完了時間
- AI誤誘導、危険見逃し、過剰拒否
- guilt/pressure/dependency報告率
- ArcなしでもQuest管理できる割合
- 年齢・言語・端末・accessibility別の不当な格差

### 10.5 Growth

- consentful share created/opened
- shared Quest adoption
- referred activation and D7 WMPU
- creator publication -> adoption -> first progress
- Report/block/appeal率と解決時間

### 10.6 Business

- AI cost per activated user / WMPU / retained user
- Premium intent、conversion、retention、contribution margin
- LTV/CAC、paid CAC payback
- Enterprise supportの採用、拒否、trust impact

## 11. 理想ユーザージャーニー

### 11.1 最初の10分

1. Questraが何をするかを平易な一文で理解する。
2. ArcがAIを利用し、何を送信・記憶するかを入力前に理解する。
3. 願いを自然文で伝える。
4. 必要な場合だけ最大3問へ答える。
5. ArcがまとめたQuestを確認・編集・承認する。
6. 最初のMissionと今日できるTaskを確認する。
7. 5〜15分で最初の一歩を開始する。

### 11.2 日次

Homeは一つのPrimary Task、親Mission、親Quest、所要時間、開始CTAを表示する。Arcは必要な理由を短く伝え、説明を先に積まない。

### 11.3 停滞

期限や頻度を責めず、`小さくする / 日を変える / 一時停止 / Arcに相談`を提示する。Arcが寂しがる、Rankを失う、仲間に迷惑をかける表現は禁止する。

### 11.4 達成

Mission/Quest達成を祝い、Trailへ証拠・学び・感情を残し、Horizonは即時に次Questを押し付けず、休む選択も提示する。

### 11.5 共有

ユーザーが明示的に選んだ項目だけをpreviewし、redact、期限付きlink、取消を可能にする。受け手はcopy後に自分用のPrivate Questとして最適化できる。

## 12. 競合・代替手段の一次情報レビュー

| サービス | 成功原則 | Questraへの示唆 |
|---|---|---|
| ChatGPT | 汎用対話、FreeからPlus/Proへの明確な段階 | 汎用チャットで競わず、実行・履歴・承認へ集中 |
| Gemini | Personalizationとconnected apps | 接続範囲とMemoryを明示し、ユーザー制御を強くする |
| Pi | 温かい会話、音声、軽いreminder | 温度感は参考にするが依存誘発を避ける |
| Replika | CompanionとMemoryの有料深化 | 「親密さの課金」ではなく伴走の深さを売る |
| Todoist | 明瞭なTask captureとFree/Pro | 今日の一歩はTodoist以上に簡潔である必要がある |
| Notion | 情報階層とtemplate ecosystem | Quest Libraryは用途特化と安全なcopyに限定 |
| Fabulous | Journey、routine、coaching | 段階導線を学ぶが、固定routineをQuestへ押し付けない |
| Finch | 小さな自己ケアと非懲罰的companion | Questraのgentle recoveryと親和性が高い |
| Habitica | Gamification、party accountability | missed taskへの罰やparty guiltは採用しない |
| Duolingo | 無料価値、習慣、明確なPremium | 継続UXは参考、streak pressureはGuardrail対象 |
| Strava | Activity recordとcommunity | Trailを獲得資産にできるが、比較競争を中心にしない |
| Headspace | 落ち着いた導入、subscription content | 認知負荷とtrust-first onboardingを参考にする |
| Wanderlog | 旅行のitinerary、reservation、map | 旅行Questでは最新情報と実務情報が必要 |
| BetterUp | assessment、coach match、session | AIだけでなく将来の専門支援境界を設計する |
| Discord | Community onboarding、AutoMod | Guildはcontent供給、moderation、権限が揃ってから開く |
| LinkedIn Learning | role guide、course、enterprise privacy | 学びwedgeと企業支援の透明性を検証する |

公式参照: [ChatGPT pricing](https://openai.com/chatgpt/pricing/)、[Gemini FAQ](https://gemini.google.com/faq?hl=en-gb)、[Pi](https://hey.pi.ai/)、[Replika plans](https://help.replika.com/hc/en-us/articles/39551043419149-Choosing-a-Subscription)、[Todoist plans](https://www.todoist.com/pricing/)、[Notion pricing](https://www.notion.com/pricing)、[Fabulous](https://www.thefabulous.co/)、[Finch approach](https://help.finchcare.com/hc/en-us/articles/37935669335309-Our-Approach-to-Self-Care)、[Habitica features](https://habitica.com/static/features)、[Duolingo strategy](https://investors.duolingo.com/company-strategy-overview-0)、[Strava subscription](https://www.strava.com/subscribe)、[Headspace subscriptions](https://www.headspace.com/subscriptions)、[Wanderlog help](https://help.wanderlog.com/hc/en-us)、[BetterUp employee experience](https://www.betterup.com/how-it-works-for-employees)、[Discord community servers](https://docs.discord.com/developers/platform/community-servers)、[LinkedIn Learning](https://www.linkedin.com/learning/)。

## 13. 法務・規制の確認点

- GDPRは通知、アクセス、訂正、削除、制限、可搬、異議申立て等を含む。[European Commission](https://commission.europa.eu/law/law-topic/data-protection/information-individuals_en)
- EU AI ActはAIとの直接対話に関する透明性を含み、適用時期が段階化されている。[European Commission AI Act FAQ](https://digital-strategy.ec.europa.eu/en/faqs/navigating-ai-act)
- COPPAは13歳未満向けまたは実際に13歳未満から収集しているサービスへ親の通知・検証可能な同意等を要求する。[FTC](https://www.ftc.gov/legal-library/browse/rules/childrens-online-privacy-protection-rule-coppa)
- 日本のAPPI対応には運営者、利用目的、第三者/委託先、開示等手続、保持・安全管理の正式確認が必要である。[PPC Japan reference translation](https://www.ppc.go.jp/files/pdf/APPI_english.pdf)

本レポートは法的助言ではない。外部配布前に対象地域の専門家承認を必須とする。

## 14. 優先ロードマップ

### Phase A: External Release Truth (QST-338〜343)

認証、年齢/法務、Memory同意、AI fail closed、AI原価、current-SHA配備/RLSを閉じる。ここを通過するまで外部Betaを開かない。

### Phase B: First Value and Retention (QST-344〜350)

最初の10分、Today Focus、Completion loop、gentle recovery、KPI、pagination/outbox、IA/accessibilityを閉じる。

### Phase C: Market Validation (QST-351〜352)

日本wedge、平易な日本語、価格仮説を検証し、その後に完全な英語化とformat matrixへ進む。

### Phase D: Ethical Growth and Business (QST-353〜356)

Trail共有、Quest Library controlled pilot、Premium unit economics、IP/Data roomを証拠付きで進める。

### Phase E: 10M Scale Gate (QST-357)

observability、段階負荷、Backlog SSOT、固定100点再監査を統合し、次phaseのGo/No-Goを判断する。

## 15. AppleレビューとM&A辛口評価

### Appleが今レビューした場合

視覚的個性とアクセシビリティへの意図は評価される一方、未認証導線、未完了法務、AI透明性、200%文字、focus、Coming Soon訴求、実際に使えないexportが問題になる。機能審査以前に、ユーザーが何へ同意し何が保存されるかの説明と、出荷物の一貫性が弱い。

### M&A候補として

現時点では「有望なプロダクト/IP基盤」であり「証明済みのmoat」ではない。Quest DNA、Arc、Challenge Graph、Planning評価、Prompt Registryは候補資産だが、権利帰属、data use、効果量、cohort retention、network liquidity、unit economicsが揃っていない。これらを現在形で誇張するとDue Diligenceで逆効果になる。

## 16. 最終判定

Questraは作り直す必要はない。しかし、追加開発の順序は変える必要がある。

**外部Beta開始条件:** QST-338〜343を完了し、current SHAの実環境で認証、RLS、Gemini、同意、data rights、法務、Android accessibilityを証明すること。  
**成長機能開始条件:** QST-344〜350でD7 WMPUと非依存Guardrailを計測できること。  
**Guild/Premium開始条件:** 単一ユーザー価値と原価、trust、controlled pilotの増分効果が証明されること。

次回の固定100点監査はQST-357で行い、未確認をPassへ変換しない。
