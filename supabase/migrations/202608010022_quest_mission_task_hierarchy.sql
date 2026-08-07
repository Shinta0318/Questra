begin;

alter table public.quests
  add column if not exists active_route_id uuid references public.route_versions(id) on delete set null,
  add column if not exists hierarchy_version integer not null default 1;

alter table public.missions
  add column if not exists route_id uuid references public.route_versions(id) on delete set null,
  add column if not exists objective text not null default '',
  add column if not exists success_condition text not null default '',
  add column if not exists expected_outcome text not null default '',
  add column if not exists required boolean not null default true,
  add column if not exists order_index integer not null default 0,
  add column if not exists weight numeric(6,3) not null default 1,
  add column if not exists target_date date,
  add column if not exists generated_by text not null default 'user',
  add column if not exists generation_version text,
  add column if not exists success_confirmed_at timestamptz,
  add column if not exists hierarchy_role text not null default 'legacy_unclassified';

alter table public.missions
  add constraint missions_weight_check check (weight > 0 and weight <= 100) not valid,
  add constraint missions_generated_by_check check (generated_by in ('user', 'arc', 'system', 'migration')) not valid,
  add constraint missions_hierarchy_role_check check (hierarchy_role in ('outcome', 'legacy_unclassified', 'legacy_task_source')) not valid;
alter table public.missions validate constraint missions_weight_check;
alter table public.missions validate constraint missions_generated_by_check;
alter table public.missions validate constraint missions_hierarchy_role_check;

update public.missions set
  objective = coalesce(nullif(objective, ''), nullif(description, ''), title),
  success_condition = coalesce(nullif(success_condition, ''), nullif(done_condition, ''), 'この中間成果の必須Taskを完了し、達成状態を確認する'),
  expected_outcome = coalesce(nullif(expected_outcome, ''), nullif(expected_output, ''), title),
  required = not is_optional,
  order_index = sort_order
where hierarchy_role = 'legacy_unclassified';

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  quest_id uuid not null references public.quests(id) on delete cascade,
  mission_id uuid not null references public.missions(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 1 and 120),
  action text not null check (char_length(btrim(action)) between 1 and 600),
  purpose text not null default '' check (char_length(purpose) <= 400),
  done_condition text not null check (char_length(btrim(done_condition)) between 1 and 600),
  expected_output text not null default '' check (char_length(expected_output) <= 400),
  estimated_effort_minutes integer check (estimated_effort_minutes is null or estimated_effort_minutes between 1 and 1440),
  status text not null default 'pending' check (status in ('pending', 'ready', 'in_progress', 'completed', 'skipped', 'blocked', 'cancelled')),
  required boolean not null default true,
  order_index integer not null default 0,
  dependency_ids uuid[] not null default '{}'::uuid[],
  scheduled_date date,
  due_date date,
  completed_at timestamptz,
  verification_type text not null default 'self' check (verification_type in ('self', 'evidence', 'arc_review', 'external')),
  generated_by text not null default 'user' check (generated_by in ('user', 'arc', 'system', 'migration')),
  generation_version text,
  source_mission_id uuid references public.missions(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (mission_id, source_mission_id)
);

create table public.mission_dependencies (
  mission_id uuid not null references public.missions(id) on delete cascade,
  depends_on_mission_id uuid not null references public.missions(id) on delete cascade,
  primary key (mission_id, depends_on_mission_id),
  check (mission_id <> depends_on_mission_id)
);

create table public.task_dependencies (
  task_id uuid references public.tasks(id) on delete set null,
  depends_on_task_id uuid not null references public.tasks(id) on delete cascade,
  primary key (task_id, depends_on_task_id),
  check (task_id <> depends_on_task_id)
);

create table public.hierarchy_migration_previews (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  quest_id uuid not null references public.quests(id) on delete cascade,
  proposed_hierarchy jsonb not null,
  uncertain_item_ids uuid[] not null default '{}'::uuid[],
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'expired')),
  expires_at timestamptz not null default now() + interval '7 days',
  approved_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.task_progress_events (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  quest_id uuid not null references public.quests(id) on delete cascade,
  mission_id uuid not null references public.missions(id) on delete cascade,
  task_id uuid not null references public.tasks(id) on delete cascade,
  event_name text not null check (event_name in ('task_created', 'task_started', 'task_completed', 'task_skipped', 'task_blocked', 'task_rescheduled', 'task_regenerated', 'task_reordered', 'task_deleted')),
  event_key text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (owner_id, event_key)
);

create index tasks_mission_order_idx on public.tasks(mission_id, order_index);
create index tasks_owner_status_idx on public.tasks(owner_id, status, scheduled_date);
create index tasks_quest_idx on public.tasks(quest_id, created_at);
create index missions_route_order_idx on public.missions(route_id, order_index) where hierarchy_role = 'outcome';

alter table public.tasks enable row level security;
alter table public.mission_dependencies enable row level security;
alter table public.task_dependencies enable row level security;
alter table public.hierarchy_migration_previews enable row level security;
alter table public.task_progress_events enable row level security;

create policy tasks_owner_all on public.tasks for all
  using (owner_id = auth.uid() and exists (
    select 1 from public.missions m join public.quests q on q.id = m.quest_id
    where m.id = tasks.mission_id and m.quest_id = tasks.quest_id and q.owner_id = auth.uid()
  ))
  with check (owner_id = auth.uid() and exists (
    select 1 from public.missions m join public.quests q on q.id = m.quest_id
    where m.id = tasks.mission_id and m.quest_id = tasks.quest_id and q.owner_id = auth.uid()
  ));

create policy mission_dependencies_owner_all on public.mission_dependencies for all
  using (exists (
    select 1 from public.missions m join public.missions d on d.id = depends_on_mission_id join public.quests q on q.id = m.quest_id
    where m.id = mission_id and d.quest_id = m.quest_id and q.owner_id = auth.uid()
  ))
  with check (exists (
    select 1 from public.missions m join public.missions d on d.id = depends_on_mission_id join public.quests q on q.id = m.quest_id
    where m.id = mission_id and d.quest_id = m.quest_id and q.owner_id = auth.uid()
  ));

create policy task_dependencies_owner_all on public.task_dependencies for all
  using (exists (
    select 1 from public.tasks t join public.tasks d on d.id = depends_on_task_id
    where t.id = task_id and t.owner_id = auth.uid() and d.owner_id = auth.uid() and t.mission_id = d.mission_id
  ))
  with check (exists (
    select 1 from public.tasks t join public.tasks d on d.id = depends_on_task_id
    where t.id = task_id and t.owner_id = auth.uid() and d.owner_id = auth.uid() and t.mission_id = d.mission_id
  ));

create policy hierarchy_migration_previews_owner on public.hierarchy_migration_previews for select using (owner_id = auth.uid());
create policy task_progress_events_owner on public.task_progress_events for select using (owner_id = auth.uid());

create or replace function public.recalculate_quest_hierarchy_progress(p_quest_id uuid)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare v_owner uuid; v_quest_progress numeric;
begin
  select owner_id into v_owner from public.quests where id = p_quest_id;
  if v_owner is null then return; end if;
  if auth.uid() is not null and auth.uid() <> v_owner then raise exception 'quest_not_owned'; end if;

  update public.missions m set
    progress_percent = stats.progress,
    status = case when stats.required_total > 0 and stats.required_completed = stats.required_total and m.success_confirmed_at is not null then 'completed' else 'todo' end,
    completed_at = case when stats.required_total > 0 and stats.required_completed = stats.required_total and m.success_confirmed_at is not null then coalesce(m.completed_at, now()) else null end,
    updated_at = now()
  from (
    select mission_id,
      count(*) filter (where required) as required_total,
      count(*) filter (where required and status = 'completed') as required_completed,
      case when count(*) filter (where required) = 0 then 0 else round(100.0 * count(*) filter (where required and status = 'completed') / count(*) filter (where required))::integer end as progress
    from public.tasks where quest_id = p_quest_id group by mission_id
  ) stats where m.id = stats.mission_id and m.hierarchy_role = 'outcome';

  select case when count(*) filter (where required and hierarchy_role = 'outcome' and route_state = 'active') = 0 then 0
    else count(*) filter (where required and hierarchy_role = 'outcome' and route_state = 'active' and status = 'completed')::numeric /
      count(*) filter (where required and hierarchy_role = 'outcome' and route_state = 'active') end
  into v_quest_progress from public.missions where quest_id = p_quest_id;
  update public.quests set progress = coalesce(v_quest_progress, 0), updated_at = now() where id = p_quest_id;
end;
$$;

create or replace function public.on_task_progress_changed()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  perform public.recalculate_quest_hierarchy_progress(coalesce(new.quest_id, old.quest_id));
  return coalesce(new, old);
end;
$$;
create trigger tasks_recalculate_progress after insert or update or delete on public.tasks
for each row execute function public.on_task_progress_changed();

create or replace function public.record_task_progress_event()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare v_event text;
begin
  v_event := case
    when tg_op='INSERT' then 'task_created'
    when tg_op='DELETE' then 'task_deleted'
    when new.status='completed' and old.status is distinct from new.status then 'task_completed'
    when new.status='in_progress' and old.status is distinct from new.status then 'task_started'
    when new.status='skipped' and old.status is distinct from new.status then 'task_skipped'
    when new.status='blocked' and old.status is distinct from new.status then 'task_blocked'
    when new.scheduled_date is distinct from old.scheduled_date then 'task_rescheduled'
    else null end;
  if v_event is not null then
    insert into public.task_progress_events(owner_id,quest_id,mission_id,task_id,event_name,event_key,metadata)
    values(coalesce(new.owner_id,old.owner_id),coalesce(new.quest_id,old.quest_id),coalesce(new.mission_id,old.mission_id),coalesce(new.id,old.id),v_event,
      concat(v_event,':',coalesce(new.id,old.id),':',extract(epoch from clock_timestamp())::bigint),
      jsonb_build_object('from_status',case when tg_op='INSERT' then null else old.status end,'to_status',case when tg_op='DELETE' then null else new.status end));
  end if;
  return coalesce(new,old);
end;
$$;
create trigger tasks_record_progress_event after insert or update on public.tasks
for each row execute function public.record_task_progress_event();
create trigger tasks_record_delete_event before delete on public.tasks
for each row execute function public.record_task_progress_event();

create or replace function public.preview_quest_hierarchy_migration(p_quest_id uuid)
returns uuid language plpgsql security definer set search_path = public, pg_temp as $$
declare v_owner uuid; v_preview_id uuid; v_payload jsonb; v_uncertain uuid[];
begin
  select owner_id into v_owner from public.quests where id = p_quest_id;
  if v_owner is null or v_owner <> auth.uid() then raise exception 'quest_not_owned'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'sourceMissionId', id, 'classification', 'task', 'groupKey', coalesce(nullif(category, ''), '実行'),
    'title', title, 'action', coalesce(nullif(action, ''), title), 'doneCondition', coalesce(nullif(done_condition, ''), description, title),
    'status', status, 'orderIndex', sort_order
  ) order by sort_order), '[]'::jsonb),
  coalesce(array_agg(id) filter (where confidence < 0.7 or char_length(coalesce(action, '')) < 5), '{}'::uuid[])
  into v_payload, v_uncertain from public.missions
  where quest_id = p_quest_id and hierarchy_role = 'legacy_unclassified' and route_state <> 'removed';
  insert into public.hierarchy_migration_previews(owner_id, quest_id, proposed_hierarchy, uncertain_item_ids)
  values (v_owner, p_quest_id, jsonb_build_object('items', v_payload, 'strategy', 'group_by_category'), v_uncertain)
  returning id into v_preview_id;
  return v_preview_id;
end;
$$;

create or replace function public.apply_quest_hierarchy_migration(p_preview_id uuid)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare v_preview public.hierarchy_migration_previews%rowtype; v_route_id uuid; v_version integer; v_group record; v_parent_id uuid; v_item jsonb; v_task_count integer := 0; v_mission_count integer := 0;
begin
  select * into v_preview from public.hierarchy_migration_previews where id = p_preview_id for update;
  if not found or v_preview.owner_id <> auth.uid() then raise exception 'preview_not_found'; end if;
  if v_preview.status = 'approved' then return jsonb_build_object('status','approved','idempotent',true); end if;
  if v_preview.status <> 'pending' or v_preview.expires_at <= now() then raise exception 'preview_not_approvable'; end if;
  if cardinality(v_preview.uncertain_item_ids) > 0 then raise exception 'uncertain_items_require_review'; end if;

  select id into v_route_id from public.route_versions where quest_id = v_preview.quest_id and status = 'active' order by version_number desc limit 1;
  if v_route_id is null then
    select coalesce(max(version_number),0)+1 into v_version from public.route_versions where quest_id = v_preview.quest_id;
    insert into public.route_versions(quest_id,version_number,status,generated_by,generation_reason,route_snapshot,approved_at,approved_by)
    values(v_preview.quest_id,v_version,'active','system','QST-258 hierarchy migration','{}',now(),auth.uid()) returning id into v_route_id;
  end if;

  for v_group in select distinct item->>'groupKey' as group_key from jsonb_array_elements(v_preview.proposed_hierarchy->'items') item loop
    insert into public.missions(quest_id,route_id,title,description,objective,success_condition,expected_outcome,guide_type,difficulty,status,sort_order,order_index,required,generated_by,generation_version,hierarchy_role,category)
    values(v_preview.quest_id,v_route_id,v_group.group_key || 'の成果を完成する',v_group.group_key || 'に必要な具体行動を完了し、中間成果を確認する',v_group.group_key || 'に必要な成果を整える','必須Taskを完了し、成果が利用できる状態になっている',v_group.group_key || 'の確認可能な成果','route','easy','todo',v_mission_count,v_mission_count,true,'migration','qst-258-v1','outcome',v_group.group_key)
    returning id into v_parent_id;
    v_mission_count := v_mission_count + 1;
    for v_item in select item from jsonb_array_elements(v_preview.proposed_hierarchy->'items') item where item->>'groupKey' = v_group.group_key loop
      insert into public.tasks(owner_id,quest_id,mission_id,title,action,purpose,done_condition,expected_output,estimated_effort_minutes,status,required,order_index,verification_type,generated_by,generation_version,source_mission_id,completed_at)
      select v_preview.owner_id,v_preview.quest_id,v_parent_id,v_item->>'title',v_item->>'action',coalesce(m.description,''),v_item->>'doneCondition',coalesce(m.expected_output,''),coalesce((m.effort_estimate->>'active_effort_minutes')::integer,30),
        case when v_item->>'status'='completed' then 'completed' else 'pending' end,true,(v_item->>'orderIndex')::integer,
        case m.verification_type when 'artifact' then 'evidence' when 'official_source' then 'external' when 'professional_review' then 'external' else 'self' end,
        'migration','qst-258-v1',m.id,case when v_item->>'status'='completed' then coalesce(m.completed_at,now()) else null end
      from public.missions m where m.id=(v_item->>'sourceMissionId')::uuid;
      update public.missions set hierarchy_role='legacy_task_source',route_state='removed',updated_at=now() where id=(v_item->>'sourceMissionId')::uuid;
      v_task_count := v_task_count + 1;
    end loop;
  end loop;
  update public.quests set active_route_id=v_route_id,hierarchy_version=2,updated_at=now() where id=v_preview.quest_id;
  update public.hierarchy_migration_previews set status='approved',approved_at=now() where id=p_preview_id;
  perform public.recalculate_quest_hierarchy_progress(v_preview.quest_id);
  return jsonb_build_object('status','approved','route_id',v_route_id,'mission_count',v_mission_count,'task_count',v_task_count);
end;
$$;

create or replace function public.approve_quest_plan_preview(
  p_preview_id uuid,
  p_approval_token uuid
) returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_preview public.quest_plan_previews%rowtype;
  v_route_id uuid;
  v_route_version integer;
  v_mission jsonb;
  v_task jsonb;
  v_ids jsonb := '{}'::jsonb;
  v_task_ids jsonb := '{}'::jsonb;
  v_mission_id uuid;
  v_task_id uuid;
  v_current_mission_id uuid;
  v_dependency text;
  v_count integer := 0;
  v_task_count integer := 0;
begin
  select * into v_preview from public.quest_plan_previews where id = p_preview_id for update;
  if not found or v_preview.owner_id <> auth.uid() then raise exception 'preview_not_found'; end if;
  if v_preview.status = 'approved' then return jsonb_build_object('preview_id',v_preview.id,'status','approved','idempotent',true); end if;
  if v_preview.status <> 'pending' or v_preview.expires_at <= now() then raise exception 'preview_not_approvable'; end if;
  if v_preview.approval_token <> p_approval_token then raise exception 'approval_token_invalid'; end if;
  if v_preview.plan_payload->'routeMissionPlan' is null then raise exception 'legacy_preview_requires_regeneration'; end if;
  if not exists(select 1 from public.quests where id=v_preview.quest_id and owner_id=auth.uid()) then raise exception 'quest_not_owned'; end if;

  update public.route_versions set status='superseded'
  where quest_id=v_preview.quest_id and status='active';
  select coalesce(max(version_number),0)+1 into v_route_version from public.route_versions where quest_id=v_preview.quest_id;
  insert into public.route_versions(quest_id,version_number,status,generated_by,generation_reason,ai_model,prompt_version,route_snapshot,approved_at,approved_by)
  values(v_preview.quest_id,v_route_version,'active','arc','approved_quest_hierarchy_plan','gemini',
    coalesce(v_preview.plan_payload #>> '{routeMissionPlan,planVersion}','1'),
    jsonb_build_object('missionOrder',v_preview.plan_payload #> '{routeMissionPlan,missions}'),now(),auth.uid())
  returning id into v_route_id;

  for v_mission in select value from jsonb_array_elements(v_preview.plan_payload #> '{routeMissionPlan,missions}') loop
    insert into public.missions(
      quest_id,route_id,title,description,objective,success_condition,expected_outcome,
      done_condition,expected_output,estimated_duration_days,sort_order,order_index,
      required,weight,confidence,generated_by,generation_version,hierarchy_role
    ) values(
      v_preview.quest_id,v_route_id,v_mission->>'title',v_mission->>'objective',
      v_mission->>'objective',v_mission->>'successCondition',v_mission->>'expectedOutcome',
      v_mission->>'successCondition',v_mission->>'expectedOutcome',greatest(0,coalesce((v_mission->>'calendarDurationDays')::integer,0)),
      v_count,v_count,coalesce((v_mission->>'required')::boolean,true),
      greatest(0.001,least(100,coalesce((v_mission->>'weight')::numeric,1))),
      greatest(0,least(1,coalesce((v_mission->>'confidence')::double precision,0.5))),
      'arc','quest-hierarchy-3.0','outcome'
    ) returning id into v_mission_id;
    v_ids := v_ids || jsonb_build_object(v_mission->>'clientId',v_mission_id);
    v_count := v_count + 1;
  end loop;

  for v_mission in select value from jsonb_array_elements(v_preview.plan_payload #> '{routeMissionPlan,missions}') loop
    for v_dependency in select value from jsonb_array_elements_text(coalesce(v_mission->'dependencies','[]'::jsonb)) loop
      if v_ids ? v_dependency then
        insert into public.mission_dependencies(mission_id,depends_on_mission_id)
        values((v_ids->>(v_mission->>'clientId'))::uuid,(v_ids->>v_dependency)::uuid) on conflict do nothing;
      end if;
    end loop;
  end loop;

  v_current_mission_id := (v_ids->>(v_preview.plan_payload #>> '{currentTaskPlan,missionClientId}'))::uuid;
  if v_current_mission_id is null then raise exception 'task_plan_mission_not_found'; end if;
  for v_task in select value from jsonb_array_elements(v_preview.plan_payload #> '{currentTaskPlan,tasks}') loop
    insert into public.tasks(owner_id,quest_id,mission_id,title,action,purpose,done_condition,expected_output,estimated_effort_minutes,required,order_index,generated_by,generation_version)
    values(v_preview.owner_id,v_preview.quest_id,v_current_mission_id,v_task->>'title',v_task->>'action',v_task->>'purpose',v_task->>'doneCondition',v_task->>'expectedOutput',
      greatest(1,least(1440,coalesce((v_task->>'estimatedEffortMinutes')::integer,30))),coalesce((v_task->>'required')::boolean,true),v_task_count,'arc','quest-hierarchy-3.0')
    returning id into v_task_id;
    v_task_ids := v_task_ids || jsonb_build_object(v_task->>'clientId',v_task_id);
    v_task_count := v_task_count + 1;
  end loop;
  for v_task in select value from jsonb_array_elements(v_preview.plan_payload #> '{currentTaskPlan,tasks}') loop
    for v_dependency in select value from jsonb_array_elements_text(coalesce(v_task->'dependencies','[]'::jsonb)) loop
      if v_task_ids ? v_dependency then
        insert into public.task_dependencies(task_id,depends_on_task_id)
        values((v_task_ids->>(v_task->>'clientId'))::uuid,(v_task_ids->>v_dependency)::uuid) on conflict do nothing;
      end if;
    end loop;
    update public.tasks set dependency_ids = coalesce((
      select array_agg((v_task_ids->>dependency)::uuid)
      from jsonb_array_elements_text(coalesce(v_task->'dependencies','[]'::jsonb)) dependency
      where v_task_ids ? dependency
    ),'{}'::uuid[])
    where id=(v_task_ids->>(v_task->>'clientId'))::uuid;
  end loop;

  update public.quests set active_route_id=v_route_id,hierarchy_version=2,estimated_mission_count=v_count,updated_at=now() where id=v_preview.quest_id;
  update public.quest_plan_previews set status='approved',approved_at=now() where id=v_preview.id;
  update public.quest_planning_runs set status='approved',completed_at=now() where id=v_preview.planning_run_id;
  perform public.recalculate_quest_hierarchy_progress(v_preview.quest_id);
  return jsonb_build_object('preview_id',v_preview.id,'status','approved','route_id',v_route_id,'mission_count',v_count,'task_count',v_task_count,'mission_ids',v_ids,'task_ids',v_task_ids);
end;
$$;

revoke all on public.tasks, public.mission_dependencies, public.task_dependencies, public.hierarchy_migration_previews, public.task_progress_events from anon;
grant select, insert, update, delete on public.tasks, public.mission_dependencies, public.task_dependencies to authenticated;
grant select on public.hierarchy_migration_previews, public.task_progress_events to authenticated;
revoke all on function public.recalculate_quest_hierarchy_progress(uuid), public.preview_quest_hierarchy_migration(uuid), public.apply_quest_hierarchy_migration(uuid) from public;
grant execute on function public.recalculate_quest_hierarchy_progress(uuid), public.preview_quest_hierarchy_migration(uuid), public.apply_quest_hierarchy_migration(uuid) to authenticated;
revoke all on function public.approve_quest_plan_preview(uuid, uuid) from public;
grant execute on function public.approve_quest_plan_preview(uuid, uuid) to authenticated;

comment on table public.tasks is 'Concrete owner-private actions. Tasks are the daily completion unit and always belong to one Mission.';
comment on column public.missions.hierarchy_role is 'Outcome Missions are the editable source of intermediate results. Legacy sources remain history only.';
comment on column public.route_versions.route_snapshot is 'Version metadata and ordering diff only. Task bodies must not be copied here.';

commit;
