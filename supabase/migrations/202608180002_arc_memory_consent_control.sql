begin;

alter table public.arc_memories
  add column if not exists provenance jsonb not null default '{}'::jsonb,
  add column if not exists retention_until timestamptz;

update public.arc_memories
set
  provenance = case
    when provenance = '{}'::jsonb then jsonb_build_object(
      'origin', source_type,
      'source_id', source_id,
      'migrated_from', 'legacy_arc_memory'
    )
    else provenance
  end,
  retention_until = coalesce(retention_until, created_at + interval '365 days');

create index if not exists arc_memories_owner_retention_idx
  on public.arc_memories (user_id, retention_until, importance_score desc);

create table if not exists public.arc_memory_consent_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.user_profiles(id) on delete cascade,
  purpose_version integer not null,
  status text not null check (status in ('granted', 'denied', 'withdrawn')),
  source text not null,
  occurred_at timestamptz not null default now(),
  evidence jsonb not null default '{}'::jsonb
);

alter table public.arc_memory_consent_events enable row level security;

create policy "Users read own Arc Memory consent history"
  on public.arc_memory_consent_events for select
  using (user_id = auth.uid());

revoke insert, update, delete on public.arc_memory_consent_events
  from anon, authenticated;

create or replace function public.record_arc_memory_consent_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.purpose_code = 'arc_personalization' then
    insert into public.arc_memory_consent_events (
      user_id,
      purpose_version,
      status,
      source,
      occurred_at,
      evidence
    ) values (
      new.user_id,
      new.purpose_version,
      new.status,
      new.source,
      coalesce(new.created_at, now()),
      jsonb_build_object('explicit_action', true)
    );
  end if;
  return new;
end;
$$;

drop trigger if exists user_consents_arc_memory_audit
  on public.user_consents;
create trigger user_consents_arc_memory_audit
after insert or update of status on public.user_consents
for each row execute function public.record_arc_memory_consent_event();

create or replace function public.arc_memory_consent_granted(target_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select (
    target_user = auth.uid()
    or coalesce(auth.role(), '') = 'service_role'
  ) and exists (
    select 1
    from public.user_consents consent
    where consent.user_id = target_user
      and consent.purpose_code = 'arc_personalization'
      and consent.status = 'granted'
      and consent.purpose_version = (
        select max(purpose.version)
        from public.consent_purposes purpose
        where purpose.purpose_code = 'arc_personalization'
          and purpose.effective_from <= now()
      )
  );
$$;

create or replace function public.enforce_arc_memory_consent()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.arc_memory_consent_granted(new.user_id) then
    raise exception using
      errcode = '42501',
      message = 'arc_memory_consent_required';
  end if;
  if new.sensitivity_level = 'sensitive' then
    raise exception using
      errcode = '22023',
      message = 'sensitive_arc_memory_prohibited';
  end if;
  if new.provenance = '{}'::jsonb then
    new.provenance := jsonb_build_object(
      'origin', new.source_type,
      'source_id', new.source_id
    );
  end if;
  if new.retention_until is null then
    new.retention_until := now() + case
      when new.sensitivity_level = 'personal' then interval '90 days'
      else interval '365 days'
    end;
  end if;
  return new;
end;
$$;

drop trigger if exists arc_memory_consent_guard on public.arc_memories;
create trigger arc_memory_consent_guard
before insert on public.arc_memories
for each row execute function public.enforce_arc_memory_consent();

drop policy if exists "Users create their own Arc memories"
  on public.arc_memories;
create policy "Users create consented own Arc memories"
  on public.arc_memories for insert
  with check (
    user_id = auth.uid()
    and public.arc_memory_consent_granted(auth.uid())
  );

create or replace function public.get_relevant_arc_memories(
  p_user_id uuid,
  p_quest_id uuid,
  p_limit integer default 3
) returns table (
  id uuid,
  memory_type text,
  title text,
  content text,
  importance_score numeric,
  source_type text,
  source_id text,
  provenance jsonb,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.arc_memory_consent_granted(p_user_id) then
    return;
  end if;
  return query
  select
    memory.id,
    memory.memory_type,
    memory.title,
    memory.content,
    memory.importance_score,
    memory.source_type,
    memory.source_id,
    memory.provenance,
    memory.updated_at
  from public.arc_memories memory
  where memory.user_id = p_user_id
    and memory.user_visible
    and memory.sensitivity_level <> 'sensitive'
    and (memory.quest_id = p_quest_id or memory.quest_id is null)
    and (memory.retention_until is null or memory.retention_until > now())
  order by memory.importance_score desc, memory.updated_at desc
  limit least(greatest(coalesce(p_limit, 3), 1), 5);
end;
$$;

revoke all on function public.get_relevant_arc_memories(uuid, uuid, integer)
  from public, anon, authenticated;
grant execute on function public.get_relevant_arc_memories(uuid, uuid, integer)
  to service_role;

revoke all on function public.arc_memory_consent_granted(uuid) from public;
grant execute on function public.arc_memory_consent_granted(uuid)
  to authenticated, service_role;
revoke all on function public.enforce_arc_memory_consent() from public;
revoke all on function public.record_arc_memory_consent_event() from public;

commit;
