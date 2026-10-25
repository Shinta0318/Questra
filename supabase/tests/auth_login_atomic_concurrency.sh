#!/usr/bin/env bash
set -euo pipefail

# This drill is confined to the isolated Supabase DB started by CI.
psql_cmd=(psql --host 127.0.0.1 --port 54322 --username postgres \
  --dbname postgres --set ON_ERROR_STOP=1 --tuples-only --no-align --quiet)
user_id=00000000-0000-4000-8000-000000000560
temp_dir=$(mktemp -d)
holder_pid=''

cleanup() {
  if [[ -n "$holder_pid" ]] && kill -0 "$holder_pid" 2>/dev/null; then
    kill "$holder_pid" 2>/dev/null || true
    wait "$holder_pid" 2>/dev/null || true
  fi
  "${psql_cmd[@]}" -c "delete from auth.users where id = '$user_id';" >/dev/null 2>&1 || true
  rm -f "$temp_dir/holder.out" "$temp_dir/holder.err"
  rmdir "$temp_dir" 2>/dev/null || true
}
trap cleanup EXIT

"${psql_cmd[@]}" <<SQL >/dev/null
insert into auth.users (
  id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at, raw_user_meta_data
)
select '$user_id', 'authenticated', 'authenticated',
       'qst557-race@example.test', 'test-only', now(), now(), now(),
       jsonb_build_object(
         'region_code', policy.region_code,
         'minimum_age_confirmed', true,
         'eligibility_version', policy.eligibility_version,
         'terms_version', policy.terms_version,
         'privacy_version', policy.privacy_version,
         'ai_disclosure_version', policy.ai_disclosure_version
       )
from public.legal_release_policies as policy
where policy.region_code = 'JP' and policy.active;
select public.record_auth_login_failure_v2('$user_id')
from generate_series(1, 9);
SQL

fixture_count=$("${psql_cmd[@]}" -c "
  select count(*) from auth.users where id = '$user_id';
")
if [[ "$fixture_count" != 1 ]]; then
  echo 'QST-557 legal-policy-compliant fixture user was not created.' >&2
  exit 1
fi

# The holder creates failure ten, then keeps its row lock while the other
# session attempts to record a successful password grant.
PGAPPNAME=qst557-holder "${psql_cmd[@]}" -c "
  begin;
  select public.record_auth_login_failure_v2('$user_id');
  select pg_sleep(8);
  commit;
" >"$temp_dir/holder.out" 2>"$temp_dir/holder.err" &
holder_pid=$!

ready=false
for _ in {1..80}; do
  waiting=$("${psql_cmd[@]}" -c "
    select count(*) from pg_stat_activity
    where application_name = 'qst557-holder'
      and wait_event = 'PgSleep';
  ")
  if [[ "$waiting" == 1 ]]; then
    ready=true
    break
  fi
  sleep 0.1
done
if [[ "$ready" != true ]]; then
  echo 'QST-557 holder did not acquire the row lock.' >&2
  exit 1
fi

decision=$("${psql_cmd[@]}" -c "
  select public.record_auth_login_success_v2('$user_id') ->> 'status';
")
wait "$holder_pid"
holder_pid=''

if [[ "$decision" != locked ]]; then
  echo 'QST-557 concurrent success crossed the lockout boundary.' >&2
  exit 1
fi

locked=$("${psql_cmd[@]}" -c "
  select failed_attempts = 10 and locked_until > now()
  from public.auth_login_accounts where user_id = '$user_id';
")
if [[ "$locked" != t ]]; then
  echo 'QST-557 tenth failure did not preserve its lockout state.' >&2
  exit 1
fi

echo 'QST-557 concurrent lockout decision: PASS'
