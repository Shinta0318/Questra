create table if not exists public.data_rights_audit_events (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  operation text not null check (
    operation in ('export', 'deletion_preview', 'task_deletion')
  ),
  scope_type text not null,
  target_id uuid,
  impact_counts jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.data_rights_audit_events enable row level security;

drop policy if exists "Users read their own data rights audit" on public.data_rights_audit_events;
create policy "Users read their own data rights audit"
  on public.data_rights_audit_events for select
  using (owner_id = auth.uid());

revoke all on public.data_rights_audit_events from anon, authenticated;
grant select on public.data_rights_audit_events to authenticated;

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
    into v_missions from public.missions m where m.owner_id = v_owner;
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

create or replace function public.preview_task_data_deletion(p_task_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_owner uuid := auth.uid();
  v_title text;
  v_trails integer;
  v_memories integer;
  v_result jsonb;
begin
  if v_owner is null then raise exception 'Authentication required.'; end if;
  select title into v_title
    from public.tasks where id = p_task_id and owner_id = v_owner;
  if not found then raise exception 'Task not found.'; end if;

  select count(*) into v_trails
    from public.trails where owner_id = v_owner and task_id = p_task_id;
  select count(*) into v_memories
    from public.arc_memories where user_id = v_owner and task_id = p_task_id;
  v_result := jsonb_build_object(
    'task_id', p_task_id,
    'task_title', v_title,
    'trail_count', v_trails,
    'memory_count', v_memories,
    'trail_action', 'preserve_and_unlink',
    'memory_action', 'delete'
  );
  insert into public.data_rights_audit_events (
    owner_id, operation, scope_type, target_id, impact_counts
  ) values (
    v_owner, 'deletion_preview', 'task', p_task_id,
    jsonb_build_object('trails', v_trails, 'arc_memories', v_memories)
  );
  return v_result;
end;
$$;

create or replace function public.delete_task_with_data_rights_audit(
  p_task_id uuid,
  p_confirmation text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_owner uuid := auth.uid();
  v_title text;
  v_trails integer;
  v_memories integer;
begin
  if v_owner is null then raise exception 'Authentication required.'; end if;
  if p_confirmation is distinct from 'DELETE:' || p_task_id::text then
    raise exception 'Explicit confirmation required.';
  end if;
  select title into v_title
    from public.tasks where id = p_task_id and owner_id = v_owner for update;
  if not found then raise exception 'Task not found.'; end if;
  select count(*) into v_trails
    from public.trails where owner_id = v_owner and task_id = p_task_id;
  select count(*) into v_memories
    from public.arc_memories where user_id = v_owner and task_id = p_task_id;

  delete from public.tasks where id = p_task_id and owner_id = v_owner;
  insert into public.data_rights_audit_events (
    owner_id, operation, scope_type, target_id, impact_counts
  ) values (
    v_owner, 'task_deletion', 'task', p_task_id,
    jsonb_build_object(
      'trails_preserved_and_unlinked', v_trails,
      'arc_memories_deleted', v_memories
    )
  );
  return jsonb_build_object(
    'deleted', true,
    'task_id', p_task_id,
    'task_title', v_title,
    'trails_preserved_and_unlinked', v_trails,
    'arc_memories_deleted', v_memories
  );
end;
$$;

revoke all on function public.export_my_questra_data() from public;
revoke all on function public.preview_task_data_deletion(uuid) from public;
revoke all on function public.delete_task_with_data_rights_audit(uuid, text) from public;
grant execute on function public.export_my_questra_data() to authenticated;
grant execute on function public.preview_task_data_deletion(uuid) to authenticated;
grant execute on function public.delete_task_with_data_rights_audit(uuid, text) to authenticated;
