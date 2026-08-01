begin;

create table public.quest_stage_state (
  quest_id uuid primary key references public.quests(id) on delete cascade,
  current_stage text not null check (current_stage in ('dreaming','exploring','planning','preparing','acting','near_completion','completed','paused','abandoned')),
  stage_source text not null check (stage_source in ('user','arc','system')),
  confidence numeric(4,3) not null default 1 check (confidence between 0 and 1),
  reason_code text,
  calculated_at timestamptz not null default now(),
  confirmed_at timestamptz,
  version integer not null default 1 check (version > 0)
);

create table public.quest_stage_history (
  id uuid primary key default gen_random_uuid(),
  quest_id uuid not null references public.quests(id) on delete cascade,
  previous_stage text,
  next_stage text not null,
  source text not null check (source in ('user','arc','system')),
  confidence numeric(4,3),
  reason_code text,
  created_at timestamptz not null default now()
);

alter table public.quest_stage_state enable row level security;
alter table public.quest_stage_history enable row level security;
create policy "Owners manage Quest stage" on public.quest_stage_state for all
  using (exists (select 1 from public.quests q where q.id = quest_id and q.owner_id = auth.uid()))
  with check (exists (select 1 from public.quests q where q.id = quest_id and q.owner_id = auth.uid()));
create policy "Owners read Quest stage history" on public.quest_stage_history for select
  using (exists (select 1 from public.quests q where q.id = quest_id and q.owner_id = auth.uid()));

create or replace function public.set_quest_lifecycle_stage(
  p_quest_id uuid, p_next_stage text, p_source text, p_confidence numeric,
  p_reason_code text, p_idempotency_key text
) returns public.quest_stage_state
language plpgsql security definer set search_path = public
as $$
declare actor_id uuid := auth.uid(); previous text; result public.quest_stage_state;
begin
  if actor_id is null then raise exception 'authentication required'; end if;
  if not exists (select 1 from public.quests where id = p_quest_id and owner_id = actor_id) then raise exception 'quest not owned'; end if;
  if p_next_stage not in ('dreaming','exploring','planning','preparing','acting','near_completion','completed','paused','abandoned') then raise exception 'invalid stage'; end if;
  if p_source not in ('user','arc','system') then raise exception 'invalid source'; end if;
  select current_stage into previous from public.quest_stage_state where quest_id = p_quest_id;
  insert into public.quest_stage_state (quest_id,current_stage,stage_source,confidence,reason_code,calculated_at,confirmed_at,version)
  values (p_quest_id,p_next_stage,p_source,least(greatest(coalesce(p_confidence,0),0),1),left(p_reason_code,80),now(),case when p_source='user' then now() end,1)
  on conflict (quest_id) do update set current_stage=excluded.current_stage,stage_source=excluded.stage_source,confidence=excluded.confidence,reason_code=excluded.reason_code,calculated_at=now(),confirmed_at=excluded.confirmed_at,version=quest_stage_state.version+1
  returning * into result;
  if previous is distinct from p_next_stage then
    insert into public.quest_stage_history (quest_id,previous_stage,next_stage,source,confidence,reason_code)
    values (p_quest_id,previous,p_next_stage,p_source,p_confidence,left(p_reason_code,80));
    perform public.record_quest_progress_event('quest_stage_changed',1,p_quest_id,null,null,p_source,now(),null,null,null,'production',null,null,null,null,jsonb_build_object('stage',p_next_stage,'reason_code',p_reason_code),p_idempotency_key);
  end if;
  return result;
end;
$$;
grant execute on function public.set_quest_lifecycle_stage(uuid,text,text,numeric,text,text) to authenticated;

insert into public.quest_stage_state (quest_id, current_stage, stage_source, confidence, reason_code)
select q.id,
  case when q.status = 'completed' then 'completed'
       when exists (select 1 from public.missions m where m.quest_id = q.id)
        and not exists (select 1 from public.missions m where m.quest_id = q.id and m.status <> 'completed') then 'near_completion'
       when exists (select 1 from public.missions m where m.quest_id = q.id and m.status = 'completed') then 'acting'
       when exists (select 1 from public.missions m where m.quest_id = q.id) then 'preparing'
       else 'planning' end,
  'system', 0.7, 'safe_backfill'
from public.quests q on conflict (quest_id) do nothing;

commit;
