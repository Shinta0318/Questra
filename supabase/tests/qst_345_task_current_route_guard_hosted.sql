-- QST-345: exercise the hosted route guard through the same owner RPCs as the app.
-- All fixture writes are transaction-local and are discarded at the end.
begin;

do $fixture$
declare
  v_owner uuid := gen_random_uuid();
  v_quest uuid := gen_random_uuid();
  v_mission uuid := gen_random_uuid();
  v_task uuid := gen_random_uuid();
begin
  perform set_config('qst.guard.owner', v_owner::text, true);
  perform set_config('qst.guard.quest', v_quest::text, true);
  perform set_config('qst.guard.mission', v_mission::text, true);
  perform set_config('qst.guard.task', v_task::text, true);

  insert into auth.users (
    id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at, raw_user_meta_data
  )
  select v_owner, 'authenticated', 'authenticated',
         'qst345-' || v_owner::text || '@example.invalid',
         'qst345', now(), now(), now(),
         jsonb_build_object(
           'region_code', policy.region_code,
           'minimum_age_confirmed', true,
           'eligibility_version', policy.eligibility_version,
           'terms_version', policy.terms_version,
           'privacy_version', policy.privacy_version,
           'ai_disclosure_version', policy.ai_disclosure_version
         )
  from public.legal_release_policies policy
  where policy.region_code = 'JP' and policy.active;
  if not found then raise exception 'qst345_test_legal_policy_missing'; end if;

  insert into public.user_profiles (id, nickname)
  values (v_owner, 'QST-345 route guard test')
  on conflict (id) do nothing;
  insert into public.quests (id, owner_id, title, status, visibility)
  values (v_quest, v_owner, 'Route guard test Quest', 'active', 'private');
  insert into public.missions (
    id, quest_id, title, guide_type, difficulty, status, route_state
  ) values (
    v_mission, v_quest, 'Route guard test Mission', 'route', 'easy', 'todo', 'paused'
  );
  insert into public.tasks (
    id, owner_id, quest_id, mission_id, title, action, done_condition,
    status, version, generated_by, origin, verification_type
  ) values (
    v_task, v_owner, v_quest, v_mission, 'Route guard test Task',
    'Check the current route', 'The route is current',
    'pending', 1, 'user', 'user', 'self'
  );
end;
$fixture$;

set local role authenticated;
select set_config('request.jwt.claim.sub', current_setting('qst.guard.owner'), true);

do $paused$
declare
  v_task uuid := current_setting('qst.guard.task')::uuid;
  v_failed boolean := false;
begin
  begin
    perform public.create_tasks_if_absent(
      'qst345-paused-insert',
      jsonb_build_array(
        (select to_jsonb(t) || jsonb_build_object(
          'id', gen_random_uuid(), 'status', 'in_progress'
        ) from public.tasks t where t.id = v_task)
      )
    );
  exception when others then
    if sqlerrm <> 'task_route_inactive' then raise; end if;
    v_failed := true;
  end;
  if not v_failed then raise exception 'paused_insert_was_accepted'; end if;

  v_failed := false;
  begin
    perform public.update_task_if_version(
      v_task, 1, 'qst345-paused-start',
      (select to_jsonb(t) || jsonb_build_object('status', 'in_progress')
       from public.tasks t where t.id = v_task)
    );
  exception when others then
    if sqlerrm <> 'task_route_inactive' then raise; end if;
    v_failed := true;
  end;
  if not v_failed then raise exception 'paused_start_was_accepted'; end if;

  v_failed := false;
  begin
    perform public.complete_task_journey(v_task, 'qst345-paused-complete', 1);
  exception when others then
    if sqlerrm <> 'task_route_inactive' then raise; end if;
    v_failed := true;
  end;
  if not v_failed then raise exception 'paused_completion_was_accepted'; end if;
  if not exists (
    select 1 from public.tasks where id = v_task and status = 'pending' and version = 1
  ) then raise exception 'rejected_progress_changed_task'; end if;
end;
$paused$;

reset role;
update public.missions set route_state = 'active'
where id = current_setting('qst.guard.mission')::uuid;
set local role authenticated;
select set_config('request.jwt.claim.sub', current_setting('qst.guard.owner'), true);

do $active$
declare
  v_task uuid := current_setting('qst.guard.task')::uuid;
  v_result jsonb;
begin
  v_result := public.update_task_if_version(
    v_task, 1, 'qst345-active-start',
    (select to_jsonb(t) || jsonb_build_object('status', 'in_progress')
     from public.tasks t where t.id = v_task)
  );
  if v_result->>'status' <> 'applied' or (v_result->>'version')::integer <> 2 then
    raise exception 'active_start_failed';
  end if;
end;
$active$;

reset role;
update public.quests set status = 'archived'
where id = current_setting('qst.guard.quest')::uuid;
set local role authenticated;
select set_config('request.jwt.claim.sub', current_setting('qst.guard.owner'), true);

do $archived$
declare
  v_task uuid := current_setting('qst.guard.task')::uuid;
  v_failed boolean := false;
begin
  begin
    perform public.complete_task_journey(v_task, 'qst345-archived-complete', 2);
  exception when others then
    if sqlerrm <> 'task_route_inactive' then raise; end if;
    v_failed := true;
  end;
  if not v_failed then raise exception 'archived_completion_was_accepted'; end if;
  if not exists (
    select 1 from public.tasks where id = v_task and status = 'in_progress' and version = 2
  ) then raise exception 'archived_rejection_changed_task'; end if;
end;
$archived$;

reset role;
update public.quests set status = 'active'
where id = current_setting('qst.guard.quest')::uuid;
set local role authenticated;
select set_config('request.jwt.claim.sub', current_setting('qst.guard.owner'), true);

do $completion$
declare
  v_task uuid := current_setting('qst.guard.task')::uuid;
  v_result jsonb;
begin
  v_result := public.complete_task_journey(v_task, 'qst345-active-complete', 2);
  if v_result->>'status' <> 'completed' or (v_result->>'version')::integer <> 3 then
    raise exception 'active_completion_failed';
  end if;
end;
$completion$;

rollback;
select 'QST-345 hosted Task route guard: PASS' as result;
