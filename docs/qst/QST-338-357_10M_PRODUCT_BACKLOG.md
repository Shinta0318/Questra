# QST-338〜357: 1,000万人プロダクト品質Backlog

> Source audit: `reports/qst/QUESTRA_10M_PRODUCT_AUDIT_20260818.md`  
> Candidate SHA: `a058344524c4c1d33c97836e5cf15f16a9e3ab39`  
> Rule: `Unverified`はPassではない。各QSTは`reports/qst/QST-XXX.md`を出力する。

## 共通Definition of Done

- Happy path、失敗復帰、negative test、権限境界、performance budgetを検証する。
- Supabaseを変更する場合はmigration、rollback/kill switch、二アカウントRLSを含める。
- AIを変更する場合はmodel/prompt/schema/thinking version、cost、latency、safety、fallbackを記録する。
- UIを変更する場合はcompact/medium/expanded、200% text、keyboard/IME、TalkBackの証拠を残す。
- Analytics payloadへ願い本文、Quest本文、Arc会話、Memory本文を送らない。
- Feature Flagは未検証経路を既定OFFにできること。

## QST-338 External Release Truth and Authenticated Router Guard

- **Priority:** Critical / P0
- **Background:** mock、未認証route、Coming Soon、過去SHA証跡が一つの体験に混在する。
- **User issue:** 保存・認証・利用可能機能を誤認し、個人画面へ未認証で入れる。
- **Goal:** 出荷された画面、データ源、認証状態、candidate SHAを常に真実と一致させる。
- **In scope:** GoRouter redirect、session復元、mock禁止/明示、capability manifest、無効CTA、Guild/Store copy整合。
- **Out of scope:** 新しいGuild、課金、デザイン全面刷新。
- **Existing relations:** QST-197、200、201、308、327、337を更新・統合する。
- **Dependencies:** なし。以後の外部検証をblockする。
- **Likely files:** `app_router.dart`、`auth_state.dart`、`app_environment.dart`、Store draft、candidate manifest、integration tests。
- **UX/Data/AI:** 認証中loading、session失効、offline復元、mock/remoteの由来を表示。AI機能のavailabilityもmanifestへ含める。
- **Security/Accessibility/Analytics:** redirect loop、deep link、screen reader status、`auth_gate_result`のみ計測。
- **Happy acceptance:** 未認証の保護routeはLoginへ、認証後は元routeへ戻る。productionでmock persistenceを起動できない。
- **Failure acceptance:** session取得失敗でも個人データ画面を描画せず、retry/logoutを選べる。
- **Negative/cross-account:** URL直打ち、stale token、別account cacheを拒否する。
- **Performance:** cold auth判定p95 500ms以内を目標とし、splash無限待機を禁止。
- **Migration/rollback/flag:** DB migration不要。`RELEASE_TRUTH_GUARD`は本番で強制ON、rollbackで認証を外してはならない。
- **Evidence:** Web/Android deep-link E2E、session expiry録画、Store-capability verifier。
- **Score lift / residual risk:** +4。法務・RLSはQST-339/343が残る。

## QST-339 Age, AI Disclosure, and Regional Legal Gate

- **Priority:** Critical / P0
- **Background:** 18+規約、運営者、連絡先、DPA、processor、保持、AI透明性が未確定。
- **User issue:** 個人情報入力前に年齢・AI処理・権利を理解できない。
- **Goal:** 日本外部Betaと将来のEU/US展開に必要な地域別Go/No-Goを証拠化する。
- **In scope:** 18+ eligibility、Terms/Privacy version consent、first-input AI disclosure、operator/contact、processor/transfer/retention matrix、legal approval。
- **Out of scope:** 未成年向け機能、EU/US一般公開、法的助言の自動化。
- **Existing relations:** QST-160、212、303〜310、Beta Legal Sign-offを更新する。
- **Dependencies:** QST-338。
- **Likely files:** Signup/Onboarding/Arc entry、legal docs、consent tables/RPC、regional release manifest。
- **UX/Data/AI:** layered plain-language notice。AIであること、Geminiへ送る範囲、保存、修正・削除を入力前に示す。
- **Security/Accessibility/Analytics:** consent versionをappend-only保存。年齢の過剰収集を避ける。理解確認をTalkBackで操作可能にする。
- **Happy acceptance:** 18+確認と規約同意がないaccountはBetaへ進めず、同意履歴を取得できる。
- **Failure acceptance:** notice取得不能時は個人入力を開始せず、後で再試行できる。
- **Negative/cross-account:** client改ざん、古い規約version、別account同意流用を拒否。
- **Performance:** noticeはcache可能だがactive versionをserver確認する。
- **Migration/rollback/flag:** consent version migration。地域flagで未承認国を閉じる。過去同意へsilent rollbackしない。
- **Evidence:** 法務署名、Japan release checklist、EU/US risk assessment、二account consent test。
- **Score lift / residual risk:** +3。未成年市場は引き続きDefer。

## QST-340 Arc Memory Consent and User Control Center

- **Priority:** Critical / P0
- **Background:** Memoryの一部経路は同意を確認するが、Arc chat作成・検索・AI contextで一貫しない。
- **User issue:** 何を覚えたか、なぜ使ったか、いつ消えるかを制御できない。
- **Goal:** Arc Memoryの全read/writeをserver-side purpose consentへ拘束する。
- **In scope:** create/retrieve/update/delete、provenance、retention、sensitivity、`覚えないで`、Memory一覧・修正・個別削除・一括OFF。
- **Out of scope:** 記憶量をPremiumで制限、診断、秘密のprofiling。
- **Existing relations:** QST-028、038、046〜047、142、Trust specsを置換せず強化。
- **Dependencies:** QST-339。
- **Likely files:** Arc screen/service、Memory extraction/retrieval/providers、consent RPC/migration、Settings/Data Rights。
- **UX/Data/AI:** Memory使用時に簡潔な由来を示す。User発言とArc生成文を分離し、Arc生成文だけを事実化しない。
- **Security/Accessibility/Analytics:** sensitive data denylist、owner RLS、audit log。本文をanalyticsへ送らない。
- **Happy acceptance:** consent ON時だけMemoryを作成・検索し、個別Memoryを確認・訂正・削除できる。
- **Failure acceptance:** consent/RPC不明時はMemoryなしで会話し、会話自体は壊さない。
- **Negative/cross-account:** 別account Memory、削除済み、撤回後cacheを取得できない。
- **Performance:** relevant Memory最大件数とtoken budgetを維持し、p95を記録。
- **Migration/rollback/flag:** provenance/retention migration。`ARC_MEMORY_CONTEXT`を即時OFF可能。削除済みMemoryをrollback復元しない。
- **Evidence:** endpoint matrix、二account RLS、withdrawal/cache test、Control Center録画。
- **Score lift / residual risk:** +4。長期的なwellbeing効果はQST-346で検証。

## QST-341 Gemini Fail-Closed Planning and Semantic Evaluation

- **Priority:** Critical / P0
- **Background:** Multi-passとCritic基盤はあるが、repair後fail-open、部分採用後の再検証、Groundingのclaim保証が不足する。
- **User issue:** 文脈に合わないMission、内部Planning artifact、古い事実が確定され得る。
- **Goal:** 不合格AI出力を一切確定せず、良い部分だけを安全に再利用する。
- **In scope:** full schema validation、semantic/critic hard gate、selected subset revalidation、Task再計算、grounded claim linkage、non-template error path。
- **Out of scope:** 新LLMへの全面移行、固定Mission fallback、AIによる自動承認。
- **Existing relations:** QST-248〜259、328〜329、335を統合評価する。
- **Dependencies:** QST-338、340。
- **Likely files:** quest planning Edge Functions/shared schemas/validators、Flutter preview/approval、evaluation tools。
- **UX/Data/AI:** 失敗時は入力と良いPass結果を保持し、retry/手動編集を提示。低品質Missionのみrepair。
- **Security/Accessibility/Analytics:** safety blockedを技術codeで見せない。prompt injection、PII、grounding URLを検証。
- **Happy acceptance:** 旅行・学び等で制約に沿う可変Missionを生成し、全gate通過後だけpreviewする。
- **Failure acceptance:** schema/critic/grounding失敗でQuest/Missionを保存せず、固定候補を返さない。
- **Negative/cross-account:** 不正questId、dependency cycle、別account context、tool injectionを拒否。
- **Performance:** pass別latency/token/cost budget、最大repair 1回、cancel対応。
- **Migration/rollback/flag:** execution metadata追加時のみmigration。prompt/schema version rollback可能、fail-closedは維持。
- **Evidence:** 200+ V2 corpus、人手blind review、release thresholds、failure injection。
- **Score lift / residual risk:** +4。provider品質変動は継続監視が必要。

## QST-342 Atomic AI Budget Admission and Cost Ledger

- **Priority:** Critical / P0
- **Background:** usage tableはあるがtoken/costが空で、free/premium policyのhard limitがNULL。
- **User issue:** 利用中に突然停止するか、事業側が予測不能な原価を抱える。
- **Goal:** provider call前後のreserve/settleでAI原価を強制・監査する。
- **In scope:** model別token/cost、atomic quota、idempotency、per-user/IP abuse limit、kill switch、alert、cost dashboard。
- **Out of scope:** Billing SDK、hard paywall、Stardust/Rank販売。
- **Existing relations:** QST-087、206、249、330とPremium readinessを更新。
- **Dependencies:** QST-341。
- **Likely files:** AI provider、entitlement/usage migrations/RPC、Edge Functions、admin metrics、tests。
- **UX/Data/AI:** quota不足はArcらしいretry/後で/manual path。モデル降格は品質Gateを下回らない。
- **Security/Accessibility/Analytics:** client quota上書き禁止。raw promptをcost logへ保存しない。
- **Happy acceptance:** concurrent requestでも上限超過せず、actual usageを一度だけsettleする。
- **Failure acceptance:** provider timeout時はreservation解放または確定policyに従い、二重課金しない。
- **Negative/cross-account:** forged userId、replayed idempotency key、parallel burstを拒否。
- **Performance:** admission p95 100ms目標。利用・cost alertにSLOを設定。
- **Migration/rollback/flag:** non-null policy、ledger/RPC migration。AI role別kill switch。unlimited本番へrollbackしない。
- **Evidence:** concurrency SQL、provider fixture、cost reconciliation、alert drill。
- **Score lift / residual risk:** +3。価格妥当性はQST-355で検証。

## QST-343 Exact-SHA Supabase Deployment and RLS Evidence Gate

- **Priority:** Critical / P0
- **Background:** local migrationがremoteより先行し、Candidate証跡は過去SHAに紐づく。
- **User issue:** clientは機能を表示するがremote RPC/tableがなく、保存・権限が破綻し得る。
- **Goal:** app artifact、migration、Edge Function、RLS、Geminiを一つのSHAへ固定する。
- **In scope:** drift detection、fresh-schema migration、function type/test/deploy manifest、two-account hosted journey、artifact checksum、rollback point。
- **Out of scope:** 新機能、RLSを静的regexだけでPass扱いすること。
- **Existing relations:** QST-196〜201、327、332、336〜337を正式に閉じる。
- **Dependencies:** QST-338〜342。
- **Likely files:** GitHub Actions、Supabase manifests/scripts、Beta candidate/readiness evidence。
- **UX/Data/AI:** Quest/Mission/Task/Trail/Memory/Media/Route/AI全主要経路をhosted環境で確認。
- **Security/Accessibility/Analytics:** service-role worker、revoked consent、cross-account deny、audit traceを検証。
- **Happy acceptance:** candidate SHAからfresh deployし、Web/Android core journeyが同じtraceへ結び付く。
- **Failure acceptance:** drift、function mismatch、RLS failureでreleaseを自動停止する。
- **Negative/cross-account:** owner以外のCRUD、signed URL、RPC、route approvalを拒否。
- **Performance:** hosted p95、query count、function latencyをbaseline化。
- **Migration/rollback/flag:** migration rollback procedureとlast-known-good manifest。破壊的down migrationを自動化しない。
- **Evidence:** current-SHA manifest、CI logs、dual-account recording、checksum、Go/No-Go署名。
- **Score lift / residual risk:** +5。物理端末a11yはQST-350で閉じる。

## QST-344 First Ten Minutes Activation Journey

- **Priority:** Critical / P0
- **Background:** Onboardingが宣言Stepを飛ばし、用語・フォーム・AI説明が価値到達前に競合する。
- **User issue:** 何ができるか分からないまま離脱する。
- **Goal:** 10分以内に理解、同意、Quest確認、最初のTask開始まで到達させる。
- **In scope:** plain promise、trust step、wish input、必要時のみclarification、Quest confirm、first Task、resume state。
- **Out of scope:** 全用語紹介、Guild、Premium、長いtutorial。
- **Existing relations:** QST-088、141〜148、233、260、322〜323をMerge/Improve。
- **Dependencies:** QST-338〜343。
- **Likely files:** Splash/Login/Signup/Onboarding/Arc/Quest create、analytics、integration tests。
- **UX/Data/AI:** 初回に紹介する固有語はArc、Quest、今日の一歩まで。Mission/Task/Trailは必要時に説明。
- **Security/Accessibility/Analytics:** trust理解前にpersonal promptを送らない。step semantics、Back、IME、resumeを実装。
- **Happy acceptance:** 新規ユーザーが10分以内に最初のTaskを開始し、親Questを説明できる。
- **Failure acceptance:** AI/通信/保存失敗でも入力を失わず、manualまたは後で再開できる。
- **Negative/cross-account:** incomplete onboardingを別accountへ引継がない。
- **Performance:** first interactive 1.5秒目標、AI待機の進捗とcancel。
- **Migration/rollback/flag:** onboarding version/state追加。旧userを強制再onboardingしない。
- **Evidence:** 5 cohort moderated test、first-Quest >=70%、用語理解>=80%、drop-off funnel。
- **Score lift / residual risk:** +4。実継続はQST-345〜347で確認。

## QST-345 Unified Today Focus and Completion Loop

- **Priority:** High / P1
- **Background:** Home、Quest、Mission、Taskが別々に次行動を示し、empty stateやdeep linkが不一致。
- **User issue:** 今日何をすべきか、完了後どこへ進むか迷う。
- **Goal:** 一つのFocus selectorと`Task -> Progress -> Trail -> Horizon`契約を全画面で共有する。
- **In scope:** primary Task最大1、secondary最大2、parent context、completion、Trail prompt、rest/Horizon、dead CTA修正。
- **Out of scope:** social ranking、forced streak、無限feed。
- **Existing relations:** QST-207、334、331〜337をImprove。
- **Dependencies:** QST-344。
- **Likely files:** Home、Quest workspace、Task、Trail、Horizon、router/deep links、analytics。
- **UX/Data/AI:** 所要時間、理由、親Missionを短く表示。完了後は祝福、記録、休憩を選べる。
- **Security/Accessibility/Analytics:** Focusの理由を説明可能にし、実行本文をanalyticsへ送らない。
- **Happy acceptance:** HomeとQuestで同じprimary Taskが出て、完了後に進捗・Trailへ一貫遷移する。
- **Failure acceptance:** stale/deleted Taskでは再選定し、壊れたdeep linkをsafe parentへ戻す。
- **Negative/cross-account:** 他account Task IDを表示・完了しない。
- **Performance:** Focus計算16ms、Home initial queryをbounded/batchedにする。
- **Migration/rollback/flag:** 原則migration不要。selector versionをflagでrollback可能。
- **Evidence:** cross-screen golden、deep-link integration、completion journey、empty/offline tests。
- **Score lift / residual risk:** +4。選定品質は個人差が残る。

## QST-346 Gentle Recovery and Non-Coercive Arc Policy

- **Priority:** High / P1
- **Background:** 停滞支援は分散し、Bond、lonely表情、通知が罪悪感や関係依存を生む可能性がある。
- **User issue:** 遅れたユーザーが責められたと感じ、戻れない。
- **Goal:** 停滞を航路調整として扱い、Arcの介入量と非依存性を明示的に制御する。
- **In scope:** pause/resume、smaller step、reschedule、notification pressure budget、Arc copy corpus、relationship safety review。
- **Out of scope:** 医療診断、危機介入の代替、人間関係の代替を示すcopy。
- **Existing relations:** QST-074、076、082、141、194〜195をImprove。
- **Dependencies:** QST-340、345。
- **Likely files:** Arc copy/services、Signal、experience settings、route replanning、evaluation corpus。
- **UX/Data/AI:** `休む`を正規選択肢にする。Arc不在・Memory OFFでもQuest管理可能。
- **Security/Accessibility/Analytics:** crisis contentは地域reviewed flow。wellbeing signalを個人評価/企業共有へ使わない。
- **Happy acceptance:** 遅延時に責めず4択を提示し、拒否した提案を繰返さない。
- **Failure acceptance:** safety classification不明時は断定せず適切なhelpを案内。
- **Negative/cross-account:** `Arcが寂しい`、loss aversion、rank剥奪、過剰pushをcorpusで拒否。
- **Performance:** 通知/提案cooldownをserver時刻で適用。
- **Migration/rollback/flag:** intervention event/preference追加。Arc proactivityを即時OFF可能。
- **Evidence:** non-coercion corpus、wellbeing user study、notification pressure audit。
- **Score lift / residual risk:** +3。長期因果は継続観測が必要。

## QST-347 Meaningful Progress Metrics and Experimentation

- **Priority:** Critical / P0
- **Background:** chat回数や作成eventはあるが、週次の意味ある前進とtrust/wellbeing guardrailがない。
- **User issue:** 改善が本当にQuest達成へ寄与するか判断できない。
- **Goal:** WMPU、Activation、D7/D30、Trust、Wellbeing、AI原価を一つのmetric treeで計測する。
- **In scope:** canonical events、funnel、cohort、experiment assignment、guardrail、data minimization、dashboard spec。
- **Out of scope:** raw conversation analytics、dark-pattern最適化、広告targeting。
- **Existing relations:** QST-089、206、274、Analytics specsをMerge。
- **Dependencies:** QST-344〜346。
- **Likely files:** analytics enum/service/repository/migrations、metrics docs、CI taxonomy verifier。
- **UX/Data/AI:** eventは結果とユーザー選択を区別。Arc提案のaccept/edit/reject後の前進を測る。
- **Security/Accessibility/Analytics:** purpose consent、retention、deletion、small cohort privacy thresholdを適用。
- **Happy acceptance:** first wishからWMPU、D7まで欠損なく追跡し、本文なしでcohort比較できる。
- **Failure acceptance:** analytics failureでcore UXを壊さず、欠損率を可視化する。
- **Negative/cross-account:** raw text/PII、別account ID、未同意event送信を拒否。
- **Performance:** event enqueueはUIをblockせず、batch/retry上限を持つ。
- **Migration/rollback/flag:** taxonomy versionとretention migration。experimentを即時停止可能。
- **Evidence:** event contract tests、synthetic funnel、privacy review、dashboard screenshot。
- **Score lift / residual risk:** +4。指標は価値の代理であり、人間研究を併用する。

## QST-348 Cursor-Paginated Journey Data Plane

- **Priority:** High / P1
- **Background:** hard limitがpaginationでなく全件置換として動き、Trail mediaはN+1。
- **User issue:** 長く使うほど古いMission/Task/Trailが見えなくなり、読み込みが遅い。
- **Goal:** 親単位の完全性を保つcursor paginationとbatch mediaを実装する。
- **In scope:** Quest/Mission/Task/Trail/Guild keyset pagination、paged Riverpod state、batch attachments、indexes、EXPLAIN fixture。
- **Out of scope:** sharding、多地域write、無限scroll。
- **Existing relations:** QST-051、067、289〜296、Performance limitsをImprove。
- **Dependencies:** QST-343、347。
- **Likely files:** repositories/controllers/performance limits、migrations/indexes、load tests。
- **UX/Data/AI:** load more/end state/retryを明示し、親Quest/Missionの件数と整合する。
- **Security/Accessibility/Analytics:** cursorへowner情報を信頼しない。load moreをscreen readerで操作可能にする。
- **Happy acceptance:** 100+ Mission、500+ Task、200+ Trailを欠落・重複なく巡回できる。
- **Failure acceptance:** page失敗で既存pageを保持し、retryできる。
- **Negative/cross-account:** forged cursorで他account行を取得しない。
- **Performance:** p95 query、rows scanned、payload、query count budgetを定義。Trail media N+1を0にする。
- **Migration/rollback/flag:** index migration。旧bounded queryへ一時rollback可能だが欠落warningを出す。
- **Evidence:** large fixture、EXPLAIN、network trace、memory profile。
- **Score lift / residual risk:** +3。1M超のpartitionは実測後。

## QST-349 Unified Durable Mutation and Conflict Recovery

- **Priority:** High / P1
- **Background:** Taskにはoutbox/versionがあるがQuest/Mission/Trail/Mediaはoptimistic upsert中心。
- **User issue:** offline、再起動、同時編集で保存が消えるか重複する。
- **Goal:** 全core mutationにidempotency、version、durable queue、conflict UXを適用する。
- **In scope:** create/update/delete、offline outbox、retry/backoff、reconnect、row version、conflict resolution、mutation status。
- **Out of scope:** collaborative real-time editing、CRDT。
- **Existing relations:** QST-041、196、261〜267、332のTask patternを横展開。
- **Dependencies:** QST-343、348。
- **Likely files:** Quest/Mission/Trail/Media repositories/controllers、RPC/migrations、offline storage。
- **UX/Data/AI:** 保存中/済/失敗/競合を共通表示し、ユーザー入力を失わない。
- **Security/Accessibility/Analytics:** encrypted local queue、logout purge、owner/version check、status live region。
- **Happy acceptance:** offline作成後の再起動・再接続で一度だけ保存される。
- **Failure acceptance:** server conflict時にremote/local差分と選択肢を示す。
- **Negative/cross-account:** logout後queueを次accountへ送らず、replayを拒否。
- **Performance:** queue drainをbounded concurrency、UI thread非blockで実行。
- **Migration/rollback/flag:** row version/RPC migration。feature別outbox flag。client直接mutationへsilent rollbackしない。
- **Evidence:** fault injection、restart、parallel update、two-account tests。
- **Score lift / residual risk:** +3。端末故障前の未同期データは完全保証できない。

## QST-350 Quest Branch IA and Accessibility Closure

- **Priority:** High / P1
- **Background:** Home/Quest/Taskの重なり、Nav overlay、focus低contrast、label縮小、motion/haptic bypassが残る。
- **User issue:** 小画面、200% text、keyboard、TalkBackで主要行動へ到達しづらい。
- **Goal:** shipped routeの情報設計とphysical accessibilityを一つのrelease gateで閉じる。
- **In scope:** dead CTA、shell consistency、bottom inset、focus 3:1、no text scaleDown、semantic headings、Back/focus restore、global motion/haptic policy、IME。
- **Out of scope:** 全画面の装飾刷新、iOS配布をしない場合のVoiceOver。
- **Existing relations:** QST-101、141、208、260、266、297、337をImprove。
- **Dependencies:** QST-344〜349。
- **Likely files:** navigation/theme/core screens/forms/experience settings、widget/integration tests。
- **UX/Data/AI:** primary CTA一つ、説明より操作を先にする。Arc quick actionsをclipしない。
- **Security/Accessibility/Analytics:** TalkBack、Switch Access、external keyboard、日本語IME、200% text、reduced motion。
- **Happy acceptance:** compact/medium/expandedで主要journeyを完走し、読み上げ順とfocusが自然。
- **Failure acceptance:** loading/error/modal後にfocusが失われず、内容が重ならない。
- **Negative/cross-account:** accessibility設定がaccount切替で意図せず漏れない。
- **Performance:** animation budget、jank、layout overflow 0。
- **Migration/rollback/flag:** UI migration不要。新shell flagで段階rollout、a11y修正は原則保持。
- **Evidence:** physical Android録画、TalkBack transcript、IME、golden、contrast report。
- **Score lift / residual risk:** +4。iOS配布前にVoiceOverを追加する。

## QST-351 Japan Wedge, Plain Language, and Pricing Validation

- **Priority:** High / P1
- **Background:** 対象市場が広く、固有語と若いtoneが働く大人・40〜60代・AI抵抗層へ負荷になる。
- **User issue:** 自分向けか理解できず、支払う価値も判断できない。
- **Goal:** 最初の日本cohortと価値提案、tone、価格仮説を定量・定性で選ぶ。
- **In scope:** 学生/働く人/親/40〜60/AI抵抗層のdiscovery、plain aliases、Arc tone modes、¥480/780/980 test。
- **Out of scope:** hard paywall、家族共同機能、未成年提供。
- **Existing relations:** QST-088、213、Premium specsをValidate。
- **Dependencies:** QST-344〜350。
- **Likely files:** research plan/results、copy/ARB、store listing、feature flag。実装は検証で必要な最小限。
- **UX/Data/AI:** 初出は`Quest（叶えたい目標）`等の補助語。defaultは主語省略の丁寧な日本語。
- **Security/Accessibility/Analytics:** research consent、匿名化、cohort fairness。AI抵抗層へ非AI/manual pathを提示。
- **Happy acceptance:** 一つのwedgeをcomprehension、activation、D7、trust、WTPで選定する。
- **Failure acceptance:** どのcohortもgate未達なら対象を広げず価値提案を再設計。
- **Negative/cross-account:** 未検証価格を本番課金へ接続しない。
- **Performance:** 対象外。
- **Migration/rollback/flag:** pricing experiment flagのみ。billing migrationなし。
- **Evidence:** interviews、moderated study、price sensitivity、decision record。
- **Score lift / residual risk:** +4。市場仮説は継続更新する。

## QST-352 English Productization and International Format Matrix

- **Priority:** High / P1
- **Background:** English localeを宣言するがUIとAI promptはほぼ日本語。
- **User issue:** 英語端末でも日本語が混ざり、日付・週・通貨・時刻を誤解する。
- **Goal:** `en-US/en-GB`を完全なproductとして成立させ、将来localeの技術基盤を作る。
- **In scope:** visible/generated strings、AI locale、store copy、dates/time/week/plural/currency scaffolding、UTC/DST、directional layout、RTL smoke。
- **Out of scope:** 全地域同時launch、機械翻訳だけの出荷。
- **Existing relations:** QST-213、Internationalization specsを更新。
- **Dependencies:** QST-351で日本wedgeを確認後。
- **Likely files:** ARB/localizations、all screens、Edge prompts、date/domain types、store assets、tests。
- **UX/Data/AI:** first-use用語は最大3つ。英語AI回答とUIのlocaleを一致させる。
- **Security/Accessibility/Analytics:** regional privacy copy、RTL/focus、locale別safety corpus。
- **Happy acceptance:** en-US/en-GB core journeyが日本語混在なく完走する。
- **Failure acceptance:** missing translationをbuild/release gateで検出し、英語対応を宣言しない。
- **Negative/cross-account:** account locale変更で保存済みdomain valueを破損しない。
- **Performance:** localization bundleとformat処理のstartup影響を測る。
- **Migration/rollback/flag:** locale preference追加時migration。国別feature flagで段階展開。
- **Evidence:** English human review、DST/RTL matrix、localized E2E、legal approval。
- **Score lift / residual risk:** +4。EU/Canadaは地域別追加審査が必要。

## QST-353 Consentful Trail Sharing and Ethical Referral

- **Priority:** Medium / P2
- **Background:** Trailはprivate coreとして機能するが、安全なshare、invite、attributionがない。
- **User issue:** 前進を共有したいが、個人情報やMediaを誤って公開したくない。
- **Goal:** user-selected snapshotだけを安全に共有し、自然な紹介の増分効果を測る。
- **In scope:** field preview/redaction、private media default、revocable/expiring link、recipient preview、deferred deep link、share funnel。
- **Out of scope:** contact upload、forced invitation、public follower graph、reward spam。
- **Existing relations:** QST-077〜080、204、Trail specsをImprove。
- **Dependencies:** QST-339、347、350。
- **Likely files:** Trail share UI/model/RPC/storage policies、deep links、analytics、moderation。
- **UX/Data/AI:** share前に実際の受信画面をpreview。Arcは共有を促し過ぎない。
- **Security/Accessibility/Analytics:** token entropy、expiry/revoke、PII scanner、report/block。本文analytics禁止。
- **Happy acceptance:** 選んだfieldだけを共有し、後から即時revokeできる。
- **Failure acceptance:** unsafe media/PIIは公開せず修正案を示す。
- **Negative/cross-account:** guessed/revoked/expired link、source削除後accessを拒否。
- **Performance:** share landing p95 1.5秒、CDN/storage policyを検証。
- **Migration/rollback/flag:** immutable snapshot/links migration。public creation flagを既定OFF。
- **Evidence:** privacy review、abuse tests、share->D7 incremental experiment。
- **Score lift / residual risk:** +3。social pressureを継続監視。

## QST-354 Guild Quest Library Controlled Pilot

- **Priority:** Medium / P2
- **Background:** publication/copy基盤はあるが`/guild`はComing Soonで、copyは実際のPrivate Questを作らない。
- **User issue:** 他者の挑戦から学び、自分用に安全に始められない。
- **Goal:** curated供給で`discover -> preview -> copy -> adapt -> first progress`を小規模実証する。
- **In scope:** curated Quest、atomic private copy、versioned snapshot、attribution、creator status、moderation、appeal、server pagination/ranking。
- **Out of scope:** follower count、人気競争、無限feed、全面public launch。
- **Existing relations:** QST-079〜080、203、211、Guild FoundationをValidate/Improve。
- **Dependencies:** QST-347、353。
- **Likely files:** Guild UI/repository/RPC/migrations、ranking、moderation ops、analytics。
- **UX/Data/AI:** copy後はArcがユーザー制約に合わせるが、sourceを変更しない。
- **Security/Accessibility/Analytics:** publication review、block/report/appeal、privacy threshold、source/adopter RLS。
- **Happy acceptance:** 一transactionで新Private Questを作り、optional Missionをcopyし、first Taskへ到達する。
- **Failure acceptance:** supply不足、moderation SLA超過、trust悪化でpilotを停止する。
- **Negative/cross-account:** unpublished/blocked/unsafe source、二重copy、source mutationを拒否。
- **Performance:** newest-40 local rankingを廃止し、server cursorとload testを使う。
- **Migration/rollback/flag:** pilot cohort flag、publication/copy RPC。全ユーザーへ自動ONしない。
- **Evidence:** liquidity、adoption、first progress、D7 lift、safety cost、creator feedback。
- **Score lift / residual risk:** +4。増分retention未証明ならDefer継続。

## QST-355 Premium Boundary and Unit Economics Validation

- **Priority:** Medium / P2
- **Background:** Free/Premium原則はあるが、export/Guild boostの矛盾、価格・WTP・原価証拠がない。
- **User issue:** Core価値がpaywallで壊れるか、価値のない機能へ課金される恐れがある。
- **Goal:** 無料Coreを守りつつ、「伴走の深さ」の一つのpackageとunit economicsを検証する。
- **In scope:** export/Guild boost除外、Mission再設計/詳細review候補、price page test、margin/LTV/CAC model、quota連携。
- **Out of scope:** App Store billing本実装、paid Stardust/Rank、広告、企業優先表示。
- **Existing relations:** QST-087、330、Premium docsをCorrect/Validate。
- **Dependencies:** QST-342、347、351。
- **Likely files:** premium flags/spec、research artifacts、pricing experiment、economic model。
- **UX/Data/AI:** paywall前に利用量と価値を明示。Data rights、basic Arc、initial planningはFree。
- **Security/Accessibility/Analytics:** entitlement server verified、価格/条件をaccessibleに表示、cohort privacy。
- **Happy acceptance:** candidate packageがtrustを下げずWTPと継続意図を示す。
- **Failure acceptance:** margin/trust/retention gate未達ならbilling実装をDefer。
- **Negative/cross-account:** client flag、restore誤用、quota raceでPremium化しない。
- **Performance:** contribution margin >=70%、LTV/CAC >=3、payback <=12か月を仮Gateとする。
- **Migration/rollback/flag:** billing migrationなし。experiment即時停止。
- **Evidence:** price study、cohort model、AI cost ledger、decision record。
- **Score lift / residual risk:** +3。実際のpurchase behaviorは後続pilotが必要。

## QST-356 IP, Data Rights, and M&A Proof Pack

- **Priority:** High / P1
- **Background:** Arc asset、Quest DNA、Graph、Prompt、data rightsの権利・効果・譲渡可能性が未証明。
- **User issue:** 直接のUX課題ではないが、提携・資金調達・M&A時の継続性と信頼を損なう。
- **Goal:** 実装済み資産と未証明moatを分け、chain of titleとpermitted-use ledgerを作る。
- **In scope:** contributor assignment、asset/license/source、trademark search、dependency notice、data class/consent/processor/retention/export/delete、claims-to-evidence。
- **Out of scope:** moatの誇張、ユーザーデータ権利の包括取得、法務承認の代替。
- **Existing relations:** Master Spec Quest DNA/Challenge Graph/Enterprise、legal docsを補強。
- **Dependencies:** QST-339、340、347。
- **Likely files:** legal/IP register、asset manifest、data inventory、evaluation evidence、data room index。
- **UX/Data/AI:** ユーザー所有権と可搬性を維持。学習・集計利用を目的別に区別。
- **Security/Accessibility/Analytics:** data room access control、audit log、個人データを含めない。
- **Happy acceptance:** 各asset/data/model dependencyの権利、制約、証拠、ownerを追跡できる。
- **Failure acceptance:** 出所不明assetはrelease対象から外し、権利未確定claimを表示しない。
- **Negative/cross-account:** consentで許可されない集計・譲渡を資産として扱わない。
- **Performance:** 対象外。
- **Migration/rollback/flag:** 文書中心。必要なdata ledgerはappend-only。権利情報を削除してrollbackしない。
- **Evidence:** counsel review、signed assignments、license inventory、claims register。
- **Score lift / residual risk:** +3。市場価値はtractionに依存する。

## QST-357 10M Scale Observability, Backlog SSOT, and Phase Gate Review

- **Priority:** Critical / P0
- **Background:** 34種のstatus、複数Backlog、static verifier、SLO/alert不足が完了判定を曖昧にする。
- **User issue:** 未検証機能が完成扱いされ、障害と品質低下の発見が遅れる。
- **Goal:** runtime observability、10K〜10M scale stage、唯一のBacklog、固定100点再監査を一つの運用Gateにする。
- **In scope:** canonical status taxonomy、legacy backlog migration、crash/error/correlation ID、SLO/dashboard/alert、load stages、QST evidence linter、review cadence。
- **Out of scope:** 直ちに10M負荷を購入、premature sharding、点数基準の緩和。
- **Existing relations:** QST-200、206、256、270〜280、327、337をMerge/Closeする。
- **Dependencies:** QST-338〜356の証拠。
- **Likely files:** `docs/qst/BACKLOG.yaml`、qst tools、CI、observability specs/instrumentation、audit reports。
- **UX/Data/AI:** crash/AI error/support IDをユーザーへ平易に示し、traceでserverまで追える。
- **Security/Accessibility/Analytics:** log redaction、retention、alert access、auditability、statusのscreen reader notice。
- **Happy acceptance:** 一つのBacklogから状態/依存/証拠を生成し、current-SHAの100点監査を再現できる。
- **Failure acceptance:** Critical、SLO、legal、RLS、a11y未達でreleaseを自動NO-GOにする。
- **Negative/cross-account:** logs/dashboardでcross-tenant dataを見せず、static textだけでPassにしない。
- **Performance:** 10K/100K/1M/10Mのquery、AI、storage、moderation、support thresholdと投資triggerを定義。
- **Migration/rollback/flag:** status変換表、observability rollout flag。過去QST履歴は削除しない。
- **Evidence:** fixed-score audit、load reports、SLO drill、alert incident exercise、Backlog linter。
- **Score lift / residual risk:** 再採点。100点は到達宣言ではなく、次phaseへ進む証拠Gate。

## 実装順序

1. QST-338〜343: 外部配布をblockするCritical。
2. QST-344〜347: Activation、Retention、Wellbeing、計測。
3. QST-348〜350: 長期データ、保存信頼性、Accessibility。
4. QST-351〜352: 日本wedgeを先に証明し、その後に英語圏。
5. QST-353〜355: 単一ユーザー価値が成立した後のGrowth/Premium。
6. QST-356〜357: 権利・運用・scaleの正式Gate。
