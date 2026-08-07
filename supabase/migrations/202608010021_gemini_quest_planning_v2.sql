begin;

create table if not exists public.ai_model_registry (
  id uuid primary key default gen_random_uuid(),
  provider text not null check (provider in ('gemini', 'openai')),
  model_name text not null unique,
  model_family text not null,
  release_type text not null check (release_type in ('stable', 'preview', 'latest', 'experimental')),
  enabled boolean not null default false,
  allowed_environments text[] not null default '{development}'::text[],
  supports_interactions boolean not null default false,
  supports_structured_output boolean not null default false,
  supports_google_search boolean not null default false,
  supports_function_calling boolean not null default false,
  supported_thinking_levels text[] not null default '{}'::text[],
  default_thinking_level text not null default 'low',
  effective_from timestamptz not null default now(),
  retire_at timestamptz,
  updated_at timestamptz not null default now()
);

insert into public.ai_model_registry (
  provider, model_name, model_family, release_type, enabled, allowed_environments,
  supports_interactions, supports_structured_output, supports_google_search,
  supports_function_calling, supported_thinking_levels, default_thinking_level
) values
  ('gemini', 'gemini-3.6-flash', 'gemini-3.6-flash', 'stable', true, '{development,staging,production}', true, true, true, true, '{low,medium,high}', 'medium'),
  ('gemini', 'gemini-3.5-flash', 'gemini-3.5-flash', 'stable', true, '{development,staging,production}', true, true, true, true, '{low,medium,high}', 'medium'),
  ('gemini', 'gemini-3.5-flash-lite', 'gemini-3.5-flash-lite', 'stable', true, '{development,staging,production}', true, true, false, true, '{minimal,low,medium,high}', 'low'),
  ('gemini', 'gemini-3.1-pro-preview', 'gemini-3.1-pro', 'preview', false, '{development,staging}', true, true, true, true, '{low,medium,high}', 'high')
on conflict (model_name) do update set
  release_type = excluded.release_type,
  enabled = excluded.enabled,
  allowed_environments = excluded.allowed_environments,
  updated_at = now();

create table if not exists public.ai_prompt_registry (
  id uuid primary key default gen_random_uuid(),
  prompt_key text not null,
  version integer not null check (version > 0),
  status text not null check (status in ('draft', 'evaluation', 'active', 'retired')),
  model_role text not null,
  thinking_level text not null check (thinking_level in ('minimal', 'low', 'medium', 'high')),
  schema_key text not null,
  schema_version text not null,
  temperature double precision not null check (temperature between 0 and 1.5),
  tools jsonb not null default '[]'::jsonb,
  change_summary text not null default '',
  created_at timestamptz not null default now(),
  activated_at timestamptz,
  retired_at timestamptz,
  unique (prompt_key, version)
);

create unique index if not exists ai_prompt_registry_one_active_idx
  on public.ai_prompt_registry(prompt_key) where status = 'active';

create table if not exists public.ai_schema_registry (
  id uuid primary key default gen_random_uuid(),
  schema_key text not null,
  version text not null,
  status text not null check (status in ('draft', 'evaluation', 'active', 'retired')),
  json_schema jsonb not null,
  compatibility text not null default 'backward_compatible',
  created_at timestamptz not null default now(),
  unique (schema_key, version)
);

create table if not exists public.quest_planning_runs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  quest_id uuid not null references public.quests(id) on delete cascade,
  trace_id uuid not null unique,
  idempotency_key text not null,
  status text not null check (status in ('running', 'needs_clarification', 'preview_ready', 'failed', 'approved')),
  pipeline_version text not null,
  schema_version text not null,
  execution_versions jsonb not null default '{}'::jsonb,
  error_category text,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  unique (owner_id, idempotency_key)
);

create table if not exists public.quest_plan_previews (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  quest_id uuid not null references public.quests(id) on delete cascade,
  planning_run_id uuid not null references public.quest_planning_runs(id) on delete cascade,
  approval_token uuid not null default gen_random_uuid(),
  plan_payload jsonb not null,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'expired')),
  expires_at timestamptz not null default now() + interval '24 hours',
  approved_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.grounded_facts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  quest_id uuid not null references public.quests(id) on delete cascade,
  mission_id uuid references public.missions(id) on delete cascade,
  fact_type text not null,
  statement text not null,
  source_title text not null,
  source_uri text not null check (source_uri like 'https://%'),
  source_domain text not null,
  source_type text not null check (source_type in ('official', 'primary', 'secondary')),
  retrieved_at timestamptz not null,
  valid_until timestamptz,
  confidence double precision not null check (confidence between 0 and 1),
  grounding_metadata jsonb not null default '{}'::jsonb
);

create table if not exists public.ai_tool_audit_logs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  trace_id uuid not null,
  tool_name text not null,
  access_type text not null check (access_type in ('read', 'preview_write', 'approved_write')),
  target_type text,
  target_id uuid,
  outcome text not null check (outcome in ('allowed', 'denied', 'failed')),
  argument_keys text[] not null default '{}'::text[],
  created_at timestamptz not null default now()
);

alter table public.ai_model_registry enable row level security;
alter table public.ai_prompt_registry enable row level security;
alter table public.ai_schema_registry enable row level security;
alter table public.quest_planning_runs enable row level security;
alter table public.quest_plan_previews enable row level security;
alter table public.grounded_facts enable row level security;
alter table public.ai_tool_audit_logs enable row level security;

create policy quest_planning_runs_owner on public.quest_planning_runs for select using (owner_id = auth.uid());
create policy quest_plan_previews_owner on public.quest_plan_previews for select using (owner_id = auth.uid());
create policy grounded_facts_owner on public.grounded_facts for select using (owner_id = auth.uid());
create policy ai_tool_audit_owner on public.ai_tool_audit_logs for select using (owner_id = auth.uid());

revoke all on public.ai_model_registry, public.ai_prompt_registry, public.ai_schema_registry from anon, authenticated;
revoke all on public.quest_planning_runs, public.quest_plan_previews, public.grounded_facts, public.ai_tool_audit_logs from anon, authenticated;
grant select on public.quest_planning_runs, public.quest_plan_previews, public.grounded_facts, public.ai_tool_audit_logs to authenticated;

create or replace function public.approve_quest_plan_preview(
  p_preview_id uuid,
  p_approval_token uuid
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_preview public.quest_plan_previews%rowtype;
  v_mission jsonb;
  v_ids jsonb := '{}'::jsonb;
  v_mission_id uuid;
  v_dependencies uuid[];
  v_count integer := 0;
begin
  select * into v_preview from public.quest_plan_previews
  where id = p_preview_id for update;
  if not found or v_preview.owner_id <> auth.uid() then raise exception 'preview_not_found'; end if;
  if v_preview.status = 'approved' then
    return jsonb_build_object('preview_id', v_preview.id, 'status', 'approved', 'idempotent', true);
  end if;
  if v_preview.status <> 'pending' or v_preview.expires_at <= now() then raise exception 'preview_not_approvable'; end if;
  if v_preview.approval_token <> p_approval_token then raise exception 'approval_token_invalid'; end if;
  if not exists (select 1 from public.quests q where q.id = v_preview.quest_id and q.owner_id = auth.uid()) then raise exception 'quest_not_owned'; end if;

  for v_mission in select value from jsonb_array_elements(v_preview.plan_payload #> '{missionPlan,missions}') loop
    insert into public.missions (
      quest_id, title, description, action, done_condition, expected_output,
      confidence, estimated_duration_days, effort_estimate, sort_order
    ) values (
      v_preview.quest_id,
      v_mission->>'title',
      v_mission->>'purpose',
      v_mission->>'action',
      v_mission->>'doneCondition',
      v_mission->>'expectedOutput',
      greatest(0, least(1, coalesce((v_mission->>'confidence')::double precision, 0.5))),
      greatest(1, coalesce((v_mission->>'calendarDurationDays')::integer, 1)),
      jsonb_build_object('active_effort_minutes', greatest(1, coalesce((v_mission->>'estimatedEffortMinutes')::integer, 30)), 'version', 'quest-planning-2.0'),
      v_count
    ) returning id into v_mission_id;
    v_ids := v_ids || jsonb_build_object(v_mission->>'clientId', v_mission_id);
    v_count := v_count + 1;
  end loop;

  for v_mission in select value from jsonb_array_elements(v_preview.plan_payload #> '{missionPlan,missions}') loop
    select coalesce(array_agg((v_ids->>dependency)::uuid), '{}'::uuid[]) into v_dependencies
    from jsonb_array_elements_text(coalesce(v_mission->'dependencies', '[]'::jsonb)) dependency
    where v_ids ? dependency;
    update public.missions set dependency_ids = v_dependencies
    where id = (v_ids->>(v_mission->>'clientId'))::uuid;
  end loop;

  update public.quest_plan_previews set status = 'approved', approved_at = now() where id = v_preview.id;
  update public.quest_planning_runs set status = 'approved', completed_at = now() where id = v_preview.planning_run_id;
  update public.quests set estimated_mission_count = v_count, updated_at = now() where id = v_preview.quest_id;
  return jsonb_build_object('preview_id', v_preview.id, 'status', 'approved', 'mission_count', v_count, 'mission_ids', v_ids);
end;
$$;

revoke all on function public.approve_quest_plan_preview(uuid, uuid) from public;
grant execute on function public.approve_quest_plan_preview(uuid, uuid) to authenticated;

commit;
