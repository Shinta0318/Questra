create table if not exists public.mission_plan_feedback (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  quest_id uuid not null references public.quests(id) on delete cascade,
  mission_id uuid not null references public.missions(id) on delete cascade,
  reason text not null check (reason in ('useful','notForMe','tooAbstract','tooHard','tooEasy','wrongOrder','alreadyDone','unnecessary','outdated','preferAnotherWay')),
  generation_version text not null check (char_length(generation_version) between 1 and 80),
  created_at timestamptz not null default now()
);

alter table public.mission_plan_feedback enable row level security;
create policy "Owners manage Mission plan feedback"
  on public.mission_plan_feedback for all
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

create index if not exists mission_plan_feedback_owner_created_idx
  on public.mission_plan_feedback (owner_id, created_at desc);
