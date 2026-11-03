-- QST-456 hosted contract checks. Run after candidate deployment.
begin;

do $$
declare
  v_route_function text;
begin
  if has_function_privilege(
    'authenticated',
    'public.approve_quest_plan_preview(uuid,uuid)',
    'EXECUTE'
  ) then
    raise exception 'direct route approval bypasses the consent-gated wrappers';
  end if;
  if not has_function_privilege(
    'authenticated',
    'public.approve_quest_plan_preview_unedited(uuid,uuid)',
    'EXECUTE'
  ) or not has_function_privilege(
    'authenticated',
    'public.approve_quest_plan_preview_with_selection(uuid,uuid,uuid)',
    'EXECUTE'
  ) then
    raise exception 'consent-gated route approval wrappers are not available';
  end if;
  v_route_function := pg_get_functiondef(
    'public.approve_quest_plan_preview(uuid,uuid)'::regprocedure
  );
  if position('route_changed_since_preview' in v_route_function) = 0 then
    raise exception 'stale route is no longer rejected';
  end if;
  if position('status <> ''completed''' in v_route_function) = 0 then
    raise exception 'completed Missions are no longer protected';
  end if;
  if position('completed_mission_duplicate_in_plan' in v_route_function) = 0 then
    raise exception 'completed Mission duplicates are no longer rejected';
  end if;
  if position('delete from public.missions' in lower(v_route_function)) <> 0 then
    raise exception 'route approval can delete Mission history';
  end if;
end;
$$;

rollback;
