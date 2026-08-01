begin;

create table public.quest_progress_events (
  event_id uuid primary key default gen_random_uuid(),
  event_name text not null,
  event_version integer not null default 1 check (event_version > 0),
  user_id uuid not null references public.user_profiles(id) on delete cascade,
  quest_id uuid references public.quests(id) on delete cascade,
  mission_id uuid references public.missions(id) on delete cascade,
  route_id uuid references public.route_versions(id) on delete set null,
  source text not null check (source in ('user', 'arc', 'system', 'business')),
  occurred_at timestamptz not null,
  received_at timestamptz not null default now(),
  session_id uuid,
  device_type text,
  app_version text,
  app_environment text not null default 'production' check (app_environment in ('development', 'test', 'production')),
  quest_dna_version integer,
  planning_engine_version text,
  model_provider text,
  model_version text,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  idempotency_key text not null check (char_length(idempotency_key) between 8 and 160),
  unique (user_id, idempotency_key)
);

create index quest_progress_events_timeline_idx
  on public.quest_progress_events (user_id, occurred_at desc);
create index quest_progress_events_quest_idx
  on public.quest_progress_events (quest_id, occurred_at);

alter table public.quest_progress_events enable row level security;
create policy "Users read their own progress events"
  on public.quest_progress_events for select using (user_id = auth.uid());

revoke insert, update, delete on public.quest_progress_events from anon, authenticated;

create or replace function public.record_quest_progress_event(
  p_event_name text,
  p_event_version integer,
  p_quest_id uuid,
  p_mission_id uuid,
  p_route_id uuid,
  p_source text,
  p_occurred_at timestamptz,
  p_session_id uuid,
  p_device_type text,
  p_app_version text,
  p_app_environment text,
  p_quest_dna_version integer,
  p_planning_engine_version text,
  p_model_provider text,
  p_model_version text,
  p_metadata jsonb,
  p_idempotency_key text
) returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  actor_id uuid := auth.uid();
  result_id uuid;
  safe_metadata jsonb;
begin
  if actor_id is null then raise exception 'authentication required'; end if;
  if p_source not in ('user', 'arc', 'system', 'business') then raise exception 'invalid source'; end if;
  if char_length(p_idempotency_key) not between 8 and 160 then raise exception 'invalid idempotency key'; end if;
  if p_quest_id is not null and not exists (
    select 1 from public.quests where id = p_quest_id and owner_id = actor_id
  ) then raise exception 'quest not owned'; end if;
  if p_mission_id is not null and not exists (
    select 1 from public.missions where id = p_mission_id and owner_id = actor_id
  ) then raise exception 'mission not owned'; end if;
  if p_route_id is not null and not exists (
    select 1 from public.route_versions rv join public.quests q on q.id = rv.quest_id
    where rv.id = p_route_id and q.owner_id = actor_id
  ) then raise exception 'route not owned'; end if;

  select coalesce(jsonb_object_agg(key, value), '{}'::jsonb)
    into safe_metadata
  from jsonb_each(coalesce(p_metadata, '{}'::jsonb))
  where key = any(array[
    'category', 'difficulty_band', 'status', 'visibility', 'surface',
    'progress_band', 'stage', 'reason_code', 'proposal_type', 'support_type',
    'interaction', 'outcome', 'source_type', 'plan_quality_band'
  ]);

  insert into public.quest_progress_events (
    event_name, event_version, user_id, quest_id, mission_id, route_id, source,
    occurred_at, session_id, device_type, app_version, app_environment,
    quest_dna_version, planning_engine_version, model_provider, model_version,
    metadata, idempotency_key
  ) values (
    left(p_event_name, 80), greatest(p_event_version, 1), actor_id,
    p_quest_id, p_mission_id, p_route_id, p_source,
    coalesce(p_occurred_at, now()), p_session_id, left(p_device_type, 40),
    left(p_app_version, 40), coalesce(p_app_environment, 'production'),
    p_quest_dna_version, left(p_planning_engine_version, 80),
    left(p_model_provider, 40), left(p_model_version, 80), safe_metadata,
    p_idempotency_key
  ) on conflict (user_id, idempotency_key) do nothing
  returning event_id into result_id;
  if result_id is null then
    select event_id into result_id from public.quest_progress_events
    where user_id = actor_id and idempotency_key = p_idempotency_key;
  end if;
  return result_id;
end;
$$;

grant execute on function public.record_quest_progress_event(
  text, integer, uuid, uuid, uuid, text, timestamptz, uuid, text, text, text,
  integer, text, text, text, jsonb, text
) to authenticated;

comment on table public.quest_progress_events is
  'Append-only owner-scoped progress events. Free-form Quest, Mission, Arc chat, and Arc Memory text are prohibited.';

commit;
