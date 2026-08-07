create table if not exists public.weekly_availability (
  user_id uuid primary key references auth.users(id) on delete cascade,
  monday_minutes integer not null default 0 check (monday_minutes between 0 and 1440),
  tuesday_minutes integer not null default 0 check (tuesday_minutes between 0 and 1440),
  wednesday_minutes integer not null default 0 check (wednesday_minutes between 0 and 1440),
  thursday_minutes integer not null default 0 check (thursday_minutes between 0 and 1440),
  friday_minutes integer not null default 0 check (friday_minutes between 0 and 1440),
  saturday_minutes integer not null default 0 check (saturday_minutes between 0 and 1440),
  sunday_minutes integer not null default 0 check (sunday_minutes between 0 and 1440),
  updated_at timestamptz not null default now()
);

alter table public.weekly_availability enable row level security;
create policy "Users manage their own availability"
  on public.weekly_availability for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
