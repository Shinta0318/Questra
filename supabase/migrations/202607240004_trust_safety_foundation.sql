begin;

create table if not exists public.abuse_signals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.user_profiles(id) on delete cascade,
  category text not null,
  severity integer not null check (severity between 0 and 4),
  confidence double precision not null check (confidence between 0 and 1),
  reason_code text not null,
  policy_version text not null,
  source_type text not null,
  review_status text not null default 'unreviewed'
    check (review_status in ('unreviewed', 'confirmed', 'dismissed', 'appealed')),
  created_at timestamptz not null default now()
);

create table if not exists public.account_restrictions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.user_profiles(id) on delete cascade,
  restriction_type text not null
    check (restriction_type in ('rate_limit', 'temporary', 'permanent')),
  status text not null default 'active'
    check (status in ('active', 'expired', 'revoked', 'appealed')),
  reason_code text not null,
  policy_version text not null,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  reviewed_by uuid,
  review_note text,
  created_at timestamptz not null default now(),
  constraint permanent_restriction_requires_review check (
    restriction_type <> 'permanent' or reviewed_by is not null
  )
);

create index if not exists abuse_signals_user_created_idx
  on public.abuse_signals (user_id, created_at desc);
create index if not exists account_restrictions_user_status_idx
  on public.account_restrictions (user_id, status, created_at desc);

alter table public.abuse_signals enable row level security;
alter table public.account_restrictions enable row level security;

drop policy if exists "Users insert their own abuse signals" on public.abuse_signals;
create policy "Users insert their own abuse signals"
  on public.abuse_signals for insert
  with check (user_id = auth.uid());

drop policy if exists "Users view their active restrictions" on public.account_restrictions;
create policy "Users view their active restrictions"
  on public.account_restrictions for select
  using (user_id = auth.uid());

comment on table public.abuse_signals is
  'Structured policy outcomes only. Raw Quest or Arc Chat text must not be stored here.';
comment on table public.account_restrictions is
  'Restriction decisions. Permanent restrictions require documented human review.';

commit;
