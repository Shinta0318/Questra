-- QST-342 hosted evidence script. Run with two authenticated users after the
-- exact migration SHA is deployed. Service-role calls are intentionally made
-- by the test harness; clients must not receive execute permission.
begin;

select has_function_privilege(
  'authenticated',
  'public.reserve_ai_usage_budget(uuid,text,text,text,text,integer,integer,uuid,text)',
  'EXECUTE'
) = false as authenticated_cannot_reserve_for_forged_user;

select has_function_privilege(
  'authenticated',
  'public.settle_ai_usage_budget(uuid,text,integer,integer,text)',
  'EXECUTE'
) = false as authenticated_cannot_settle;

select monthly_hard_limit is not null
    and monthly_cost_hard_limit_micros is not null
    and per_minute_hard_limit is not null as limits_are_fail_closed
from public.ai_usage_policies;

select count(*) = 0 as no_duplicate_idempotency_rows
from (
  select user_id, operation, idempotency_key
  from public.ai_budget_reservations
  group by user_id, operation, idempotency_key
  having count(*) > 1
) duplicates;

rollback;
