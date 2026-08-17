begin;

create or replace function public.navigator_rank_for_stardust(p_stardust integer)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select case
    when greatest(coalesce(p_stardust, 0), 0) >= 300 then 'navigator'
    when greatest(coalesce(p_stardust, 0), 0) >= 150 then 'stargazer'
    when greatest(coalesce(p_stardust, 0), 0) >= 50 then 'pathfinder'
    else 'novice'
  end;
$$;

create table if not exists public.stardust_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  event_type text not null check (event_type in (
    'quest_created',
    'mission_completed',
    'task_completed',
    'trail_recorded',
    'trail_reflection_recorded',
    'quest_completed'
  )),
  source_id uuid not null,
  amount integer not null check (amount between 1 and 100),
  reason_code text not null,
  created_at timestamptz not null default now(),
  unique (user_id, event_type, source_id)
);

create index if not exists stardust_events_user_created_idx
  on public.stardust_events (user_id, created_at desc);

alter table public.stardust_events enable row level security;

drop policy if exists stardust_events_owner_select on public.stardust_events;
create policy stardust_events_owner_select
  on public.stardust_events for select
  using (user_id = auth.uid());

create or replace function public.protect_progression_columns()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'INSERT' then
    if current_user not in ('postgres', 'service_role') and
       (new.stardust_balance <> 0 or new.navigator_rank <> 'novice') then
      raise exception 'progression_columns_are_server_managed';
    end if;
  elsif (new.stardust_balance is distinct from old.stardust_balance or
         new.navigator_rank is distinct from old.navigator_rank) and
        current_user not in ('postgres', 'service_role') and
        coalesce(current_setting('questra.stardust_award', true), '') <> 'allowed' then
    raise exception 'progression_columns_are_server_managed';
  end if;
  return new;
end;
$$;

drop trigger if exists user_profiles_progression_insert_guard on public.user_profiles;
create trigger user_profiles_progression_insert_guard
before insert on public.user_profiles
for each row execute function public.protect_progression_columns();

drop trigger if exists user_profiles_progression_update_guard on public.user_profiles;
create trigger user_profiles_progression_update_guard
before update of stardust_balance, navigator_rank on public.user_profiles
for each row execute function public.protect_progression_columns();

create or replace function public.award_stardust(
  p_event_type text,
  p_source_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := auth.uid();
  v_amount integer;
  v_reason text;
  v_inserted_amount integer;
  v_balance integer;
  v_rank text;
begin
  if v_actor is null then
    raise exception 'authentication_required';
  end if;

  case p_event_type
    when 'quest_created' then
      if not exists (
        select 1 from public.quests q
        where q.id = p_source_id and q.owner_id = v_actor
      ) then raise exception 'source_not_owned'; end if;
      v_amount := 5;
      v_reason := 'quest_created';
    when 'mission_completed' then
      if not exists (
        select 1 from public.missions m
        join public.quests q on q.id = m.quest_id
        where m.id = p_source_id
          and q.owner_id = v_actor
          and m.status = 'completed'
      ) then raise exception 'source_not_completed_or_owned'; end if;
      v_amount := 10;
      v_reason := 'mission_completed';
    when 'task_completed' then
      if not exists (
        select 1 from public.tasks t
        where t.id = p_source_id
          and t.owner_id = v_actor
          and t.status = 'completed'
      ) then raise exception 'source_not_completed_or_owned'; end if;
      v_amount := 2;
      v_reason := 'task_completed';
    when 'trail_recorded' then
      if not exists (
        select 1 from public.trails t
        where t.id = p_source_id
          and t.owner_id = v_actor
          and t.trail_type <> 'arc_reflection'
      ) then raise exception 'source_not_owned'; end if;
      v_amount := 3;
      v_reason := p_event_type;
    when 'trail_reflection_recorded' then
      if not exists (
        select 1 from public.trails t
        where t.id = p_source_id
          and t.owner_id = v_actor
          and t.trail_type = 'arc_reflection'
      ) then raise exception 'source_not_owned'; end if;
      v_amount := 3;
      v_reason := p_event_type;
    when 'quest_completed' then
      if not exists (
        select 1 from public.quests q
        where q.id = p_source_id
          and q.owner_id = v_actor
          and q.status = 'completed'
      ) then raise exception 'source_not_completed_or_owned'; end if;
      v_amount := 25;
      v_reason := 'quest_completed';
    else
      raise exception 'unsupported_stardust_event';
  end case;

  insert into public.stardust_events (
    user_id, event_type, source_id, amount, reason_code
  ) values (
    v_actor, p_event_type, p_source_id, v_amount, v_reason
  )
  on conflict (user_id, event_type, source_id) do nothing
  returning amount into v_inserted_amount;

  if v_inserted_amount is not null then
    perform set_config('questra.stardust_award', 'allowed', true);
    update public.user_profiles
    set stardust_balance = stardust_balance + v_inserted_amount,
        navigator_rank = public.navigator_rank_for_stardust(
          stardust_balance + v_inserted_amount
        ),
        updated_at = now()
    where id = v_actor
    returning stardust_balance, navigator_rank into v_balance, v_rank;
  else
    select stardust_balance,
           public.navigator_rank_for_stardust(stardust_balance)
      into v_balance, v_rank
    from public.user_profiles
    where id = v_actor;
  end if;

  if v_balance is null then raise exception 'profile_not_found'; end if;

  return jsonb_build_object(
    'awarded', v_inserted_amount is not null,
    'amount', coalesce(v_inserted_amount, 0),
    'stardust_balance', v_balance,
    'navigator_rank', v_rank
  );
end;
$$;

revoke all on function public.award_stardust(text, uuid) from public;
grant execute on function public.award_stardust(text, uuid) to authenticated;

update public.user_profiles
set navigator_rank = public.navigator_rank_for_stardust(stardust_balance)
where navigator_rank is distinct from public.navigator_rank_for_stardust(stardust_balance);

commit;
