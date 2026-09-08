# QST-419 to QST-428 Beta Completion Sprint

## Purpose

新機能を広げる前に、現在のLocal MVPをcurrent-SHAのExternal Beta候補へ変える。QST-394〜401の未完了外部実行を置き換えず、その成果を同一候補へ結合して正式に閉じる。

## Shared Rules

- Master SpecとDesign Bibleを上位原則とする。
- mock、local fallback、過去SHA、emulator、静的testを外部実証へ代用しない。
- 秘密値、account識別子、private Quest内容を証拠へ保存しない。
- DBの破壊的rollbackを行わず、forward fixとapp artifact rollbackを分離する。
- blocked gateが一つでもあればExternal BetaはNO-GOとする。
- 各QSTは `reports/qst/QST-<ID>.md` を出力する。

## QST-419 Current Candidate Baseline Refresh

- Priority: Critical / P0
- Existing relation: QST-393のcandidate partitionを現在worktreeで実行し、QST-417/418を含める。
- Scope: intended diff inventory、secret scan、clean SHA、Web/Android artifact、checksum、rollback SHA、candidate manifest。
- Non-scope: Supabase配備、provider実行、distribution approval。
- Likely files: `docs/qst/BETA_CANDIDATE.yaml`、`CANDIDATE_PREFLIGHT.yaml`、candidate tool、QST report。
- Acceptance: clean SHAとartifact hashを固定し、stale/dirty/secret混入時はfail closed。
- Negative test: staged-only、untracked secret、rename、generated output、SHA mismatchを拒させる。
- Rollback: candidateをdraftへ戻し、artifactを配布対象から除外する。
- Expected score impact: Release and operations +1。

## QST-420 Hosted Supabase Drift Closure

- Priority: Critical / P0
- Existing relation: QST-394の実行完了QST。
- Scope: dry-run、backup確認、未適用migration、12 Function、secret name、remote readback。
- Non-scope: 本番ユーザーデータ作成、破壊的schema rollback。
- Likely files: `docs/qst/BETA_SUPABASE_PROJECT.yaml`、`HOSTED_EVIDENCE_RUN.yaml`、deployment scripts、QST report。
- Acceptance: local/hosted migration headとFunction inventoryがcandidateに一致する。
- Negative test: out-of-order migration、欠落Function、secret漏洩、partial deploymentを検出する。
- Rollback: app Function versionを前版へ戻し、DBはforward fixで回復する。
- Expected score impact: Data +2、Release +1。

## QST-421 Current-SHA RLS and Data Rights Acceptance

- Priority: Critical / P0
- Existing relation: QST-395とQST-368/374のcurrent-SHA実証。
- Scope: ephemeral two-account、owner CRUD、cross-owner拒否、Storage、Route RPC、Data Rights、cleanup。
- Non-scope: 実ユーザー、本番content、人手moderation判断。
- Likely files: RLS evidence manifests、dual-account runner、hosted evidence、QST report。
- Acceptance: owner正常系とcross-owner失敗系を全対象で通し、cleanup後にfixtureが残らない。
- Negative test: forged user ID、foreign parent、stale route、replayed request、service-only table access。
- Rollback: candidate distributionを停止し、影響Functionをpauseする。
- Expected score impact: Data +2、Security +1。

## QST-422 Supported Web Connected Journey Evidence

- Priority: Critical / P0
- Existing relation: QST-396とQST-417の実画面完了QST。
- Scope: supported browser、remote Auth/Persistence/Arc、core journey、reload、IME、responsive、error recovery。
- Non-scope: performance load test、unsupported browser、public distribution。
- Likely files: `WEB_CANDIDATE_SESSION.yaml`、sanitized screenshots、session report。
- Acceptance: registered userがArc相談からTrailまで進み、再loginで本人データを復元できる。
- Negative test: expired session、offline、provider timeout、double submit、browser back。
- Rollback: evidenceをinvalidへし、candidate approvalへ使わない。
- Expected score impact: Core +1、UI/UX +1、Release +1。

## QST-423 Physical Android Accessibility Evidence

- Priority: Critical / P0
- Existing relation: QST-397とQST-371/376の物理端末完了QST。
- Scope: physical Android、install、resume、TalkBack、200%文字、IME、compact、reduced motion、haptics opt-out。
- Non-scope: iOS、tablet全機種、store review。
- Likely files: `ANDROID_CANDIDATE_SESSION.yaml`、`PHYSICAL_ACCESSIBILITY_EVIDENCE.yaml`、sanitized evidence、QST report。
- Acceptance: 主要航路が読み上げと大文字でも操作でき、primary actionを失わない。
- Negative test: keyboard表示、rotation、process resume、permission denial、network loss。
- Rollback: candidateをdevice gate不合格としてdistributionから除外する。
- Expected score impact: UI/UX +1、Security/Trust +1、Release +1。

## QST-424 Arc Remote Provenance and Degraded Mode Boundary

- Priority: Critical / P0
- Existing relation: QST-410/418をruntime事実へ接続する新規改善。
- Scope: sanitized response provenance state、Settings反映、remote failure boundary、retry/manual/postpone。
- Non-scope: provider prompt変更、Mission品質改善、会話本文analytics。
- Likely files: Arc chat response/service/provider/screen、Settings connection state、tests、QST report。
- Acceptance: remote成功だけを確認済みとし、fallbackからQuest/Mission/Route操作を出さない。
- Negative test: timeout、malformed response、local preview、stale success、app restart、foreign trace。
- Analytics: provider名ではなくbounded source class、latency bucket、fallback reason codeだけを記録する。
- Feature flag: `ARC_REMOTE_PROVENANCE_V1`。
- Rollback: statusを常に確認待ちへ戻し、planning writeは引き続き禁止する。
- Expected score impact: Arc/AI +1、Trust +1。

## QST-425 Provider-backed Planning Quality Gate Execution

- Priority: Critical / P0
- Existing relation: QST-400の実provider評価完了QST。
- Scope: 200 planning、safety corpus、人手sample、schema、quality、grounding、usage、latency、cost。
- Non-scope: promptを評価中に変更すること、account追加によるquota迂回。
- Likely files: regression JSON、human review sheet、provider manifests、QST report。
- Acceptance: fixed configurationで全gateを測定し、未達ならactive化しない。
- Negative test: partial run、sample差替え、config drift、fallback混入、citation欠落、PII出力。
- Rollback: previous active prompt/model/schemaへ設定だけで戻す。
- Expected score impact: Arc/AI +2、Release +1。

## QST-426 Legal Asset and License Release Closure

- Priority: Critical / P0
- Existing relation: QST-398/399とdependency notice reviewの完了QST。
- Scope: named owners、contacts、legal versions、Arc chain of title、asset package、dependency licenses。
- Non-scope: 新しいmonetization terms、Enterprise contract、public marketing。
- Likely files: legal signoff、asset provenance、license manifest、Third Party Notices、QST report。
- Acceptance: signed current-candidate evidenceが揃い、未承認物をrelease artifactへ含めない。
- Negative test: hash drift、期限切れ承認、署名者欠落、unknown license、unapproved asset。
- Rollback: assetまたはdependencyをrelease packageから除外する。
- Expected score impact: Security/Trust +1、Release +1。

## QST-427 Runtime Operations and Evidence Status Normalization

- Priority: Critical / P0
- Existing relation: QST-401とQST-379/390の実演、およびBacklog SSOTの改善。
- Scope: feedback channel、owner、incident receipt、SLO alert、feature pause、artifact rollback、status taxonomy。
- Non-scope: production outage、real user notification、destructive DB rollback。
- Likely files: operations manifests、incident runner、Backlog、SSOT verifier、QST report。
- Acceptance: operations drillがcurrent candidateに結合され、QST statusとevidence stateを分離できる。
- Negative test: competing pause owner、missing receipt、stale SHA、unknown status、cleanup failure。
- Rollback: featureをpausedに保ち、candidate distributionを停止する。
- Expected score impact: Maintainability +1、Release +2。

## QST-428 QST-419 to QST-427 Completion Review

- Priority: Critical / P0
- Existing relation: 10-QST cadence review。QST-402の未完了findingも継承する。
- Scope: prompt再実行、same-SHA evidence、score、finding、Master Spec、Go/No-Go、next backlog。
- Non-scope: review中の新機能実装、blocked gateの推測合格。
- Likely files: cross-review report、Go/No-Go manifest、Backlog、readiness matrix。
- Acceptance: 全証拠を再計算し、blockedがあればNO-GOを維持する。
- Negative test: stale evidence、dirty candidate、hash mismatch、manual GO override。
- Rollback: 最新のverified NO-GO decisionへ戻す。
- Expected score impact: scoreの正確性と次の意思決定を改善。直接加点しない。
