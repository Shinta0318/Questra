# Questra Authentication Specification V1

## 1. Purpose

Questraの認証は、ユーザーのQuest、Mission、Task、Trail、Arc Memoryを本人だけが継続利用できるようにするための境界である。認証UXの簡潔さより、アカウント乗っ取り、認証情報漏えい、列挙攻撃、ブルートフォースへの耐性を優先する。

## 2. Account Identity

- 認証主体はSupabase Authの`auth.users`である。
- ユーザーは登録時にログインID、メールアドレス、パスワード、Arcからの呼び名を設定する。
- ログインIDは3〜40文字で、先頭は半角英数字、以降は半角英数字・`.`・`_`・`-`を使用できる。
- ログインIDは小文字へ正規化し、システム全体で一意とする。
- ログイン画面ではログインIDまたは登録メールアドレスを利用できる。
- メールアドレスとログインIDの対応は`auth_login_accounts`へ隔離し、公開Profileや通常のData APIから取得できない。

## 3. First Use Flow

1. ユーザー作成画面で必須項目を入力する。
2. Supabase Authへユーザーを作成する。
3. DBトリガーが`user_profiles`と`auth_login_accounts`を作成する。
4. 登録メールアドレスの確認メールを送る。
5. ユーザーが既定の確認メールのリンクを開くと、Supabaseがメールアドレスを確認し、Questraが戻り先の一時セッショントークンを検証してセッションを確立する。
6. 成功時は追加のパスワード入力なしで法的同意の確認、オンボーディング、またはHomeへ進む。失効・使用済み・通信失敗時は結果を明示し、再送と既に確認済みのユーザー向けログインを案内する。

登録直後はまだログイン済みと扱わない。メール確認リンクの成功だけが初回セッション作成を許可する。確認メールが無効なローカルモックではメール確認を装わず、従来のローカルログイン導線を維持する。
確認メールの戻り先はWebでは登録を行ったOriginの`/?auth_callback=signup`、モバイルでは`com.questra.questra://login-callback/confirm?auth_callback=signup`とする。登録・確認メール再送では、PKCE検証器を元のブラウザーへ保存しない独立したimplicit-flowクライアントを使う。Supabaseの既定確認メールは検証後、戻り先URLのフラグメントに一時的なセッショントークンを渡す。QuestraはトークンをSDK起動前にWebのアドレス欄から除き、Supabaseで確認済みユーザーと検証してから初回セッションを確立する。これにより登録時と異なるブラウザーでも確認できる。リンクを開いたブラウザー／端末がログイン状態になるため、メールの転送やリンク共有はしないよう案内する。トークンをログ・計測・文書へ保存しない。Webのパスワード回復も別のimplicit-flowクライアントを使い、通常ログインとモバイルの回復は従来の経路を維持する。旧PKCEリンクは移行期間のみSDKの交換を試し、失敗を成功と表示しない。将来カスタムSMTPが導入された場合は`token_hash`をアプリで検証する方式へ切り替え可能。Supabase DashboardのSite URL・Redirect URLsを配布対象へ合わせ、ローカルの`localhost:3000`を外部BetaのSite URLとして残さない。
確認メールが届かない場合は、ログイン画面から登録メールアドレスを入力して確認メールを再送できる。再送は初回登録要求があったアドレスだけを対象とし、アカウントの有無を画面で明らかにしない。送信要求の受付と受信箱への到達は区別し、短時間の連打を防ぐ。宛先誤記を再送だけで修正できるとは案内しない。

## 4. Session Policy

### Mobile

- Supabaseが発行する短時間のアクセストークンとローテーションされる更新トークンを使用する。
- セッションは`flutter_secure_storage`を通してOSのKeychain、Keystore相当へ保存する。
- 2回目以降は保存セッションを復元し、ログイン画面を通さずHomeまたはオンボーディングへ進む。
- 明示ログアウト、パスワード変更、トークン失効時は保存セッションを削除する。

### Web

- `EmptyLocalStorage`を使用し、アクセストークンと更新トークンをブラウザの永続領域へ保存しない。
- ページ再読み込み、タブ終了、再訪問後はログインを要求する。
- 開いている同一実行セッション内だけはログイン状態を維持する。
- メール確認直後の一時セッションも同じ方針とし、後日のWeb再訪時に自動ログインしない。

## 5. Password Reset

1. ログイン画面から「パスワードを忘れた方」を開く。
2. 登録メールアドレスを入力する。
3. アカウントの存在にかかわらず同じ送信完了文を表示する。
4. Webでは別ブラウザーでも利用できるimplicit-flow回復リンクからQuestraへ戻り、一時セッションを検証する。モバイルでは既存のPKCE回復リンクを使用する。
5. 新しいパスワードを2回入力して更新する。
6. 失敗回数とロックを解除し、全プラットフォームでログイン画面へ戻る。

Webの新しい回復メールは現在のOriginの`/?auth_callback=recovery`へ戻す。フラグメントの`type=recovery`と完全なセッショントークンを検査し、URLからトークンを除いた後にSupabaseでセッションを検証する。回復セッションを確認できるまで新パスワード欄を表示しない。これによりメールを別ブラウザーで開いた場合も、元のブラウザーに保存されたPKCE検証器へ依存しない。既発行のWeb PKCEリンク`/#/reset-password`は移行期間中のみ従来のSDK交換を試し、失敗時は成功を装わない。モバイルの`com.questra.questra://login-callback`はPKCEを維持する。Supabase DashboardのRedirect URLsにも登録確認と回復の配布URLを完全一致で登録し、ワイルドカードは使用しない。メール送信ログだけでは戻り先や受信を証明できないため、実リンクの往復を別に検証する。

## 6. Failed Login Lock

Supabase Authの`invalid_credentials`だけをパスワード失敗として数える。`email_not_confirmed`は失敗回数へ加算せず、アカウント有無を明かさない共通の401応答と確認メール案内へ誘導する。その他の分類できないAuth応答は資格情報の誤りと断定せず、再試行可能なサービスエラーとして扱う。Hostedに古い`auth-login`が残っている間は、この境界が本番で有効だとみなさない。

- 15分以内の連続失敗を記録する。
- 10回目の失敗で30分間ロックする。
- ロック中は正しいパスワードでも新しいログインを拒否する。
- 攻撃者が既存利用者を追い出せないよう、既存セッションは失効させない。
- 正常ログイン、ロック期限後の正常ログイン、パスワード再設定で失敗回数を0へ戻す。
- エラー文ではログインID、メールアドレス、ロック状態のどれが正しいかを明らかにしない。

無料枠では`auth-login` Edge Functionがアプリ経由の失敗を数える。Freeで利用可能なCustom Access Token Hookは、ロック済みアカウントの新規パスワードトークン発行を拒否する。回復トークンと既存セッションの更新は通し、パスワード再設定と既存利用を妨げない。公開Auth APIへ直接送った失敗パスワード試行はQuestraのカウンターへ反映されないため、「すべての経路で10回失敗したらロック」は無料枠では未達である。Supabase標準のIPレート制限だけをその代替とはみなさない。外部Beta前に直接Auth API、Hook、RLS、回復のHosted実行を確認し、全経路の10回ロックが必須なら対応プランのPassword Verification Hookまたは別の認証境界を決める。

## 7. Security Requirements

- パスワード、アクセストークン、更新トークンをログへ出力しない。
- Edge Functionは4KBを超えるログイン要求を拒否する。
- Web Originは`ALLOWED_WEB_ORIGINS`の完全一致とlocalhost開発環境だけを許可する。
- 認証応答は`Cache-Control: no-store`と`X-Content-Type-Options: nosniff`を付与する。
- ログインIDからメールアドレスをクライアントへ返さない。
- パスワードはSupabase Authだけがbcryptで保持し、Questraテーブルへ保存しない。
- 本番ではSupabase Authのメール送信レート制限、CAPTCHA、最低パスワード長、漏えいパスワード保護、JWT有効期限をRelease Managerが確認する。

## 8. Required Cloud Settings

- Email provider: enabled
- Confirm email: enabled
- Secure email change: enabled
- Secure password change: enabled
- JWT expiry: 3600 secondsを基本値とする
- Refresh token rotation: enabled
- Redirect URL: 本番Webの`/?auth_callback=recovery`。移行期間のみ旧`/#/reset-password`も許可可
- Redirect URL: 本番Webの`/?auth_callback=signup`（登録確認）
- Redirect URL: `com.questra.questra://login-callback/confirm?auth_callback=signup`（登録確認）
- Redirect URL: `com.questra.questra://login-callback`
- Confirmation email template: Hosted無料枠の既定テンプレートを使用する。独自SMTPを導入しない限り、Dashboard上のテンプレート変更を前提にしない。
- Edge Function `auth-login`: `verify_jwt=false`
- `auth-login`からSupabase Authへのパスワード照合は公開`apikey`ヘッダーで行う。publishable keyを`Authorization: Bearer`へ入れない。
- Secret `ALLOWED_WEB_ORIGINS`: 本番Web Originの完全一致リスト
- Custom Access Token Hook: Freeプランでは`public.hook_questra_access_token`を選択し、パスワードトークンのロック判定を確認する
- Password Verification Hook: Teams/Enterpriseなど対応プランへの移行後にのみ`public.hook_password_verification_attempt`を検討する。Freeプランの設定では無効にする

## 9. Acceptance

- 登録直後はメール確認を案内し、リンク検証成功後はパスワード再入力なしでアプリへ進む。
- リンク失効・再利用・別形式・通信失敗時に成功を装わず、再送またはログインへ進める。
- 確認メール未着時は再送画面へ進め、入力検証・再送間隔・一般化した応答が機能する。
- モバイル再起動後は有効な保存セッションで自動復帰する。
- Web再読み込み後はログインを要求する。
- ログインIDまたはメールアドレスでログインできる。
- パスワード再設定メールの要求と新パスワード設定ができる。
- 15分以内に10回失敗したアカウントは30分間新規ログインできない。
- 認証テーブルはanon/authenticatedから参照できない。
