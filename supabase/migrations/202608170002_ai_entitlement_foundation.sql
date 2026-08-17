begin;

create table if not exists public.user_entitlements (
  user_id uuid primary key references auth.users(id) on delete cascade,
  subscription_state text not null default 'free' check (
    subscription_state in ('free', 'premium', 'grace_period')
  ),
  source text not null default 'system' check (
    source in ('system', 'admin', 'future_billing_provider')
  ),
  effective_from timestamptz not null default now(),
  expires_at timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists public.ai_usage_policies (
  operation text not null,
  subscription_state text not null check (
    subscription_state in ('free', 'premium', 'grace_period')
  ),
  monthly_hard_limit integer check (monthly_hard_limit is null or monthly_hard_limit > 0),
  enabled boolean not null default true,
  updated_at timestamptz not null default now(),
  primary key (operation, subscription_state),
  check (operation in (
    'arc_consultation',
    'quest_planning',
    'basic_mission_planning',
    'mission_redesign',
    'detailed_progress_review'
  ))
);

create table if not exists public.ai_usage_counters (
  user_id uuid not null references auth.users(id) on delete cascade,
  operation text not null,
  period_start date not null,
  usage_count integer not null default 0 check (usage_count >= 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, operation, period_start),
  check (operation in (
    'arc_consultation',
    'quest_planning',
    'basic_mission_planning',
    'mission_redesign',
    'detailed_progress_review'
  ))
);

insert into public.ai_usage_policies (
  operation, subscription_state, monthly_hard_limit
)
select operation, subscription_state, null
from unnest(array[
  'arc_consultation',
  'quest_planning',
  'basic_mission_planning',
  'mission_redesign',
  'detailed_progress_review'
]) operation
cross join unnest(array['free', 'premium', 'grace_period']) subscription_state
on conflict (operation, subscription_state) do nothing;

alter table public.user_entitlements enable row level security;
alter table public.ai_usage_policies enable row level security;
alter table public.ai_usage_counters enable row level security;

drop policy if exists user_entitlements_owner_select on public.user_entitlements;
create policy user_entitlements_owner_select
  on public.user_entitlements for select using (user_id = auth.uid());

drop policy if exists ai_usage_counters_owner_select on public.ai_usage_counters;
create policy ai_usage_counters_owner_select
  on public.ai_usage_counters for select using (user_id = auth.uid());

create or replace function public.resolve_ai_entitlement(p_operation text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := auth.uid();
  v_state text;
  v_limit integer;
  v_used integer;
  v_period date := date_trunc('month', now())::date;
  v_policy_found boolean := false;
begin
  if v_actor is null then raise exception 'authentication_required'; end if;
  if p_operation not in (
    'arc_consultation', 'quest_planning', 'basic_mission_planning',
    'mission_redesign', 'detailed_progress_review'
  ) then raise exception 'unsupported_ai_operation'; end if;

  select case
      when expires_at is not null and expires_at <= now() then 'free'
      else subscription_state
    end
    into v_state
  from public.user_entitlements where user_id = v_actor;
  v_state := coalesce(v_state, 'free');

  select monthly_hard_limit, true into v_limit, v_policy_found
  from public.ai_usage_policies
  where operation = p_operation and subscription_state = v_state and enabled;
  if not v_policy_found then raise exception 'ai_usage_policy_not_configured'; end if;

  select coalesce(usage_count, 0) into v_used
  from public.ai_usage_counters
  where user_id = v_actor and operation = p_operation and period_start = v_period;
  v_used := coalesce(v_used, 0);

  return jsonb_build_object(
    'subscription_state', v_state,
    'operation', p_operation,
    'allowed', v_limit is null or v_used < v_limit,
    'used', v_used,
    'hard_limit', v_limit,
    'period_start', v_period,
    'resets_at', (v_period + interval '1 month')
  );
end;
$$;

revoke all on function public.resolve_ai_entitlement(text) from public;
grant execute on function public.resolve_ai_entitlement(text) to authenticated;

commit;
