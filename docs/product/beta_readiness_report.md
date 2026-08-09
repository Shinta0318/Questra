# Beta Launch Readiness Report

## Decision

**NO-GO for tester distribution**

Questraのアプリ実装と自動品質はInternal Beta候補に近い。一方で、新しいArc Memory Taskと
Task Data Rights migration、現candidateのcross-account RLS、実機、配布artifact、運営窓口、法務承認の証跡が不足している。
未確認を合格として扱わず、全P0 gateが揃うまでtester invitationを開始しない。

## Readiness Score

**70 / 100**

| Dimension | Weight | Earned | Evidence |
| --- | ---: | ---: | --- |
| Product and core flow | 30 | 27 | Quest -> Mission -> Task -> Trail、Arc、Signal、offline recoveryを実装。UI監査の改善余地あり |
| Automated quality | 20 | 20 | pub get、analyze 0件、510 tests、RLS/performance/feedback/privacy verifiers |
| Supabase and security evidence | 20 | 14 | 実projectと既存RLS証跡あり。最新Task Memory/Data Rights migrationsは未配備 |
| Device and distribution evidence | 15 | 3 | device-capable E2Eとartifact checksum自動化あり。hosted/physical evidenceなし |
| Trust, legal, and operations | 15 | 6 | consent、Feedback、Go/No-Go運用あり。contactとLegal sign-offなし |
| **Total** | **100** | **70** | P0 evidence missingのためscoreに関係なくNO-GO |

Scoreは実装量ではなく、現在のcandidateを安全に配布できる証跡を評価する。Machine-readableな
状態は`docs/qst/BETA_LAUNCH_READINESS.yaml`をsource of truthとする。

## Automated Evidence

| Gate | Status | Evidence |
| --- | --- | --- |
| Dependency resolution | Pass | `flutter pub get` |
| Static analysis | Pass | `flutter analyze --no-pub` |
| Flutter tests | Pass | `flutter test --no-pub`: 510 passed |
| RLS static readiness | Pass | 40 tables、51 required policies、DB behavior harness確認 |
| Performance readiness | Pass | Arc assets、bounded queries、Thinking UI、README手順確認 |
| Feedback and triage | Pass | Intake、S0-S3、QST conversion verifier |
| Error capture contract | Pass | taxonomy、redaction、retention、Privacy gate verifier |
| Privacy copy | Pass | stored/processed data、provider、Beta limits verifier |
| Release Notes | Pass | ready、experimental、unavailable、stop states verifier |

これらはFlutter sourceとrepository contractを証明する。実Supabase、実機、運営承認を代替しない。

## Candidate Manifest

- Status: Draft, not distribution-ready
- App version: `1.0.0+1`
- Source commit: `a5e0cad266e1dd8b5e9fae65414c988c4342d409`
- Rollback commit: `1334712618716cbd0c5ce7d0f7dfa890bcf8200b`
- Automated gates: 9 passed
- Artifact: not built
- External evidence: missing

`docs/qst/BETA_CANDIDATE.yaml`はlocal fallbackと自動testをcloud/device/legal evidenceとして
扱わず、artifact checksumと外部証跡がない限り`distribution_ready: false`を維持する。

## Ready Surfaces

| Surface | Status | Notes |
| --- | --- | --- |
| Home | Ready | Arc、今日のTaskと親Mission、進行中Questを中心に表示 |
| Quest | Ready | Arc-led作成、編集、詳細、統一progress |
| Mission | Ready | 中間成果、Task生成、成果確認を表示 |
| Task | Ready | Missionに属する具体行動、進捗、完了条件を表示 |
| Arc | Ready with fallback | remote生成とlocal fallback。provider設定の実証は未完了 |
| Profile | Ready | account ownerと旅路statusを表示 |
| Settings | Ready | Feedback、data processing、Arc Memory、planned controlsを説明 |
| Trail | Included, verification pending | Quest -> Mission -> Task -> Trailの中核ループとしてPrimary Navigationへ復帰。Media実機証跡はQST-204で取得 |
| Guild | Deferred | Discovery、Moderation、RLSの実環境検証が完了するまでPrimary Navigationから除外 |

## Open P0 Blockers

### BLK-001 Supabase Project Evidence

- Beta用Supabase project、region、既存migrationとFunctionsの証跡は存在する。
- `202608090001_arc_memory_task_events.sql`と`202608090002_task_data_rights_operations.sql`はlocalのみで、remote headは`202608080006`のまま。
- Task Memoryのowner/parent guard、Data Rights export/delete RPC、削除連鎖を二アカウントで再実証する必要がある。

### BLK-002 Persistence and Cross-Account RLS (Resolved 2026-07-25)

- Questra Betaで31件のdatabase-backed RLS assertionを実行し、transaction rollbackを確認した。
- 一時Tester A/Bで再login後のProfile、Quest、Mission、Task、Trail、Arc Memory、Media、Route永続化を確認した。
- Tester Bと匿名ユーザーからPrivate Quest、Mission、Task、Trail、Arc Memory、Media row、Storage object、Routeを遮断した。
- Pending Guild publicationとowner mappingがTester Bおよび匿名ユーザーへ露出しないことを確認した。
- sanitized evidence: `docs/qst/BETA_RLS_EVIDENCE.yaml`、`docs/qst/BETA_DUAL_ACCOUNT_PERSISTENCE.yaml`。
- Candidate SHA固定後、同じverifierを再実行して配布candidateへ結び付ける。

### BLK-003 Candidate Artifact and Device Evidence

- Candidate commit、build timestamp、artifact checksum、rollback SHAが未固定。
- Android physical device、small/large text、keyboard、Web sanityの配布candidate証跡がない。
- iOSをBeta対象に含める場合、iOS sanity evidenceも必要。

### BLK-004 Beta Operations

- Privacy/support contact、Feedback受付channel、daily triage owner、response SLAが未確定。
- 最新Feedback batchのopen S0/S1 countを証明するissue registerがない。

### BLK-005 Legal Sign-Off

- Operator identity、target region、retention、Supabase/OpenAI project settingが未確定。
- Terms、Privacy Policy、Beta data noticeにLegal Reviewerのdated sign-offがない。

## P1 Readiness Gaps

- App iconとsplashの最終design。
- Tabletとlarge textの実機evidence。
- External crash collectorを導入しない期間のmanual incident運用演習。
- TrailのMedia実機証跡と、GuildをBeta scopeへ戻すためのDiscovery / Moderation / RLS完了判定。

## QST-197 Beta Scope Decision

- `Trail`: Initial Betaへ含める。QuestとMissionの進捗を旅の記録として残す中核体験であり、空状態、入力、Timeline、Mediaの実装が存在する。QST-204で実Supabase StorageとAndroid/WebのMedia証跡を取得するまでは、配布判定を`verification pending`とする。
- `Guild`: Initial Betaでは延期する。Discovery UIと永続化基盤は保持するが、参加、投稿、削除、Moderation、公開境界の実環境証跡が揃うまで利用可能とは表示しない。
- Product owner: Product / Release Manager
- Decision date: 2026-07-25
- Re-entry gate for Guild: QST-199、QST-203、QST-214〜220の必要範囲を完了し、公開データとPrivate Questの境界を実証すること。

## Terminology and Product Constitution

- User-facing app sourceに旧`Story` product namingはない。
- ArcをAI Assistantとして扱うuser-facing copyはない。
- Arc provider利用は隠さず、Arcをjourney navigatorとして表示する。
- Privateな挑戦dataをGuildや企業へ自動共有しない。

## Recommended QSTs

| QST | Priority | Outcome |
| --- | --- | --- |
| QST-283 Candidate Device and Artifact Evidence Closure | P0 | Android/Web E2E、artifact、IME/TalkBack証跡を固定 |
| QST-289 Arc Memory Task Event Integration | P0 | migration配備と二アカウントRLSを実証 |
| QST-290 Beta Candidate Manifest and Readiness Refresh | P0 | 現行candidateの全証跡を一つのmanifestへ統合 |
| QST-291 Task-Aware Data Rights Operations | P1 | Taskを含むexport/delete/訂正を実装 |
| QST-292 Long Route Task Performance Pass | P2 | 長期航路のframe/query budgetを実証 |
| QST-293 Decennial Cross Review | P0 | QST-283〜292を再監査しGO/NO-GOを更新 |

## Completion Criteria

Internal Beta完成は次をすべて満たした状態とする。

1. QST-283〜293のP0 evidenceがrepositoryまたは承認済みsecure locationにある。
2. Candidate SHAからartifactを生成しchecksumとrollback SHAを記録する。
3. Open S0が0、Open S1が0または承認済み例外である。
4. Release Manager、Engineering Owner、Product Owner、Legal Reviewerが同じcandidateへ署名する。
5. QST-167でGOとなり、限定testerへの配布とrollback手順が有効である。

## Final QST-130 Judgment

QST-121〜129でBetaの機能、Feedback、Privacy、Release Notes、Go/No-Go運用は準備された。
QST-130のreviewにより、Questraは**Technical Beta Candidate**だが、まだ**Operational Beta**では
ないと判断する。次はQST-159から証跡を埋め、NO-GOを解除する。
