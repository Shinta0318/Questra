\set ON_ERROR_STOP on

begin;

do $$
declare
  target regprocedure;
  body text;
begin
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
    'public.purge_expired_runtime_evidence(integer)'::regprocedure,
    'public.claim_runtime_evidence_alert(uuid)'::regprocedure,
    'public.purge_runtime_evidence_event(uuid)'::regprocedure
  ] loop
    select function_row.prosrc into body
    from pg_catalog.pg_proc function_row
    where function_row.oid = target::oid;
    if body is null
       or position('auth.role() <> ''service_role''' in body) > 0
       or position('auth.role() is distinct from ''service_role''' in body) = 0 then
      raise exception 'Operator role guard is not null-safe: %', target;
    end if;
  end loop;
end;
$$;

create function pg_temp.assert_operator_denied(statement text, label text)
returns void language plpgsql as $$
declare rejected boolean := false;
begin
  begin
    execute statement;
  exception when others then
    rejected := true;
  end;
  if not rejected then
    raise exception 'Operator call was allowed: %', label;
  end if;
end;
$$;

set local role authenticated;
select set_config('request.jwt.claim.role', '', true);
select pg_temp.assert_operator_denied(
  'select public.get_data_rights_fulfillment_metrics()', 'Data Rights metrics without JWT role');
select pg_temp.assert_operator_denied(
  'select public.get_runtime_slo_window(now())', 'runtime SLO without JWT role');

select set_config('request.jwt.claim.role', 'authenticated', true);
select pg_temp.assert_operator_denied(
  'select public.get_data_rights_fulfillment_metrics()', 'Data Rights metrics as authenticated');
select pg_temp.assert_operator_denied(
  'select public.get_runtime_slo_window(now())', 'runtime SLO as authenticated');

rollback;

\echo 'Operator RPC role guards reject missing and authenticated JWT roles'
