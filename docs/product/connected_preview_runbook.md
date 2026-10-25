# 実接続プレビュー起動手順

QST-417は、ローカルUIモックと実接続レビューを混同しないための起動契約を定義する。実接続プレビューはSupabase Auth、Data API、Storage、Edge Functionsを利用し、ArcのGemini呼び出しは認証済みユーザーからサーバー側Edge Functionを経由する。

## 設定ファイル

設定ファイルはリポジトリ外へ置く。例: `$HOME/.questra/beta-preview.env`。

```dotenv
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_ANON_KEY=sb_publishable_<public-client-key>
```

`sb_secret_`、`service_role`、`GEMINI_API_KEY`、`OPENAI_API_KEY`はFlutterへ渡さない。Geminiの秘密値はSupabase Edge FunctionのSecretとしてのみ管理する。

## 起動

レビュー用のモックは、設定ファイルがある場合に実接続版として起動する。Supabase認証・保存とArcのGemini呼び出しは実サービスを使用する。ログインは実アカウントで行い、ローカルのモックログインを実接続の証拠にしない。

```powershell
pwsh -NoProfile -File tools/qst/run_mock.ps1
```

`-Port 5280`でポートを変更できる。接続だけ確認する場合は`-ValidateOnly`を付ける。設定がない場合は起動に失敗するため、接続済みと誤認しない。純粋なUIモックが必要な場合のみ`-Offline`を明示する（Supabase/Geminiは使わない）。設定ファイルは既定で`$HOME/.questra/beta-preview.env`から読み、`QUESTRA_PREVIEW_CONFIG`で変更できる。

ログインを省いて画面を見たい開発者は、実接続版と別ポートでオフラインモックを起動する。

```powershell
pwsh -NoProfile -File tools/qst/run_mock.ps1 -Offline -Port 5282
```

`http://127.0.0.1:5282/#/guild`などの直リンクも、開発ビルド内の一時的なプレビュー利用者で開く。自動入場は`AUTO_ENTER_LOCAL_MOCK=true`、Supabase未設定、ローカル永続化許可、非リリースビルドの全条件がそろう場合だけ有効。Guildの検索UIは空状態で表示するが、公開Questの取得・取り込み・公開申請はできない。画面上でもオフラインプレビューと明示する。ここでの操作やスクリーンショットはSupabase保存・Gemini応答・RLSの検証証拠に使用しない。

オフラインモックはWebのprofileモードで起動する。新しいブラウザタブで開発用スクリプトの大量読み込みが白画面のまま止まる事象を避けるためで、releaseモードの認証制約は緩めない。初回ビルドには時間がかかり、コード変更の反映には再起動が必要になる。

実接続プレビューもWeb Serverではprofileモードで起動する。接続先・認証必須・mock persistence無効の設定は変わらない。初回ビルドが完了する前のHTTP 200や白画面を、ログイン画面の表示成功と判定しない。

オフラインモックは認証メールを送らない。ログイン画面に確認メール・パスワード再設定のリンクを出さず、復旧画面の直リンクも利用不可を表示する。ローカルの認証処理を直接呼んでもメール送信やパスワード更新を成功扱いにしない。メール到着・リンク復帰・再設定・ログインの確認は実接続版で行う。

ランチャーは次を実施する。

1. URLがHosted SupabaseのHTTPS URLであることを確認する。
2. キーがpublishableまたはlegacy anonであり、secret/service roleではないことを確認する。
3. Supabase AuthとData APIの到達性をprobeする。匿名Questアクセスが拒否されても、Data APIが到達可能な場合は正常とする。さらに、空の認証情報で`auth-login` Edge Functionが期待どおり`401 / invalid_credentials`を返し、起動ポートのOriginへCORSを許可することを確認する。`x-questra-auth-contract`が現行版と異なるか存在しない場合、通常のプレビューは警告付きで起動できるが、現行ログイン処理の検証には使えない。この入口probeは実ID・パスワード、ユーザー検索、ログイン成功、DB制約の検証ではない。認証済みデータ取得は別途検証する。
4. 一時的な`dart-define-from-file`を作り、`APP_ENVIRONMENT=production`かつmock persistence無効でWeb版を起動する。
5. Flutter終了後、一時ファイルを削除する。

設定値自体はコンソールへ表示しない。`-ValidateOnly`で起動せず検証だけを実施できる。

Hosted認証関数の現行契約を必須にする検証では、`pwsh -NoProfile -File tools/qst/run_mock.ps1 -ValidateOnly -RequireCurrentAuthContract`を実行する。旧関数または契約ヘッダー欠落時は失敗する。Betaで旧`auth-login`が残る間はこのチェックに通らない。通常起動の警告を無視して、実ログインや配備一致を検証済みと記録しない。`-RequireCurrentAuthContract`と`-SkipRemoteProbe`の併用は拒否される。

## Gemini確認

公開probeだけではGemini応答品質を証明しない。アプリで認証済みになった後、Arcへ短い相談を送り、固定応答ではなくEdge Function由来の応答になること、thinking表示、失敗時の非テンプレート回復を確認する。GeminiキーをブラウザのNetwork、ログ、スクリーンショットへ含めない。

## 初回登録メール確認

実接続プレビューで初回登録を試す前に、BetaプロジェクトのAuth URL Configurationに**実際に起動しているOrigin**の`/?auth_callback=signup`を完全一致で追加する。`localhost`と`127.0.0.1`、ポート違いは別のURLである。`/#/...`を許可先に登録しても、確認リンクの戻り先としては使わない。モバイルで試す場合は`com.questra.questra://login-callback/confirm?auth_callback=signup`も許可する。

Hosted無料枠では既定の確認メールテンプレートを使う。登録・確認メール再送にはimplicit-flowの確認リンクを発行し、Questraへの戻り先でセッションを検証する。メールのリンクを開いたブラウザー／端末がログイン状態になるため、リンクは共有しない。許可先を変更した後に**新しく送ったメール**で確認する。旧メールのリンクを繰り返し開かない。

Webのパスワード再設定を検証する場合は、同じOriginの`/?auth_callback=recovery`もAuth Redirect URLsに完全一致で追加する。新しい回復メールは別ブラウザーで開いても検証できるが、リンクに含まれる一時トークンを共有しない。Questraが開いただけでは再設定成功ではない。新しいパスワードを保存した表示を確認し、その後ログインIDまたは登録メールアドレスでログインできるまで確認する。既発行の`/#/reset-password`リンクは同一ブラウザーでの旧PKCE経路であり、期限が切れた後に再送する。接続版とオフラインモックを混同しない。

検証用アカウントで、リンク成功時にSupabase Authの`Confirmed at`が埋まり、Questraがログイン画面を挟まず初回設定またはHomeへ進むことを確認する。期限切れ・使用済みリンクはエラーと再送を示す。Webを再読み込みすると従来どおりログインが必要になる。送信ログだけ、あるいはQuestraの画面が開いただけでは成功扱いにしない。Hosted側の変更と実リンク往復を確認するまでは`BETA_AUTH_REDIRECT_EVIDENCE.json`の`signup_confirmation_roundtrip_verified`を`false`に保つ。

2026-10-05のBeta環境では、公開キーだけのArc Function呼び出しにもGemini由来の応答が返った。これは接続確認にはなるが、ユーザー認証・AI利用制限の証明にはならない。認可と呼び出し制限を修正・配備するまで、公開利用可能な状態と判定しない。

## 現在の配備差分

`docs/qst/BETA_SUPABASE_PROJECT.yaml`で`migrations.status`が`applied`でない場合、ローカル最新機能の一部は未配備である。起動成功を全機能の配備完了とは扱わない。認証済みの実操作、対象row ID、Edge Function traceを別の候補証跡として記録する。
