# Beta Crash and Error Capture Plan

## Status

QST-126でBeta向け収集戦略を`Prepared`とする。外部Crash SDKや自動送信先は
まだ追加せず、QST-127 Privacy Reviewを通過するまで端末外へ自動送信しない。

## Goal

内部Betaのクラッシュ、Supabase保存失敗、認証・Media失敗、Arc Chat / Guideの
フォールバックを、再現と優先順位判断に十分な最小証跡として扱う。障害調査以外へ
転用せず、ユーザーの挑戦内容を収集しない。

## Current Audit

| Boundary | Current state | Beta target |
| --- | --- | --- |
| Flutter framework error | Global handlerなし | `FlutterError.onError`から正規化eventへ変換 |
| Unhandled async error | Global handlerなし | `PlatformDispatcher.instance.onError`またはguarded zoneで捕捉 |
| Quest / Mission persistence | UIへ`failed`状態を返す | operation、error code、correlation IDを記録 |
| Trail / Media persistence | UIへ`failed`状態を返す | upload / replace / deleteを区別して記録 |
| Auth / Profile | 各Controller内でcatch | 個人情報を除いたauth operationのみ記録 |
| Arc Chat | 失敗時にlocal fallback | `ai_fallback`と理由codeを記録 |
| Arc Quest Guide | 失敗・候補不足時にlocal fallback | transport failureとinvalid responseを区別 |

既存のフォールバックと保存失敗UIは維持する。証跡収集失敗によって本来の操作や
フォールバックを失敗させてはならない。

## Event Taxonomy

- `app_crash`: process継続が保証できない未処理例外。
- `flutter_framework_error`: Flutter frameworkから通知された例外。
- `unhandled_async_error`: isolate / platform境界の未処理非同期例外。
- `persistence_failure`: Quest、Mission、Trail、Reflection、Arc Memory、Profileの保存・取得失敗。
- `auth_failure`: sign-in、session restore、profile bootstrap失敗。
- `media_failure`: Trail画像のupload、replace、delete失敗。
- `ai_fallback`: Arc Chat、Quest Guide、Arc Adviceがremote応答を使えずlocal結果へ切替。

## Minimum Evidence Schema

- `event_id`: UUID。
- `occurred_at`: UTC timestamp。
- `build_version`: app versionとcommitまたはbuild number。
- `environment`: local、internal_beta、production。
- `platform`: Android、iOS、Webなど。
- `surface`: Home、Quest、Mission、Trail、Guild、Arc Chat、Arc Memory、Profile、Media、Auth。
- `operation`: `quest.create`、`trail.media.replace`、`arc_chat.invoke`などの固定key。
- `event_type`: Event Taxonomyの値。
- `severity`: QST-125のS0-S3。
- `error_code`: 既知の正規化code。生の例外本文は保存しない。
- `fingerprint`: exception type、surface、operation、先頭stack frameから生成するhash。
- `correlation_id`: 1回の操作内の保存・Edge Function呼び出しを結ぶrandom ID。
- `handled`: UIまたはfallbackで継続できたか。
- `fallback_used`: local Arc responseなどへ切り替えたか。

HTTP status、Supabase request ID、匿名化tester ID、stack fingerprintは、調査に必要な
場合だけ任意で追加する。user IDを使う場合はBeta専用saltで不可逆化する。

## Prohibited Data

以下はevent、breadcrumb、tag、添付logへ保存しない。

- メールアドレス、氏名、電話番号、位置情報、認証token、cookie、API key。
- Quest、Mission、Trail、Reflection、Arc Memoryの本文。
- Arc Chatのprompt、会話履歴、生成応答全文。
- 画像、画像URL、signed URL、Storage object path。
- Supabase request body、database row全文、raw SQL、raw exception message。

再現情報はQST-124 Feedback Entryでtesterが確認して提出する。添付資料もRelease Managerが
個人情報を除去してから保管する。

## Capture Boundaries

1. App bootstrapでFlutter frameworkとunhandled asyncの入口を登録する。
2. Repository / Controllerのcatch境界でoperationと正規化error codeを付ける。
3. SupabaseはHTTP status、サービス分類、request IDだけを抽出する。
4. Arc serviceはremote未設定、network、timeout、invalid response、候補不足を区別する。
5. 同じ`correlation_id`の下位失敗は1 incidentへまとめ、二重登録を避ける。
6. Reporter自身の失敗は握りつぶし、アプリ操作へ影響させない。

## Severity and Response

| Condition | Severity | Action |
| --- | --- | --- |
| Crash、data loss、RLS/owner境界違反、起動不能 | S0 | Beta拡大停止、P0 QSTを即時作成 |
| Quest -> Mission主要導線不能、継続する保存失敗 | S1 | 24時間以内にP0 QST化 |
| fallbackで継続可能なAI/Supabase失敗、局所的機能失敗 | S2 | 同fingerprint 3件でP1候補 |
| ユーザー影響が見えないhandled event | S3 | weekly review、反復時のみ候補 |

QST化にはQST-125のTitle、Problem、Evidence、Scope、Acceptance、Validation形式を使う。

## Storage, Access, and Retention

- 内部Betaの保持期間は30日。匿名化集計だけを残し、原eventは削除する。
- Raw eventはRelease Managerと指定Engineering ownerだけが閲覧する。
- 外部providerの保存地域、subprocessor、削除API、sampling、PII scrubbingをQST-127で
  レビューしてから有効化する。
- ProductionではPrivacy copyと同意境界が整うまでtester IDを収集しない。

## Rollout

### Phase A: Internal Beta Preparation

- 本文書と`docs/qst/BETA_FEEDBACK.yaml`を収集契約とする。
- 自動送信は無効。Flutter consoleの最小logとFeedback Entryを手動証跡として使う。
- 実機検証でevent type、operation、severity、fallback結果を記録する。

### Phase B: Capture Adapter

- UIやRepositoryからproviderを直接呼ばない`ErrorEvidenceSink`境界を追加する。
- No-op sinkをdefaultとし、承認済みproviderだけをenvironment flagで差し替える。
- 正規化、redaction、sampling、fingerprintを端末側で送信前に適用する。

### Phase C: Beta Operation

- S0/S1 alert、同fingerprint件数、build別regressionをRelease Managerが確認する。
- 収集量とPrivacy項目を週次監査し、不要なeventを削減する。

## Verification Matrix

| Scenario | Expected evidence | Expected UX |
| --- | --- | --- |
| Flutter test exception | framework event、fingerprint、S0/S1 | Beta buildでQST化 |
| Supabase Quest save failure | `persistence_failure`、`quest.save` | 失敗表示、入力保持 |
| Trail media upload failure | `media_failure`、`trail.media.upload` | 再試行可能、既存Trail維持 |
| Arc Chat timeout | `ai_fallback`、timeout、fallback=true | Arcらしいlocal response |
| Quest Guide invalid response | `ai_fallback`、invalid_response | local guideまたは手動Mission |
| Reporter transport failure | 送信なし | 元操作とfallbackを継続 |

## Exit Criteria

- Taxonomy、schema、収集禁止data、retention、access ownerが定義されている。
- Flutter、Supabase、Arc fallbackのcapture pointが特定されている。
- S0-S3とBeta停止/QST変換がQST-125へ接続されている。
- 外部provider導入前にQST-127 Privacy Reviewが必要と明記されている。
- 実機検証で使う期待証跡とUXが定義されている。
