begin;

create extension if not exists pg_cron;

create function public.prune_expired_quest_planning_checkpoints()
returns integer
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  deleted_count integer;
begin
  with expired as (
    select id
    from public.quest_planning_pass_checkpoints
    where expires_at <= now()
    order by expires_at
    limit 2000
    for update skip locked
  )
  delete from public.quest_planning_pass_checkpoints checkpoint
  using expired
  where checkpoint.id = expired.id;

  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$$;

revoke all on function public.prune_expired_quest_planning_checkpoints()
  from public, anon, authenticated, service_role;

select cron.schedule(
  'questra-planning-checkpoint-prune',
  '0 * * * *',
  'select public.prune_expired_quest_planning_checkpoints()'
);

drop trigger prune_quest_planning_pass_checkpoints_after_write
  on public.quest_planning_pass_checkpoints;
drop function public.prune_quest_planning_pass_checkpoints();

commit;
