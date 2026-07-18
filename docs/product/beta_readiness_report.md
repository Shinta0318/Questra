# Beta Launch Readiness Report

## Decision

**NO-GO for tester distribution**

Questraのアプリ実装と自動品質はInternal Beta候補に近い。一方で、実Supabase project、
cross-account RLS、実機、配布artifact、運営窓口、法務承認の証跡が不足している。
未確認を合格として扱わず、全P0 gateが揃うまでtester invitationを開始しない。

## Readiness Score

**66 / 100**

| Dimension | Weight | Earned | Evidence |
| --- | ---: | ---: | --- |
| Product and core flow | 30 | 28 | Home -> Arc -> Quest -> Mission、empty state、progress、fallback実装とtest |
| Automated quality | 20 | 20 | pub get、analyze、219 tests、RLS/performance/feedback/privacy verifiers |
| Supabase and security evidence | 20 | 5 | schema、RLS policies、behavior harnessあり。実project証跡なし |
| Device and distribution evidence | 15 | 4 | responsive automationあり。physical deviceとartifact evidenceなし |
| Trust, legal, and operations | 15 | 9 | data notice、Feedback、Go/No-Go運用あり。contactとLegal sign-offなし |
| **Total** | **100** | **66** | P0 evidence missingのためscoreに関係なくNO-GO |

Scoreは実装量ではなく、現在のcandidateを安全に配布できる証跡を評価する。Machine-readableな
状態は`docs/qst/BETA_LAUNCH_READINESS.yaml`をsource of truthとする。

## Automated Evidence

| Gate | Status | Evidence |
| --- | --- | --- |
| Dependency resolution | Pass | `flutter pub get` |
| Static analysis | Pass | `flutter analyze --no-pub` |
| Flutter tests | Pass | `flutter test --reporter compact`: 219 passed |
| RLS static readiness | Pass | 10 tables、37 policies、DB behavior harness確認 |
| Performance readiness | Pass | Arc assets、bounded queries、Thinking UI、README手順確認 |
| Feedback and triage | Pass | Intake、S0-S3、QST conversion verifier |
| Error capture contract | Pass | taxonomy、redaction、retention、Privacy gate verifier |
| Privacy copy | Pass | stored/processed data、provider、Beta limits verifier |
| Release Notes | Pass | ready、experimental、unavailable、stop states verifier |

これらはFlutter sourceとrepository contractを証明する。実Supabase、実機、運営承認を代替しない。

## Candidate Manifest

- Status: Validated, not distribution-ready
- App version: `1.0.0+1`
- Source commit: `faf69ffc8d4d94a108307d34061f4a835fc5e7fe`
- Rollback commit: `49ed2f50f24d3ac9d4a789befb58baf95cb1ae58`
- Automated gates: 9 passed
- Artifact: not built
- External evidence: missing

`docs/qst/BETA_CANDIDATE.yaml`はlocal fallbackと自動testをcloud/device/legal evidenceとして
扱わず、artifact checksumと外部証跡がない限り`distribution_ready: false`を維持する。

## Ready Surfaces

| Surface | Status | Notes |
| --- | --- | --- |
| Home | Ready | Arc、今日のMission、進行中Questを中心に表示 |
| Quest | Ready | Arc-led作成、編集、詳細、統一progress |
| Mission | Ready | 生成候補、採用、編集、並べ替え、today、完了 |
| Arc | Ready with fallback | remote生成とlocal fallback。provider設定の実証は未完了 |
| Profile | Ready | account ownerと旅路statusを表示 |
| Settings | Ready | Feedback、data processing、Arc Memory、planned controlsを説明 |
| Trail | Deferred | Primary surfaceはComing Soon。既存code/dataは保持 |
| Guild | Deferred | Primary surfaceはComing Soon。既存code/dataは保持 |

## Open P0 Blockers

### BLK-001 Supabase Project Evidence

- Beta用Supabase project ref、region、ownerが未確定。
- Migration適用logとEdge Function deployment evidenceがない。
- `SUPABASE_URL` / `SUPABASE_ANON_KEY`を使ったcandidate起動証跡がない。
- QST-160でlocal config、guarded bootstrap、sanitized evidence contract、cloud verifierは準備済み。
- `--require-cloud`は実project証跡が揃うまで意図的に失敗し、未確認を合格へ変換しない。

### BLK-002 Persistence and Cross-Account RLS

- Tester AでProfile、Quest、Missionを保存し、再login後に残る実証がない。
- Tester BからAのPrivate Quest、Mission、Arc Memoryが見えない実証がない。
- SQL behavior harnessはあるが、実databaseで未実行。
- QST-161でpassword-safe runner、migration/RLS evidence capture、strict cloud gateは準備済み。
- hosted project未認証のため実行証跡はなく、QST-160完了後もNO-GOを維持する。

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
- Trail / GuildをいつBeta scopeへ戻すかのrelease decision。

## Terminology and Product Constitution

- User-facing app sourceに旧`Story` product namingはない。
- ArcをAI Assistantとして扱うuser-facing copyはない。
- Arc provider利用は隠さず、Arcをjourney navigatorとして表示する。
- Privateな挑戦dataをGuildや企業へ自動共有しない。

## Recommended QSTs

| QST | Priority | Outcome |
| --- | --- | --- |
| QST-159 Beta Candidate Manifest Automation | P0 | version、commit、checksum、rollback、gate結果を固定 |
| QST-160 Supabase Beta Project Bootstrap | P0 | project contract、config、migration/deployment runbookを確定 |
| QST-161 Cloud Migration and RLS Evidence | P0 | 実DBへmigration適用しRLS harnessを実行 |
| QST-162 Dual Account Persistence Acceptance | P0 | A/B accountで保存・再login・分離を実証 |
| QST-163 Real Device Beta Validation Evidence | P0 | Android/Webと対象device classのevidenceを保存 |
| QST-164 Beta Support Operations Activation | P0 | contact、channel、owner、SLA、issue registerを運用開始 |
| QST-165 Legal and Privacy Sign-Off Closure | P0 | external Beta向けLegal Reviewer approvalを取得 |
| QST-166 Beta Candidate Build and Distribution | P0 | signed-off artifactを限定testerへ配布 |
| QST-167 Beta Go-Live Review | P0 | 全gateを再監査しGO/NO-GOを確定 |

## Completion Criteria

Internal Beta完成は次をすべて満たした状態とする。

1. QST-159〜165がDoneで、P0 evidenceがrepositoryまたは承認済みsecure locationにある。
2. Candidate SHAからartifactを生成しchecksumとrollback SHAを記録する。
3. Open S0が0、Open S1が0または承認済み例外である。
4. Release Manager、Engineering Owner、Product Owner、Legal Reviewerが同じcandidateへ署名する。
5. QST-167でGOとなり、限定testerへの配布とrollback手順が有効である。

## Final QST-130 Judgment

QST-121〜129でBetaの機能、Feedback、Privacy、Release Notes、Go/No-Go運用は準備された。
QST-130のreviewにより、Questraは**Technical Beta Candidate**だが、まだ**Operational Beta**では
ないと判断する。次はQST-159から証跡を埋め、NO-GOを解除する。
