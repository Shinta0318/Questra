# QST Tools

Local DEV-QST helpers live here. They use the repository backlog at
`docs/product/qst_backlog.md` and write no files by default.

## Commands

```powershell
.\tools\qst\qst.ps1 next
.\tools\qst\qst.ps1 prompt QST-003
.\tools\qst\qst.ps1 report QST-003
```

- `next`: prints the first `Ready` backlog item.
- `prompt`: prints an implementation prompt for a backlog item.
- `report`: prints a QST report template for a backlog item.

Reports produced from the template should be saved under `reports/qst`.

## Release Checks

```powershell
dart run tools\qst\verify_rls_readiness.dart
$env:SUPABASE_DB_URL = '<secret-postgresql-url>'
.\tools\qst\run_rls_behavior_tests.ps1
```

- `verify_rls_readiness.dart`: checks the MVP Supabase migration for RLS
  enablement and required owner/public/Guild policies for Quest, Mission, Trail,
  TrailEvent, Arc Memory, and media boundaries.
- `run_rls_behavior_tests.ps1`: runs database-backed RLS behavior tests from
  `supabase/tests/rls_behavior.sql`. It parses `SUPABASE_DB_URL`, passes only
  sanitized connection fields to `psql`, and keeps the password in a temporary
  process environment variable. The SQL test rolls back its seed data.
- `verify_hosted_login_roundtrip.mjs`: with `SUPABASE_URL`,
  `SUPABASE_ANON_KEY`, `QST_TEST_LOGIN_ID`, and `QST_TEST_PASSWORD` supplied
  through a private process environment, makes one login attempt and reads the
  returned Auth user and owner profile. It prints only pass/fail stages, never
  credentials, tokens, account identifiers, or profile content. Use a verified
  test account after password reset; clear the temporary environment variables
  after the run. Do not use a shared or user-supplied chat password.
- `capture_cloud_rls_evidence.ps1`: verifies linked migrations, executes the
  RLS harness, and writes candidate-bound sanitized Beta evidence.
- `verify_cloud_rls_evidence.dart`: validates the static evidence contract and,
  with `--require-cloud`, requires real project/migration/RLS evidence.

### Candidate Source and Evidence Commits

Build and test the candidate from one clean, immutable source commit. Record
that SHA as `source_commit` in `BETA_CANDIDATE.yaml` and bind all Hosted, device,
legal, and AI evidence to it. Evidence can be committed later without changing
the candidate identity, but every path changed between the source commit and
the evidence HEAD must be in the release evidence allowlist in
`candidate_git_state.dart`. A later app, migration, function, asset, or test
change invalidates the candidate and requires a new source SHA and new evidence.
The final GO check also requires a clean working tree; an uncommitted evidence
file is not a distribution-ready decision.
The approved manifest must name both SHA-bound Web and Android files under
`artifacts/candidate/`. The release check measures each file's byte count and
SHA-256 again; a manifest checksum alone is not artifact evidence.

### Edge Function PR Contract

`.github/workflows/edge-contract.yml` runs independently of the Flutter release
job when Edge functions or their Hosted probes change. It checks all function
entrypoints with pinned Deno 2.4.5 and runs the auth/direct-AI/probe Node tests
with Node 24. Locally, run `deno check supabase/functions/*/index.ts` in a shell
that expands the glob, then run the test files under
`supabase/functions/auth-login`, `supabase/functions/_shared`, and the two
`verify_hosted_*` probe tests. A green check does not establish a deployed
function, a successful user login, or a real Gemini response; the candidate-
bound Hosted gates remain separate.
