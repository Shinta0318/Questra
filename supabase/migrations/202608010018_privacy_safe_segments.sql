begin;

create table public.segment_definitions (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  version integer not null default 1,
  allowed_dimensions jsonb not null,
  minimum_cohort_size integer not null default 10 check (minimum_cohort_size >= 10),
  sensitivity_policy text not null default 'exclude_restricted',
  active boolean not null default true,
  unique (name, version)
);

create table public.segment_snapshots (
  id uuid primary key default gen_random_uuid(),
  segment_definition_id uuid not null references public.segment_definitions(id) on delete cascade,
  dimension_values jsonb not null,
  cohort_size integer not null check (cohort_size >= 10),
  metrics jsonb not null,
  generated_at timestamptz not null default now(),
  expires_at timestamptz not null,
  consent_version integer not null
);

create table public.segment_access_audit (
  id uuid primary key default gen_random_uuid(),
  business_account_id uuid references public.business_accounts(id) on delete cascade,
  segment_snapshot_id uuid not null references public.segment_snapshots(id) on delete cascade,
  accessed_at timestamptz not null default now(),
  query_fingerprint text not null
);

alter table public.segment_definitions enable row level security;
alter table public.segment_snapshots enable row level security;
alter table public.segment_access_audit enable row level security;
-- Client access is intentionally absent. Approved server-side jobs create and expose snapshots.

comment on table public.segment_snapshots is
  'K-anonymous expiring aggregate snapshots. Raw Quest, Mission, Arc chat, Arc Memory, PII, and sensitive attributes are prohibited.';

commit;
