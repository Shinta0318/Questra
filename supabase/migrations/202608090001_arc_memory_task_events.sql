alter table public.arc_memories
  add column if not exists task_id uuid
  references public.tasks(id) on delete cascade;

alter table public.arc_memories
  drop constraint if exists arc_memories_memory_type_check;

alter table public.arc_memories
  add constraint arc_memories_memory_type_check check (
    memory_type in (
      'quest_memory',
      'mission_memory',
      'task_memory',
      'trail_memory',
      'preference_memory',
      'emotional_memory',
      'life_event_memory',
      'arc_relationship_memory'
    )
  );

create index if not exists arc_memories_user_task_created_idx
  on public.arc_memories (user_id, task_id, created_at desc)
  where task_id is not null;

create or replace function public.enforce_arc_memory_task_context()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.task_id is null then
    return new;
  end if;

  if not exists (
    select 1
    from public.tasks t
    where t.id = new.task_id
      and t.owner_id = new.user_id
      and t.quest_id = new.quest_id
      and t.mission_id = new.mission_id
  ) then
    raise exception 'Arc Memory Task context must share owner, Quest and Mission.';
  end if;
  return new;
end;
$$;

drop trigger if exists arc_memory_task_context_guard
  on public.arc_memories;
create trigger arc_memory_task_context_guard
before insert or update of user_id, quest_id, mission_id, task_id
on public.arc_memories
for each row execute function public.enforce_arc_memory_task_context();

revoke all on function public.enforce_arc_memory_task_context() from public;
