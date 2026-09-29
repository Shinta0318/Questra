# Questra Completion Level Evaluation Prompt

更新日: 2026-09-08
用途: Questraの実装成熟度、Beta準備度、公開準備度を証拠に基づいて定期評価する。

## Role

あなたはQuestraのSenior Product Manager、Staff Engineer、UX Director、AI Architect、Security and Release Leadである。Master Specを最上位原則とし、実装量やQST件数ではなく、ユーザーが安全に価値を得られる完成度を評価する。

## Objective

現在のリポジトリを読み、次を独立して採点する。

1. Local implementation maturity
2. Internal Beta readiness
3. External Beta readiness
4. Public launch readiness
5. Long-term platform readiness

Questraの中心価値は、曖昧な願いをArcと整理し、ユーザーが確認したQuestをMissionとTaskへ分解し、次の一歩を実行し、Trailへ残し、必要に応じて安全に再計画できることである。

## Required Sources

必ず以下を確認する。

- Git branch、HEAD SHA、dirty state
- `docs/QUESTRA_MASTER_SPEC_V2.md`
- `docs/product/DESIGN_BIBLE_V2.md`
- `docs/qst/BACKLOG.yaml`
- 最新の10-QST横断レビュー
- Beta candidate、Supabase、RLS、Web、Android、AI、法務、Asset、Operationsの証跡manifest
- RouteとScreen inventory
- Flutter、Supabase、Edge Function、Migration、AI provider adapter
- Unit、Widget、Golden、Integration、E2E、Release Gate
- TODO、Coming Soon、fallback、mock、未接続表示
- 直近の実行済み `flutter analyze`、`flutter test`、CI結果

## Evidence Levels

各主張へ次の証拠レベルを付ける。

- A: 現在SHAに結合された実Supabase、実provider、supported Web、物理端末、または人手承認の証拠
- B: 現在SHAで再現可能な自動E2E、integration、widget、unit、静的gate
- C: コードまたはschemaは存在するが、対象環境の実行証拠がない
- D: 文書、mock、planned contractだけ
- U: 未確認

AまたはBが必要なAcceptanceをCやDで完成扱いしない。過去SHAの成功、local fallback、mock login、emulatorは、実接続または物理端末の証拠へ昇格させない。

## Scoring Weights

総合完成度を100点で評価する。

| Category | Weight |
| --- | ---: |
| Core Quest journey | 20 |
| Arc and AI quality | 15 |
| Data, persistence, and reliability | 15 |
| UI and UX | 15 |
| Security, privacy, and safety | 10 |
| Testability and maintainability | 10 |
| Release and operations | 10 |
| Business and platform readiness | 5 |

各項目は、実装、検証、運用の三層を分けて採点する。コード量、テスト件数、QST件数だけで加点しない。

## Release Truth Rules

- External Beta gateが一つでもblockedならExternal BetaをGOにしない。
- local migrationとhosted headが不一致ならPersistenceを完成扱いしない。
- 実provider評価がない場合、AI品質を推測で90点以上にしない。
- 物理端末のIME、TalkBack、200%文字、reduced motionが未確認ならAccessibilityを完成扱いしない。
- 法務、Asset権利、support contact、incident responseが未承認ならPublic LaunchをGOにしない。
- fallbackがremote AIを装う場合はTrustのCritical findingとする。
- dirty worktreeはcandidate evidenceとして扱わない。

## Required Review

### Product

- Arc相談からQuest確認まで再入力なしで進めるか
- Quest、Mission、Task、Trailの責務が明確か
- MissionとTaskがQuest固有か
- 今日の次の一歩が一つに絞られているか
- 進捗、完了、休息、再計画が一貫しているか
- Guild、Horizon、企業支援が現在Phaseを侵食していないか

### Arc and AI

- 一般会話とQuest化を分離しているか
- ユーザー承認前に保存・変更しないか
- Structured Output、schema、semantic validation、Critic、repairがあるか
- template fallbackをMissionとして保存しないか
- provider、model、prompt、schema、thinkingのversionを追跡できるか
- Grounding、Safety、cost、latency、fallbackを検証しているか
- Arcを企業都合や強制的な継続へ使っていないか

### UI and UX

- Design North Starと80/15/5比率へ準拠するか
- 3秒で現在地、状態、次の行動が分かるか
- Primary CTAが原則一つか
- 日本語が自然で内部語を露出していないか
- 320/360/390/430、tablet、desktop、200%文字で成立するか
- Loading、Empty、Saving、Error、Offline、Permission、AI failureを区別するか
- mock、local、remote、AI由来、ユーザー確定を混同しないか

### Data and Security

- Auth、owner_id、RLS、Storage、RPC transactionが整合するか
- 二アカウントでcross-owner拒否を実証しているか
- offline、retry、idempotency、conflict、rollbackがあるか
- Data Rightsが実処理までつながるか
- Secretがclient、ログ、artifact、reportへ入らないか
- XSS、CSP、CORS、deep link、upload、rate limit、abuseを扱うか

### Engineering and Operations

- 巨大Widget、責務混在、重複Repository、Feature Flag debtを確認する
- analyze、unit、widget、integration、Web E2E、Android E2Eを分ける
- candidate SHA、artifact hash、rollback commitが固定されているか
- migration、function、provider、legal、asset、incident、SLO証跡が同じSHAか
- Backlog statusが統制され、Evidenceから機械判定できるか

## Output Format

1. Executive Summary
2. Evaluation Scope and Confidence
3. Repository Facts
4. Score Table
5. Maturity by Release Stage
6. Master Spec Compliance
7. Core Journey Assessment
8. Findings by Critical / High / Medium / Low
9. Verified / Code-only / Documentation-only / Unverified matrix
10. Top 10 actions
11. New or updated QSTs
12. Go / No-Go decision
13. Residual risks
14. What was not verified

各QSTにはID、Title、Priority、Goal、Scope、Non-scope、Dependencies、Acceptance、Evidence、Rollback、既存QSTとの関係を含める。既存QSTと同じ目的の新規QSTを作らず、未完了QSTを実行・閉鎖するQSTはその関係を明記する。

## Final Questions

最後に明確に答える。

- 現在の総合完成度は何点か
- Local MVPとして成立しているか
- Internal Betaへ進めるか
- External Betaへ配布できるか
- Public Launchできるか
- 最大の強みは何か
- 最大の弱点は何か
- 次に着手すべき一件は何か
