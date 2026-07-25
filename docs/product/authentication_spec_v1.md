# Questra Authentication Specification V1

## 1. Purpose

Questraの認証は、ユーザーのQuest、Mission、Trail、Arc Memoryを本人だけが継続利用できるようにするための境界である。認証UXの簡潔さより、アカウント乗っ取り、認証情報漏えい、列挙攻撃、ブルートフォースへの耐性を優先する。

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
5. ユーザーはメール確認後、ログインIDまたはメールアドレスとパスワードでログインする。
6. 初回ログイン後はオンボーディングへ進む。

登録直後に自動ログイン済みとは扱わない。メール確認が無効なローカル環境でも、一度ログイン画面へ戻す。

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

## 5. Password Reset

1. ログイン画面から「パスワードを忘れた方」を開く。
2. 登録メールアドレスを入力する。
3. アカウントの存在にかかわらず同じ送信完了文を表示する。
4. SupabaseのPKCE回復リンクからQuestraへ戻る。
5. 新しいパスワードを2回入力して更新する。
6. 失敗回数とロックを解除し、全プラットフォームでログイン画面へ戻る。

回復リンクはWebの`/#/reset-password`とモバイルの`com.questra.questra://login-callback`だけを許可する。Supabase DashboardのRedirect URLsにも本番URLを明示登録し、ワイルドカードは使用しない。

## 6. Failed Login Lock

- 15分以内の連続失敗を記録する。
- 10回目の失敗で30分間ロックする。
- ロック中は正しいパスワードでも新しいログインを拒否する。
- 攻撃者が既存利用者を追い出せないよう、既存セッションは失効させない。
- 正常ログイン、ロック期限後の正常ログイン、パスワード再設定で失敗回数を0へ戻す。
- エラー文ではログインID、メールアドレス、ロック状態のどれが正しいかを明らかにしない。

無料枠では`auth-login` Edge Functionが失敗回数とロックを強制する。Supabase Password Verification Hookが利用できるプランでは同Hookを必ず有効化し、公開Auth APIへ直接アクセスする迂回ログインも拒否する。Hook未対応プランの直接Auth APIにはSupabase標準のIPレート制限が適用されるが、Questra独自の10回ロックを完全強制できないため、外部Beta前にプランとHook有効化をRelease Managerが確認する。

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
- Redirect URL: 本番Webの`/#/reset-password`
- Redirect URL: `com.questra.questra://login-callback`
- Edge Function `auth-login`: `verify_jwt=false`
- Secret `ALLOWED_WEB_ORIGINS`: 本番Web Originの完全一致リスト
- Password Verification Hook: 対応プランでは`public.hook_password_verification_attempt`を選択

## 9. Acceptance

- 登録後はログイン画面へ戻る。
- モバイル再起動後は有効な保存セッションで自動復帰する。
- Web再読み込み後はログインを要求する。
- ログインIDまたはメールアドレスでログインできる。
- パスワード再設定メールの要求と新パスワード設定ができる。
- 15分以内に10回失敗したアカウントは30分間新規ログインできない。
- 認証テーブルはanon/authenticatedから参照できない。
