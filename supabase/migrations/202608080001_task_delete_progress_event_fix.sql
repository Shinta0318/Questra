-- QST-273: keep Quest cascade deletion valid after Task hierarchy rollout.
-- A task_deleted event cannot outlive its Task because task_id uses ON DELETE
-- CASCADE. The BEFORE DELETE trigger therefore created an event that was
-- immediately removed for direct deletes and blocked parent Quest cascades.
drop trigger if exists tasks_record_delete_event on public.tasks;

create or replace function public.record_task_progress_event()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare v_event text;
begin
  v_event := case
    when tg_op='INSERT' then 'task_created'
    when new.status='completed' and old.status is distinct from new.status then 'task_completed'
    when new.status='in_progress' and old.status is distinct from new.status then 'task_started'
    when new.status='skipped' and old.status is distinct from new.status then 'task_skipped'
    when new.status='blocked' and old.status is distinct from new.status then 'task_blocked'
    when new.scheduled_date is distinct from old.scheduled_date then 'task_rescheduled'
    else null end;
  if v_event is not null then
    insert into public.task_progress_events(owner_id,quest_id,mission_id,task_id,event_name,event_key,metadata)
    values(new.owner_id,new.quest_id,new.mission_id,new.id,v_event,
      concat(v_event,':',new.id,':',extract(epoch from clock_timestamp())::bigint),
      jsonb_build_object('from_status',case when tg_op='INSERT' then null else old.status end,'to_status',new.status));
  end if;
  return new;
end;
$$;
