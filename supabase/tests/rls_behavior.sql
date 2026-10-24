\set ON_ERROR_STOP on

\echo 'QST-041 RLS behavior tests'

begin;

create function pg_temp.qst_assert_eq(
  actual bigint,
  expected integer,
  label text
)
returns void
language plpgsql
as $$
begin
  if actual <> expected then
    raise exception '%: expected %, got %', label, expected, actual;
  end if;
end;
$$;

create function pg_temp.qst_assert_raises(
  statement text,
  label text
)
returns void
language plpgsql
as $$
declare
  did_raise boolean := false;
begin
  begin
    execute statement;
  exception
    when others then
      did_raise := true;
  end;

  if not did_raise then
    raise exception '%: expected statement to fail', label;
  end if;
end;
$$;

\set owner_id '00000000-0000-4000-8000-000000000041'
\set other_id '00000000-0000-4000-8000-000000000042'
\set owner_private_quest_id '00000000-0000-4000-8000-000000004101'
\set owner_public_quest_id '00000000-0000-4000-8000-000000004102'
\set other_private_quest_id '00000000-0000-4000-8000-000000004201'
\set owner_private_mission_id '00000000-0000-4000-8000-000000014101'
\set owner_private_task_id '00000000-0000-4000-8000-000000154101'
\set owner_qst528_task_id '00000000-0000-4000-8000-000000154128'
\set owner_qst534_task_id '00000000-0000-4000-8000-000000154134'
\set owner_qst535_dependent_task_id '00000000-0000-4000-8000-000000154135'
\set owner_public_mission_id '00000000-0000-4000-8000-000000014102'
\set other_private_mission_id '00000000-0000-4000-8000-000000014201'
\set owner_private_trail_id '00000000-0000-4000-8000-000000024101'
\set owner_public_trail_id '00000000-0000-4000-8000-000000024102'
\set other_private_trail_id '00000000-0000-4000-8000-000000024201'
\set owner_validated_trail_id '00000000-0000-4000-8000-000000024103'
\set owner_memory_id '00000000-0000-4000-8000-000000034101'
\set other_memory_id '00000000-0000-4000-8000-000000034201'
\set owner_media_id '00000000-0000-4000-8000-000000044101'
\set owner_public_media_id '00000000-0000-4000-8000-000000044102'
\set other_media_id '00000000-0000-4000-8000-000000044201'
\set guild_publication_id '00000000-0000-4000-8000-000000054101'
\set guild_pending_publication_id '00000000-0000-4000-8000-000000054102'
\set guild_mission_publication_id '00000000-0000-4000-8000-000000064101'
\set guild_copy_event_id '00000000-0000-4000-8000-000000074201'
\set owner_route_version_id '00000000-0000-4000-8000-000000084101'
\set owner_route_proposal_id '00000000-0000-4000-8000-000000094101'
\set owner_route_item_id '00000000-0000-4000-8000-000000104101'
\set owner_progress_event_id '00000000-0000-4000-8000-000000114101'
\set owner_dna_version_id '00000000-0000-4000-8000-000000124101'
\set owner_business_signal_id '00000000-0000-4000-8000-000000134101'
\set owner_consent_id '00000000-0000-4000-8000-000000144101'
\set owner_planning_run_id '00000000-0000-4000-8000-000000164101'
\set owner_plan_preview_id '00000000-0000-4000-8000-000000174101'
\set owner_mission_draft_id '00000000-0000-4000-8000-000000184101'
\set owner_mission_candidate_id '00000000-0000-4000-8000-000000194101'
\set owner_data_rights_request_id '00000000-0000-4000-8000-000000204101'
\set other_data_rights_request_id '00000000-0000-4000-8000-000000204201'
\set owner_runtime_event_id '00000000-0000-4000-8000-000000214101'
\set other_runtime_event_id '00000000-0000-4000-8000-000000214201'

insert into auth.users (
  id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at, raw_user_meta_data
)
select fixture.id::uuid, 'authenticated', 'authenticated', fixture.email,
       'qst41', now(), now(), now(),
       jsonb_build_object(
         'region_code', policy.region_code,
         'minimum_age_confirmed', true,
         'eligibility_version', policy.eligibility_version,
         'terms_version', policy.terms_version,
         'privacy_version', policy.privacy_version,
         'ai_disclosure_version', policy.ai_disclosure_version
       )
from (values
  (:'owner_id', 'qst41-owner@example.test'),
  (:'other_id', 'qst41-other@example.test')
) as fixture(id, email)
cross join public.legal_release_policies as policy
where policy.region_code = 'JP' and policy.active
on conflict (id) do nothing;

select pg_temp.qst_assert_eq(
  (select count(*) from auth.users where id in (:'owner_id', :'other_id')),
  2, 'legal-policy-compliant RLS fixture users exist'
);

insert into public.user_profiles (id, nickname)
values
  (:'owner_id', 'QST41 Owner'),
  (:'other_id', 'QST41 Other')
on conflict (id) do nothing;

insert into public.quests (id, owner_id, title, description, status, visibility)
values
  (:'owner_private_quest_id', :'owner_id', 'Owner private Quest', 'RLS private owner Quest.', 'active', 'private'),
  (:'owner_public_quest_id', :'owner_id', 'Owner public Quest', 'RLS public owner Quest.', 'active', 'public'),
  (:'other_private_quest_id', :'other_id', 'Other private Quest', 'RLS private other Quest.', 'active', 'private');

insert into public.missions (id, quest_id, title, description, guide_type, difficulty, status)
values
  (:'owner_private_mission_id', :'owner_private_quest_id', 'Owner private Mission', 'Private Mission.', 'route', 'easy', 'todo'),
  (:'owner_public_mission_id', :'owner_public_quest_id', 'Owner public Mission', 'Public Mission.', 'route', 'easy', 'todo'),
  (:'other_private_mission_id', :'other_private_quest_id', 'Other private Mission', 'Other private Mission.', 'route', 'easy', 'todo');

insert into public.tasks (id, owner_id, quest_id, mission_id, title, action, done_condition)
values
  (:'owner_private_task_id', :'owner_id', :'owner_private_quest_id', :'owner_private_mission_id', 'Owner private Task', 'Ownerだけが実行できる具体行動', '結果を確認できる状態になる'),
  (:'owner_qst534_task_id', :'owner_id', :'owner_public_quest_id', :'owner_public_mission_id', 'Replay Test Task', '再送後の版番号を検証する', '版番号の整合を確認する');

insert into public.trails (id, owner_id, quest_id, mission_id, title, summary, content, visibility, trail_type)
values
  (:'owner_private_trail_id', :'owner_id', :'owner_private_quest_id', :'owner_private_mission_id', 'Owner private Trail', 'Private Trail.', 'Private Trail content.', 'private', 'quest_record'),
  (:'owner_public_trail_id', :'owner_id', :'owner_public_quest_id', :'owner_public_mission_id', 'Owner public Trail', 'Public Trail.', 'Public Trail content.', 'public', 'quest_record'),
  (:'other_private_trail_id', :'other_id', :'other_private_quest_id', :'other_private_mission_id', 'Other private Trail', 'Other private Trail.', 'Other private Trail content.', 'private', 'quest_record');

select set_config('request.jwt.claim.role', 'service_role', true);
insert into public.user_consents (user_id, purpose_code, purpose_version, status, granted_at, source)
values
  (:'owner_id', 'arc_personalization', 1, 'granted', now(), 'settings'),
  (:'other_id', 'arc_personalization', 1, 'granted', now(), 'settings');

insert into public.arc_memories (id, user_id, quest_id, title, content, memory_type, source_type)
values
  (:'owner_memory_id', :'owner_id', :'owner_private_quest_id', 'Owner memory', 'Owner-only Arc Memory.', 'quest_memory', 'quest_created'),
  (:'other_memory_id', :'other_id', :'other_private_quest_id', 'Other memory', 'Other-only Arc Memory.', 'quest_memory', 'quest_created');
select set_config('request.jwt.claim.role', '', true);

insert into public.media (id, owner_id, bucket, path, media_type, related_table, related_id, visibility)
values
  (:'owner_media_id', :'owner_id', 'trail-media', :'owner_id' || '/qst41/private.jpg', 'image', 'trails', :'owner_private_trail_id', 'private'),
  (:'owner_public_media_id', :'owner_id', 'trail-media', :'owner_id' || '/qst41/public.jpg', 'image', 'trails', :'owner_public_trail_id', 'public'),
  (:'other_media_id', :'other_id', 'trail-media', :'other_id' || '/qst41/private.jpg', 'image', 'trails', :'other_private_trail_id', 'private');

insert into public.guild_quest_publications (
  id, title, summary, author_display_name, tags, difficulty_score,
  visibility, moderation_status
) values
  (:'guild_publication_id', 'Public Guild Quest', 'Approved public snapshot.', 'Owner Navigator', array['挑戦'], 3, 'public', 'approved'),
  (:'guild_pending_publication_id', 'Pending Guild Quest', 'Pending owner snapshot.', 'Owner Navigator', array['学習'], 2, 'public', 'pending');

insert into public.guild_quest_publication_owners (publication_id, owner_id, source_quest_id)
values
  (:'guild_publication_id', :'owner_id', :'owner_public_quest_id'),
  (:'guild_pending_publication_id', :'owner_id', :'owner_private_quest_id');

insert into public.guild_mission_publications (
  id, quest_publication_id, title, purpose, order_index, moderation_status
) values (
  :'guild_mission_publication_id', :'guild_publication_id',
  'Public Guild Mission', 'Approved public Mission purpose.', 0, 'approved'
);

insert into public.guild_mission_publication_owners (
  mission_publication_id, owner_id, source_mission_id
) values (
  :'guild_mission_publication_id', :'owner_id', :'owner_public_mission_id'
);

insert into public.guild_quest_copy_events (
  id, publication_id, copier_id, destination_quest_id, include_missions,
  arc_optimization_requested, idempotency_key
) values (
  :'guild_copy_event_id', :'guild_publication_id', :'other_id',
  :'other_private_quest_id', true, true, 'qst41-copy-other-001'
);

insert into public.route_versions (
  id, quest_id, version_number, status, generated_by, generation_reason
) values (
  :'owner_route_version_id', :'owner_private_quest_id', 1,
  'proposed', 'arc', 'QST-199 RLS behavior proof'
);

insert into public.route_change_proposals (
  id, quest_id, route_version_id, proposal_type, summary, reason,
  confidence_score
) values (
  :'owner_route_proposal_id', :'owner_private_quest_id',
  :'owner_route_version_id', 'replan', 'Private route proposal',
  'QST-199 RLS behavior proof', 0.8
);

insert into public.route_change_items (
  id, proposal_id, action_type, target_mission_id, title, reason, safety_level
) values (
  :'owner_route_item_id', :'owner_route_proposal_id', 'reschedule',
  :'owner_private_mission_id', 'Private route item',
  'QST-199 RLS behavior proof', 2
);

insert into public.quest_progress_events (
  event_id,event_name,event_version,user_id,quest_id,source,occurred_at,idempotency_key
) values (
  :'owner_progress_event_id','quest_created',1,:'owner_id',:'owner_private_quest_id','user',now(),'qst-business-owner-event-001'
);

insert into public.quest_stage_state (
  quest_id,current_stage,stage_source,confidence,reason_code
) values (
  :'owner_private_quest_id','planning','system',0.8,'rls_test'
);

insert into public.quest_dna_versions (
  id,quest_id,owner_id,version,attributes,sensitivity_level
) values (
  :'owner_dna_version_id',:'owner_private_quest_id',:'owner_id',1,'{"category":{"value":"test","confidence":1,"source":"user"}}','normal'
);

insert into public.business_quest_signals (
  signal_id,owner_id,quest_id,anonymous_subject_id,quest_category,quest_stage,
  commercial_relevance,expires_at,consent_version
) values (
  :'owner_business_signal_id',:'owner_id',:'owner_private_quest_id',gen_random_uuid(),
  'test','planning','none',now()+interval '30 days',1
);

insert into public.user_consents (
  id,user_id,purpose_code,purpose_version,status,granted_at,source
) values (
  :'owner_consent_id',:'owner_id','anonymous_analytics',1,'granted',now(),'settings'
);

insert into public.quest_planning_runs (
  id,owner_id,quest_id,trace_id,idempotency_key,status,pipeline_version,schema_version
) values (
  :'owner_planning_run_id',:'owner_id',:'owner_private_quest_id',gen_random_uuid(),
  'qst259-rls-owner','preview_ready','4.0','mission-architecture-4.0'
);
insert into public.quest_plan_previews (
  id,owner_id,quest_id,planning_run_id,plan_payload
) values (
  :'owner_plan_preview_id',:'owner_id',:'owner_private_quest_id',:'owner_planning_run_id','{}'::jsonb
);
insert into public.mission_plan_drafts (
  id,owner_id,quest_id,planning_run_id,preview_id,schema_version,model_name,thinking_level
) values (
  :'owner_mission_draft_id',:'owner_id',:'owner_private_quest_id',:'owner_planning_run_id',
  :'owner_plan_preview_id','mission-architecture-4.0','gemini-test','high'
);
insert into public.mission_candidates (
  id,owner_id,draft_id,client_id,title,objective,success_condition,expected_outcome,
  reason_required,child_task_estimate,confidence,verdict,order_index,original_payload
) values (
  :'owner_mission_candidate_id',:'owner_id',:'owner_mission_draft_id','mission-1',
  'Owner outcome Mission','複数Taskで中間成果を完成する','成果が確認できれば完了',
  '確認可能な成果','Quest成功条件を前進させる',2,0.95,'pass',0,'{}'::jsonb
);

insert into public.data_rights_requests (
  id,owner_id,request_type,status,scope,idempotency_key
) values
  (:'owner_data_rights_request_id',:'owner_id','correction','submitted',
   '{"target_type":"profile","requested_change":"Owner fixture change"}'::jsonb,
   'qst373-owner-request'),
  (:'other_data_rights_request_id',:'other_id','correction','submitted',
   '{"target_type":"profile","requested_change":"Other fixture change"}'::jsonb,
   'qst373-other-request');

insert into public.runtime_evidence_events (
  id,owner_id,event_id,occurred_at,build_version,environment,platform,
  surface,operation,event_type,severity,error_code,correlation_id,
  handled,fallback_used
) values
  (:'owner_runtime_event_id',:'owner_id','qst373-owner-event',now(),
   'qst373','internal_beta','android','arc_chat','arc_chat.invoke',
   'aiFallback','S2','remote_failure','qst373-owner-trace',true,true),
  (:'other_runtime_event_id',:'other_id','qst373-other-event',now(),
   'qst373','internal_beta','android','arc_chat','arc_chat.invoke',
   'aiFallback','S2','remote_failure','qst373-other-trace',true,true);

set local role authenticated;

select set_config('request.jwt.claim.sub', :'owner_id', true);

select pg_temp.qst_assert_eq((select count(*) from public.quests where id = :'owner_private_quest_id'), 1, 'owner can read own private Quest');
select pg_temp.qst_assert_eq((select count(*) from public.quests where id = :'other_private_quest_id'), 0, 'owner cannot read another private Quest');
select pg_temp.qst_assert_eq((select count(*) from public.missions where id = :'owner_private_mission_id'), 1, 'owner can read own private Mission');
select pg_temp.qst_assert_eq((select count(*) from public.missions where id = :'other_private_mission_id'), 0, 'owner cannot read another private Mission');
select pg_temp.qst_assert_eq((select count(*) from public.trails where id = :'owner_private_trail_id'), 1, 'owner can read own private Trail');
select pg_temp.qst_assert_eq((select count(*) from public.trails where id = :'other_private_trail_id'), 0, 'owner cannot read another private Trail');
insert into public.trails (
  id, owner_id, quest_id, mission_id, title, summary, content, visibility, trail_type
) values (
  :'owner_validated_trail_id', :'owner_id', :'owner_private_quest_id',
  :'owner_private_mission_id', 'Validated owner Trail', 'Valid parent pair.',
  'Owner can save a Trail under a Mission belonging to the selected Quest.',
  'private', 'mission_record'
);
select pg_temp.qst_assert_eq(
  (select count(*) from public.trails where id = :'owner_validated_trail_id'),
  1,
  'owner can create a Trail with matching Quest and Mission parents'
);
select pg_temp.qst_assert_raises(
  format(
    'insert into public.trails (owner_id, quest_id, mission_id, title, visibility, trail_type) values (%L, %L, %L, %L, %L, %L)',
    :'owner_id', :'owner_private_quest_id', :'owner_public_mission_id',
    'Invalid cross-Quest Trail', 'private', 'mission_record'
  ),
  'owner cannot create a Trail with a Mission from another Quest'
);
select pg_temp.qst_assert_raises(
  format(
    'insert into public.trails (owner_id, quest_id, mission_id, title, visibility, trail_type) values (%L, %L, %L, %L, %L, %L)',
    :'owner_id', :'other_private_quest_id', :'other_private_mission_id',
    'Invalid cross-account Trail', 'private', 'mission_record'
  ),
  'owner cannot create a Trail under another owner journey'
);
select pg_temp.qst_assert_eq((select count(*) from public.arc_memories where id = :'owner_memory_id'), 1, 'owner can read own Arc Memory');
select pg_temp.qst_assert_eq((select count(*) from public.arc_memories where id = :'other_memory_id'), 0, 'owner cannot read another Arc Memory');
select pg_temp.qst_assert_eq((select count(*) from public.media where id = :'owner_media_id'), 1, 'owner can read own private media row');
select pg_temp.qst_assert_eq((select count(*) from public.media where id = :'other_media_id'), 0, 'owner cannot read another private media row');
select pg_temp.qst_assert_eq((select count(*) from public.guild_quest_publications where id = :'guild_publication_id'), 1, 'owner can read own approved Guild publication');
select pg_temp.qst_assert_eq((select count(*) from public.guild_quest_publications where id = :'guild_pending_publication_id'), 1, 'owner can read own pending Guild publication');
select pg_temp.qst_assert_eq((select count(*) from public.guild_quest_publication_owners where publication_id = :'guild_publication_id'), 1, 'owner can read Guild publication ownership');
select pg_temp.qst_assert_eq((select count(*) from public.guild_quest_copy_events where id = :'guild_copy_event_id'), 0, 'source owner cannot inspect copier event');
select pg_temp.qst_assert_eq((select count(*) from public.route_versions where id = :'owner_route_version_id'), 1, 'owner can read own private Route version');
select pg_temp.qst_assert_eq((select count(*) from public.route_change_proposals where id = :'owner_route_proposal_id'), 1, 'owner can read own private Route proposal');
select pg_temp.qst_assert_eq((select count(*) from public.route_change_items where id = :'owner_route_item_id'), 1, 'owner can read own private Route item');
select pg_temp.qst_assert_eq((select count(*) from public.quest_progress_events where event_id = :'owner_progress_event_id'), 1, 'owner can read own progress event');
select pg_temp.qst_assert_eq((select count(*) from public.quest_dna_versions where id = :'owner_dna_version_id'), 1, 'owner can read own Quest DNA version');
select pg_temp.qst_assert_eq((select count(*) from public.user_consents where id = :'owner_consent_id'), 1, 'owner can read own consent');
select pg_temp.qst_assert_eq((select count(*) from public.tasks where id = :'owner_private_task_id'), 1, 'owner can read own private Task');
select pg_temp.qst_assert_eq(
  has_table_privilege('authenticated', 'public.tasks', 'INSERT')::integer,
  0, 'QST-528 authenticated cannot directly create Tasks'
);
select pg_temp.qst_assert_eq(
  has_table_privilege('authenticated', 'public.tasks', 'UPDATE')::integer,
  0, 'QST-528 authenticated cannot directly update Tasks'
);
select pg_temp.qst_assert_eq(
  has_table_privilege('authenticated', 'public.tasks', 'DELETE')::integer,
  0, 'QST-528 authenticated cannot directly delete Tasks'
);
select pg_temp.qst_assert_raises(
  format(
    'insert into public.tasks (owner_id, quest_id, mission_id, title, action, done_condition) values (%L, %L, %L, %L, %L, %L)',
    :'owner_id', :'owner_private_quest_id', :'owner_private_mission_id',
    'Bypass creation', '直接作成を試みる', '拒否される'
  ),
  'QST-528 direct owner Task creation is denied'
);
select pg_temp.qst_assert_raises(
  format('update public.tasks set title = %L where id = %L',
    'Bypass version', :'owner_private_task_id'),
  'QST-528 direct owner Task update is denied'
);
select pg_temp.qst_assert_raises(
  format('delete from public.tasks where id = %L', :'owner_private_task_id'),
  'QST-528 direct owner Task delete is denied'
);
select pg_temp.qst_assert_eq(
  (public.create_tasks_if_absent(
    'qst528-create-owner',
    jsonb_build_array(jsonb_build_object(
      'id', :'owner_qst528_task_id', 'owner_id', :'owner_id',
      'quest_id', :'owner_private_quest_id',
      'mission_id', :'owner_private_mission_id',
      'title', '航路を確認する', 'action', '安全な情報源を確認する',
      'done_condition', '確認内容を記録する', 'status', 'pending',
      'required', true, 'order_index', 2, 'version', 1,
      'generated_by', 'user', 'origin', 'user',
      'verification_type', 'self'
    ))
  )->>'count')::bigint,
  1, 'QST-528 owner can create a Task through the batch RPC'
);
select pg_temp.qst_assert_eq(
  (public.create_tasks_if_absent(
    'qst528-create-owner',
    jsonb_build_array(jsonb_build_object(
      'id', :'owner_qst528_task_id', 'owner_id', :'owner_id',
      'quest_id', :'owner_private_quest_id',
      'mission_id', :'owner_private_mission_id',
      'title', '航路を確認する', 'action', '安全な情報源を確認する',
      'done_condition', '確認内容を記録する', 'status', 'pending',
      'required', true, 'order_index', 2, 'version', 1,
      'generated_by', 'user', 'origin', 'user',
      'verification_type', 'self'
    ))
  )->>'count')::bigint,
  1, 'QST-528 lost response retry is idempotent'
);
select pg_temp.qst_assert_eq(
  (select count(*) from public.tasks where id = :'owner_qst528_task_id'),
  1, 'QST-528 retry never creates a duplicate Task'
);
select pg_temp.qst_assert_raises(
  format(
    'select public.create_tasks_if_absent(%L, jsonb_build_array(jsonb_build_object(''id'', %L, ''owner_id'', %L, ''quest_id'', %L, ''mission_id'', %L, ''title'', %L, ''action'', %L, ''done_condition'', %L, ''status'', %L, ''required'', true, ''order_index'', 3, ''generated_by'', ''user'', ''origin'', ''user'', ''verification_type'', ''self'')))',
    'qst528-create-without-version', '00000000-0000-4000-8000-000000154131',
    :'owner_id', :'owner_private_quest_id', :'owner_private_mission_id',
    '版番号なし', '版番号なしのTask作成を試みる', '作成を拒否する', 'pending'
  ),
  'QST-528 create RPC rejects a missing version'
);
select pg_temp.qst_assert_eq(
  (select count(*) from public.tasks
   where id = '00000000-0000-4000-8000-000000154131'),
  0, 'QST-528 missing version never creates a Task'
);
select pg_temp.qst_assert_raises(
  format(
    'select public.create_tasks_if_absent(%L, %L::jsonb)',
    'qst528-batch-bad-dependency',
    jsonb_build_array(
      jsonb_build_object(
        'id', '00000000-0000-4000-8000-000000154132',
        'owner_id', :'owner_id', 'quest_id', :'owner_private_quest_id',
        'mission_id', :'owner_private_mission_id', 'title', '先に作られるTask',
        'action', '必要なことを確認する', 'done_condition', '確認結果を残す',
        'status', 'pending', 'required', true, 'order_index', 3, 'version', 1,
        'generated_by', 'user', 'origin', 'user', 'verification_type', 'self'
      ),
      jsonb_build_object(
        'id', '00000000-0000-4000-8000-000000154133',
        'owner_id', :'owner_id', 'quest_id', :'owner_private_quest_id',
        'mission_id', :'owner_private_mission_id', 'title', '無効な依存Task',
        'action', '存在しないTaskへ依存する', 'done_condition', '依存先を確認する',
        'status', 'pending', 'required', true, 'order_index', 4, 'version', 1,
        'generated_by', 'user', 'origin', 'user', 'verification_type', 'self',
        'dependency_ids', jsonb_build_array('00000000-0000-4000-8000-000000159999')
      )
    )::text
  ),
  'QST-528 invalid dependency rejects the entire Task batch'
);
select pg_temp.qst_assert_eq(
  (select count(*) from public.tasks where id in (
    '00000000-0000-4000-8000-000000154132',
    '00000000-0000-4000-8000-000000154133'
  )),
  0, 'QST-528 rejected batch leaves no partial Tasks'
);
select pg_temp.qst_assert_eq(
  (public.reorder_mission_tasks(
    :'owner_private_mission_id'::uuid,
    array[:'owner_private_task_id'::uuid],
    'qst528-reorder-incomplete',
    jsonb_build_object(:'owner_private_task_id', 1)
  )->>'status' = 'conflict')::integer,
  1, 'QST-528 incomplete Task list cannot overwrite mission order'
);
select pg_temp.qst_assert_eq(
  (public.reorder_mission_tasks(
    :'owner_private_mission_id'::uuid,
    array[:'owner_qst528_task_id'::uuid, :'owner_private_task_id'::uuid],
    'qst528-reorder-owner',
    jsonb_build_object(:'owner_private_task_id', 1, :'owner_qst528_task_id', 1)
  )->>'updated_count')::bigint,
  2, 'QST-528 owner can reorder both Tasks with their expected versions'
);
select pg_temp.qst_assert_eq(
  (public.reorder_mission_tasks(
    :'owner_private_mission_id'::uuid,
    array[:'owner_qst528_task_id'::uuid, :'owner_private_task_id'::uuid],
    'qst528-reorder-owner',
    jsonb_build_object(:'owner_private_task_id', 1, :'owner_qst528_task_id', 1)
  )->>'status' = 'already_applied')::integer,
  1, 'QST-528 lost reorder response does not replay the update'
);
select pg_temp.qst_assert_eq(
  (select count(*) from public.tasks
   where id in (:'owner_private_task_id', :'owner_qst528_task_id')
     and version = 2),
  2, 'QST-528 reorder retry preserves the new versions'
);
select pg_temp.qst_assert_eq(
  (public.create_tasks_if_absent(
    'qst528-create-owner',
    jsonb_build_array(jsonb_build_object(
      'id', :'owner_qst528_task_id', 'owner_id', :'owner_id',
      'quest_id', :'owner_private_quest_id',
      'mission_id', :'owner_private_mission_id',
      'title', '航路を確認する', 'action', '安全な情報源を確認する',
      'done_condition', '確認内容を記録する', 'status', 'pending',
      'required', true, 'order_index', 2, 'version', 1,
      'generated_by', 'user', 'origin', 'user',
      'verification_type', 'self'
    ))
  )->>'status' = 'conflict')::integer,
  1, 'QST-528 create retry cannot hide a later Task reorder'
);
select pg_temp.qst_assert_eq(
  (public.reorder_mission_tasks(
    :'owner_private_mission_id'::uuid,
    array[:'owner_private_task_id'::uuid, :'owner_qst528_task_id'::uuid],
    'qst528-reorder-stale',
    jsonb_build_object(:'owner_private_task_id', 1, :'owner_qst528_task_id', 1)
  )->>'status' = 'conflict')::integer,
  1, 'QST-528 stale Task reorder cannot overwrite a newer order'
);
select pg_temp.qst_assert_eq(
  (select count(*) from public.tasks
   where id in (:'owner_private_task_id', :'owner_qst528_task_id')
     and version = 2),
  2, 'QST-528 stale reorder leaves both Tasks unchanged'
);

select (to_jsonb(task) || jsonb_build_object('title', 'First edit'))::text
  as qst534_first_payload
from public.tasks task where id = :'owner_qst534_task_id' \gset
select pg_temp.qst_assert_eq(
  (public.update_task_if_version(
    :'owner_qst534_task_id'::uuid, 1, 'qst534-first-edit',
    :'qst534_first_payload'::jsonb
  )->>'version')::bigint,
  2, 'QST-534 first Task update advances version once'
);
select pg_temp.qst_assert_eq(
  (public.update_task_if_version(
    :'owner_qst534_task_id'::uuid, 1, 'qst534-first-edit',
    :'qst534_first_payload'::jsonb
  )->>'status' = 'already_applied')::integer,
  1, 'QST-534 immediate lost-response retry is idempotent'
);
select pg_temp.qst_assert_eq(
  (public.update_task_if_version(
    :'owner_qst534_task_id'::uuid, 2, 'qst534-second-edit',
    (select to_jsonb(task) || jsonb_build_object('title', 'Second edit')
     from public.tasks task where id = :'owner_qst534_task_id')
  )->>'version')::bigint,
  3, 'QST-534 later Task update advances version'
);
select pg_temp.qst_assert_eq(
  (public.update_task_if_version(
    :'owner_qst534_task_id'::uuid, 1, 'qst534-first-edit',
    :'qst534_first_payload'::jsonb
  )->>'status' = 'conflict')::integer,
  1, 'QST-534 stale replay cannot hide the later Task edit'
);
select pg_temp.qst_assert_eq(
  (select count(*) from public.tasks
   where id = :'owner_qst534_task_id' and title = 'Second edit' and version = 3),
  1, 'QST-534 stale replay leaves the later Task edit intact'
);
select pg_temp.qst_assert_eq(
  (public.complete_task_journey(
    :'owner_qst534_task_id'::uuid, 'qst534-complete', 3
  )->>'version')::bigint,
  4, 'QST-534 first completion advances version once'
);
select pg_temp.qst_assert_eq(
  (public.complete_task_journey(
    :'owner_qst534_task_id'::uuid, 'qst534-complete', 3
  )->>'already_applied' = 'true')::integer,
  1, 'QST-534 completion retry confirms the same operation'
);
select pg_temp.qst_assert_eq(
  (select count(*) from public.task_progress_events
   where owner_id = :'owner_id' and event_key = 'journey:qst534-complete'),
  1, 'QST-534 completion retry creates one journey event'
);
select pg_temp.qst_assert_eq(
  (public.update_task_if_version(
    :'owner_qst534_task_id'::uuid, 4, 'qst534-after-complete-edit',
    (select to_jsonb(task) || jsonb_build_object('title', 'After completion')
     from public.tasks task where id = :'owner_qst534_task_id')
  )->>'version')::bigint,
  5, 'QST-534 completed Task can receive a later metadata edit'
);
select pg_temp.qst_assert_eq(
  (public.complete_task_journey(
    :'owner_qst534_task_id'::uuid, 'qst534-complete', 3
  )->>'status' = 'conflict')::integer,
  1, 'QST-534 completion replay cannot hide a later edit'
);
select pg_temp.qst_assert_raises(
  'select count(*) from public.task_completion_operations',
  'QST-534 app user cannot read completion operation ledger'
);
select pg_temp.qst_assert_eq(
  (public.confirm_mission_outcome(:'owner_public_mission_id'::uuid)->>'status' = 'completed')::integer,
  1, 'QST-535 Mission success is confirmed before Task reopen'
);
select pg_temp.qst_assert_eq(
  (public.reopen_task_journey(:'owner_qst534_task_id'::uuid, 'qst535-reopen', 5)->>'version')::bigint,
  6, 'QST-535 completed Task reopens atomically'
);
select pg_temp.qst_assert_eq(
  (select count(*) from public.missions where id = :'owner_public_mission_id'
    and success_confirmed_at is null and status <> 'completed'),
  1, 'QST-535 reopening required Task clears Mission confirmation'
);
select pg_temp.qst_assert_eq(
  (public.reopen_task_journey(:'owner_qst534_task_id'::uuid, 'qst535-reopen', 5)->>'status' = 'already_applied')::integer,
  1, 'QST-535 immediate replay is idempotent'
);
select pg_temp.qst_assert_eq(
  (public.update_task_if_version(
    :'owner_qst534_task_id'::uuid, 6, 'qst535-later-edit',
    (select to_jsonb(task) || jsonb_build_object('title', 'Reopened and edited')
      from public.tasks task where id = :'owner_qst534_task_id')
  )->>'version')::bigint,
  7, 'QST-535 later Task edit advances version'
);
select pg_temp.qst_assert_eq(
  (public.reopen_task_journey(:'owner_qst534_task_id'::uuid, 'qst535-reopen', 5)->>'status' = 'conflict')::integer,
  1, 'QST-535 stale replay does not hide later Task edit'
);
select pg_temp.qst_assert_eq(
  (public.complete_task_journey(:'owner_qst534_task_id'::uuid, 'qst535-recomplete', 7)->>'version')::bigint,
  8, 'QST-535 Task may complete again after reopen'
);
select pg_temp.qst_assert_eq(
  (select count(*) from public.missions where id = :'owner_public_mission_id'
    and success_confirmed_at is null and status <> 'completed'),
  1, 'QST-535 re-completion does not silently confirm Mission'
);
select pg_temp.qst_assert_eq(
  (select count(*) from public.stardust_events
    where user_id = :'owner_id' and event_type = 'task_completed'
      and source_id = :'owner_qst534_task_id'),
  1, 'QST-535 re-completion does not duplicate Stardust'
);
select pg_temp.qst_assert_eq(
  (public.create_tasks_if_absent(
    'qst535-dependent-create',
    jsonb_build_array(jsonb_build_object(
      'id', :'owner_qst535_dependent_task_id', 'owner_id', :'owner_id',
      'quest_id', :'owner_public_quest_id',
      'mission_id', :'owner_public_mission_id',
      'title', 'Dependent Task', 'action', '前のTaskに続く',
      'done_condition', '結果を確認する', 'status', 'pending',
      'required', true, 'order_index', 1, 'version', 1,
      'dependency_ids', jsonb_build_array(:'owner_qst534_task_id'),
      'generated_by', 'user', 'origin', 'user', 'verification_type', 'self'
    ))
  )->>'count')::bigint,
  1, 'QST-535 dependent Task is created through the owner RPC'
);
select pg_temp.qst_assert_eq(
  (public.update_task_if_version(
    :'owner_qst535_dependent_task_id'::uuid, 1, 'qst535-dependent-start',
    (select to_jsonb(task) || jsonb_build_object('status', 'in_progress')
      from public.tasks task where id = :'owner_qst535_dependent_task_id')
  )->>'version')::bigint,
  2, 'QST-535 dependent Task starts through the versioned RPC'
);
select pg_temp.qst_assert_eq(
  (public.reopen_task_journey(:'owner_qst534_task_id'::uuid, 'qst535-dependent', 8)->>'status' = 'conflict')::integer,
  1, 'QST-535 active dependent blocks prerequisite reopen'
);
select pg_temp.qst_assert_eq((select count(*) from public.mission_plan_drafts where id = :'owner_mission_draft_id'), 1, 'owner can read own Mission plan draft');
select pg_temp.qst_assert_eq((select count(*) from public.mission_candidates where id = :'owner_mission_candidate_id'), 1, 'owner can read own Mission candidate');
select pg_temp.qst_assert_eq((select count(*) from public.data_rights_requests where id = :'owner_data_rights_request_id'), 1, 'owner can read own Data Rights request');
select pg_temp.qst_assert_eq((select count(*) from public.data_rights_requests where id = :'other_data_rights_request_id'), 0, 'owner cannot read another Data Rights request');
select pg_temp.qst_assert_eq((select count(*) from public.runtime_evidence_events where id = :'owner_runtime_event_id'), 1, 'owner can read own runtime evidence');
select pg_temp.qst_assert_eq((select count(*) from public.runtime_evidence_events where id = :'other_runtime_event_id'), 0, 'owner cannot read another runtime evidence row');
select pg_temp.qst_assert_raises(
  'select count(*) from public.data_rights_fulfillment_receipts',
  'app user cannot read Data Rights fulfillment receipts'
);
select pg_temp.qst_assert_raises(
  'select count(*) from public.runtime_evidence_alert_queue',
  'app user cannot read runtime alert queue'
);
select pg_temp.qst_assert_raises(
  'select count(*) from public.runtime_evidence_rate_buckets',
  'app user cannot read runtime rate buckets'
);
select pg_temp.qst_assert_raises(
  format('select count(*) from public.business_quest_signals where signal_id = %L', :'owner_business_signal_id'),
  'Business signal is not client-readable'
);

select set_config('request.jwt.claim.sub', :'other_id', true);

select pg_temp.qst_assert_raises(
  format('select public.complete_task_journey(%L, %L, 5)',
    :'owner_qst534_task_id', 'qst534-foreign-complete'),
  'QST-534 another account cannot complete the owner Task'
);
select pg_temp.qst_assert_raises(
  format('select public.reopen_task_journey(%L, %L, 8)',
    :'owner_qst534_task_id', 'qst535-foreign-reopen'),
  'QST-535 another account cannot reopen the owner Task'
);

select pg_temp.qst_assert_eq((select count(*) from public.quests where id = :'owner_private_quest_id'), 0, 'other cannot read owner private Quest');
select pg_temp.qst_assert_eq((select count(*) from public.quests where id = :'owner_public_quest_id'), 1, 'other can read public Quest');
select pg_temp.qst_assert_eq((select count(*) from public.missions where id = :'owner_private_mission_id'), 0, 'other cannot read Mission on private Quest');
select pg_temp.qst_assert_eq((select count(*) from public.missions where id = :'owner_public_mission_id'), 1, 'other can read Mission on public Quest');
select pg_temp.qst_assert_eq((select count(*) from public.trails where id = :'owner_private_trail_id'), 0, 'other cannot read owner private Trail');
select pg_temp.qst_assert_eq((select count(*) from public.trails where id = :'owner_public_trail_id'), 1, 'other can read public Trail');
select pg_temp.qst_assert_eq((select count(*) from public.arc_memories where id = :'owner_memory_id'), 0, 'other cannot read owner Arc Memory');
select pg_temp.qst_assert_eq((select count(*) from public.media where id = :'owner_media_id'), 0, 'other cannot read owner private media row');
select pg_temp.qst_assert_eq((select count(*) from public.media where id = :'owner_public_media_id'), 1, 'other can read public media row');
select pg_temp.qst_assert_eq((select count(*) from public.guild_quest_publications where id = :'guild_publication_id'), 1, 'other can read approved public Guild publication');
select pg_temp.qst_assert_eq((select count(*) from public.guild_quest_publications where id = :'guild_pending_publication_id'), 0, 'other cannot read pending Guild publication');
select pg_temp.qst_assert_eq((select count(*) from public.guild_mission_publications where id = :'guild_mission_publication_id'), 1, 'other can read approved Guild Mission publication');
select pg_temp.qst_assert_eq((select count(*) from public.guild_quest_publication_owners where publication_id = :'guild_publication_id'), 0, 'other cannot read Guild publication ownership');
select pg_temp.qst_assert_eq((select count(*) from public.guild_quest_copy_events where id = :'guild_copy_event_id'), 1, 'copier can read own private copy event');
select pg_temp.qst_assert_eq((select count(*) from public.route_versions where id = :'owner_route_version_id'), 0, 'other cannot read owner private Route version');
select pg_temp.qst_assert_eq((select count(*) from public.route_change_proposals where id = :'owner_route_proposal_id'), 0, 'other cannot read owner private Route proposal');
select pg_temp.qst_assert_eq((select count(*) from public.route_change_items where id = :'owner_route_item_id'), 0, 'other cannot read owner private Route item');
select pg_temp.qst_assert_eq((select count(*) from public.quest_progress_events where event_id = :'owner_progress_event_id'), 0, 'other cannot read owner progress event');
select pg_temp.qst_assert_eq((select count(*) from public.quest_dna_versions where id = :'owner_dna_version_id'), 0, 'other cannot read owner Quest DNA version');
select pg_temp.qst_assert_eq((select count(*) from public.user_consents where id = :'owner_consent_id'), 0, 'other cannot read owner consent');
select pg_temp.qst_assert_eq((select count(*) from public.tasks where id = :'owner_private_task_id'), 0, 'other cannot read owner private Task');
select pg_temp.qst_assert_raises(
  format(
    'select public.create_tasks_if_absent(%L, jsonb_build_array(jsonb_build_object(''id'', %L, ''owner_id'', %L, ''quest_id'', %L, ''mission_id'', %L, ''title'', %L, ''action'', %L, ''done_condition'', %L, ''status'', %L, ''required'', true, ''order_index'', 0, ''version'', 1, ''generated_by'', ''user'', ''origin'', ''user'', ''verification_type'', ''self'')))',
    'qst528-cross-owner', '00000000-0000-4000-8000-000000154129',
    :'owner_id', :'owner_private_quest_id', :'owner_private_mission_id',
    '越境Task', '他人のQuestへ追加する', '追加結果を記録する', 'pending'
  ),
  'QST-528 batch RPC rejects cross-owner Task creation'
);
select pg_temp.qst_assert_eq(
  (public.reorder_mission_tasks(
    :'owner_private_mission_id'::uuid,
    array[:'owner_private_task_id'::uuid, :'owner_qst528_task_id'::uuid],
    'qst528-cross-owner-reorder',
    jsonb_build_object(:'owner_private_task_id', 2, :'owner_qst528_task_id', 2)
  )->>'status' = 'conflict')::integer,
  1, 'QST-528 other owner cannot reorder private Tasks through RPC'
);
select pg_temp.qst_assert_eq((select count(*) from public.mission_plan_drafts where id = :'owner_mission_draft_id'), 0, 'other cannot read owner Mission plan draft');
select pg_temp.qst_assert_eq((select count(*) from public.mission_candidates where id = :'owner_mission_candidate_id'), 0, 'other cannot read owner Mission candidate');
select pg_temp.qst_assert_eq((select count(*) from public.data_rights_requests where id = :'owner_data_rights_request_id'), 0, 'other cannot read owner Data Rights request');
select pg_temp.qst_assert_eq((select count(*) from public.runtime_evidence_events where id = :'owner_runtime_event_id'), 0, 'other cannot read owner runtime evidence');

select pg_temp.qst_assert_raises(
  format(
    'insert into public.data_rights_requests (owner_id, request_type, status, scope) values (%L, %L, %L, %L::jsonb)',
    :'other_id', 'correction', 'submitted', '{}'
  ),
  'app user cannot bypass Data Rights request RPC'
);

select pg_temp.qst_assert_raises(
  format(
    'insert into public.runtime_evidence_events (owner_id,event_id,occurred_at,build_version,environment,platform,surface,operation,event_type,severity,error_code,correlation_id,handled,fallback_used) values (%L,%L,now(),%L,%L,%L,%L,%L,%L,%L,%L,%L,true,true)',
    :'other_id','qst373-direct','qst373','internal_beta','android','arc_chat',
    'arc_chat.invoke','aiFallback','S2','remote_failure','qst373-direct-trace'
  ),
  'app user cannot bypass runtime evidence RPC'
);
select pg_temp.qst_assert_raises(
  format(
    'select * from public.claim_runtime_evidence_alert(%L::uuid)',
    :'owner_runtime_event_id'
  ),
  'app user cannot claim runtime evidence alert'
);
select pg_temp.qst_assert_raises(
  format(
    'select public.purge_runtime_evidence_event(%L::uuid)',
    :'owner_runtime_event_id'
  ),
  'app user cannot purge runtime evidence event'
);

select pg_temp.qst_assert_raises(
  format(
    'insert into public.tasks (owner_id, quest_id, mission_id, title, action, done_condition) values (%L, %L, %L, %L, %L, %L)',
    :'owner_id', :'owner_private_quest_id', :'owner_private_mission_id',
    'Invalid Task', '他人のMissionへ追加する', '追加結果が存在する'
  ),
  'other cannot create a Task for owner'
);

select pg_temp.qst_assert_raises(
  format(
    'insert into public.route_versions (quest_id, version_number, status, generated_by, generation_reason) values (%L, %s, %L, %L, %L)',
    :'owner_private_quest_id',
    99,
    'proposed',
    'user',
    'Cross-account Route write must fail'
  ),
  'other cannot create a Route version for owner'
);

select pg_temp.qst_assert_raises(
  format(
    'insert into public.quests (owner_id, title, status, visibility) values (%L, %L, %L, %L)',
    :'owner_id',
    'Invalid other-owned Quest',
    'active',
    'private'
  ),
  'other cannot create a Quest for owner'
);

select pg_temp.qst_assert_raises(
  format(
    'insert into public.missions (quest_id, title, guide_type, difficulty, status) values (%L, %L, %L, %L, %L)',
    :'owner_private_quest_id',
    'Invalid Mission on private owner Quest',
    'route',
    'easy',
    'todo'
  ),
  'other cannot create a Mission on owner private Quest'
);

select pg_temp.qst_assert_raises(
  format(
    'insert into public.arc_memories (user_id, title, content, memory_type, source_type) values (%L, %L, %L, %L, %L)',
    :'owner_id',
    'Invalid owner memory',
    'Other user should not create owner memory.',
    'quest_memory',
    'quest_created'
  ),
  'other cannot create an Arc Memory for owner'
);

select pg_temp.qst_assert_raises(
  format(
    'insert into public.media (owner_id, bucket, path, media_type, visibility) values (%L, %L, %L, %L, %L)',
    :'owner_id',
    'trail-media',
    :'owner_id' || '/qst41/invalid.jpg',
    'image',
    'private'
  ),
  'other cannot create a media row for owner'
);

select pg_temp.qst_assert_raises(
  'select * from public.ai_usage_policies limit 1',
  'app user cannot read server AI usage policies'
);

select pg_temp.qst_assert_raises(
  'select * from public.mission_research_requests limit 1',
  'app user cannot read Mission research rate metadata'
);

select pg_temp.qst_assert_raises(
  'select * from public.enterprise_support_proposals limit 1',
  'app user cannot read unprojected enterprise support proposals'
);

select set_config('request.jwt.claim.sub', :'owner_id', true);
select pg_temp.qst_assert_eq(
  (public.create_tasks_if_absent(
    'qst528-create-after-reorder',
    jsonb_build_array(jsonb_build_object(
      'id', '00000000-0000-4000-8000-000000154130',
      'owner_id', :'owner_id', 'quest_id', :'owner_private_quest_id',
      'mission_id', :'owner_private_mission_id',
      'title', '追加の準備', 'action', '準備項目を確認する',
      'done_condition', '確認内容を記録する', 'status', 'pending',
      'required', true, 'order_index', 2, 'version', 1,
      'generated_by', 'user', 'origin', 'user',
      'verification_type', 'self'
    ))
  )->>'status' = 'applied')::integer,
  1, 'QST-528 another device can add a Task after reorder'
);
select pg_temp.qst_assert_eq(
  (public.reorder_mission_tasks(
    :'owner_private_mission_id'::uuid,
    array[:'owner_qst528_task_id'::uuid, :'owner_private_task_id'::uuid],
    'qst528-reorder-owner',
    jsonb_build_object(:'owner_private_task_id', 1, :'owner_qst528_task_id', 1)
  )->>'status' = 'conflict')::integer,
  1, 'QST-528 replay does not claim success after the mission Task set changed'
);

rollback;

\echo 'QST-041 RLS behavior tests passed'
