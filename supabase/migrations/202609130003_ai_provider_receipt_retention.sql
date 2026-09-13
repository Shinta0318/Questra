begin;

create table if not exists public.ai_evidence_retention_policies (
  policy_version text primary key check (char_length(policy_version) between 3 and 80),
  status text not null check (status in ('active', 'retired')),
  receipt_days integer not null check (receipt_days between 1 and 3650),
  attempt_days integer not null check (attempt_days between 1 and 3650),
  resolved_case_days integer not null check (resolved_case_days between 1 and 3650),
  audit_days integer not null check (audit_days between 30 and 3650),
  rationale text not null check (char_length(rationale) between 10 and 500),
  effective_from timestamptz not null,
  created_at timestamptz not null default now()
);

create unique index if not exists ai_evidence_retention_one_active_idx
  on public.ai_evidence_retention_policies (status)
  where status = 'active';

insert into public.ai_evidence_retention_policies (
  policy_version,
  status,
  receipt_days,
  attempt_days,
  resolved_case_days,
  audit_days,
  rationale,
  effective_from
) values (
  '2026-09-13.v1',
  'active',
  90,
  180,
  365,
  730,
  'Keep billing recovery evidence only for reconciliation, dispute, and security review.',
  timestamptz '2026-09-13 00:00:00+00'
) on conflict (policy_version) do nothing;

create or replace function public.protect_ai_evidence_retention_policy_history()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if old.effective_from <= now() then
    if tg_op = 'DELETE' then
      raise exception 'effective_ai_evidence_retention_policy_is_immutable';
    end if;
    if row(
      old.receipt_days,
      old.attempt_days,
      old.resolved_case_days,
      old.audit_days,
      old.rationale,
      old.effective_from
    ) is distinct from row(
      new.receipt_days,
      new.attempt_days,
      new.resolved_case_days,
      new.audit_days,
      new.rationale,
      new.effective_from
    ) then
      raise exception 'effective_ai_evidence_retention_policy_is_immutable';
    end if;
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

drop trigger if exists protect_ai_evidence_retention_policy_history
  on public.ai_evidence_retention_policies;
create trigger protect_ai_evidence_retention_policy_history
before update or delete on public.ai_evidence_retention_policies
for each row execute function public.protect_ai_evidence_retention_policy_history();

alter table public.ai_provider_execution_receipts
  add column if not exists retention_policy_version text,
  add column if not exists retention_until timestamptz,
  add column if not exists legal_hold_until timestamptz,
  add column if not exists legal_hold_reason text;

alter table public.ai_budget_reconciliation_attempts
  add column if not exists retention_policy_version text,
  add column if not exists retention_until timestamptz,
  add column if not exists legal_hold_until timestamptz,
  add column if not exists legal_hold_reason text;

alter table public.ai_budget_reconciliation_cases
  add column if not exists retention_policy_version text,
  add column if not exists retention_until timestamptz,
  add column if not exists legal_hold_until timestamptz,
  add column if not exists legal_hold_reason text;

update public.ai_provider_execution_receipts
set retention_policy_version = coalesce(retention_policy_version, '2026-09-13.v1'),
    retention_until = coalesce(retention_until, recorded_at + interval '90 days');

update public.ai_budget_reconciliation_attempts
set retention_policy_version = coalesce(retention_policy_version, '2026-09-13.v1'),
    retention_until = coalesce(retention_until, attempted_at + interval '180 days');

update public.ai_budget_reconciliation_cases
set retention_policy_version = coalesce(retention_policy_version, '2026-09-13.v1'),
    retention_until = case
      when status = 'open' then null
      else coalesce(
        retention_until,
        coalesce(resolved_at, opened_at) + interval '365 days'
      )
    end;

alter table public.ai_provider_execution_receipts
  alter column retention_policy_version set default '2026-09-13.v1',
  alter column retention_policy_version set not null,
  alter column retention_until set default (now() + interval '90 days'),
  alter column retention_until set not null,
  add constraint ai_provider_receipt_hold_check check (
    (legal_hold_until is null and legal_hold_reason is null)
    or (
      legal_hold_until is not null
      and legal_hold_reason in ('billing_dispute', 'security_incident', 'legal_request')
    )
  );

alter table public.ai_budget_reconciliation_attempts
  alter column retention_policy_version set default '2026-09-13.v1',
  alter column retention_policy_version set not null,
  alter column retention_until set default (now() + interval '180 days'),
  alter column retention_until set not null,
  add constraint ai_budget_reconciliation_attempt_hold_check check (
    (legal_hold_until is null and legal_hold_reason is null)
    or (
      legal_hold_until is not null
      and legal_hold_reason in ('billing_dispute', 'security_incident', 'legal_request')
    )
  );

alter table public.ai_budget_reconciliation_cases
  alter column retention_policy_version set default '2026-09-13.v1',
  alter column retention_policy_version set not null,
  add constraint ai_budget_reconciliation_case_retention_check check (
    (status = 'open' and retention_until is null)
    or (status in ('resolved', 'dismissed') and retention_until is not null)
  ),
  add constraint ai_budget_reconciliation_case_hold_check check (
    (legal_hold_until is null and legal_hold_reason is null)
    or (
      legal_hold_until is not null
      and legal_hold_reason in ('billing_dispute', 'security_incident', 'legal_request')
    )
  );

alter table public.ai_provider_execution_receipts
  add constraint ai_provider_receipt_retention_policy_fk foreign key (
    retention_policy_version
  ) references public.ai_evidence_retention_policies(policy_version);
alter table public.ai_budget_reconciliation_attempts
  add constraint ai_budget_attempt_retention_policy_fk foreign key (
    retention_policy_version
  ) references public.ai_evidence_retention_policies(policy_version);
alter table public.ai_budget_reconciliation_cases
  add constraint ai_budget_case_retention_policy_fk foreign key (
    retention_policy_version
  ) references public.ai_evidence_retention_policies(policy_version);

create index if not exists ai_provider_receipt_retention_idx
  on public.ai_provider_execution_receipts (retention_until);
create index if not exists ai_budget_attempt_retention_idx
  on public.ai_budget_reconciliation_attempts (retention_until);
create index if not exists ai_budget_case_retention_idx
  on public.ai_budget_reconciliation_cases (retention_until)
  where status in ('resolved', 'dismissed');

create or replace function public.set_ai_evidence_row_retention()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_policy public.ai_evidence_retention_policies%rowtype;
begin
  select * into v_policy
  from public.ai_evidence_retention_policies
  where status = 'active'
    and effective_from <= now()
  order by effective_from desc
  limit 1;
  if not found then raise exception 'ai_evidence_retention_policy_missing'; end if;
  new.retention_policy_version := v_policy.policy_version;
  if tg_table_name = 'ai_provider_execution_receipts' then
    new.retention_until := new.recorded_at + make_interval(days => v_policy.receipt_days);
  elsif tg_table_name = 'ai_budget_reconciliation_attempts' then
    new.retention_until := new.attempted_at + make_interval(days => v_policy.attempt_days);
  else
    raise exception 'unsupported_ai_evidence_retention_table';
  end if;
  return new;
end;
$$;

drop trigger if exists set_ai_provider_receipt_retention
  on public.ai_provider_execution_receipts;
create trigger set_ai_provider_receipt_retention
before insert on public.ai_provider_execution_receipts
for each row execute function public.set_ai_evidence_row_retention();

drop trigger if exists set_ai_budget_attempt_retention
  on public.ai_budget_reconciliation_attempts;
create trigger set_ai_budget_attempt_retention
before insert on public.ai_budget_reconciliation_attempts
for each row execute function public.set_ai_evidence_row_retention();

create or replace function public.set_ai_reconciliation_case_retention()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_policy public.ai_evidence_retention_policies%rowtype;
begin
  select * into v_policy
  from public.ai_evidence_retention_policies
  where status = 'active'
    and effective_from <= now()
  order by effective_from desc
  limit 1;
  if not found then raise exception 'ai_evidence_retention_policy_missing'; end if;
  new.retention_policy_version := v_policy.policy_version;
  if new.status = 'open' then
    new.retention_until := null;
  else
    new.resolved_at := coalesce(new.resolved_at, now());
    new.retention_until := new.resolved_at + make_interval(days => v_policy.resolved_case_days);
  end if;
  return new;
end;
$$;

drop trigger if exists set_ai_reconciliation_case_retention
  on public.ai_budget_reconciliation_cases;
create trigger set_ai_reconciliation_case_retention
before insert or update of status on public.ai_budget_reconciliation_cases
for each row execute function public.set_ai_reconciliation_case_retention();

create table if not exists public.ai_evidence_retention_runs (
  id uuid primary key default gen_random_uuid(),
  policy_version text not null,
  run_reason text not null check (run_reason in (
    'scheduled_retention', 'manual_privacy_drill', 'account_cleanup'
  )),
  receipts_deleted integer not null check (receipts_deleted >= 0),
  attempts_deleted integer not null check (attempts_deleted >= 0),
  cases_deleted integer not null check (cases_deleted >= 0),
  rows_held integer not null check (rows_held >= 0),
  old_audits_deleted integer not null check (old_audits_deleted >= 0),
  executed_at timestamptz not null default now(),
  retention_until timestamptz not null default (now() + interval '730 days')
);

alter table public.ai_evidence_retention_policies enable row level security;
alter table public.ai_evidence_retention_runs enable row level security;
revoke all on public.ai_evidence_retention_policies from anon, authenticated;
revoke all on public.ai_evidence_retention_runs from anon, authenticated;

create or replace function public.set_ai_budget_evidence_legal_hold(
  p_reservation_id uuid,
  p_hold_until timestamptz,
  p_reason text
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service_role_required';
  end if;
  if not exists (
    select 1 from public.ai_budget_reservations where id = p_reservation_id
  ) then
    raise exception 'ai_reservation_not_found';
  end if;
  if p_hold_until is null then
    if p_reason is not null then raise exception 'hold_reason_without_expiry'; end if;
  elsif p_hold_until <= now()
    or p_hold_until > now() + interval '10 years'
    or p_reason not in ('billing_dispute', 'security_incident', 'legal_request') then
    raise exception 'invalid_evidence_hold';
  end if;

  update public.ai_provider_execution_receipts
  set legal_hold_until = p_hold_until,
      legal_hold_reason = p_reason
  where reservation_id = p_reservation_id;
  update public.ai_budget_reconciliation_attempts
  set legal_hold_until = p_hold_until,
      legal_hold_reason = p_reason
  where reservation_id = p_reservation_id;
  update public.ai_budget_reconciliation_cases
  set legal_hold_until = p_hold_until,
      legal_hold_reason = p_reason
  where reservation_id = p_reservation_id;

  return jsonb_build_object(
    'updated', true,
    'hold_active', p_hold_until is not null
  );
end;
$$;

create or replace function public.purge_expired_ai_budget_evidence(
  p_limit integer default 1000,
  p_run_reason text default 'scheduled_retention'
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_policy public.ai_evidence_retention_policies%rowtype;
  v_receipts_deleted integer := 0;
  v_attempts_deleted integer := 0;
  v_cases_deleted integer := 0;
  v_rows_held integer := 0;
  v_old_audits_deleted integer := 0;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_limit not between 1 and 10000 then
    raise exception 'invalid_retention_batch_limit';
  end if;
  if p_run_reason not in (
    'scheduled_retention', 'manual_privacy_drill', 'account_cleanup'
  ) then
    raise exception 'invalid_retention_run_reason';
  end if;
  select * into v_policy
  from public.ai_evidence_retention_policies
  where status = 'active'
    and effective_from <= now()
  order by effective_from desc
  limit 1;
  if not found then raise exception 'ai_evidence_retention_policy_missing'; end if;

  select
    (select count(*) from (
       select 1
       from public.ai_provider_execution_receipts receipt
       where receipt.retention_until <= now()
         and (
           receipt.legal_hold_until > now()
           or exists (
             select 1 from public.ai_budget_reconciliation_cases review
             where review.reservation_id = receipt.reservation_id
               and review.status = 'open'
           )
         )
       limit p_limit
     ) as held_receipts)
    + (select count(*) from (
         select 1
         from public.ai_budget_reconciliation_attempts attempt
         where attempt.retention_until <= now()
           and (
             attempt.legal_hold_until > now()
             or exists (
               select 1 from public.ai_budget_reconciliation_cases review
               where review.reservation_id = attempt.reservation_id
                 and review.status = 'open'
             )
           )
         limit p_limit
       ) as held_attempts)
    + (select count(*) from (
         select 1
         from public.ai_budget_reconciliation_cases review
         where review.status in ('resolved', 'dismissed')
           and review.retention_until <= now()
           and review.legal_hold_until > now()
         limit p_limit
       ) as held_cases)
  into v_rows_held;

  with expired as (
    select receipt.reservation_id
    from public.ai_provider_execution_receipts receipt
    where receipt.retention_until <= now()
      and (receipt.legal_hold_until is null or receipt.legal_hold_until <= now())
      and not exists (
        select 1 from public.ai_budget_reconciliation_cases review
        where review.reservation_id = receipt.reservation_id
          and review.status = 'open'
      )
    order by receipt.retention_until
    for update skip locked
    limit p_limit
  )
  delete from public.ai_provider_execution_receipts receipt
  using expired
  where receipt.reservation_id = expired.reservation_id;
  get diagnostics v_receipts_deleted = row_count;

  with expired as (
    select attempt.id
    from public.ai_budget_reconciliation_attempts attempt
    where attempt.retention_until <= now()
      and (attempt.legal_hold_until is null or attempt.legal_hold_until <= now())
      and not exists (
        select 1 from public.ai_budget_reconciliation_cases review
        where review.reservation_id = attempt.reservation_id
          and review.status = 'open'
      )
    order by attempt.retention_until
    for update skip locked
    limit p_limit
  )
  delete from public.ai_budget_reconciliation_attempts attempt
  using expired
  where attempt.id = expired.id;
  get diagnostics v_attempts_deleted = row_count;

  with expired as (
    select review.reservation_id
    from public.ai_budget_reconciliation_cases review
    where review.status in ('resolved', 'dismissed')
      and review.retention_until <= now()
      and (review.legal_hold_until is null or review.legal_hold_until <= now())
    order by review.retention_until
    for update skip locked
    limit p_limit
  )
  delete from public.ai_budget_reconciliation_cases review
  using expired
  where review.reservation_id = expired.reservation_id;
  get diagnostics v_cases_deleted = row_count;

  with expired as (
    select id
    from public.ai_evidence_retention_runs
    where retention_until <= now()
    order by retention_until
    for update skip locked
    limit p_limit
  )
  delete from public.ai_evidence_retention_runs audit
  using expired
  where audit.id = expired.id;
  get diagnostics v_old_audits_deleted = row_count;

  insert into public.ai_evidence_retention_runs (
    policy_version,
    run_reason,
    receipts_deleted,
    attempts_deleted,
    cases_deleted,
    rows_held,
    old_audits_deleted,
    retention_until
  ) values (
    v_policy.policy_version,
    p_run_reason,
    v_receipts_deleted,
    v_attempts_deleted,
    v_cases_deleted,
    v_rows_held,
    v_old_audits_deleted,
    now() + make_interval(days => v_policy.audit_days)
  );

  return jsonb_build_object(
    'policy_version', v_policy.policy_version,
    'run_reason', p_run_reason,
    'receipts_deleted', v_receipts_deleted,
    'attempts_deleted', v_attempts_deleted,
    'cases_deleted', v_cases_deleted,
    'rows_held', v_rows_held,
    'old_audits_deleted', v_old_audits_deleted
  );
end;
$$;

revoke all on function public.set_ai_reconciliation_case_retention() from public;
revoke all on function public.set_ai_evidence_row_retention() from public;
revoke all on function public.protect_ai_evidence_retention_policy_history()
  from public;
revoke all on function public.set_ai_budget_evidence_legal_hold(
  uuid, timestamptz, text
) from public;
revoke all on function public.purge_expired_ai_budget_evidence(integer, text)
  from public;
grant execute on function public.set_ai_budget_evidence_legal_hold(
  uuid, timestamptz, text
) to service_role;
grant execute on function public.purge_expired_ai_budget_evidence(integer, text)
  to service_role;

commit;
