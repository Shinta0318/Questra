-- Hosted RLS behavior with two transaction-local Auth users. No data persists.
begin;

create function pg_temp.qst199_id(p_owner uuid, p_kind text)
returns uuid language sql immutable
as $$ select md5(p_owner::text || ':' || p_kind)::uuid $$;

create function pg_temp.qst199_assert_isolated(
  p_table regclass, p_own uuid, p_other uuid
) returns void language plpgsql as $$
declare
  v_own integer;
  v_other integer;
begin
  execute format('select count(*) from %s where id = $1', p_table)
    into v_own using p_own;
  execute format('select count(*) from %s where id = $1', p_table)
    into v_other using p_other;
  if v_own <> 1 or v_other <> 0 then
    raise exception 'QST-199 isolation failed for %: own %, other %',
      p_table, v_own, v_other;
  end if;
end;
$$;

do $fixture$
declare
  v_a uuid := gen_random_uuid();
  v_b uuid := gen_random_uuid();
begin
  perform set_config('qst199.user_a', v_a::text, true);
  perform set_config('qst199.user_b', v_b::text, true);

  insert into auth.users (
    id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at, raw_user_meta_data
  )
  select fixture.id, 'authenticated', 'authenticated',
         'qst199-' || fixture.id::text || '@example.invalid',
         'qst199-test-only', now(), now(), now(),
         jsonb_build_object(
           'region_code', policy.region_code,
           'minimum_age_confirmed', true,
           'eligibility_version', policy.eligibility_version,
           'terms_version', policy.terms_version,
           'privacy_version', policy.privacy_version,
           'ai_disclosure_version', policy.ai_disclosure_version
         )
  from (values (v_a), (v_b)) fixture(id)
  cross join public.legal_release_policies policy
  where policy.region_code = 'JP' and policy.active;
  if (select count(*) from auth.users where id in (v_a, v_b)) <> 2 then
    raise exception 'QST-199 legal-policy-compliant fixture users missing';
  end if;

  insert into public.user_profiles (id, nickname)
  values (v_a, 'QST-199 A'), (v_b, 'QST-199 B')
  on conflict (id) do nothing;
  insert into public.quests (id, owner_id, title, status, visibility)
  values
    (pg_temp.qst199_id(v_a, 'quest'), v_a, 'QST-199 A Quest', 'active', 'private'),
    (pg_temp.qst199_id(v_b, 'quest'), v_b, 'QST-199 B Quest', 'active', 'private');
  insert into public.missions (id, quest_id, title, guide_type, difficulty, status)
  values
    (pg_temp.qst199_id(v_a, 'mission'), pg_temp.qst199_id(v_a, 'quest'), 'A Mission', 'route', 'easy', 'todo'),
    (pg_temp.qst199_id(v_b, 'mission'), pg_temp.qst199_id(v_b, 'quest'), 'B Mission', 'route', 'easy', 'todo');
  insert into public.tasks (
    id, owner_id, quest_id, mission_id, title, action, done_condition
  ) values
    (pg_temp.qst199_id(v_a, 'task'), v_a, pg_temp.qst199_id(v_a, 'quest'), pg_temp.qst199_id(v_a, 'mission'), 'A Task', 'Complete A action', 'A result exists'),
    (pg_temp.qst199_id(v_b, 'task'), v_b, pg_temp.qst199_id(v_b, 'quest'), pg_temp.qst199_id(v_b, 'mission'), 'B Task', 'Complete B action', 'B result exists');
  insert into public.trails (
    id, owner_id, quest_id, mission_id, title, summary, content, visibility, trail_type
  ) values
    (pg_temp.qst199_id(v_a, 'trail'), v_a, pg_temp.qst199_id(v_a, 'quest'), pg_temp.qst199_id(v_a, 'mission'), 'A Trail', 'A only', 'A progress', 'private', 'quest_record'),
    (pg_temp.qst199_id(v_b, 'trail'), v_b, pg_temp.qst199_id(v_b, 'quest'), pg_temp.qst199_id(v_b, 'mission'), 'B Trail', 'B only', 'B progress', 'private', 'quest_record');
  insert into public.user_consents (
    user_id, purpose_code, purpose_version, status, granted_at, source
  ) values
    (v_a, 'arc_personalization', 1, 'granted', now(), 'settings'),
    (v_b, 'arc_personalization', 1, 'granted', now(), 'settings');
  perform set_config('request.jwt.claim.role', 'service_role', true);
  insert into public.arc_memories (
    id, user_id, quest_id, title, content, memory_type, source_type
  ) values
    (pg_temp.qst199_id(v_a, 'memory'), v_a, pg_temp.qst199_id(v_a, 'quest'), 'A Memory', 'A only', 'quest_memory', 'quest_created'),
    (pg_temp.qst199_id(v_b, 'memory'), v_b, pg_temp.qst199_id(v_b, 'quest'), 'B Memory', 'B only', 'quest_memory', 'quest_created');
  perform set_config('request.jwt.claim.role', '', true);
  insert into public.media (
    id, owner_id, bucket, path, media_type, related_table, related_id, visibility
  ) values
    (pg_temp.qst199_id(v_a, 'media'), v_a, 'trail-media', v_a::text || '/qst199/a.jpg', 'image', 'trails', pg_temp.qst199_id(v_a, 'trail'), 'private'),
    (pg_temp.qst199_id(v_b, 'media'), v_b, 'trail-media', v_b::text || '/qst199/b.jpg', 'image', 'trails', pg_temp.qst199_id(v_b, 'trail'), 'private');
  insert into public.route_versions (
    id, quest_id, version_number, status, generated_by, generation_reason
  ) values
    (pg_temp.qst199_id(v_a, 'route'), pg_temp.qst199_id(v_a, 'quest'), 1, 'proposed', 'arc', 'QST-199 isolation'),
    (pg_temp.qst199_id(v_b, 'route'), pg_temp.qst199_id(v_b, 'quest'), 1, 'proposed', 'arc', 'QST-199 isolation');
end;
$fixture$;

set local role authenticated;
select set_config('request.jwt.claim.sub', current_setting('qst199.user_a'), true);
do $check_a$
declare
  v_a uuid := current_setting('qst199.user_a')::uuid;
  v_b uuid := current_setting('qst199.user_b')::uuid;
  v_changed integer;
begin
  perform pg_temp.qst199_assert_isolated('public.quests', pg_temp.qst199_id(v_a, 'quest'), pg_temp.qst199_id(v_b, 'quest'));
  perform pg_temp.qst199_assert_isolated('public.missions', pg_temp.qst199_id(v_a, 'mission'), pg_temp.qst199_id(v_b, 'mission'));
  perform pg_temp.qst199_assert_isolated('public.tasks', pg_temp.qst199_id(v_a, 'task'), pg_temp.qst199_id(v_b, 'task'));
  perform pg_temp.qst199_assert_isolated('public.trails', pg_temp.qst199_id(v_a, 'trail'), pg_temp.qst199_id(v_b, 'trail'));
  perform pg_temp.qst199_assert_isolated('public.arc_memories', pg_temp.qst199_id(v_a, 'memory'), pg_temp.qst199_id(v_b, 'memory'));
  perform pg_temp.qst199_assert_isolated('public.media', pg_temp.qst199_id(v_a, 'media'), pg_temp.qst199_id(v_b, 'media'));
  perform pg_temp.qst199_assert_isolated('public.route_versions', pg_temp.qst199_id(v_a, 'route'), pg_temp.qst199_id(v_b, 'route'));
  update public.quests set title = 'Cross-account write' where id = pg_temp.qst199_id(v_b, 'quest');
  get diagnostics v_changed = row_count;
  if v_changed <> 0 then raise exception 'QST-199 cross-account Quest update succeeded'; end if;
end;
$check_a$;

select set_config('request.jwt.claim.sub', current_setting('qst199.user_b'), true);
do $check_b$
declare
  v_a uuid := current_setting('qst199.user_a')::uuid;
  v_b uuid := current_setting('qst199.user_b')::uuid;
begin
  perform pg_temp.qst199_assert_isolated('public.quests', pg_temp.qst199_id(v_b, 'quest'), pg_temp.qst199_id(v_a, 'quest'));
  perform pg_temp.qst199_assert_isolated('public.missions', pg_temp.qst199_id(v_b, 'mission'), pg_temp.qst199_id(v_a, 'mission'));
  perform pg_temp.qst199_assert_isolated('public.tasks', pg_temp.qst199_id(v_b, 'task'), pg_temp.qst199_id(v_a, 'task'));
  perform pg_temp.qst199_assert_isolated('public.trails', pg_temp.qst199_id(v_b, 'trail'), pg_temp.qst199_id(v_a, 'trail'));
  perform pg_temp.qst199_assert_isolated('public.arc_memories', pg_temp.qst199_id(v_b, 'memory'), pg_temp.qst199_id(v_a, 'memory'));
  perform pg_temp.qst199_assert_isolated('public.media', pg_temp.qst199_id(v_b, 'media'), pg_temp.qst199_id(v_a, 'media'));
  perform pg_temp.qst199_assert_isolated('public.route_versions', pg_temp.qst199_id(v_b, 'route'), pg_temp.qst199_id(v_a, 'route'));
end;
$check_b$;

reset role;
do $verify$
begin
  if exists (
    select 1 from public.quests
    where id = pg_temp.qst199_id(current_setting('qst199.user_b')::uuid, 'quest')
      and title = 'Cross-account write'
  ) then raise exception 'QST-199 other owner Quest changed'; end if;
end;
$verify$;

rollback;

select 'QST-199 hosted owner isolation passed' as result;
