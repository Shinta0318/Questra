# Cloud Migration and RLS Evidence

## Purpose

Questra Beta databaseへ全migrationが適用され、owner dataとcross-account accessがRLSで分離される
ことを、candidate固有のsanitized evidenceとして記録する。静的policy検査やlocal database結果は
cloud evidenceを代替しない。

## Prerequisite

QST-160のcloud completion gateが成功していること。

```powershell
dart run tools/qst/verify_supabase_beta_bootstrap.dart --require-cloud
```

次をlocal secretとして用意する。値をrepository、terminal command、Reportへ貼り付けない。

- `SUPABASE_DB_URL`: Supabase DashboardのConnect画面から取得したPostgreSQL URL
- Supabase CLI login/link state
- `psql` client

## Secure Connection Validation

```powershell
$env:SUPABASE_DB_URL = '<secret-postgresql-url>'
powershell -ExecutionPolicy Bypass -File tools/qst/run_rls_behavior_tests.ps1 -ValidateOnly
```

runnerはURLをhost、port、user、databaseへ分解し、passwordを`PGPASSWORD`へ一時設定する。
URL全体を`psql`のprocess argumentや出力へ渡さない。remote接続では`sslmode=require`を使い、
実行後にdatabase関連環境変数を元へ戻す。

## Evidence Capture

```powershell
powershell -ExecutionPolicy Bypass -File tools/qst/capture_cloud_rls_evidence.ps1 `
  -ProjectRef '<20-character-project-ref>'
```

captureは次を実行する。

1. QST-160 project evidenceとproject refの一致確認
2. `supabase migration list --linked`とlatest local migrationの一致確認
3. `supabase/tests/rls_behavior.sql`をremote databaseでtransaction内実行
4. owner read、cross-account deny/public read、unauthorized write denyのassertion確認
5. test file SHA-256、assertion数、candidate commit、実行時刻、psql versionの記録

test transactionは最後に`rollback`し、固定test userやjourney recordをdatabaseへ残さない。

## Completion Gate

```powershell
dart run tools/qst/verify_cloud_rls_evidence.dart --require-cloud
```

このgateはQST-160 project evidence、project ref、migration head、test SHA-256、現在のassertion数、
owner/cross-account/write-denial結果を照合する。DB URL、password、private journey contentが
evidenceへ含まれる場合は失敗する。

## Failure Handling

- `db push`またはmigration listが不一致なら、remote schemaを直接変更しない。
- `migration repair`は履歴とschemaを個別確認した後にのみ使用する。
- RLS assertionが1件でも失敗したらBeta配布を停止し、evidenceを`verified`へ変更しない。
- connection errorとpolicy failureを区別し、秘密値を含まない要約だけをissueへ記録する。

## Official References

- https://supabase.com/docs/guides/deployment/database-migrations
- https://supabase.com/docs/guides/database/postgres/row-level-security
- https://supabase.com/docs/guides/local-development/cli/testing-and-linting
