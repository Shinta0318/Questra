create table if not exists public.mission_source_references (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  mission_id uuid not null references public.missions(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 200),
  source_url text not null check (source_url ~ '^https://'),
  publisher text not null check (char_length(publisher) between 1 and 160),
  checked_at timestamptz not null,
  recheck_after timestamptz,
  is_official boolean not null default false,
  created_at timestamptz not null default now(),
  constraint source_recheck_order check (recheck_after is null or recheck_after > checked_at)
);

alter table public.mission_source_references enable row level security;
create policy "Owners manage Mission sources"
  on public.mission_source_references for all
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

create index if not exists mission_source_references_mission_idx
  on public.mission_source_references (mission_id, checked_at desc);
