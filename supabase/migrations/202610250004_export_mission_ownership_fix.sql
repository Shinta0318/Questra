begin;

create or replace function public.export_my_questra_data()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_owner uuid := auth.uid();
  v_profile jsonb;
  v_quests jsonb;
  v_missions jsonb;
  v_tasks jsonb;
  v_trails jsonb;
  v_memories jsonb;
  v_counts jsonb;
begin
  if v_owner is null then
    raise exception 'Authentication required.';
  end if;

  select coalesce(to_jsonb(p), '{}'::jsonb)
    into v_profile
    from public.user_profiles p
    where p.id = v_owner;
  select coalesce(jsonb_agg(to_jsonb(q) order by q.created_at), '[]'::jsonb)
    into v_quests from public.quests q where q.owner_id = v_owner;
  select coalesce(jsonb_agg(to_jsonb(m) order by m.created_at), '[]'::jsonb)
    into v_missions
    from public.missions m
    join public.quests q on q.id = m.quest_id
    where q.owner_id = v_owner;
  select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb)
    into v_tasks from public.tasks t where t.owner_id = v_owner;
  select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb)
    into v_trails from public.trails t where t.owner_id = v_owner;
  select coalesce(jsonb_agg(to_jsonb(a) order by a.created_at), '[]'::jsonb)
    into v_memories from public.arc_memories a where a.user_id = v_owner;

  v_counts := jsonb_build_object(
    'profile', case when v_profile = '{}'::jsonb then 0 else 1 end,
    'quests', jsonb_array_length(v_quests),
    'missions', jsonb_array_length(v_missions),
    'tasks', jsonb_array_length(v_tasks),
    'trails', jsonb_array_length(v_trails),
    'arc_memories', jsonb_array_length(v_memories)
  );

  insert into public.data_rights_audit_events (
    owner_id, operation, scope_type, impact_counts
  ) values (v_owner, 'export', 'account', v_counts);

  return jsonb_build_object(
    'version', 1,
    'generated_at', now(),
    'counts', v_counts,
    'profile', v_profile,
    'quests', v_quests,
    'missions', v_missions,
    'tasks', v_tasks,
    'trails', v_trails,
    'arc_memories', v_memories
  );
end;
$$;

commit;
