begin;

do $$
declare
  target regprocedure;
  definition text;
  original_guard constant text := 'auth.role() <> ''service_role''';
  safe_guard constant text := 'auth.role() is distinct from ''service_role''';
  guard_count integer;
  is_definer boolean;
  function_language name;
begin
  -- These committed functions were never deployed to Beta, but the additive
  -- migration also repairs environments that already applied their originals.
  foreach target in array array[
    'public.claim_scheduled_account_deletions(integer)'::regprocedure,
    'public.fulfill_pending_consent_withdrawals(integer)'::regprocedure,
    'public.claim_pending_correction_requests(integer)'::regprocedure,
    'public.claim_data_correction_request(uuid)'::regprocedure,
    'public.fulfill_consent_withdrawal_request(uuid)'::regprocedure,
    'public.claim_account_deletion_request(uuid)'::regprocedure,
    'public.resolve_data_correction_request(uuid,text)'::regprocedure,
    'public.resolve_account_deletion_worker(uuid,boolean,text)'::regprocedure,
    'public.get_data_rights_fulfillment_metrics()'::regprocedure,
    'public.claim_runtime_evidence_alerts(integer)'::regprocedure,
    'public.resolve_runtime_evidence_alert(uuid,text)'::regprocedure,
    'public.get_runtime_slo_window(timestamp with time zone)'::regprocedure,
    'public.purge_expired_runtime_evidence(integer)'::regprocedure
  ] loop
    select function_row.prosecdef, language_row.lanname
    into is_definer, function_language
    from pg_catalog.pg_proc function_row
    join pg_catalog.pg_language language_row on language_row.oid = function_row.prolang
    where function_row.oid = target::oid;
    if not found or not is_definer or function_language <> 'plpgsql' then
      raise exception 'Unexpected operator function contract: %', target;
    end if;

    definition := pg_catalog.pg_get_functiondef(target::oid);
    guard_count := (length(definition) - length(replace(definition, original_guard, '')))
      / length(original_guard);
    if guard_count <> 1 then
      raise exception 'Expected exactly one vulnerable role guard in %, found %', target, guard_count;
    end if;

    execute replace(definition, original_guard, safe_guard);
    definition := pg_catalog.pg_get_functiondef(target::oid);
    if position(original_guard in definition) > 0
       or position(safe_guard in definition) = 0 then
      raise exception 'Role guard replacement did not persist for %', target;
    end if;
  end loop;
end;
$$;

commit;
