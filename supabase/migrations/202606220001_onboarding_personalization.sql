alter table public.user_profiles
  add column if not exists arc_name text not null default 'Arc',
  add column if not exists quest_interest text not null default 'adventure',
  add column if not exists signal_frequency text not null default 'balanced';

alter table public.user_profiles
  drop constraint if exists user_profiles_quest_interest_check,
  add constraint user_profiles_quest_interest_check check (
    quest_interest in ('adventure', 'learning', 'health', 'work', 'family', 'challenge')
  );

alter table public.user_profiles
  drop constraint if exists user_profiles_signal_frequency_check,
  add constraint user_profiles_signal_frequency_check check (
    signal_frequency in ('quiet', 'balanced', 'frequent')
  );
