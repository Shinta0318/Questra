create unique index if not exists mission_source_references_owner_url_idx
  on public.mission_source_references (owner_id, mission_id, source_url);

create or replace function public.mission_plan_feedback_aggregates()
returns table(reason text, feedback_count bigint)
language sql
security definer
set search_path = public, pg_temp
as $$
  select feedback.reason, count(*) as feedback_count
  from public.mission_plan_feedback feedback
  group by feedback.reason
  having count(*) >= 10
  order by feedback_count desc;
$$;

revoke all on function public.mission_plan_feedback_aggregates() from public;
grant execute on function public.mission_plan_feedback_aggregates() to authenticated;
