begin;

create or replace function public.record_quest_progress_event(
  p_event_name text, p_event_version integer, p_quest_id uuid,
  p_mission_id uuid, p_route_id uuid, p_source text,
  p_occurred_at timestamptz, p_session_id uuid, p_device_type text,
  p_app_version text, p_app_environment text, p_quest_dna_version integer,
  p_planning_engine_version text, p_model_provider text,
  p_model_version text, p_metadata jsonb, p_idempotency_key text
) returns uuid
language plpgsql security definer set search_path = public
as $$
declare actor_id uuid := auth.uid(); result_id uuid; safe_metadata jsonb;
begin
  if actor_id is null then raise exception 'authentication required'; end if;
  if p_source not in ('user','arc','system','business') then raise exception 'invalid source'; end if;
  if char_length(p_idempotency_key) not between 8 and 160 then raise exception 'invalid idempotency key'; end if;
  if p_quest_id is not null and not exists (select 1 from public.quests where id=p_quest_id and owner_id=actor_id) then raise exception 'quest not owned'; end if;
  if p_mission_id is not null and not exists (select 1 from public.missions where id=p_mission_id and owner_id=actor_id) then raise exception 'mission not owned'; end if;
  if p_route_id is not null and not exists (
    select 1 from public.route_versions rv join public.quests q on q.id=rv.quest_id
    where rv.id=p_route_id and q.owner_id=actor_id
  ) then raise exception 'route not owned'; end if;

  select coalesce(jsonb_object_agg(key,value),'{}'::jsonb) into safe_metadata
  from jsonb_each(coalesce(p_metadata,'{}'::jsonb))
  where key=any(array['category','difficulty_band','status','visibility','surface','progress_band','stage','reason_code','proposal_type','support_type','interaction','outcome','source_type','plan_quality_band']);

  insert into public.quest_progress_events (
    event_name,event_version,user_id,quest_id,mission_id,route_id,source,
    occurred_at,session_id,device_type,app_version,app_environment,
    quest_dna_version,planning_engine_version,model_provider,model_version,
    metadata,idempotency_key
  ) values (
    left(p_event_name,80),greatest(p_event_version,1),actor_id,p_quest_id,
    p_mission_id,p_route_id,p_source,coalesce(p_occurred_at,now()),p_session_id,
    left(p_device_type,40),left(p_app_version,40),coalesce(p_app_environment,'production'),
    p_quest_dna_version,left(p_planning_engine_version,80),left(p_model_provider,40),
    left(p_model_version,80),safe_metadata,p_idempotency_key
  ) on conflict (user_id,idempotency_key) do nothing returning event_id into result_id;
  if result_id is null then
    select event_id into result_id from public.quest_progress_events
    where user_id=actor_id and idempotency_key=p_idempotency_key;
  end if;
  return result_id;
end;
$$;

commit;
