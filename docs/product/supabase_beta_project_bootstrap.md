# Supabase Beta Project Bootstrap

## Purpose

Questra Internal Betaで使用するSupabase projectを一意に固定し、migration、Edge Function、
server-side secret、Flutter client設定の証跡を同じcandidate commitへ結び付ける。
ローカルfallbackや静的検証は、クラウド配備の証跡として扱わない。

## Source Of Truth

- Local CLI configuration: `supabase/config.toml`
- Cloud evidence: `docs/qst/BETA_SUPABASE_PROJECT.yaml`
- Bootstrap command: `tools/qst/bootstrap_supabase_beta.ps1`
- Preparation verifier: `dart run tools/qst/verify_supabase_beta_bootstrap.dart`
- Cloud completion verifier: `dart run tools/qst/verify_supabase_beta_bootstrap.dart --require-cloud`

`config.toml`の`project_id = "questra"`はローカルstack識別子であり、hosted project refではない。
hosted projectとの関連付けは`supabase link --project-ref`で行い、CLI内部状態はGitへ追加しない。

## Prerequisites

1. Supabase DashboardでBeta専用projectを作成する。
2. Regionは対象testerとPrivacy copyに整合するものを選び、作成後は変更しない。
3. Engineering Ownerを1名決め、database passwordとaccess tokenをpassword managerで管理する。
4. Supabase CLIをインストールし、repository rootで`supabase login`を完了する。
5. `supabase/functions/.env.example`を`supabase/functions/.env.beta.local`へ複製し、`AI_PROVIDER=gemini`とGemini API keyを安全に設定する。

`.env.beta.local`、service-role key、database password、personal access token、provider API keyは
commit、QST Report、screenshot、terminal logへ残してはいけない。

## Preflight

```powershell
dart run tools/qst/verify_supabase_beta_bootstrap.dart

powershell -ExecutionPolicy Bypass -File tools/qst/bootstrap_supabase_beta.ps1 `
  -ProjectRef "<20-character-project-ref>" `
  -Region "<project-region>" `
  -Owner "<engineering-owner>" `
  -DashboardEvidence "<sanitized-secure-evidence-reference>"
```

`-Apply`を付けない実行はremoteを変更しない。project ref、region、owner、CLI、migration、
function、secret fileの前提だけを確認する。

## Apply

```powershell
powershell -ExecutionPolicy Bypass -File tools/qst/bootstrap_supabase_beta.ps1 `
  -ProjectRef "<20-character-project-ref>" `
  -Region "<project-region>" `
  -Owner "<engineering-owner>" `
  -DashboardEvidence "<sanitized-secure-evidence-reference>" `
  -Apply
```

スクリプトは次を順番に実行し、途中失敗時はcloud evidenceを`verified`へ変更しない。

1. `supabase projects list`でproject refとregionへのaccessを照合
2. `supabase link --project-ref`
3. `supabase db push --linked`
4. `supabase migration list --linked`でlatest migrationを照合
5. `supabase secrets set --env-file`でserver-side secretを登録
6. `supabase functions deploy <function-name>`で6つのEdge FunctionをJWT検証有効のままdeploy
7. sanitized evidenceを`docs/qst/BETA_SUPABASE_PROJECT.yaml`へ生成

MVP/Betaの既定AI経路はGemini stable Interactions APIである。`GEMINI_API_KEY`はEdge Functionの
server-side secretとしてのみ保存する。OpenAI互換経路は`AI_PROVIDER=openai`を明示した場合だけ使用し、
provider障害時に別providerへ暗黙送信しない。選択providerが利用できない場合はArcのローカルfallbackへ戻る。

remote schemaをDashboardやSQL Editorで直接変更しない。すべてのschema変更はtimestamp付きmigrationを
経由させ、履歴不一致がある場合は自動repairせず、`supabase migration list`の差分をレビューする。

## Completion Check

```powershell
dart run tools/qst/verify_supabase_beta_bootstrap.dart --require-cloud
```

このcheckはproject ref、region、owner、Dashboard証跡参照、CLI access、migration head、6 function、
secret名、candidate commitを要求する。
secret値は要求せず、記録されている場合は失敗する。QST-160はこのcheckが成功するまで完了ではない。

## Flutter Candidate Configuration

Flutterへ渡してよい値はpublic project URLとanon keyだけである。

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

`SUPABASE_SERVICE_ROLE_KEY`とprovider API keyをFlutter buildへ渡してはいけない。

## Official References

- https://supabase.com/docs/guides/local-development/cli/config
- https://supabase.com/docs/guides/local-development/cli-workflows
- https://supabase.com/docs/guides/deployment/database-migrations
- https://supabase.com/docs/guides/functions/deploy
- https://supabase.com/docs/guides/functions/secrets
