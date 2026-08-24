# Questra 1,000万人監査 Traceability

> Audit: `QUESTRA_10M_PRODUCT_AUDIT_20260818.md`  
> QST detail: `docs/qst/QST-338-357_10M_PRODUCT_BACKLOG.md`

## Critical findings

| ID | Finding | Evidence | QST | Closure evidence |
|---|---|---|---|---|
| TM-001 | 未認証で保護画面へ到達できる | `app_router.dart` route redirect不在、実画面直アクセス | 338 | Web/Android deep-link auth E2E |
| TM-002 | mock/local/remoteの成功を区別できない | Arc fallback、mock persistence、candidate manifest | 338 | source disclosure、production mock prohibition |
| TM-003 | 18+と規約同意をenforceしていない | Signup、Terms、Legal sign-off | 339 | versioned eligibility/consent、legal signature |
| TM-004 | AI利用と外部処理を入力前に理解できない | Onboarding、Privacy draft、Arc entry | 339 | first-input disclosure usability evidence |
| TM-005 | Arc Memoryの全read/writeが同意に拘束されない | Arc screen `_rememberChat`、Memory extraction/retrieval | 340 | endpoint matrix、withdrawal、two-account RLS |
| TM-006 | Critic/repair/部分採用でAI計画がfail openし得る | Planning validators、approval path、evaluation harness | 341 | V2 200+ corpus、failure injection、hard gate |
| TM-007 | AI usage/cost/quotaが強制されない | entitlement migrationのNULL limit、provider telemetry | 342 | atomic reserve/settle concurrency evidence |
| TM-008 | current SHAとremote Supabaseの証拠が一致しない | Candidate `a5e0cad`、remote/local migration drift | 343 | exact-SHA manifest、hosted RLS、artifact checksum |
| TM-009 | 最初の10分が価値より用語・設定を優先する | Onboarding step jump、default Quest、実画面 | 344 | moderated activation、first Task start |
| TM-010 | 意味のある前進とtrust guardrailが計測不能 | Analytics taxonomy | 347 | WMPU/D7/D30/trust metric contract |

## High findings

| ID | Finding | QST | Key acceptance |
|---|---|---|---|
| TM-011 | Home/Quest/Taskの次行動が不一致 | 345 | 共通Focus selector、完了Trail loop |
| TM-012 | Arcの孤独・Bond・通知が依存圧力になり得る | 346 | non-coercion corpus、休む選択、pressure budget |
| TM-013 | hard limitが履歴を黙って切り捨てる | 348 | cursor pagination、per-parent completeness |
| TM-014 | Trail media N+1 | 348 | batch attachment、query count budget |
| TM-015 | Task以外のoffline mutationが再起動に弱い | 349 | durable outbox、idempotency、conflict UX |
| TM-016 | Nav overlay、focus contrast、text scaleDown | 350 | physical TalkBack/IME/200%/focus evidence |
| TM-017 | 日本の最初のcohortとWTPが未決定 | 351 | cohort decision、plain language、price study |
| TM-018 | English locale宣言と実装が不一致 | 352 | en-US/en-GB full journey、format matrix |
| TM-019 | Trail共有/referralが存在しない | 353 | revocable snapshot、referred D7 experiment |
| TM-020 | Guildはprototype/Coming Soonで閉ループでない | 354 | controlled library adoption pilot |
| TM-021 | Premium境界にexport/Guild boost矛盾 | 355 | candidates除外、free core contract |
| TM-022 | Arc asset/data/moatの権利と効果が未証明 | 356 | chain of title、permitted-use ledger |
| TM-023 | Backlog/status/証拠とruntime監視が分散 | 357 | SSOT linter、SLO、fixed-score re-audit |

## Score recovery model

点数増分は計画上の目安であり、QST完了だけでは加点しない。closure evidenceがcandidate SHAへ固定され、独立レビューでPassした場合のみ再採点する。

| Gate | QST | Expected evidence effect |
|---|---|---:|
| Release Truth | 338〜343 | +23まで |
| Activation/Retention | 344〜347 | +15まで |
| Reliability/Accessibility | 348〜350 | +10まで |
| Market/Global | 351〜352 | +8まで |
| Growth/Business/Diligence | 353〜356 | +13まで |
| Re-audit | 357 | score recalculation only |

理論上の増分を足して100点を宣言してはならない。相互作用、回帰、外部検証、残存riskを考慮してQST-357で固定配点を再採点する。

## Release decision hierarchy

1. QST-338〜343未完了: 外部Beta NO-GO。
2. QST-344〜350未完了: 招待制の限定検証を超えて拡大しない。
3. QST-351未完了: 日本のpaid acquisitionを開始しない。
4. QST-352未完了: 英語対応をStoreで宣言しない。
5. QST-353〜354未完了: Public Guild/viral loopを開かない。
6. QST-355未完了: Billing SDKを本番導入しない。
7. QST-356未完了: moat、network effect、企業効果を現在形で主張しない。
