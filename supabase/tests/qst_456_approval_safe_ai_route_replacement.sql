-- QST-456 hosted contract checks. Run after candidate deployment.
begin;

select has_function_privilege(
  'authenticated',
  'public.approve_quest_plan_preview(uuid,uuid)',
  'EXECUTE'
) as authenticated_owner_can_approve_preview;

select position(
  'route_changed_since_preview'
  in pg_get_functiondef(
    'public.approve_quest_plan_preview(uuid,uuid)'::regprocedure
  )
) > 0 as stale_route_is_rejected;

select position(
  'status <> ''completed'''
  in pg_get_functiondef(
    'public.approve_quest_plan_preview(uuid,uuid)'::regprocedure
  )
) > 0 as only_unfinished_route_is_replaced;

select position(
  'completed_mission_duplicate_in_plan'
  in pg_get_functiondef(
    'public.approve_quest_plan_preview(uuid,uuid)'::regprocedure
  )
) > 0 as completed_mission_duplicates_are_rejected;

select position(
  'delete from public.missions'
  in lower(pg_get_functiondef(
    'public.approve_quest_plan_preview(uuid,uuid)'::regprocedure
  ))
) = 0 as mission_history_is_not_deleted;

rollback;
