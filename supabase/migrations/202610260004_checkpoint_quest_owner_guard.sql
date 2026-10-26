begin;

create function public.validate_quest_planning_checkpoint_owner()
returns trigger language plpgsql security definer
set search_path = pg_catalog
as $$
begin
  if not exists (
    select 1 from public.quests q
    where q.id = new.quest_id and q.owner_id = new.owner_id
  ) then
    raise exception 'checkpoint_quest_owner_mismatch' using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger validate_quest_planning_checkpoint_owner_before_write
before insert or update of owner_id, quest_id
on public.quest_planning_pass_checkpoints
for each row execute function public.validate_quest_planning_checkpoint_owner();

revoke all on function public.validate_quest_planning_checkpoint_owner()
  from public, anon, authenticated;

commit;
