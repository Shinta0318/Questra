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
\set owner_public_mission_id '00000000-0000-4000-8000-000000014102'
\set other_private_mission_id '00000000-0000-4000-8000-000000014201'
\set owner_private_trail_id '00000000-0000-4000-8000-000000024101'
\set owner_public_trail_id '00000000-0000-4000-8000-000000024102'
\set other_private_trail_id '00000000-0000-4000-8000-000000024201'
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

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values
  (:'owner_id', 'authenticated', 'authenticated', 'qst41-owner@example.test', 'qst41', now(), now(), now()),
  (:'other_id', 'authenticated', 'authenticated', 'qst41-other@example.test', 'qst41', now(), now(), now())
on conflict (id) do nothing;

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

insert into public.trails (id, owner_id, quest_id, mission_id, title, summary, content, visibility, trail_type)
values
  (:'owner_private_trail_id', :'owner_id', :'owner_private_quest_id', :'owner_private_mission_id', 'Owner private Trail', 'Private Trail.', 'Private Trail content.', 'private', 'quest_record'),
  (:'owner_public_trail_id', :'owner_id', :'owner_public_quest_id', :'owner_public_mission_id', 'Owner public Trail', 'Public Trail.', 'Public Trail content.', 'public', 'quest_record'),
  (:'other_private_trail_id', :'other_id', :'other_private_quest_id', :'other_private_mission_id', 'Other private Trail', 'Other private Trail.', 'Other private Trail content.', 'private', 'quest_record');

insert into public.arc_memories (id, user_id, quest_id, title, content, memory_type, source_type)
values
  (:'owner_memory_id', :'owner_id', :'owner_private_quest_id', 'Owner memory', 'Owner-only Arc Memory.', 'quest_memory', 'quest_created'),
  (:'other_memory_id', :'other_id', :'other_private_quest_id', 'Other memory', 'Other-only Arc Memory.', 'quest_memory', 'quest_created');

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

set local role authenticated;

select set_config('request.jwt.claim.sub', :'owner_id', true);

select pg_temp.qst_assert_eq((select count(*) from public.quests where id = :'owner_private_quest_id'), 1, 'owner can read own private Quest');
select pg_temp.qst_assert_eq((select count(*) from public.quests where id = :'other_private_quest_id'), 0, 'owner cannot read another private Quest');
select pg_temp.qst_assert_eq((select count(*) from public.missions where id = :'owner_private_mission_id'), 1, 'owner can read own private Mission');
select pg_temp.qst_assert_eq((select count(*) from public.missions where id = :'other_private_mission_id'), 0, 'owner cannot read another private Mission');
select pg_temp.qst_assert_eq((select count(*) from public.trails where id = :'owner_private_trail_id'), 1, 'owner can read own private Trail');
select pg_temp.qst_assert_eq((select count(*) from public.trails where id = :'other_private_trail_id'), 0, 'owner cannot read another private Trail');
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

select set_config('request.jwt.claim.sub', :'other_id', true);

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

rollback;

\echo 'QST-041 RLS behavior tests passed'
