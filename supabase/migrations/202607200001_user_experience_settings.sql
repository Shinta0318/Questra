create table if not exists public.user_experience_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  arc_motion_level text not null default 'reduced'
    check (arc_motion_level in ('full', 'reduced', 'off')),
  haptics_enabled boolean not null default true,
  sound_effects_enabled boolean not null default false,
  completion_effect_level text not null default 'full'
    check (completion_effect_level in ('full', 'simple', 'off')),
  motion_preference text not null default 'standard'
    check (motion_preference in ('standard', 'reduced')),
  swipe_gestures_enabled boolean not null default true,
  power_saving_mode boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.user_experience_settings enable row level security;

revoke all on table public.user_experience_settings from anon, public;
grant select, insert, update, delete on table public.user_experience_settings
  to authenticated;

drop policy if exists "experience settings owner select"
  on public.user_experience_settings;
create policy "experience settings owner select"
  on public.user_experience_settings
  for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "experience settings owner insert"
  on public.user_experience_settings;
create policy "experience settings owner insert"
  on public.user_experience_settings
  for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "experience settings owner update"
  on public.user_experience_settings;
create policy "experience settings owner update"
  on public.user_experience_settings
  for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "experience settings owner delete"
  on public.user_experience_settings;
create policy "experience settings owner delete"
  on public.user_experience_settings
  for delete to authenticated
  using (auth.uid() = user_id);
