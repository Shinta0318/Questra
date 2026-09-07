-- QST-354: controlled cohort discovery and atomic private Quest adoption.
begin;

create table if not exists public.guild_pilot_members (
  user_id uuid primary key references public.user_profiles(id) on delete cascade,
  enabled boolean not null default false,
  cohort text not null default 'internal_beta' check (char_length(cohort) between 1 and 80),
  enabled_at timestamptz,
  created_at timestamptz not null default now()
);
alter table public.guild_pilot_members enable row level security;
create policy "Guild pilot members inspect their own eligibility"
  on public.guild_pilot_members for select using (user_id = auth.uid());

alter table public.guild_quest_publications
  add column if not exists snapshot_version integer not null default 1;
alter table public.guild_quest_copy_events
  add column if not exists source_snapshot_version integer not null default 1;
alter table public.guild_mission_publications
  add column if not exists action text not null default '',
  add column if not exists done_condition text not null default '',
  add column if not exists expected_output text not null default '';

create table if not exists public.guild_moderation_appeals (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.user_profiles(id) on delete cascade,
  publication_id uuid not null references public.guild_quest_publications(id) on delete cascade,
  reason text not null check (char_length(btrim(reason)) between 10 and 1000),
  status text not null default 'pending' check (status in ('pending','reviewing','accepted','rejected')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);
alter table public.guild_moderation_appeals enable row level security;
create policy "Guild publication owners submit and inspect appeals"
  on public.guild_moderation_appeals for all
  using (owner_id=auth.uid()) with check (
    owner_id=auth.uid() and exists(
      select 1 from public.guild_quest_publication_owners ownership
      where ownership.publication_id=publication_id and ownership.owner_id=auth.uid()
    )
  );

create or replace function public.version_guild_quest_snapshot()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if row(new.title,new.summary,new.tags,new.difficulty_score,new.estimated_duration_days,new.estimated_cost_label)
     is distinct from
     row(old.title,old.summary,old.tags,old.difficulty_score,old.estimated_duration_days,old.estimated_cost_label) then
    new.snapshot_version := old.snapshot_version + 1;
  end if;
  return new;
end;
$$;
drop trigger if exists guild_quest_snapshot_version on public.guild_quest_publications;
create trigger guild_quest_snapshot_version before update on public.guild_quest_publications
for each row execute function public.version_guild_quest_snapshot();

create or replace function public.capture_guild_mission_copy_contract()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  update public.guild_mission_publications publication set
    action = coalesce(nullif(source.action, ''), source.title),
    done_condition = coalesce(nullif(source.done_condition, ''), nullif(source.success_condition, ''), source.title || 'を完了したと確認できる'),
    expected_output = coalesce(nullif(source.expected_output, ''), nullif(source.expected_outcome, ''), source.title)
  from public.missions source
  where publication.id = new.mission_publication_id
    and source.id = new.source_mission_id;
  return new;
end;
$$;
drop trigger if exists guild_mission_capture_copy_contract on public.guild_mission_publication_owners;
create trigger guild_mission_capture_copy_contract
after insert or update of source_mission_id on public.guild_mission_publication_owners
for each row execute function public.capture_guild_mission_copy_contract();

drop policy if exists "Guild Discovery reads approved public snapshots" on public.guild_quest_publications;
create policy "Guild pilot reads approved public snapshots" on public.guild_quest_publications
  for select using (
    exists (
      select 1 from public.guild_pilot_members member
      where member.user_id = auth.uid() and member.enabled
    ) and visibility = 'public' and moderation_status = 'approved'
    or exists (
      select 1 from public.guild_quest_publication_owners ownership
      where ownership.publication_id = id and ownership.owner_id = auth.uid()
    )
  );

create or replace function public.list_guild_pilot_quests(
  p_limit integer default 20,
  p_before_published_at timestamptz default null,
  p_before_id uuid default null
) returns setof public.guild_quest_publications
language sql stable security invoker set search_path = public, pg_temp as $$
  select publication.*
  from public.guild_quest_publications publication
  where publication.visibility='public'
    and publication.moderation_status='approved'
    and (
      (p_before_published_at is null and p_before_id is null)
      or (
        p_before_published_at is not null and p_before_id is not null
        and (publication.published_at,publication.id) < (p_before_published_at,p_before_id)
      )
    )
  order by publication.published_at desc,publication.id desc
  limit greatest(1,least(coalesce(p_limit,20),50));
$$;

create or replace function public.copy_guild_quest_to_private(
  p_publication_id uuid,
  p_include_missions boolean,
  p_arc_optimization_requested boolean,
  p_idempotency_key text
) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_actor uuid := auth.uid();
  v_publication public.guild_quest_publications%rowtype;
  v_existing public.guild_quest_copy_events%rowtype;
  v_quest_id uuid;
  v_mission_id uuid;
  v_source_mission public.guild_mission_publications%rowtype;
  v_first_mission uuid;
  v_mission_count integer := 0;
begin
  if v_actor is null then raise exception 'authentication_required'; end if;
  if char_length(p_idempotency_key) not between 8 and 120 then raise exception 'invalid_idempotency_key'; end if;
  if not exists(select 1 from public.guild_pilot_members where user_id=v_actor and enabled) then
    raise exception 'guild_pilot_not_enabled';
  end if;
  select * into v_existing from public.guild_quest_copy_events
    where copier_id=v_actor and idempotency_key=p_idempotency_key;
  if found then
    return jsonb_build_object('quest_id',v_existing.destination_quest_id,'already_applied',true);
  end if;
  select * into v_publication from public.guild_quest_publications
    where id=p_publication_id and visibility='public' and moderation_status='approved' for share;
  if not found then raise exception 'publication_not_available'; end if;

  insert into public.quests(owner_id,title,description,difficulty,status,visibility,category)
  values(v_actor,v_publication.title,v_publication.summary,
    case when v_publication.difficulty_score >= 4 then 'hard' when v_publication.difficulty_score <= 1 then 'easy' else 'normal' end,
    'active','private',coalesce(v_publication.tags[1],'冒険')) returning id into v_quest_id;

  if p_include_missions then
    for v_source_mission in
      select * from public.guild_mission_publications
      where quest_publication_id=p_publication_id and moderation_status='approved'
      order by order_index,id
    loop
      insert into public.missions(
        quest_id,title,description,objective,success_condition,expected_outcome,
        done_condition,expected_output,action,guide_type,difficulty,status,
        sort_order,order_index,generated_by,generation_version,hierarchy_role
      ) values(
        v_quest_id,v_source_mission.title,v_source_mission.purpose,v_source_mission.purpose,
        v_source_mission.done_condition,v_source_mission.expected_output,
        v_source_mission.done_condition,v_source_mission.expected_output,v_source_mission.action,
        'route','easy','todo',v_source_mission.order_index,v_source_mission.order_index,
        'system','guild-pilot-snapshot-v1','outcome'
      ) returning id into v_mission_id;
      v_first_mission := coalesce(v_first_mission,v_mission_id);
      v_mission_count := v_mission_count + 1;
    end loop;
  end if;
  if v_first_mission is not null then
    select * into v_source_mission from public.guild_mission_publications
      where quest_publication_id=p_publication_id and moderation_status='approved'
      order by order_index,id limit 1;
    insert into public.tasks(owner_id,quest_id,mission_id,title,action,purpose,done_condition,expected_output,status,origin,generated_by,generation_version)
    values(v_actor,v_quest_id,v_first_mission,v_source_mission.title,v_source_mission.action,
      v_source_mission.purpose,v_source_mission.done_condition,v_source_mission.expected_output,
      'ready','copied','system','guild-pilot-snapshot-v1');
  end if;
  insert into public.guild_quest_copy_events(publication_id,copier_id,destination_quest_id,include_missions,arc_optimization_requested,idempotency_key,source_snapshot_version)
  values(p_publication_id,v_actor,v_quest_id,p_include_missions,p_arc_optimization_requested,p_idempotency_key,v_publication.snapshot_version);
  update public.guild_quest_publications set copy_count=copy_count+1 where id=p_publication_id;
  return jsonb_build_object('quest_id',v_quest_id,'mission_count',v_mission_count,'first_task_created',v_first_mission is not null,'already_applied',false);
end;
$$;

revoke all on public.guild_pilot_members,public.guild_moderation_appeals from anon, authenticated;
grant select on public.guild_pilot_members to authenticated;
grant select,insert on public.guild_moderation_appeals to authenticated;
revoke all on function public.copy_guild_quest_to_private(uuid,boolean,boolean,text) from public,anon;
grant execute on function public.copy_guild_quest_to_private(uuid,boolean,boolean,text) to authenticated;
revoke all on function public.list_guild_pilot_quests(integer,timestamptz,uuid) from public,anon;
grant execute on function public.list_guild_pilot_quests(integer,timestamptz,uuid) to authenticated;

comment on function public.copy_guild_quest_to_private(uuid,boolean,boolean,text) is
  'Atomically derives an owner-private Quest from an approved immutable Guild snapshot; source rows are never modified.';
commit;
