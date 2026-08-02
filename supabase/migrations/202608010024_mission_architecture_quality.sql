begin;

create table if not exists public.mission_plan_drafts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  quest_id uuid not null references public.quests(id) on delete cascade,
  planning_run_id uuid not null references public.quest_planning_runs(id) on delete cascade,
  preview_id uuid not null unique references public.quest_plan_previews(id) on delete cascade,
  status text not null default 'reviewing' check (status in ('generating','reviewing','approved','rejected','expired')),
  quest_understanding_version integer not null default 1,
  success_contract_version integer not null default 1,
  prompt_versions jsonb not null default '{}'::jsonb,
  schema_version text not null,
  model_name text not null,
  model_version text not null default '',
  thinking_level text not null check (thinking_level in ('minimal','low','medium','high')),
  overall_confidence double precision not null default 0 check (overall_confidence between 0 and 1),
  achievement_domains jsonb not null default '[]'::jsonb,
  coverage_analysis jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '24 hours',
  approved_at timestamptz
);

create table if not exists public.mission_candidates (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  draft_id uuid not null references public.mission_plan_drafts(id) on delete cascade,
  client_id text not null,
  title text not null,
  objective text not null,
  success_condition text not null,
  expected_outcome text not null,
  reason_required text not null,
  covered_success_conditions text[] not null default '{}'::text[],
  dependency_client_ids text[] not null default '{}'::text[],
  required boolean not null default true,
  parallelizable boolean not null default false,
  child_task_estimate integer not null check (child_task_estimate between 1 and 30),
  confidence double precision not null check (confidence between 0 and 1),
  critic_scores jsonb not null default '{}'::jsonb,
  verdict text not null check (verdict in ('pass','repair','merge','split','convert_to_task','delete')),
  order_index integer not null,
  user_decision text check (user_decision is null or user_decision in ('accepted','edited','deleted','converted_to_task','merged','split','regenerated')),
  original_payload jsonb not null,
  created_at timestamptz not null default now(),
  unique (draft_id, client_id)
);

create table if not exists public.mission_plan_feedback_events (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  quest_id uuid not null references public.quests(id) on delete cascade,
  draft_id uuid not null references public.mission_plan_drafts(id) on delete cascade,
  candidate_id uuid references public.mission_candidates(id) on delete set null,
  event_type text not null check (event_type in (
    'viewed','accepted','edited','deleted','converted_to_task','merged','split','regenerated',
    'too_abstract','too_specific','not_relevant','duplicate','missing_required_mission','plan_approved','plan_rejected'
  )),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists mission_plan_drafts_owner_quest_idx on public.mission_plan_drafts(owner_id, quest_id, created_at desc);
create index if not exists mission_candidates_draft_order_idx on public.mission_candidates(draft_id, order_index);
create index if not exists mission_feedback_quest_created_idx on public.mission_plan_feedback_events(quest_id, created_at desc);

alter table public.mission_plan_drafts enable row level security;
alter table public.mission_candidates enable row level security;
alter table public.mission_plan_feedback_events enable row level security;

create policy mission_plan_drafts_owner_select on public.mission_plan_drafts for select using (owner_id = auth.uid());
create policy mission_candidates_owner_select on public.mission_candidates for select using (owner_id = auth.uid());
create policy mission_feedback_owner_select on public.mission_plan_feedback_events for select using (owner_id = auth.uid());

revoke all on public.mission_plan_drafts, public.mission_candidates, public.mission_plan_feedback_events from anon, authenticated;
grant select on public.mission_plan_drafts, public.mission_candidates, public.mission_plan_feedback_events to authenticated;

create or replace function public.sync_mission_plan_draft_status()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_draft_id uuid;
begin
  if new.status is distinct from old.status and new.status in ('approved','rejected','expired') then
    update public.mission_plan_drafts set status=new.status, approved_at=case when new.status='approved' then coalesce(new.approved_at,now()) else approved_at end
    where preview_id=new.id returning id into v_draft_id;
    if v_draft_id is not null and new.status in ('approved','rejected') then
      insert into public.mission_plan_feedback_events(owner_id,quest_id,draft_id,event_type)
      values(new.owner_id,new.quest_id,v_draft_id,case when new.status='approved' then 'plan_approved' else 'plan_rejected' end);
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists quest_plan_preview_sync_mission_draft on public.quest_plan_previews;
create trigger quest_plan_preview_sync_mission_draft after update of status on public.quest_plan_previews
for each row execute function public.sync_mission_plan_draft_status();

create or replace function public.record_mission_candidate_feedback(
  p_draft_id uuid,
  p_client_id text,
  p_event_type text,
  p_metadata jsonb default '{}'::jsonb
) returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_draft public.mission_plan_drafts%rowtype;
  v_candidate public.mission_candidates%rowtype;
  v_event_id uuid;
begin
  select * into v_draft from public.mission_plan_drafts where id = p_draft_id and owner_id = auth.uid();
  if not found then raise exception 'draft_not_found'; end if;
  select * into v_candidate from public.mission_candidates where draft_id = p_draft_id and client_id = p_client_id;
  if not found then raise exception 'candidate_not_found'; end if;
  if p_event_type not in ('viewed','accepted','edited','deleted','converted_to_task','merged','split','regenerated','too_abstract','too_specific','not_relevant','duplicate','missing_required_mission') then raise exception 'invalid_event_type'; end if;
  update public.mission_candidates set user_decision = case p_event_type
    when 'viewed' then user_decision when 'too_abstract' then user_decision when 'too_specific' then user_decision
    when 'not_relevant' then user_decision when 'duplicate' then user_decision when 'missing_required_mission' then user_decision
    else p_event_type end
  where id = v_candidate.id;
  insert into public.mission_plan_feedback_events(owner_id,quest_id,draft_id,candidate_id,event_type,metadata)
  values(auth.uid(),v_draft.quest_id,v_draft.id,v_candidate.id,p_event_type,coalesce(p_metadata,'{}'::jsonb)) returning id into v_event_id;
  return v_event_id;
end;
$$;

revoke all on function public.record_mission_candidate_feedback(uuid,text,text,jsonb) from public;
grant execute on function public.record_mission_candidate_feedback(uuid,text,text,jsonb) to authenticated;
revoke all on function public.sync_mission_plan_draft_status() from public;

comment on table public.mission_plan_drafts is 'QST-259 approval-gated Mission architecture plans. Drafts are never formal Missions.';
comment on table public.mission_candidates is 'Outcome-level Mission candidates with granularity and independent Critic evidence.';

commit;
