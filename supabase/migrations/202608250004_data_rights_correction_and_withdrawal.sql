begin;

-- Contextual confirmation is required to grant personal sharing, never to revoke it.
create or replace function public.set_user_consent(
  p_purpose_code text, p_purpose_version integer, p_granted boolean, p_source text
) returns public.user_consents
language plpgsql security definer set search_path = public, pg_temp
as $$
declare result public.user_consents; actor_id uuid := auth.uid();
begin
  if actor_id is null then raise exception 'authentication required'; end if;
  if p_purpose_code = 'personal_data_sharing' and p_granted
     and p_source <> 'contextual_prompt' then
    raise exception 'contextual confirmation required';
  end if;
  if p_source not in ('onboarding', 'settings', 'contextual_prompt') then
    raise exception 'unsupported consent source';
  end if;
  if not exists (
    select 1 from public.consent_purposes
    where purpose_code = p_purpose_code and version = p_purpose_version
  ) then
    raise exception 'unknown consent purpose';
  end if;

  insert into public.user_consents (
    user_id, purpose_code, purpose_version, status, granted_at, withdrawn_at, source, evidence
  ) values (
    actor_id, p_purpose_code, p_purpose_version,
    case when p_granted then 'granted' else 'withdrawn' end,
    case when p_granted then now() end,
    case when not p_granted then now() end,
    p_source, jsonb_build_object('explicit_action', true)
  ) on conflict (user_id, purpose_code, purpose_version) do update set
    status = excluded.status, granted_at = excluded.granted_at,
    withdrawn_at = excluded.withdrawn_at, source = excluded.source,
    evidence = excluded.evidence, created_at = now()
  returning * into result;

  if not p_granted and p_purpose_code in (
    'business_segment_analysis', 'business_recommendations', 'personal_data_sharing'
  ) then
    delete from public.business_quest_signals where owner_id = actor_id;
  end if;
  return result;
end;
$$;

create or replace function public.submit_data_rights_request(
  p_request_type text,
  p_scope jsonb default '{}'::jsonb,
  p_idempotency_key text default null
) returns public.data_rights_requests
language plpgsql security definer set search_path = public, pg_temp
as $$
declare
  v_owner uuid := auth.uid();
  v_issued_at timestamptz;
  v_result public.data_rights_requests;
  v_scope jsonb := '{}'::jsonb;
  v_target_type text;
  v_requested_change text;
  v_purpose_code text;
begin
  if v_owner is null then raise exception 'Authentication required.'; end if;
  if p_request_type not in ('correction', 'consent_withdrawal', 'account_deletion') then
    raise exception 'Unsupported data rights request.';
  end if;
  if p_idempotency_key is null or length(trim(p_idempotency_key)) < 8 then
    raise exception 'Idempotency key is required.';
  end if;

  if p_request_type = 'correction' then
    v_target_type := nullif(trim(p_scope ->> 'target_type'), '');
    v_requested_change := nullif(trim(p_scope ->> 'requested_change'), '');
    if v_target_type not in ('profile', 'arc_memory', 'quest_dna', 'tag') then
      raise exception 'Unsupported correction target.';
    end if;
    if v_requested_change is null or length(v_requested_change) < 5
       or length(v_requested_change) > 500 then
      raise exception 'Correction detail must be between 5 and 500 characters.';
    end if;
    v_scope := jsonb_build_object(
      'target_type', v_target_type,
      'requested_change', v_requested_change
    );
  elsif p_request_type = 'consent_withdrawal' then
    v_purpose_code := nullif(trim(p_scope ->> 'purpose_code'), '');
    if not exists (
      select 1 from public.consent_purposes
      where purpose_code = v_purpose_code and version = 1
    ) then
      raise exception 'Unknown consent purpose.';
    end if;
    v_scope := jsonb_build_object('purpose_code', v_purpose_code);
  else
    v_scope := jsonb_build_object(
      'retention_exceptions', jsonb_build_array('legal', 'security_audit')
    );
  end if;

  v_issued_at := to_timestamp(coalesce((auth.jwt() ->> 'iat')::double precision, 0));
  if p_request_type = 'account_deletion' and v_issued_at < now() - interval '10 minutes' then
    raise exception 'Recent authentication required.';
  end if;
  if p_request_type = 'account_deletion' then
    select * into v_result from public.data_rights_requests
      where owner_id = v_owner and request_type = 'account_deletion'
        and status in ('scheduled', 'reviewing')
      order by submitted_at desc limit 1;
    if found then return v_result; end if;
  end if;
  select * into v_result from public.data_rights_requests
    where owner_id = v_owner and idempotency_key = trim(p_idempotency_key);
  if found then return v_result; end if;

  insert into public.data_rights_requests(
    owner_id, request_type, status, scope, reauthenticated_at,
    scheduled_for, cancellable_until, idempotency_key
  ) values (
    v_owner, p_request_type,
    case when p_request_type = 'account_deletion' then 'scheduled' else 'submitted' end,
    v_scope,
    case when p_request_type = 'account_deletion' then now() else null end,
    case when p_request_type = 'account_deletion' then now() + interval '72 hours' else null end,
    case when p_request_type = 'account_deletion' then now() + interval '72 hours' else null end,
    trim(p_idempotency_key)
  ) returning * into v_result;
  insert into public.data_rights_audit_events(owner_id, operation, scope_type, target_id)
  values (v_owner, 'rights_request_submitted', p_request_type, v_result.id);
  return v_result;
end;
$$;

revoke all on function public.set_user_consent(text, integer, boolean, text) from public;
revoke all on function public.submit_data_rights_request(text, jsonb, text) from public;
grant execute on function public.set_user_consent(text, integer, boolean, text) to authenticated;
grant execute on function public.submit_data_rights_request(text, jsonb, text) to authenticated;

commit;
