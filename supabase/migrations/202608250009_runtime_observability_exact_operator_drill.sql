begin;

create or replace function public.claim_runtime_evidence_alert(
  p_event_row_id uuid
) returns table(
  alert_id uuid,
  severity text,
  build_version text,
  surface text,
  operation text,
  error_code text
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if auth.role() <> 'service_role' then
    raise exception 'Alert operator authorization required.';
  end if;
  return query
  with claimed as (
    update public.runtime_evidence_alert_queue queue
    set state = 'claimed', claimed_at = now()
    where queue.event_row_id = p_event_row_id and queue.state = 'pending'
    returning queue.id, queue.event_row_id, queue.severity
  )
  select claimed.id, claimed.severity, event.build_version, event.surface,
    event.operation, event.error_code
  from claimed
  join public.runtime_evidence_events event on event.id = claimed.event_row_id;
end;
$$;

create or replace function public.purge_runtime_evidence_event(
  p_event_row_id uuid
) returns boolean
language plpgsql security definer set search_path = public, pg_temp
as $$
declare
  v_deleted integer;
begin
  if auth.role() <> 'service_role' then
    raise exception 'Retention worker authorization required.';
  end if;
  delete from public.runtime_evidence_events
  where id = p_event_row_id and retention_until <= now();
  get diagnostics v_deleted = row_count;
  return v_deleted = 1;
end;
$$;

revoke all on function public.claim_runtime_evidence_alert(uuid) from public;
revoke all on function public.purge_runtime_evidence_event(uuid) from public;
grant execute on function public.claim_runtime_evidence_alert(uuid) to service_role;
grant execute on function public.purge_runtime_evidence_event(uuid) to service_role;

commit;
