alter table public.missions
  add column if not exists progress_percent integer not null default 0;

alter table public.missions
  drop constraint if exists missions_progress_percent_check;

alter table public.missions
  add constraint missions_progress_percent_check
  check (progress_percent between 0 and 100);

update public.missions
set progress_percent = 100
where status = 'completed' and progress_percent = 0;

create table if not exists public.quest_planning_feedback (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  quest_id uuid not null references public.quests(id) on delete cascade,
  category_key text not null,
  source_type text not null,
  generated_count integer not null,
  accepted_count integer not null,
  edited_count integer not null default 0,
  target_window text not null default 'unspecified',
  created_at timestamptz not null default now(),
  constraint quest_planning_feedback_counts_check check (
    generated_count between 1 and 20 and
    accepted_count between 0 and generated_count and
    edited_count between 0 and accepted_count
  )
);

create index if not exists quest_planning_feedback_owner_category_idx
  on public.quest_planning_feedback (owner_id, category_key, created_at desc);

alter table public.quest_planning_feedback enable row level security;

create policy "Owners read planning feedback"
  on public.quest_planning_feedback for select
  using (auth.uid() = owner_id);

create policy "Owners create planning feedback"
  on public.quest_planning_feedback for insert
  with check (
    auth.uid() = owner_id and exists (
      select 1 from public.quests q
      where q.id = quest_id and q.owner_id = auth.uid()
    )
  );

comment on table public.quest_planning_feedback is
  'Owner-scoped aggregate plan outcomes. Raw consultation text is intentionally excluded.';
