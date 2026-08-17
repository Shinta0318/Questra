# UI/UX 100-Point Traceability

- Audit: `reports/qst/UI_UX_100_POINT_AUDIT_20260809.md`
- Master Spec: `docs/QUESTRA_MASTER_SPEC_V2.md` v2.1, Section 8.6 and Phase Gate
- Decision: `docs/decisions/ADR-002-ui-ux-constitution.md`
- Backlog: `docs/qst/BACKLOG.yaml`

| 指摘ID | 評価領域 | Master Spec | 既存QST | 新規・更新QST | Acceptance / Test | 目標点 |
| --- | --- | --- | --- | --- | --- | ---: |
| UX-001 | Auth / Navigation | 8.6, Phase Gate | 301, 312 | 319 | 未認証direct URL、reload、deep linkを認証へredirectするE2E | +3 |
| UX-002 | Persistence truth | 8.6, Phase Gate | 123, 301 | 319 | production設定欠落はfail-closed、Demo mode表示、保存誤認0 | +3 |
| UX-003 | Arc continuity | 8.6, 9, Phase Gate | 298 | 308, 314 | restart、owner switch、expiry、discard、duplicate防止 | +4 |
| UX-004 | Release evidence | Phase Gate | 301, 304, 309 | 312, 327 | hosted migration、RLS、Gemini、deviceを同一SHAへ固定 | +4 |
| UX-005 | Information architecture | 8.6 | 197, 299 | 321, 326 | route inventory、Primary nav、return contractのtest | +2 |
| UX-006 | Responsive | 8.6, Phase Gate | 300, 304 | 315, 321 | 320 / 390 / 768 / 200% golden、overflow 0 | +3 |
| UX-007 | Home truth | 8.6 | 123, 207 | 320 | real / loading / empty / error / hidden、fixture非表示 | +3 |
| UX-008 | Quest entry | 8.6, 10 | 155, 294, 295 | 322 | Arc-first、manual fallback、Primary CTA 1つ | +3 |
| UX-009 | Return navigation | 8.6 | 299 | 321 | Settings / Feedback / Data Rightsのbackとdeep-link fallback | +2 |
| UX-010 | Visual continuity | 8.6 | 208, 302 | 310 | semantic surface、contrast、cross-screen golden | +3 |
| UX-011 | Mutation recovery | 8.6, Phase Gate | 255, 277, 287 | 325 | saving / saved / failed / offline / retry、idempotency | +3 |
| UX-012 | Onboarding | 8.6 | 132 | 323 | progress、Back、Skip、resume、replay、IME | +3 |
| UX-013 | Empty states | 8.6 | 207, 208 | 320, 326 | 1 Primary CTA、架空データなし、compact copy | +1 |
| UX-014 | Mission / Task a11y | 8.6 | 260, 269, 274, 304 | 316 | physical TalkBack、200%、glyph、IME | +2 |
| UX-015 | Achievement loop | 8.6, 11, 12, 21 | 272, 285 | 324 | Task→Mission→Quest→Trail→Horizon E2E | +3 |
| UX-016 | Accessibility | 8.6, Phase Gate | 304, 315 | 316, 327 | device matrix、focus、tap target、screen reader | +3 |
| UX-017 | Maintainability | 29, 31.6 | 209, 305 | 311 | extracted Widget tests、route / visual no-regression | +1 |
| UX-018 | UI system | 8.6 | 208, 302 | 310, 326 | Screen state matrix、component contract、golden | +2 |
| UX-019 | Feedback | 8.6, Phase Gate | 299 | 313 | owner-scoped persistence、receipt、retry、triage | +2 |
| UX-020 | Data Rights | 22, Phase Gate | 306 | 309, 317 | reauth、worker、status、legal owner、RLS | +3 |

## Coverage Rules

- Critical / High指摘はすべて既存または新規QSTへ接続した。
- Master Specへは恒久原則だけを反映し、個別overflow、glyph、固定文言はQSTと監査へ残した。
- QST-327が再採点の唯一の最終Gateであり、各QSTの自己申告点を合算して100点とはしない。
- 実装AcceptanceはUnit / Widgetだけで閉じず、対象に応じてIntegration、hosted、RLS、device、visual evidenceを要求する。

## Evidence Classes

| 区分 | 本監査での利用 |
| --- | --- |
| Executed | route移動、Arc日本語入力、Enter送信、clarification、reload |
| Visual | 320 / 390 / 768 / 1280の22画像 |
| Code-confirmed | Router、fallback、Horizon、Screen数、巨大Screen |
| Test-confirmed | 514 tests、Web / Android emulator E2E、build |
| Documentation | Master Spec、Backlog、QST report、Beta evidence YAML |
| Inferred | ユーザー影響の一部。推測として明示 |
| Unverified | Hosted、physical device、iOS、Screen reader |
