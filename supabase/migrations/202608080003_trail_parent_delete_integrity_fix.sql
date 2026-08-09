-- QST-278 follow-up: keep ON DELETE SET NULL Trail history consistent.
begin;

create or replace function public.validate_trail_hierarchy()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_quest_owner uuid;
  v_mission_quest uuid;
  v_task_owner uuid;
  v_task_quest uuid;
  v_task_mission uuid;
begin
  -- Parent deletion detaches the full lower context in one row update. This
  -- prevents individual SET NULL actions from exposing a transient mismatch.
  if new.quest_id is null then
    new.mission_id := null;
    new.task_id := null;
  elsif new.mission_id is null then
    new.task_id := null;
  end if;

  if new.quest_id is not null then
    select owner_id into v_quest_owner from public.quests where id = new.quest_id;
    if v_quest_owner is null or v_quest_owner <> new.owner_id then
      raise exception 'trail_quest_mismatch';
    end if;
  end if;

  if new.mission_id is not null then
    select quest_id into v_mission_quest from public.missions where id = new.mission_id;
    if v_mission_quest is null or v_mission_quest <> new.quest_id then
      raise exception 'trail_mission_mismatch';
    end if;
  end if;

  if new.task_id is not null then
    select owner_id, quest_id, mission_id
      into v_task_owner, v_task_quest, v_task_mission
    from public.tasks where id = new.task_id;
    if v_task_owner is null
      or v_task_owner <> new.owner_id
      or v_task_quest <> new.quest_id
      or v_task_mission <> new.mission_id then
      raise exception 'trail_task_mismatch';
    end if;
  end if;

  if new.trail_type = 'mission_record' and new.mission_id is null
    and not (tg_op = 'UPDATE' and old.mission_id is not null) then
    raise exception 'mission_trail_requires_mission';
  end if;
  return new;
end;
$$;

commit;
