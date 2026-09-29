# Questra UI/UX Review 2026-09-14

## Review protocol

`docs/product/ui_ux_review_protocol_v5.md`の5回自己レビュー済み基準を使用した。

## Evidence

- 実画面: Web mockのHome、Arc、Quest、Trail、Profileを約770x767で操作・確認。
- Code: Router、AppShell、Navigation Rail、Home、Quest、Trail、ArcEmptyState、Themeを確認。
- Test: Responsive navigation、Empty state、semantic surfaceの既存契約を確認。
- 未確認: 320/390/430px実ブラウザ、Android物理端末、200%文字、TalkBack、Hosted Supabase、実Gemini応答。

## Score

一次改善後のUI/UXは70/100。Arc画面とHomeの暗色世界観、Primary Navigation、Quest階層は成立している。空状態、重複CTA、Auth切替の視認性は改善したが、Profileの大型light cardとHome下部の未活用空間が完成度を下げる。

## Findings

### High

- QuestとTrailの空状態がほぼ同じ巨大白カードで、画面固有の次の行動よりテンプレート感が強い。
- Quest空状態ではAppBarの追加アイコンとカード内CTAが競合する。
- medium Railの「プロフィール」が幅80pxに収まらず、文字が切れる。
- Auth切替で未選択側の文字にlight theme由来の暗色が適用され、濃紺背景上で読みにくい。

### Medium

- 空状態にArcの吹き出し、タイトル、共通説明、CTAが重なり、同じ意味を複数回読む。
- Profileは白い大型カードが連続し、暗いHome・Arcとの視覚的連続性が弱い。
- Homeの初期状態は上部2面だけで下部が大きく空く。初回導線としては明快だが、デスクトップの構図は未完成に見える。

## Implemented first pass

- `ArcEmptyState`をdark surface、Arc portrait、短いtitle/message、単一CTAへ再構成した。
- 重複していた固定説明文を削除した。
- Questが0件のときAppBarの追加アイコンを隠し、Primary CTAを1つにした。
- compact Railでは「プロフィール」ではなく「自分」を表示した。
- Dark cardのborderを弱いsky blueへ変更し、白い枠の強さを抑えた。
- Auth切替を専用状態色へ変更し、選択中は明るい面と濃紺文字、未選択は濃紺面と白文字、keyboard focusは金色の輪郭で示した。

## Verified effect

- Release Web mockでQuestとTrailのempty stateがdark surfaceかつcompact layoutで表示されることを確認した。
- Questが0件のとき、作成導線が`ArcとQuestを考える`の1 CTAになることを確認した。
- Trailが0件のとき、短い説明と`最初のTrailを残す`の1 CTAになることを確認した。
- Medium Railのcompact labelはWidget Testで`自分`となり、`プロフィール`が残らないことを確認した。

## Validation

- `flutter analyze --no-pub`: PASS、issue 0件。
- Focused Widget Tests: PASS、18件。
  - `test/arc_empty_state_test.dart`
  - `test/bottom_navigation_v2_test.dart`
  - `test/qst_407_trail_single_timeline_test.dart`
  - `test/qst_414_auth_plain_language_test.dart`
  - `test/auth_beta_account_copy_test.dart`
- `flutter build web --release --no-pub`: PASS。
- Release Web mock: Quest／Trailのempty state、Login／Signupの切替状態を実画面で再確認。
- Full Flutter test suite: UI関連を含む818件がPASS。別作業中のQST-448 contract testが`pricing_source_uri`を禁止語`source_uri`の部分一致で検出して1件FAILしたため、suite全体の終了コードは1。今回のUI差分に起因する失敗はない。

## Remaining priorities

1. QST-321の戻る・deep link・全Navigation契約を完了する。
2. Profileの大型light cardをsemantic dark surfaceへ段階移行する。
3. Home初期状態のデスクトップ構図を、説明追加ではなく余白と幅で調整する。
4. 320/390/430、200%文字、日本語IME、Androidで現行SHAのvisual evidenceを取得する。
5. QST-322のArc-first Quest入口を実画面で再検証する。

## Evidence boundary

本レビューはWeb mockの限定画面とコードに基づく。物理端末、Screen Reader、Hosted Backend、実provider接続の品質を確認済みとは扱わない。
