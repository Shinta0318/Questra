-- Run only against the isolated validation project. The transaction leaves no data.
begin;

do $$
declare
  v_owner uuid := gen_random_uuid();
  v_other uuid := gen_random_uuid();
  v_quest uuid := gen_random_uuid();
  v_policy record;
  v_output jsonb := '{"result":"synthetic checkpoint"}'::jsonb;
begin
  select region_code, eligibility_version, terms_version,
    privacy_version, ai_disclosure_version
    into v_policy
  from public.legal_release_policies
  where region_code = 'JP' and active
  limit 1;
  if not found then raise exception 'validation_legal_policy_missing'; end if;

  insert into auth.users (
    id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at, raw_user_meta_data
  ) values
    (v_owner, 'authenticated', 'authenticated',
      'checkpoint-' || v_owner::text || '@example.test', 'fixture',
      now(), now(), now(), jsonb_build_object(
        'region_code', v_policy.region_code,
        'minimum_age_confirmed', true,
        'eligibility_version', v_policy.eligibility_version,
        'terms_version', v_policy.terms_version,
        'privacy_version', v_policy.privacy_version,
        'ai_disclosure_version', v_policy.ai_disclosure_version
      )),
    (v_other, 'authenticated', 'authenticated',
      'checkpoint-' || v_other::text || '@example.test', 'fixture',
      now(), now(), now(), jsonb_build_object(
        'region_code', v_policy.region_code,
        'minimum_age_confirmed', true,
        'eligibility_version', v_policy.eligibility_version,
        'terms_version', v_policy.terms_version,
        'privacy_version', v_policy.privacy_version,
        'ai_disclosure_version', v_policy.ai_disclosure_version
      ));

  insert into public.quests (id, owner_id, title, description, status, visibility)
  values (v_quest, v_owner, 'Checkpoint validation Quest',
    'Synthetic transaction-only fixture', 'active', 'private');

  insert into public.quest_planning_pass_checkpoints (
    owner_id, quest_id, pass_name, input_fingerprint,
    output, provider_metadata, expires_at
  ) values (
    v_owner, v_quest, 'quest_planning.quest_understanding',
    repeat('a', 64), v_output,
    '{"provider":"gemini","model":"synthetic"}'::jsonb,
    now() + interval '1 hour'
  );

  if not exists (
    select 1 from public.quest_planning_pass_checkpoints
    where owner_id = v_owner and quest_id = v_quest
      and input_fingerprint = repeat('a', 64)
      and output = v_output and expires_at > now()
  ) then raise exception 'checkpoint_roundtrip_failed'; end if;

  if has_table_privilege('authenticated',
      'public.quest_planning_pass_checkpoints', 'SELECT')
    or has_table_privilege('authenticated',
      'public.quest_planning_pass_checkpoints', 'INSERT')
  then raise exception 'checkpoint_client_access_allowed'; end if;

  begin
    insert into public.quest_planning_pass_checkpoints (
      owner_id, quest_id, pass_name, input_fingerprint,
      output, provider_metadata, expires_at
    ) values (
      v_other, v_quest, 'quest_planning.quest_understanding',
      repeat('b', 64), v_output, '{}'::jsonb,
      now() + interval '1 hour'
    );
    raise exception 'checkpoint_cross_owner_write_allowed';
  exception
    when sqlstate '23514' then null;
  end;
end;
$$;

rollback;
