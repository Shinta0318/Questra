# Questra Completion Evaluation 2026-09-08

適用プロンプト: `docs/qst/QUESTRA_COMPLETION_EVALUATION_PROMPT.md`
対象Branch: `codex/initial-questra-structure-pr`
対象HEAD: `5363e1f509b2b601e069b1fcfe109e438ddaa84a`
判定: **Local MVP成立 / 限定Internal Betaは条件付きGO / External Beta NO-GO / Public Launch NO-GO**

## 1. Executive Summary

Questraはprototypeの段階を越え、Arc相談、Quest、Mission、Task、Trail、再計画、Guild pilot、Data Rightsまでを持つ大規模なLocal MVPへ到達している。28 Route、28 Screen、77 Migration、12 Edge Function、215 Dart test filesがあり、今回の全Flutter testは769件、静的解析は0 issueだった。

一方、完成度を最も下げているのは機能不足ではなく、現在SHAに結合された外部証拠の不足である。候補manifestは過去SHAのdraft、hosted migrationはlocal headより古く、Webと物理Androidのcandidate sessionは未実行、provider-backed 200 case評価、法務承認、Arc asset権利、incident/SLO運用も未完了である。External Betaの12 gateは0 pass / 12 blockedであり、配布可能とは評価しない。

総合完成度は **66 / 100**。Local implementation maturityは高いが、外部βの運用品質と公開責任が追いついていない。

## 2. Evaluation Scope and Confidence

| Scope | Evidence | Confidence |
| --- | --- | ---: |
| Repository、Master Spec、Design Bible、Backlog | current worktree read | High |
| Flutter code、Route、test inventory | current worktree read and execution | High |
| Static analysis | `flutter analyze --no-pub` PASS | High |
| Regression | `flutter test --no-pub` 769 PASS | High |
| Supabase deployment | manifest read only; current executionなし | Low |
| Gemini quality | code and old smoke evidence; current provider runなし | Low |
| Web/Android UX | past screenshots and widget tests; current live sessionなし | Medium-Low |
| Legal、asset rights、operations | pending manifests | High for incompleteness |

監査信頼度は **84 / 100**。コードとローカル検証の評価は強いが、外部サービス、物理端末、利用者評価は未確認である。

## 3. Repository Facts

- Branch: `codex/initial-questra-structure-pr`
- HEAD: `5363e1f509b2b601e069b1fcfe109e438ddaa84a`
- Worktree: QST-417、418と本監査の未コミット変更あり
- Routes: 28
- Screen files: 28
- Dart test files: 215
- Integration test files: 2
- Latest full Flutter result: 769 tests PASS
- Migrations: 77
- Edge Functions: 12
- Large files: `arc_screen.dart` 3336 lines、`quest_detail_screen.dart` 4673 lines、`settings_screen.dart` 955 lines
- Localization: Japanese and English ARBあり。ただし画面内hard-coded copyが多く、完全移行ではない
- Backlog status labels: 30種類以上。実装済み、証跡待ち、配備待ちが分散している

## 4. Score Table

| Category | Weight | Score | Assessment |
| --- | ---: | ---: | --- |
| Core Quest journey | 20 | 16 | 階層と主要導線は実装・test済み。実provider・再起動・実保存のcurrent-SHA E2E不足 |
| Arc and AI quality | 15 | 10 | Structured planning、Safety、Critic契約は厚い。200 case実provider評価とfallback provenance不足 |
| Data, persistence, reliability | 15 | 9 | schema、RLS、RPC、offline契約あり。hosted driftとData Rights function未配備 |
| UI and UX | 15 | 11 | Design Bible、responsive/widget証拠あり。current UIの実Web/Android全面確認なし |
| Security, privacy, safety | 10 | 7 | fail-closed契約、RLS、secret hygieneあり。current-SHA hosted/physical/operations証明なし |
| Testability and maintainability | 10 | 8 | 769 testsとrelease gatesは強い。巨大画面と少ないintegration testsが負債 |
| Release and operations | 10 | 3 | candidate、incident、SLO、support、legalが未完了 |
| Business and platform readiness | 5 | 2 | FoundationはあるがGuild、支援、PremiumはBeta境界または未接続 |
| **Total** | **100** | **66** | **Local MVPは成立、External BetaはNO-GO** |

## 5. Maturity by Release Stage

| Stage | Score | Decision |
| --- | ---: | --- |
| Local implementation maturity | 84 | GO |
| Local MVP completeness | 82 | GO |
| Controlled internal review | 72 | 条件付きGO。mock/local/remoteを明示し実データを扱わない |
| Connected internal Beta | 56 | NO-GO。current hosted driftとcandidate evidenceを閉じる必要あり |
| External Beta | 38 | NO-GO。12 gate blocked |
| Public Launch | 27 | NO-GO。法務、権利、物理端末、運用が不足 |
| Long-term platform readiness | 44 | Foundation段階。運用実績とscale evidenceなし |

## 6. Master Spec Compliance

Local code compliance: **82%**
Release evidence compliance: **52%**

満たしている点:

- Quest → Mission → Task → Trailの責務が仕様化され、Widget/Domain testがある。
- Arc一般会話とQuest化同意、AI失敗時に固定Missionを保存しない契約がある。
- Story旧称を主要表示から排除している。
- local/mock/remoteを区別し、秘密情報をclientへ渡さない設計がある。
- User ownership、RLS、Data Rights、Safetyを設計対象に含めている。

未達:

- 現在候補SHAに結合されたhosted、provider、device、legal、asset、operations証拠。
- 実Gemini品質、Grounding鮮度、cost/latency gateの実測。
- 物理端末Accessibility。
- Guild、企業支援、Premiumを正式に提供するためのPhase gate。
- 全画面copyのLocalization SSOT化。

## 7. Core Journey Assessment

| Journey | State | Evidence |
| --- | --- | --- |
| Arc相談 → Quest確認 | Implemented | B: Widget/unit、QST-410 |
| Quest確認 → Mission/Task計画 | Implemented, provider unverified | B/C |
| Mission/Task実行 → 進捗 | Implemented | B |
| Task → Trail | Implemented | B |
| 遅延 → 再計画 → 承認 | Implemented contract | B/C |
| Logout/Login → remote復元 | Not current-SHA verified | U |
| Two-account owner isolation | old evidenceのみ | C |
| Provider AI quality | current runなし | U |
| Web candidate journey | pending | U |
| Physical Android journey | pending | U |

## 8. Findings

### Critical

1. **External Beta gate 0/12**: candidate、hosted、RLS、Web、Android、Accessibility、legal、Data Rights、asset、license、operations、SLO、AI品質がcurrent SHAで閉じていない。
2. **Hosted drift**: local latest `202609030001_explicit_server_only_table_grants.sql` に対しremote headは `202608080006_route_proposal_stale_conflict_guard.sql`。`process-data-rights-requests`もlocal pending deployment。
3. **Candidate identity stale**: candidate manifestは過去SHAのdraftで、現在worktreeはdirty。artifact hashとrollback地点を配布候補として固定できない。
4. **Provider quality unverified**: 200 case planning/safety、人手評価、cost、latency、fallback率が実Geminiで未実行。
5. **Physical and legal evidence missing**: Android TalkBack、200%文字、IME、Arc asset chain of title、Product/Legal sign-offがない。

### High

1. **Arc degraded-mode provenance**: QST-418は準備状態を正直に表示するが、実際にremote応答を受けた時刻とsourceをsessionへ反映しない。remote失敗時のlocal responseがplanning候補を持てる境界も明示的に閉じる必要がある。
2. **Backlog state fragmentation**: 30種類以上のstatusにより、Doneと証跡待ちを機械的に集計しにくい。
3. **Architecture concentration**: Arc 3336行、Quest Detail 4673行、Settings 955行。変更影響、画面test、所有責務が大きい。
4. **Integration coverage imbalance**: 215 unit/widget filesに対してintegration testは2 files。実際のAuth、remote persistence、AI、reload境界の証明が弱い。
5. **Localization partial migration**: ARBはあるが多くの日本語copyがWidget内に残る。

### Medium

- Guild、企業支援、PremiumはFoundationまたは限定提供であり、現在Phaseでは正直に隠す/限定表示する必要がある。
- current Web/Android screenshot matrixがQST-403以降のUI変更へ追随していない。
- Backlogとevidence manifestの更新日・SHAが複数時点に分散する。

## 9. Keep / Improve / Defer

### Keep

- Master SpecとDesign BibleのRelease Truth原則
- Quest/Mission/Task/Trailの階層
- AI失敗時に固定Missionを保存しない方針
- 769件の自動回帰とfail-closed release gates
- Arcをユーザーの主体性より前へ出さない設計

### Improve now

- current-SHA candidateと外部証拠
- hosted migration/function drift
- Arc remote/fallback provenance
- physical Accessibilityとprovider評価
- Backlog status taxonomy

### Defer

- 複雑なPremium課金
- Public Guildの全面展開
- Enterprise offer配信
- Quest Passport/Score/Marketplace
- 3D Arc本実装

## 10. Next QSTs

QST-419〜428をBacklogへ追加した。詳細は `docs/qst/QST-419-428_BETA_COMPLETION_SPRINT.md` に記録した。既存QST-394〜401を置き換えず、未完了の外部実行を現在候補で閉鎖するcompletion sprintとして扱う。

| ID | Priority | Title | Primary outcome |
| --- | --- | --- | --- |
| QST-419 | P0 | Current Candidate Baseline Refresh | clean SHA、artifact、rollback、manifestを現在化 |
| QST-420 | P0 | Hosted Supabase Drift Closure | migration/function head一致 |
| QST-421 | P0 | Current-SHA RLS and Data Rights Acceptance | 二accountとData Rights実証 |
| QST-422 | P0 | Supported Web Connected Journey Evidence | WebでAuth/Core/Arc/IME証拠 |
| QST-423 | P0 | Physical Android Accessibility Evidence | 物理Android、TalkBack、200%文字 |
| QST-424 | P0 | Arc Remote Provenance and Degraded Mode Boundary | remote成功とfallbackを正しく分離 |
| QST-425 | P0 | Provider-backed Planning Quality Gate Execution | 200 case、人手評価、cost/latency |
| QST-426 | P0 | Legal Asset and License Release Closure | 法務、Arc権利、license承認 |
| QST-427 | P0 | Runtime Operations and Evidence Status Normalization | incident/SLO/supportとstatus統制 |
| QST-428 | P0 | QST-419 to QST-427 Completion Review | 同一SHAでGo/No-Go再判定 |

## 11. Final Decision

- 現在の総合完成度: **66 / 100**
- Local MVP: **成立**
- Controlled internal review: **条件付きで可能**
- Connected internal Beta: **未達**
- External Beta: **NO-GO**
- Public Launch: **NO-GO**
- 最大の強み: ArcとQuest階層を中心に、AI、Data、Safety、UIを同じProduct Constitutionへ統合していること
- 最大の弱点: 実装量に対してcurrent-SHAの外部証拠と運用責任が不足していること
- 次に着手すべき一件: **QST-419 Current Candidate Baseline Refresh**

## 12. Not Verified

本監査では本番/hosted DB変更、Gemini呼び出し、supported Web操作、Android物理端末、TalkBack、法務承認、asset権利承認、incident live drillを実行していない。未確認項目をPassへ置き換えていない。
