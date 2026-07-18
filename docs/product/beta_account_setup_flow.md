# Beta Account Setup Flow

QST-121 prepares the tester account path required before wider internal beta.
The goal is that a beta tester can sign in, create a first Quest, and confirm
that the Quest persists without developer help.

## Scope

- Account creation and login copy in the Flutter app.
- First Quest creation after onboarding or login.
- Supabase project readiness checks for Auth, profiles, Quest persistence, and
  RLS ownership.
- Evidence that separates real beta persistence from local fallback behavior.

## Required Environment

Beta persistence must use a real Supabase project. The Flutter app must be
launched with:

```powershell
flutter run -d chrome `
  --dart-define=SUPABASE_URL=<project-url> `
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

Local fallback mode is useful for UI work, but it is not valid persistence
evidence for beta launch.

## Tester Flow

1. Open Questra.
2. Choose `はじめる`.
3. Create a beta account or log in with the provided beta account.
4. Complete onboarding if prompted.
5. Open Quest.
6. Create a first Quest with:
   - Quest名
   - 叶えたい理由・背景
   - カテゴリ
7. Confirm the app shows `Questを保存しました。`.
8. Refresh or restart the app.
9. Log in again with the same account.
10. Confirm the Quest is still visible and belongs only to that account.

## Operator Verification

Before inviting testers, the release operator must verify:

| Check | Expected Evidence |
| --- | --- |
| Supabase Auth is enabled | A beta user can sign up or sign in. |
| `user_profiles` upsert works | A profile row appears for the beta user. |
| Quest insert works | A Quest row appears with `owner_id` equal to the beta user id. |
| Quest fetch works | The created Quest appears after app restart and login. |
| RLS ownership works | A second beta account cannot see the first account's private Quest. |
| Local fallback is not mistaken for beta | Evidence includes Supabase project URL and row ids. |

## Stop Conditions

- A beta account cannot sign up or sign in.
- Profile creation fails after sign-up.
- Quest save shows a failure state or does not persist after restart.
- Private Quest data appears under another account.
- The app is run without Supabase dart defines during beta evidence capture.

## Current App Copy

The login and account creation screens use Japanese beta-ready copy:

- `ログイン`
- `ベータテスト用に案内されたメールアドレスとパスワードでログインしてください。`
- `ベータアカウントを作成`
- `最初のQuestを保存できるように、プロフィールを作成します。`

## Remaining Manual Evidence

This QST prepares and documents the flow. Final beta approval still requires a
real Supabase project run with screenshot or log evidence for the checks above.

## Dual Account Acceptance Runner

QST-162では、専用BetaアカウントA/Bを用いて同じ受入を自動化する。認証情報は現在のshell sessionの
環境変数だけに設定し、`.env`、terminal command、evidenceへ値を残さない。

```powershell
dart run tools/qst/run_dual_account_persistence.dart
dart run tools/qst/verify_dual_account_persistence.dart --require-cloud
```

runnerはAccount AでProfileを確認し、private Quest、Mission、Arc Memoryを作成する。Aへ再ログインして
4領域を再取得した後、Account Bから3つのprivate journey IDが0件になることを確認する。最後にAの
試験データを削除し、メール、password、anon key、private contentを含まないsanitized evidenceだけを
`docs/qst/BETA_DUAL_ACCOUNT_PERSISTENCE.yaml`へ保存する。
