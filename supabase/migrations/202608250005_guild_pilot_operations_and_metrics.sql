-- QST-363: controlled Guild pilot operations, moderation audit, and privacy-safe metrics.
begin;

create table if not exists public.guild_pilot_operators (
  user_id uuid primary key references public.user_profiles(id) on delete cascade,
  role text not null default 'reviewer' check (role in ('reviewer', 'operator')),
  created_at timestamptz not null default now()
);

create table if not exists public.guild_pilot_events (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.user_profiles(id) on delete cascade,
  publication_id uuid references public.guild_quest_publications(id) on delete set null,
  destination_quest_id uuid references public.quests(id) on delete cascade,
  event_name text not null check (
    event_name in (
      'discovery_opened', 'copy_completed', 'first_progress_completed',
      'moderation_appeal_submitted'
    )
  ),
  event_key text not null check (char_length(event_key) between 8 and 160),
  occurred_at timestamptz not null default now(),
  unique (owner_id, event_key)
);

create table if not exists public.guild_pilot_moderation_events (
  id uuid primary key default gen_random_uuid(),
  operator_id uuid not null references public.user_profiles(id) on delete restrict,
  publication_id uuid references public.guild_quest_publications(id) on delete set null,
  appeal_id uuid references public.guild_moderation_appeals(id) on delete set null,
  action text not null check (
    action in (
      'publication_approved', 'publication_rejected',
      'appeal_accepted', 'appeal_rejected', 'member_enabled', 'member_disabled'
    )
  ),
  reason_code text not null check (reason_code ~ '^[a-z0-9_]{3,60}$'),
  created_at timestamptz not null default now()
);

create index if not exists guild_pilot_events_funnel_idx
  on public.guild_pilot_events(event_name, occurred_at desc);
create index if not exists guild_pilot_moderation_queue_idx
  on public.guild_quest_publications(moderation_status, updated_at);
create unique index if not exists guild_moderation_one_open_appeal_idx
  on public.guild_moderation_appeals(owner_id, publication_id)
  where status in ('pending', 'reviewing');

alter table public.guild_pilot_operators enable row level security;
alter table public.guild_pilot_events enable row level security;
alter table public.guild_pilot_moderation_events enable row level security;

create policy "Guild pilot members inspect their own events"
  on public.guild_pilot_events for select using (owner_id = auth.uid());

create or replace function public.is_guild_pilot_operator()
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists(
    select 1 from public.guild_pilot_operators where user_id = auth.uid()
  );
$$;

create or replace function public.get_guild_pilot_status()
returns jsonb language sql stable security definer set search_path = public, pg_temp as $$
  select case when auth.uid() is null then
    jsonb_build_object('configured', true, 'enabled', false, 'cohort', null)
  else coalesce((
    select jsonb_build_object(
      'configured', true,
      'enabled', member.enabled,
      'cohort', member.cohort
    )
    from public.guild_pilot_members member where member.user_id = auth.uid()
  ), jsonb_build_object('configured', true, 'enabled', false, 'cohort', null)) end;
$$;

create or replace function public.record_guild_pilot_event(
  p_event_name text,
  p_publication_id uuid,
  p_event_key text
) returns uuid
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_actor uuid := auth.uid();
  v_id uuid;
begin
  if v_actor is null then raise exception 'authentication_required'; end if;
  if p_event_name <> 'discovery_opened' then raise exception 'unsupported_event'; end if;
  if char_length(trim(p_event_key)) not between 8 and 160 then raise exception 'invalid_event_key'; end if;
  if not exists(
    select 1 from public.guild_pilot_members
    where user_id = v_actor and enabled
  ) then raise exception 'guild_pilot_not_enabled'; end if;
  if not exists(
    select 1 from public.guild_quest_publications
    where id = p_publication_id and visibility = 'public' and moderation_status = 'approved'
  ) then raise exception 'publication_not_available'; end if;

  insert into public.guild_pilot_events(owner_id, publication_id, event_name, event_key)
  values(v_actor, p_publication_id, p_event_name, trim(p_event_key))
  on conflict (owner_id, event_key) do update set event_key = excluded.event_key
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.capture_guild_copy_metric()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  insert into public.guild_pilot_events(
    owner_id, publication_id, destination_quest_id, event_name, event_key, occurred_at
  ) values(
    new.copier_id, new.publication_id, new.destination_quest_id,
    'copy_completed', 'copy:' || new.id::text, new.created_at
  ) on conflict (owner_id, event_key) do nothing;
  return new;
end;
$$;

drop trigger if exists guild_copy_metric on public.guild_quest_copy_events;
create trigger guild_copy_metric after insert on public.guild_quest_copy_events
for each row execute function public.capture_guild_copy_metric();

create or replace function public.capture_guild_first_progress_metric()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_copy public.guild_quest_copy_events%rowtype;
begin
  if new.status <> 'completed' or old.status = 'completed' then return new; end if;
  select * into v_copy from public.guild_quest_copy_events
    where destination_quest_id = new.quest_id and copier_id = new.owner_id
    order by created_at limit 1;
  if not found then return new; end if;
  insert into public.guild_pilot_events(
    owner_id, publication_id, destination_quest_id, event_name, event_key
  ) values(
    new.owner_id, v_copy.publication_id, new.quest_id,
    'first_progress_completed', 'first-progress:' || new.quest_id::text
  ) on conflict (owner_id, event_key) do nothing;
  return new;
end;
$$;

drop trigger if exists guild_first_progress_metric on public.tasks;
create trigger guild_first_progress_metric after update of status on public.tasks
for each row execute function public.capture_guild_first_progress_metric();

create or replace function public.capture_guild_appeal_metric()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  insert into public.guild_pilot_events(owner_id, publication_id, event_name, event_key)
  values(new.owner_id, new.publication_id, 'moderation_appeal_submitted', 'appeal:' || new.id::text)
  on conflict (owner_id, event_key) do nothing;
  return new;
end;
$$;

drop trigger if exists guild_appeal_metric on public.guild_moderation_appeals;
create trigger guild_appeal_metric after insert on public.guild_moderation_appeals
for each row execute function public.capture_guild_appeal_metric();

create or replace function public.set_guild_pilot_member(
  p_user_id uuid,
  p_enabled boolean,
  p_cohort text,
  p_reason_code text
) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_guild_pilot_operator() then raise exception 'operator_required'; end if;
  if char_length(trim(p_cohort)) not between 1 and 80 then raise exception 'invalid_cohort'; end if;
  if trim(p_reason_code) !~ '^[a-z0-9_]{3,60}$' then raise exception 'invalid_reason_code'; end if;
  insert into public.guild_pilot_members(user_id, enabled, cohort, enabled_at)
  values(p_user_id, p_enabled, trim(p_cohort), case when p_enabled then now() end)
  on conflict (user_id) do update set
    enabled = excluded.enabled,
    cohort = excluded.cohort,
    enabled_at = case when excluded.enabled then now() else null end;
  insert into public.guild_pilot_moderation_events(operator_id, action, reason_code)
  values(auth.uid(), case when p_enabled then 'member_enabled' else 'member_disabled' end, trim(p_reason_code));
end;
$$;

create or replace function public.resolve_guild_publication_moderation(
  p_publication_id uuid,
  p_approved boolean,
  p_reason_code text
) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_guild_pilot_operator() then raise exception 'operator_required'; end if;
  if trim(p_reason_code) !~ '^[a-z0-9_]{3,60}$' then raise exception 'invalid_reason_code'; end if;
  update public.guild_quest_publications set
    moderation_status = case when p_approved then 'approved' else 'rejected' end,
    updated_at = now()
  where id = p_publication_id and moderation_status = 'pending';
  if not found then raise exception 'publication_not_pending'; end if;
  insert into public.guild_pilot_moderation_events(operator_id, publication_id, action, reason_code)
  values(
    auth.uid(), p_publication_id,
    case when p_approved then 'publication_approved' else 'publication_rejected' end,
    trim(p_reason_code)
  );
end;
$$;

create or replace function public.resolve_guild_moderation_appeal(
  p_appeal_id uuid,
  p_accepted boolean,
  p_reason_code text
) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_publication_id uuid;
begin
  if not public.is_guild_pilot_operator() then raise exception 'operator_required'; end if;
  if trim(p_reason_code) !~ '^[a-z0-9_]{3,60}$' then raise exception 'invalid_reason_code'; end if;
  update public.guild_moderation_appeals set
    status = case when p_accepted then 'accepted' else 'rejected' end,
    resolved_at = now()
  where id = p_appeal_id and status in ('pending', 'reviewing')
  returning publication_id into v_publication_id;
  if v_publication_id is null then raise exception 'appeal_not_open'; end if;
  if p_accepted then
    update public.guild_quest_publications set moderation_status = 'pending', updated_at = now()
    where id = v_publication_id;
  end if;
  insert into public.guild_pilot_moderation_events(
    operator_id, publication_id, appeal_id, action, reason_code
  ) values(
    auth.uid(), v_publication_id, p_appeal_id,
    case when p_accepted then 'appeal_accepted' else 'appeal_rejected' end,
    trim(p_reason_code)
  );
end;
$$;

create or replace function public.get_guild_pilot_metrics()
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
declare
  v_members integer;
  v_opens integer;
  v_copies integer;
  v_progress integer;
  v_appeals integer;
begin
  if not public.is_guild_pilot_operator() then raise exception 'operator_required'; end if;
  select count(*) into v_members from public.guild_pilot_members where enabled;
  select count(*) filter(where event_name='discovery_opened'),
         count(*) filter(where event_name='copy_completed'),
         count(*) filter(where event_name='first_progress_completed'),
         count(*) filter(where event_name='moderation_appeal_submitted')
    into v_opens, v_copies, v_progress, v_appeals
  from public.guild_pilot_events;
  return jsonb_build_object(
    'enabled_members', v_members,
    'discovery_opens', v_opens,
    'copies', v_copies,
    'first_progress', v_progress,
    'appeals', v_appeals,
    'copy_to_first_progress_rate', case when v_copies = 0 then 0 else round(v_progress::numeric / v_copies, 4) end
  );
end;
$$;

revoke all on public.guild_pilot_operators, public.guild_pilot_events,
  public.guild_pilot_moderation_events from anon, authenticated;
grant select on public.guild_pilot_events to authenticated;

revoke all on function public.is_guild_pilot_operator() from public, anon;
revoke all on function public.get_guild_pilot_status() from public, anon;
revoke all on function public.record_guild_pilot_event(text, uuid, text) from public, anon;
revoke all on function public.set_guild_pilot_member(uuid, boolean, text, text) from public, anon;
revoke all on function public.resolve_guild_publication_moderation(uuid, boolean, text) from public, anon;
revoke all on function public.resolve_guild_moderation_appeal(uuid, boolean, text) from public, anon;
revoke all on function public.get_guild_pilot_metrics() from public, anon;
grant execute on function public.is_guild_pilot_operator() to authenticated;
grant execute on function public.get_guild_pilot_status() to authenticated;
grant execute on function public.record_guild_pilot_event(text, uuid, text) to authenticated;
grant execute on function public.set_guild_pilot_member(uuid, boolean, text, text) to authenticated;
grant execute on function public.resolve_guild_publication_moderation(uuid, boolean, text) to authenticated;
grant execute on function public.resolve_guild_moderation_appeal(uuid, boolean, text) to authenticated;
grant execute on function public.get_guild_pilot_metrics() to authenticated;

comment on table public.guild_pilot_events is
  'Metadata-only controlled-pilot funnel events. Quest, Mission, Task, Trail, Arc chat, and profile text are forbidden.';
comment on table public.guild_pilot_moderation_events is
  'Operator action audit using allowlisted reason codes; no user content is copied into this table.';

commit;
