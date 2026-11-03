-- Run after the atomic edited-approval migration is applied.
begin;

do $$
declare
  v_function text;
begin
  if not exists (
    select 1 from pg_class
    where oid = 'public.quest_plan_approval_selections'::regclass
      and relrowsecurity
  ) then
    raise exception 'approval selection RLS is not enabled';
  end if;
  if has_table_privilege('anon', 'public.quest_plan_approval_selections', 'SELECT')
    or has_table_privilege('authenticated', 'public.quest_plan_approval_selections', 'SELECT')
    or has_table_privilege('authenticated', 'public.quest_plan_approval_selections', 'INSERT')
  then
    raise exception 'approval selection table is exposed to a client role';
  end if;
  if not has_table_privilege('service_role', 'public.quest_plan_approval_selections', 'SELECT')
    or not has_table_privilege('service_role', 'public.quest_plan_approval_selections', 'INSERT')
  then
    raise exception 'Edge Function cannot stage a reviewed selection';
  end if;
  if has_function_privilege(
    'anon',
    'public.approve_quest_plan_preview_with_selection(uuid,uuid,uuid)',
    'EXECUTE'
  ) or not has_function_privilege(
    'authenticated',
    'public.approve_quest_plan_preview_with_selection(uuid,uuid,uuid)',
    'EXECUTE'
  ) then
    raise exception 'atomic approval RPC grants are incorrect';
  end if;
  if has_function_privilege(
    'authenticated',
    'public.approve_quest_plan_preview(uuid,uuid)',
    'EXECUTE'
  ) then
    raise exception 'legacy approval RPC bypasses the consent gate';
  end if;
  if has_function_privilege(
    'anon',
    'public.approve_quest_plan_preview_unedited(uuid,uuid)',
    'EXECUTE'
  ) or not has_function_privilege(
    'authenticated',
    'public.approve_quest_plan_preview_unedited(uuid,uuid)',
    'EXECUTE'
  ) then
    raise exception 'unedited approval RPC grants are incorrect';
  end if;

  v_function := lower(pg_get_functiondef(
    'public.approve_quest_plan_preview_with_selection(uuid,uuid,uuid)'::regprocedure
  ));
  if position('for update' in v_function) = 0
    or position('approved_selection_id' in v_function) = 0
    or position('has_current_ai_legal_acceptance' in v_function) = 0
    or position('public.approve_quest_plan_preview(' in v_function) = 0
  then
    raise exception 'atomic approval RPC is missing its lock, replay guard, or route transaction';
  end if;
  v_function := lower(pg_get_functiondef(
    'public.approve_quest_plan_preview_unedited(uuid,uuid)'::regprocedure
  ));
  if position('approved_selection_id' in v_function) = 0
    or position('approval_token_invalid' in v_function) = 0
    or position('has_current_ai_legal_acceptance' in v_function) = 0
  then
    raise exception 'unedited approval RPC is missing its replay or token guard';
  end if;
  if has_function_privilege(
    'authenticated',
    'public.prune_stale_quest_plan_approval_selections()',
    'EXECUTE'
  ) then
    raise exception 'stale selection cleanup is exposed to clients';
  end if;
end;
$$;

do $$
declare
  v_owner uuid := gen_random_uuid();
  v_quest uuid := gen_random_uuid();
  v_run uuid := gen_random_uuid();
  v_preview uuid := gen_random_uuid();
  v_token uuid := gen_random_uuid();
  v_selection uuid := gen_random_uuid();
  v_original jsonb := '{"routeMissionPlan":{"missions":[]}}'::jsonb;
  v_valid_plan jsonb;
  v_policy record;
  v_result jsonb;
begin
  select region_code, eligibility_version, terms_version,
    privacy_version, ai_disclosure_version into v_policy
  from public.legal_release_policies
  where region_code = 'JP' and active
  limit 1;
  if not found then raise exception 'validation_legal_policy_missing'; end if;

  insert into auth.users (
    id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at, raw_user_meta_data
  ) values (
    v_owner, 'authenticated', 'authenticated',
    'approval-' || v_owner::text || '@example.test', 'fixture',
    now(), now(), now(), jsonb_build_object(
      'region_code', v_policy.region_code,
      'minimum_age_confirmed', true,
      'eligibility_version', v_policy.eligibility_version,
      'terms_version', v_policy.terms_version,
      'privacy_version', v_policy.privacy_version,
      'ai_disclosure_version', v_policy.ai_disclosure_version
    )
  );
  insert into public.quests (id, owner_id, title, status, visibility)
  values (v_quest, v_owner, 'Atomic approval fixture', 'active', 'private');
  insert into public.quest_planning_runs (
    id, owner_id, quest_id, trace_id, idempotency_key, status,
    pipeline_version, schema_version
  ) values (
    v_run, v_owner, v_quest, gen_random_uuid(), v_run::text,
    'preview_ready', 'fixture', 'fixture'
  );
  insert into public.quest_plan_previews (
    id, owner_id, quest_id, planning_run_id, approval_token, plan_payload
  ) values (v_preview, v_owner, v_quest, v_run, v_token, v_original);
  insert into public.quest_plan_approval_selections (
    id, owner_id, preview_id, selection_fingerprint, plan_payload
  ) values (
    v_selection, v_owner, v_preview, repeat('a', 64),
    '{"sentinel":"edited"}'::jsonb
  );

  delete from public.legal_acceptances where user_id = v_owner;
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  begin
    perform public.approve_quest_plan_preview_with_selection(
      v_preview, v_token, v_selection
    );
    raise exception 'edited approval accepted a user without current consent';
  exception when others then
    if sqlerrm not like '%ai_legal_consent_required%' then raise; end if;
  end;
  begin
    perform public.approve_quest_plan_preview_unedited(v_preview, v_token);
    raise exception 'unedited approval accepted a user without current consent';
  exception when others then
    if sqlerrm not like '%ai_legal_consent_required%' then raise; end if;
  end;
  insert into public.legal_acceptances (
    user_id, eligibility_version, terms_version, privacy_version,
    ai_disclosure_version, region_code, minimum_age_confirmed, source
  ) values (
    v_owner, v_policy.eligibility_version, v_policy.terms_version,
    v_policy.privacy_version, v_policy.ai_disclosure_version,
    v_policy.region_code, true, 'account_gate'
  );

  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  begin
    perform public.approve_quest_plan_preview_with_selection(
      v_preview, gen_random_uuid(), v_selection
    );
    raise exception 'wrong token was accepted';
  exception when others then
    if sqlerrm not like '%approval_token_invalid%' then raise; end if;
  end;

  perform set_config('request.jwt.claim.sub', gen_random_uuid()::text, true);
  begin
    perform public.approve_quest_plan_preview_with_selection(
      v_preview, v_token, v_selection
    );
    raise exception 'cross-account approval was accepted';
  exception when others then
    if sqlerrm not like '%preview_not_found%' then raise; end if;
  end;

  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  v_valid_plan := jsonb_build_object(
    'routeApplication', jsonb_build_object(
      'applicationMode', 'initial', 'baseMissions', '[]'::jsonb
    ),
    'routeMissionPlan', jsonb_build_object(
      'planVersion', 1,
      'missions', jsonb_build_array(jsonb_build_object(
        'clientId', 'mission-1',
        'title', 'Plan the first journey',
        'objective', 'Choose a destination and travel dates',
        'successCondition', 'Destination and dates are written down',
        'expectedOutcome', 'A concrete travel outline',
        'calendarDurationDays', 7,
        'dependencies', '[]'::jsonb
      ))
    ),
    'currentTaskPlan', jsonb_build_object(
      'missionClientId', 'mission-1',
      'tasks', jsonb_build_array(jsonb_build_object(
        'clientId', 'task-1',
        'title', 'Check available travel dates',
        'action', 'Check the calendar for available dates',
        'purpose', 'Set a feasible travel window',
        'doneCondition', 'Travel dates have been selected',
        'expectedOutput', 'Candidate travel dates',
        'estimatedEffortMinutes', 20,
        'dependencies', '[]'::jsonb
      ))
    ),
    'qualityGate', jsonb_build_object(
      'status', 'passed', 'version', 'qst-341-v1'
    ),
    'missionCritic', jsonb_build_object(
      'passed', true, 'overallScore', 95,
      'missionResults', jsonb_build_array(jsonb_build_object(
        'clientId', 'mission-1', 'passed', true, 'verdict', 'pass',
        'scores', jsonb_build_object(
          'questRelevance', 95,
          'outcomeQuality', 95,
          'missionGranularity', 95,
          'successConditionQuality', 95,
          'personalization', 95,
          'nonTemplateQuality', 95,
          'uniqueness', 95,
          'sequencing', 95,
          'completenessContribution', 95,
          'taskSeparation', 95
        )
      ))
    ),
    'currentTaskCritic', jsonb_build_object(
      'passed', true, 'overallScore', 95,
      'taskResults', jsonb_build_array(jsonb_build_object(
        'clientId', 'task-1', 'passed', true
      ))
    )
  );
  update public.quest_plan_approval_selections
  set plan_payload = jsonb_set(
    v_valid_plan, '{currentTaskPlan,missionClientId}', '"missing-mission"'::jsonb
  )
  where id = v_selection;
  begin
    perform public.approve_quest_plan_preview_with_selection(
      v_preview, v_token, v_selection
    );
    raise exception 'route with a missing Task parent was approved';
  exception when others then
    if sqlerrm not like '%task_plan_mission_not_found%' then raise; end if;
  end;
  if not exists (
    select 1 from public.quest_plan_previews
    where id = v_preview and status = 'pending'
      and plan_payload = v_original and approved_selection_id is null
  ) then
    raise exception 'failed approval changed the pending preview';
  end if;
  if not exists (
    select 1 from public.quest_plan_approval_selections
    where id = v_selection
  ) then
    raise exception 'failed approval discarded the reviewed selection';
  end if;
  if exists (select 1 from public.route_versions where quest_id = v_quest)
    or exists (select 1 from public.missions where quest_id = v_quest)
    or exists (select 1 from public.tasks where quest_id = v_quest)
    or exists (
      select 1 from public.quests
      where id = v_quest and active_route_id is not null
    )
  then
    raise exception 'late route failure left partial route writes behind';
  end if;

  update public.quest_plan_approval_selections
  set plan_payload = v_valid_plan
  where id = v_selection;
  v_result := public.approve_quest_plan_preview_with_selection(
    v_preview, v_token, v_selection
  );
  if v_result->>'status' <> 'approved'
    or v_result->>'mission_count' <> '1'
    or v_result->>'task_count' <> '1'
    or v_result->>'idempotent' is not null
  then
    raise exception 'edited approval did not persist one Mission and Task';
  end if;
  if not exists (
    select 1 from public.quest_plan_previews
    where id = v_preview and status = 'approved'
      and approved_selection_id = v_selection
      and approved_selection_fingerprint = repeat('a', 64)
      and plan_payload #>> '{routeMissionPlan,missions,0,title}' = 'Plan the first journey'
  ) or (select count(*) from public.missions where quest_id = v_quest and route_state <> 'removed') <> 1
    or (select count(*) from public.tasks where quest_id = v_quest) <> 1
    or exists (select 1 from public.quest_plan_approval_selections where preview_id = v_preview)
  then
    raise exception 'edited approval did not atomically replace the plan and clear staging';
  end if;
  v_result := public.approve_quest_plan_preview_with_selection(
    v_preview, v_token, v_selection
  );
  if v_result->>'status' <> 'approved'
    or v_result->>'idempotent' <> 'true'
    or (select count(*) from public.missions where quest_id = v_quest and route_state <> 'removed') <> 1
    or (select count(*) from public.tasks where quest_id = v_quest) <> 1
  then
    raise exception 'same edited approval replay duplicated the route';
  end if;
  begin
    perform public.approve_quest_plan_preview_with_selection(
      v_preview, v_token, gen_random_uuid()
    );
    raise exception 'different edited approval was accepted';
  exception when others then
    if sqlerrm not like '%preview_already_approved_with_different_selection%'
    then raise; end if;
  end;
  begin
    perform public.approve_quest_plan_preview_unedited(v_preview, v_token);
    raise exception 'unedited approval accepted an edited route';
  exception when others then
    if sqlerrm not like '%preview_already_approved_with_different_selection%'
    then raise; end if;
  end;
end;
$$;

rollback;
