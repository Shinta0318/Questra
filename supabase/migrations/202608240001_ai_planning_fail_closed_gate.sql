begin;

create or replace function public.enforce_quest_plan_quality_gate()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_mission_count integer;
  v_task_count integer;
  v_review_count integer;
  v_task_review_count integer;
  v_current_mission text;
begin
  if new.status <> 'approved' or old.status = 'approved' then
    return new;
  end if;

  if new.plan_payload #>> '{qualityGate,status}' <> 'passed'
     or new.plan_payload #>> '{qualityGate,version}' <> 'qst-341-v1' then
    raise exception 'planning_quality_gate_missing';
  end if;
  if jsonb_typeof(new.plan_payload #> '{routeMissionPlan,missions}') <> 'array'
     or jsonb_typeof(new.plan_payload #> '{currentTaskPlan,tasks}') <> 'array' then
    raise exception 'planning_payload_incomplete';
  end if;

  select jsonb_array_length(new.plan_payload #> '{routeMissionPlan,missions}'),
         jsonb_array_length(new.plan_payload #> '{currentTaskPlan,tasks}')
  into v_mission_count, v_task_count;
  if v_mission_count < 1 or v_task_count < 1 then
    raise exception 'planning_payload_empty';
  end if;
  if coalesce((new.plan_payload #>> '{missionCritic,passed}')::boolean, false) is not true
     or coalesce((new.plan_payload #>> '{missionCritic,overallScore}')::numeric, 0) < 85 then
    raise exception 'mission_critic_gate_failed';
  end if;
  if coalesce((new.plan_payload #>> '{currentTaskCritic,passed}')::boolean, false) is not true
     or coalesce((new.plan_payload #>> '{currentTaskCritic,overallScore}')::numeric, 0) < 85 then
    raise exception 'task_critic_gate_failed';
  end if;

  select count(distinct review->>'clientId') into v_review_count
  from jsonb_array_elements(new.plan_payload #> '{missionCritic,missionResults}') review
  where coalesce((review->>'passed')::boolean, false) is true
    and review->>'verdict' = 'pass'
    and coalesce((review #>> '{scores,questRelevance}')::numeric, 0) >= 90
    and coalesce((review #>> '{scores,outcomeQuality}')::numeric, 0) >= 85
    and coalesce((review #>> '{scores,missionGranularity}')::numeric, 0) >= 90
    and coalesce((review #>> '{scores,successConditionQuality}')::numeric, 0) >= 90
    and coalesce((review #>> '{scores,personalization}')::numeric, 0) >= 80
    and coalesce((review #>> '{scores,nonTemplateQuality}')::numeric, 0) >= 90
    and coalesce((review #>> '{scores,uniqueness}')::numeric, 0) >= 90
    and coalesce((review #>> '{scores,sequencing}')::numeric, 0) >= 80
    and coalesce((review #>> '{scores,completenessContribution}')::numeric, 0) >= 85
    and coalesce((review #>> '{scores,taskSeparation}')::numeric, 0) >= 95
    and exists (
      select 1
      from jsonb_array_elements(new.plan_payload #> '{routeMissionPlan,missions}') mission
      where mission->>'clientId' = review->>'clientId'
    );
  if v_review_count <> v_mission_count then
    raise exception 'mission_critic_results_incomplete';
  end if;

  select count(distinct review->>'clientId') into v_task_review_count
  from jsonb_array_elements(new.plan_payload #> '{currentTaskCritic,taskResults}') review
  where coalesce((review->>'passed')::boolean, false) is true
    and exists (
      select 1
      from jsonb_array_elements(new.plan_payload #> '{currentTaskPlan,tasks}') task
      where task->>'clientId' = review->>'clientId'
    );
  if v_task_review_count <> v_task_count then
    raise exception 'task_critic_results_incomplete';
  end if;

  v_current_mission := new.plan_payload #>> '{currentTaskPlan,missionClientId}';
  if v_current_mission is null or not exists (
    select 1
    from jsonb_array_elements(new.plan_payload #> '{routeMissionPlan,missions}') mission
    where mission->>'clientId' = v_current_mission
  ) then
    raise exception 'task_plan_mission_not_found';
  end if;
  return new;
end;
$$;

drop trigger if exists quest_plan_previews_enforce_quality_gate on public.quest_plan_previews;
create trigger quest_plan_previews_enforce_quality_gate
before update of status on public.quest_plan_previews
for each row execute function public.enforce_quest_plan_quality_gate();

revoke all on function public.enforce_quest_plan_quality_gate() from public;

comment on function public.enforce_quest_plan_quality_gate() is
  'Fail-closed approval boundary. Mission and Task plans require complete QST-341 critic evidence before transactional persistence.';

commit;
