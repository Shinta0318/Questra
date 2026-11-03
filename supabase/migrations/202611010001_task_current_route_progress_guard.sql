begin;

-- Reject stale Task progress after another device closes or pauses its route.
create or replace function public.guard_task_progress_current_route()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.status not in ('in_progress', 'completed') then
    return new;
  end if;
  if tg_op = 'UPDATE' then
    if new.status is not distinct from old.status then
      return new;
    end if;
  end if;

  -- NOWAIT fails closed instead of waiting on a concurrent route change.
  perform 1
  from public.missions m
  join public.quests q on q.id = m.quest_id
  where m.id = new.mission_id
    and m.quest_id = new.quest_id
    and q.owner_id = new.owner_id
    and q.status = 'active'
    and m.status = 'todo'
    and m.route_state = 'active'
  for share of m, q nowait;

  if not found then
    raise exception 'task_route_inactive';
  end if;
  return new;
end;
$$;

revoke all on function public.guard_task_progress_current_route()
  from public, anon, authenticated;

drop trigger if exists tasks_guard_progress_current_route on public.tasks;
create trigger tasks_guard_progress_current_route
before insert or update of status on public.tasks
for each row execute function public.guard_task_progress_current_route();

commit;
