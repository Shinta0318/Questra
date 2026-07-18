alter table if exists public.user_profiles
  add column if not exists has_seen_onboarding_tour boolean not null default false;
