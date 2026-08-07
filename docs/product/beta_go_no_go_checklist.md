# Beta Go / No-Go Checklist

## Decision Scope

このchecklistは、Questra Internal Beta candidateを新しいtesterへ配布してよいかを判断する。
Public release、Store審査、外部一般公開の承認には使用しない。

## Current Decision

**NO-GO: evidence incomplete**

自動testは通過しているが、real Supabase project、cross-account RLS、real-device、Legal Reviewer、
operator/contact、candidate build identityの配布証跡が未確定である。Release Managerは全P0 gateが
揃うまでGOへ変更してはならない。

## Decision Rules

- `P0`: 1件でもFailまたはEvidence MissingならNO-GO。
- `P1`: owner、期限、回避策があり、主要導線を妨げない場合だけ条件付きGO候補。
- `P2`: Release Notesへ記載し、次回polishへ送れる。
- Open S0は常にNO-GO。Open S1はRelease ManagerとProduct Ownerの明示承認がない限りNO-GO。
- `Local fallback passed`をreal persistenceまたはremote Arc成功の証跡として扱わない。

## A. Candidate Identity

| ID | Gate | Priority | Required evidence | Owner |
| --- | --- | --- | --- | --- |
| A1 | versionとcommitが固定されている | P0 | `pubspec.yaml` version、commit SHA、build timestamp | Release Manager |
| A2 | 配布物が固定commitから生成された | P0 | build logとartifact checksum | Release Manager |
| A3 | Release Notesのcandidate commitが記入済み | P0 | `beta_release_notes_draft.md`配布版 | Release Manager |
| A4 | rollback先の直前安定commitが記録済み | P0 | rollback SHA | Engineering Owner |

## B. Automated Quality

| ID | Gate | Priority | Command / evidence | Pass rule |
| --- | --- | --- | --- | --- |
| B1 | Dependency resolution | P0 | `flutter pub get` | Exit 0 |
| B2 | Static analysis | P0 | `flutter analyze --no-pub` | No issues |
| B3 | Flutter tests | P0 | `flutter test --reporter compact` | All pass |
| B4 | RLS static readiness | P0 | `dart run tools/qst/verify_rls_readiness.dart` | Pass |
| B5 | Performance readiness | P1 | `dart run tools/qst/verify_performance_readiness.dart` | Pass |
| B6 | Feedback readiness | P1 | `dart run tools/qst/verify_beta_feedback_readiness.dart` | Pass |
| B7 | Error capture contract | P1 | `dart run tools/qst/verify_beta_error_capture_readiness.dart` | Pass |
| B8 | Privacy copy contract | P0 | `dart run tools/qst/verify_beta_privacy_copy_readiness.dart` | Pass |
| B9 | Release Notes contract | P1 | `dart run tools/qst/verify_beta_release_notes_readiness.dart` | Pass |

結果にはcommand、date、commit、exit code、summaryを残す。過去commitの結果を流用しない。

## C. Supabase and Ownership

| ID | Gate | Priority | Required evidence | Stop condition |
| --- | --- | --- | --- | --- |
| C1 | Beta Supabase projectが固定済み | P0 | project ref、region、owner | 未作成・不明 |
| C2 | Migration適用済み | P0 | migration list / CI log | schema mismatch |
| C3 | AuthとProfile作成成功 | P0 | tester Aのlogin/profile evidence | sign-in/profile failure |
| C4 | Quest/Missionが再起動後も保存 | P0 | row IDと再login screenshot | data loss |
| C5 | Cross-account RLS分離 | P0 | tester A/Bのowner isolation log | 他account data表示 |
| C6 | Arc Memory owner境界 | P0 | A/B isolation evidence | memory leakage |
| C7 | Edge Function secretsがclientへ露出しない | P0 | deployment config review | API key exposure |

## D. Core Experience

| ID | Gate | Priority | Required evidence | Pass rule |
| --- | --- | --- | --- | --- |
| D1 | Home -> Arc -> Quest導線 | P0 | screen recording | 迷わず到達、crashなし |
| D2 | First Quest creation | P0 | create/save/restart recording | clear success/failure state |
| D3 | Mission adoption and completion | P0 | Arc Guideから完了まで | progress consistent |
| D4 | Arc Chat thinking/fallback | P1 | remote successとforced fallback | UXが壊れない |
| D5 | Empty account state | P0 | fresh account screenshot | demo dataなし |
| D6 | Logout / owner switch | P0 | A logout -> B login recording | A data残留なし |
| D7 | Trail included / Guild deferred state | P1 | Trail primary navigation + Guild Coming Soon screenshots | scopeを誤認しない |

## E. Device and Accessibility

| ID | Gate | Priority | Required evidence | Owner |
| --- | --- | --- | --- | --- |
| E1 | Android physical device | P0 | model、OS、Home/Quest/Arc screenshots | QA Owner |
| E2 | Small phone + large text | P1 | no-overflow screenshot set | QA Owner |
| E3 | Tablet / expanded layout | P1 | navigation and long-scroll evidence | QA Owner |
| E4 | Edge or Chrome web sanity | P1 | browser/version/result | QA Owner |
| E5 | iOS sanity when target includes iOS | P0 | device/simulator result | QA Owner |
| E6 | Keyboard and active input | P0 | Quest form and Arc Chat recording | QA Owner |

## F. Trust, Privacy, and Operations

| ID | Gate | Priority | Required evidence | Stop condition |
| --- | --- | --- | --- | --- |
| F1 | Beta data noticeが配布される | P0 | versioned notice | notice missing |
| F2 | OpenAI/Supabase処理が実装と一致 | P0 | code/config/copy review | provider omission |
| F3 | Operatorとprivacy/support contact確定 | P0 | approved contact | contact missing |
| F4 | Legal Reviewerが対象地域向けcopy承認 | P0 | dated sign-off | review pending |
| F5 | Feedback受付先とdaily triage owner確定 | P0 | channel、owner、SLA | reports受領不能 |
| F6 | External crash collector状態が説明と一致 | P0 | disabled evidenceまたはapproved config | hidden collection |
| F7 | Data export/delete未提供を明記 | P0 | Settings + Release Notes | 利用可能と誤認 |

## G. Issue State

- Open S0 count: `0`が必須。
- Open S1 count: `0`が原則。例外はowner、期限、回避策、tester影響、承認者を記録する。
- すべてのS0/S1へQST-125形式のQST candidateがある。
- 最新feedback batchがtriage済みである。
- Known limitationがRelease Notesと一致する。

## GO Sign-Off

次の4者が同じcandidate SHAに署名した場合のみGOとする。

| Role | Name | Decision | Date | Evidence link |
| --- | --- | --- | --- | --- |
| Release Manager |  | GO / NO-GO |  |  |
| Engineering Owner |  | GO / NO-GO |  |  |
| Product Owner |  | GO / NO-GO |  |  |
| Legal Reviewer |  | GO / NO-GO |  |  |

## Rollback Triggers

- S0 crash、起動不能、data loss、cross-account data exposure。
- Sign-in、Quest save、Mission completionが継続的に失敗する。
- API key、token、private contentがclient logや別accountへ露出する。
- Release Notesと異なるprovider/data collectionが有効になっている。
- 修正版を短時間で検証できず、tester影響を封じ込められない。

## Rollback Procedure

1. 新規tester invitationと配布linkを停止する。
2. Beta channelへ影響範囲、回避行動、data exposure有無を通知する。
3. Supabase Edge Functionまたはfeature flagで影響機能を停止する。
4. 記録済みrollback SHAのartifactへ戻す。破壊的DB rollbackは行わない。
5. Event、build、account、timestampを保存し、秘密情報や旅路本文をlogへ追加しない。
6. S0/P0 QSTを作成し、修正後にA-Gを新candidate SHAで再実行する。
7. Data exposureの疑いがあればPrivacy/Legal ownerへ即時escalationする。

## Evidence Index

```markdown
### Candidate
- Version:
- Commit:
- Artifact checksum:
- Built at:

### Automated checks
- Command / result / evidence path:

### Supabase
- Project ref / region:
- Migration evidence:
- Account A/B RLS evidence:

### Devices
- Device / OS / result / evidence path:

### Issues and approvals
- Open S0 / S1:
- Release Manager:
- Engineering Owner:
- Product Owner:
- Legal Reviewer:
- Decision: GO / NO-GO
```
