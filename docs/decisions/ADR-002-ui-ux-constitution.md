# ADR-002: UI/UX Constitution and Release Experience Gate

- Status: Accepted
- Date: 2026-08-09
- Decision owners: Product / Design / Technology / Trust
- Master Spec: `docs/QUESTRA_MASTER_SPEC_V2.md` v2.1
- Evidence: `reports/qst/UI_UX_100_POINT_AUDIT_20260809.md`

## Context

QuestraにはArc、Quest、Mission、Task、Trailの主要機能が存在する一方、画面単位の実装完了と、ユーザーが一続きの旅として理解できる状態が一致していなかった。実画面監査では、Primary CTAの競合、再読み込み時のArc相談消失、画面surfaceの分断、320px幅の省略、未認証routeの直接到達、開発用fallbackと実保存の識別不足が確認された。

これらは個別Widgetの見た目だけでは解決できず、今後の画面設計とBeta判定へ共通する上位原則が必要である。

## Decision

Master Spec v2.1へProduct Experience Constitutionを追加し、次を恒久要件とする。

1. 中心導線を `Arc相談 → Quest確認 → Mission生成 → Task・今日の一歩 → 進捗 → 達成 → Trail → Horizon` とする。
2. 主要画面へ3秒ルールと1画面1主要CTAを適用する。
3. Homeは今日の最小Taskを親Mission・Questの文脈付きで示す。
4. 主要画面はInitialからPermission deniedまでの状態完全性を持つ。
5. AI、Arc、ユーザー、企業、モックの情報源を区別し、架空の個別状態を実データとして見せない。
6. 未完成機能はComing Soon、Navigation非表示、Beta対象外のいずれかを明示的に選ぶ。
7. 認証routeと配布構成をfail-closedにし、開発用fallbackはDemo Modeとして識別する。
8. 320px、200%文字、日本語IME、キーボード、Screen readerをBeta Gateに含める。
9. Master Spec、Design Bible、Screen Bible、QST、監査証跡の責務を分離する。

## Current Beta Navigation Decision

QST-197のRelease Decisionを現在の基準とし、Primary Navigationは `Home / Quest / Arc / Trail / Profile` とする。GuildはBeta対象外のComing Soonとし、通常Navigationへ復帰させる場合は独立したRelease Decisionを必要とする。既存の `docs/architecture/mvp-navigation.md` は実装QSTでこの決定へ同期する。

## Consequences

- 画面の完成判定は、Content状態だけでなく失敗、復帰、認証、レスポンシブ、アクセシビリティを含む。
- QST完了後でも、現在の候補SHAでAcceptanceを満たさない場合は回帰として再オープンできる。
- Design BibleはTokenとComponent、Screen Bibleは画面状態とroute契約を所有する。
- 実装詳細や一時的不具合はMaster Specへ記載せず、監査指摘とQSTへ保持する。
- Beta公開にはCritical 0件とcandidate SHAへ結び付いた実環境証跡が必要になる。

## Alternatives Considered

### 個別画面の修正だけで対応する

短期的には速いが、別画面で同じ問題が再発し、QST完了と体験完成の差が残るため採用しない。

### Design Bibleだけを更新する

視覚ルールは整理できるが、認証、状態完全性、情報源の透明性、Release GateはProduct Constitutionの責務であるため不十分と判断した。

### 未確認項目を減点せず実装済みとして扱う

実環境でのデータ復元、RLS、TalkBack、IMEを証明できず、Betaの信頼性を誤認させるため採用しない。

## Migration

- QST-319以降で認証、Home、Navigation、Quest入口、Onboarding、回復状態、Screen Bible、最終Evidence Gateを段階的に実装する。
- QST-299とQST-300は実画面回帰を理由に再オープンする。
- QST-260、QST-269、QST-274は自動Web/Android証跡を認めつつ、物理端末とアクセシビリティ証跡が揃うまで正式完了にしない。

## Review

QST-327のUI/UX Candidate Evidence Gate、Beta Go / No-Go、または中心導線の変更時に本Decisionを再確認する。
