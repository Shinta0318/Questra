create extension if not exists "pgcrypto";
create extension if not exists vector;

create table if not exists public.user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nickname text not null,
  avatar_url text,
  onboarding_completed boolean not null default false,
  public_profile boolean not null default false,
  arc_level integer not null default 1,
  bond_score integer not null default 0,
  stardust_balance integer not null default 0,
  navigator_rank text not null default 'novice',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_profiles_arc_level_check check (arc_level >= 1),
  constraint user_profiles_bond_score_check check (bond_score >= 0),
  constraint user_profiles_stardust_balance_check check (stardust_balance >= 0),
  constraint user_profiles_navigator_rank_check check (
    navigator_rank in ('novice', 'pathfinder', 'stargazer', 'navigator')
  )
);

create table if not exists public.quests (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.user_profiles(id) on delete cascade,
  title text not null,
  description text,
  difficulty text not null default 'normal',
  status text not null default 'draft',
  visibility text not null default 'private',
  guild_id uuid,
  target_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint quests_difficulty_check check (difficulty in ('easy', 'normal', 'hard', 'legendary')),
  constraint quests_status_check check (status in ('draft', 'active', 'completed', 'archived')),
  constraint quests_visibility_check check (visibility in ('private', 'guild', 'public')),
  constraint quests_guild_visibility_check check (
    visibility <> 'guild' or guild_id is not null
  )
);

create table if not exists public.missions (
  id uuid primary key default gen_random_uuid(),
  quest_id uuid not null references public.quests(id) on delete cascade,
  title text not null,
  description text,
  guide_type text not null default 'route',
  difficulty text not null default 'easy',
  status text not null default 'todo',
  sort_order integer not null default 0,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint missions_guide_type_check check (
    guide_type in ('route', 'knowledge', 'training', 'guild', 'resource', 'opportunity')
  ),
  constraint missions_difficulty_check check (difficulty in ('easy', 'normal')),
  constraint missions_status_check check (status in ('todo', 'doing', 'completed'))
);

create table if not exists public.trails (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.user_profiles(id) on delete cascade,
  quest_id uuid references public.quests(id) on delete set null,
  mission_id uuid references public.missions(id) on delete set null,
  guild_id uuid,
  title text not null,
  summary text not null default '',
  content text not null default '',
  visibility text not null default 'private',
  trail_type text not null default 'quest_record',
  source_type text not null default 'trail',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint trails_trail_type_check check (
    trail_type in ('quest_record', 'mission_record', 'arc_reflection', 'manual_note')
  ),
  constraint trails_visibility_check check (
    visibility in ('private', 'guild', 'public')
  ),
  constraint trails_guild_visibility_check check (
    visibility <> 'guild' or guild_id is not null
  )
);

create table if not exists public.trail_events (
  id uuid primary key default gen_random_uuid(),
  trail_id uuid not null references public.trails(id) on delete cascade,
  quest_id uuid references public.quests(id) on delete set null,
  mission_id uuid references public.missions(id) on delete set null,
  event_type text not null default 'mission_update',
  content text not null default '',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint trail_events_event_type_check check (
    event_type in ('quest_created', 'guide_generated', 'mission_created', 'mission_completed', 'arc_reflection', 'manual_note')
  )
);

create table if not exists public.guilds (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  owner_id uuid references public.user_profiles(id) on delete set null,
  visibility text not null default 'public',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint guilds_visibility_check check (visibility in ('private', 'public'))
);

alter table public.quests
  add constraint quests_guild_id_fkey
  foreign key (guild_id) references public.guilds(id) on delete set null;

alter table public.trails
  add constraint trails_guild_id_fkey
  foreign key (guild_id) references public.guilds(id) on delete set null;

create table if not exists public.guild_members (
  id uuid primary key default gen_random_uuid(),
  guild_id uuid not null references public.guilds(id) on delete cascade,
  user_id uuid not null references public.user_profiles(id) on delete cascade,
  role text not null default 'member',
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (guild_id, user_id),
  constraint guild_members_role_check check (role in ('owner', 'admin', 'member')),
  constraint guild_members_status_check check (status in ('invited', 'active', 'blocked'))
);

create table if not exists public.business_accounts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.user_profiles(id) on delete cascade,
  name text not null,
  account_type text not null default 'business',
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint business_accounts_account_type_check check (
    account_type in ('business', 'sponsor', 'enterprise')
  ),
  constraint business_accounts_status_check check (
    status in ('active', 'suspended', 'closed')
  )
);

create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.user_profiles(id) on delete cascade,
  business_account_id uuid references public.business_accounts(id) on delete cascade,
  plan_code text not null,
  status text not null default 'inactive',
  current_period_start timestamptz,
  current_period_end timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint subscriptions_owner_check check (
    user_id is not null or business_account_id is not null
  ),
  constraint subscriptions_status_check check (
    status in ('inactive', 'trialing', 'active', 'past_due', 'canceled')
  )
);

create table if not exists public.media (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.user_profiles(id) on delete cascade,
  guild_id uuid references public.guilds(id) on delete set null,
  bucket text not null,
  path text not null,
  media_type text not null default 'image',
  related_table text,
  related_id uuid,
  visibility text not null default 'private',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (bucket, path),
  constraint media_media_type_check check (
    media_type in ('image', 'video', 'audio', 'document')
  ),
  constraint media_visibility_check check (
    visibility in ('private', 'guild', 'public')
  ),
  constraint media_guild_visibility_check check (
    visibility <> 'guild' or guild_id is not null
  )
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.user_profiles(id) on delete cascade,
  actor_id uuid references public.user_profiles(id) on delete set null,
  notification_type text not null,
  title text not null,
  body text not null default '',
  data jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.arc_memories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.user_profiles(id) on delete cascade,
  quest_id uuid references public.quests(id) on delete set null,
  mission_id uuid references public.missions(id) on delete set null,
  trail_id uuid references public.trails(id) on delete set null,
  trail_event_id uuid references public.trail_events(id) on delete set null,
  memory_type text not null default 'quest_memory',
  title text not null,
  content text not null,
  importance_score numeric(3,2) not null default 0.50,
  emotional_tone text not null default 'neutral',
  source_type text not null default 'arc_memory',
  source_id text,
  embedding vector(1536),
  metadata jsonb not null default '{}'::jsonb,
  sensitivity_level text not null default 'standard',
  user_visible boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint arc_memories_memory_type_check check (
    memory_type in (
      'quest_memory',
      'mission_memory',
      'trail_memory',
      'preference_memory',
      'emotional_memory',
      'life_event_memory',
      'arc_relationship_memory'
    )
  ),
  constraint arc_memories_importance_score_check check (
    importance_score >= 0 and importance_score <= 1
  ),
  constraint arc_memories_emotional_tone_check check (
    emotional_tone in ('neutral', 'positive', 'excited', 'supportive', 'serious', 'worried', 'lonely', 'celebratory')
  ),
  constraint arc_memories_sensitivity_level_check check (
    sensitivity_level in ('standard', 'personal', 'sensitive')
  )
);

create index if not exists arc_memories_user_created_idx
  on public.arc_memories (user_id, created_at desc);

create index if not exists arc_memories_context_idx
  on public.arc_memories (quest_id, mission_id, trail_id);

create index if not exists arc_memories_type_idx
  on public.arc_memories (memory_type);

create table if not exists public.journal_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.user_profiles(id) on delete cascade,
  related_quest_id uuid references public.quests(id) on delete set null,
  related_memory_ids uuid[] not null default '{}'::uuid[],
  related_trail_ids uuid[] not null default '{}'::uuid[],
  title text not null,
  body text not null default '',
  status text not null default 'draft',
  generated_by text not null default 'arc',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint journal_entries_status_check check (
    status in ('draft', 'generated', 'published', 'archived')
  ),
  constraint journal_entries_generated_by_check check (
    generated_by in ('arc', 'user', 'system')
  )
);

create table if not exists public.arc_letters (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.user_profiles(id) on delete cascade,
  related_quest_id uuid references public.quests(id) on delete set null,
  related_memory_ids uuid[] not null default '{}'::uuid[],
  related_trail_ids uuid[] not null default '{}'::uuid[],
  title text not null,
  body text not null default '',
  letter_type text not null default 'weekly',
  delivery_status text not null default 'draft',
  scheduled_for timestamptz,
  sent_at timestamptz,
  read_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint arc_letters_letter_type_check check (
    letter_type in ('weekly', 'monthly', 'milestone', 'manual')
  ),
  constraint arc_letters_delivery_status_check check (
    delivery_status in ('draft', 'queued', 'sent', 'read', 'failed')
  )
);

create table if not exists public.generation_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.user_profiles(id) on delete set null,
  target_type text not null,
  target_id uuid,
  source_type text not null,
  prompt_version text,
  model_name text,
  status text not null default 'queued',
  error_message text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint generation_logs_target_type_check check (
    target_type in ('arc_journal', 'arc_letter', 'arc_advice', 'mission', 'quest_guides')
  ),
  constraint generation_logs_status_check check (
    status in ('queued', 'running', 'succeeded', 'failed', 'skipped')
  )
);

create table if not exists public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.user_profiles(id) on delete set null,
  event_name text not null,
  properties jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references public.user_profiles(id) on delete set null,
  reported_user_id uuid references public.user_profiles(id) on delete set null,
  target_type text not null,
  target_id uuid,
  reason text not null,
  status text not null default 'open',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint reports_status_check check (status in ('open', 'reviewing', 'resolved', 'dismissed'))
);

create table if not exists public.user_blocks (
  blocker_id uuid not null references public.user_profiles(id) on delete cascade,
  blocked_id uuid not null references public.user_profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint user_blocks_no_self_block check (blocker_id <> blocked_id)
);

create index if not exists user_profiles_public_idx
  on public.user_profiles (public_profile);

create index if not exists quests_owner_status_idx
  on public.quests (owner_id, status);

create index if not exists quests_visibility_idx
  on public.quests (visibility);

create index if not exists quests_guild_idx
  on public.quests (guild_id);

create index if not exists missions_quest_status_idx
  on public.missions (quest_id, status);

create index if not exists trails_owner_created_idx
  on public.trails (owner_id, created_at desc);

create index if not exists trails_quest_created_idx
  on public.trails (quest_id, created_at desc);

create index if not exists trails_visibility_idx
  on public.trails (visibility);

create index if not exists trails_guild_idx
  on public.trails (guild_id);

create index if not exists trail_events_trail_created_idx
  on public.trail_events (trail_id, created_at desc);

create index if not exists guilds_owner_idx
  on public.guilds (owner_id);

create index if not exists guild_members_user_idx
  on public.guild_members (user_id, status);

create index if not exists guild_members_guild_idx
  on public.guild_members (guild_id, status);

create index if not exists business_accounts_owner_idx
  on public.business_accounts (owner_id);

create index if not exists subscriptions_user_idx
  on public.subscriptions (user_id, status);

create index if not exists subscriptions_business_account_idx
  on public.subscriptions (business_account_id, status);

create index if not exists media_owner_created_idx
  on public.media (owner_id, created_at desc);

create index if not exists media_related_idx
  on public.media (related_table, related_id);

create index if not exists notifications_user_read_idx
  on public.notifications (user_id, read_at, created_at desc);

create index if not exists journal_entries_user_created_idx
  on public.journal_entries (user_id, created_at desc);

create index if not exists arc_letters_user_status_idx
  on public.arc_letters (user_id, delivery_status, created_at desc);

create index if not exists generation_logs_target_idx
  on public.generation_logs (target_type, target_id);

create or replace function public.is_guild_member(target_guild_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.guild_members gm
    where gm.guild_id = target_guild_id
      and gm.user_id = auth.uid()
      and gm.status = 'active'
  );
$$;

create or replace function public.is_guild_owner(target_guild_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.guilds g
    where g.id = target_guild_id
      and g.owner_id = auth.uid()
  );
$$;

alter table public.user_profiles enable row level security;
alter table public.quests enable row level security;
alter table public.missions enable row level security;
alter table public.trails enable row level security;
alter table public.trail_events enable row level security;
alter table public.guilds enable row level security;
alter table public.guild_members enable row level security;
alter table public.business_accounts enable row level security;
alter table public.subscriptions enable row level security;
alter table public.media enable row level security;
alter table public.notifications enable row level security;
alter table public.arc_memories enable row level security;
alter table public.journal_entries enable row level security;
alter table public.arc_letters enable row level security;
alter table public.generation_logs enable row level security;
alter table public.analytics_events enable row level security;
alter table public.reports enable row level security;
alter table public.user_blocks enable row level security;

create policy "Profiles are visible to owner or public profiles"
  on public.user_profiles for select
  using (id = auth.uid() or public_profile = true);

create policy "Users create their own profile"
  on public.user_profiles for insert
  with check (id = auth.uid());

create policy "Users update their own profile"
  on public.user_profiles for update
  using (id = auth.uid())
  with check (id = auth.uid());

create policy "Quest visibility follows owner public or guild"
  on public.quests for select
  using (
    owner_id = auth.uid()
    or visibility = 'public'
    or (visibility = 'guild' and guild_id is not null and public.is_guild_member(guild_id))
  );

create policy "Users create their own quests"
  on public.quests for insert
  with check (
    owner_id = auth.uid()
    and (
      visibility <> 'guild'
      or (
        guild_id is not null
        and (public.is_guild_member(guild_id) or public.is_guild_owner(guild_id))
      )
    )
  );

create policy "Users update their own quests"
  on public.quests for update
  using (owner_id = auth.uid())
  with check (
    owner_id = auth.uid()
    and (
      visibility <> 'guild'
      or (
        guild_id is not null
        and (public.is_guild_member(guild_id) or public.is_guild_owner(guild_id))
      )
    )
  );

create policy "Users delete their own quests"
  on public.quests for delete
  using (owner_id = auth.uid());

create policy "Mission visibility follows related quest"
  on public.missions for select
  using (
    exists (
      select 1
      from public.quests q
      where q.id = missions.quest_id
        and (
          q.owner_id = auth.uid()
          or q.visibility = 'public'
          or (q.visibility = 'guild' and q.guild_id is not null and public.is_guild_member(q.guild_id))
        )
    )
  );

create policy "Quest owners create missions"
  on public.missions for insert
  with check (
    exists (
      select 1
      from public.quests q
      where q.id = missions.quest_id
        and q.owner_id = auth.uid()
    )
  );

create policy "Quest owners update missions"
  on public.missions for update
  using (
    exists (
      select 1
      from public.quests q
      where q.id = missions.quest_id
        and q.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from public.quests q
      where q.id = missions.quest_id
        and q.owner_id = auth.uid()
    )
  );

create policy "Quest owners delete missions"
  on public.missions for delete
  using (
    exists (
      select 1
      from public.quests q
      where q.id = missions.quest_id
        and q.owner_id = auth.uid()
    )
  );

create policy "Trail visibility follows owner public or guild"
  on public.trails for select
  using (
    owner_id = auth.uid()
    or visibility = 'public'
    or (visibility = 'guild' and guild_id is not null and public.is_guild_member(guild_id))
  );

create policy "Users create their own trails"
  on public.trails for insert
  with check (
    owner_id = auth.uid()
    and (
      visibility <> 'guild'
      or (
        guild_id is not null
        and (public.is_guild_member(guild_id) or public.is_guild_owner(guild_id))
      )
    )
  );

create policy "Users update their own trails"
  on public.trails for update
  using (owner_id = auth.uid())
  with check (
    owner_id = auth.uid()
    and (
      visibility <> 'guild'
      or (
        guild_id is not null
        and (public.is_guild_member(guild_id) or public.is_guild_owner(guild_id))
      )
    )
  );

create policy "Users delete their own trails"
  on public.trails for delete
  using (owner_id = auth.uid());

create policy "Trail event visibility follows trail"
  on public.trail_events for select
  using (
    exists (
      select 1
      from public.trails t
      where t.id = trail_events.trail_id
        and (
          t.owner_id = auth.uid()
          or t.visibility = 'public'
          or (t.visibility = 'guild' and t.guild_id is not null and public.is_guild_member(t.guild_id))
        )
    )
  );

create policy "Trail owners create trail events"
  on public.trail_events for insert
  with check (
    exists (
      select 1
      from public.trails t
      where t.id = trail_events.trail_id
        and t.owner_id = auth.uid()
    )
  );

create policy "Public guilds are discoverable"
  on public.guilds for select
  using (
    visibility = 'public'
    or owner_id = auth.uid()
    or public.is_guild_member(id)
  );

create policy "Users create owned guilds"
  on public.guilds for insert
  with check (owner_id = auth.uid());

create policy "Guild owners update guilds"
  on public.guilds for update
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy "Guild owners delete guilds"
  on public.guilds for delete
  using (owner_id = auth.uid());

create policy "Users read their own guild memberships"
  on public.guild_members for select
  using (user_id = auth.uid() or public.is_guild_owner(guild_id));

create policy "Guild owners manage memberships"
  on public.guild_members for all
  using (public.is_guild_owner(guild_id))
  with check (public.is_guild_owner(guild_id));

create policy "Business accounts are owner visible"
  on public.business_accounts for select
  using (owner_id = auth.uid());

create policy "Users create owned business accounts"
  on public.business_accounts for insert
  with check (owner_id = auth.uid());

create policy "Business account owners update accounts"
  on public.business_accounts for update
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy "Subscriptions are visible to owner"
  on public.subscriptions for select
  using (
    user_id = auth.uid()
    or exists (
      select 1
      from public.business_accounts ba
      where ba.id = subscriptions.business_account_id
        and ba.owner_id = auth.uid()
    )
  );

create policy "Media visibility follows owner public or guild"
  on public.media for select
  using (
    owner_id = auth.uid()
    or visibility = 'public'
    or (visibility = 'guild' and guild_id is not null and public.is_guild_member(guild_id))
  );

create policy "Users create their own media records"
  on public.media for insert
  with check (
    owner_id = auth.uid()
    and (
      visibility <> 'guild'
      or (
        guild_id is not null
        and (public.is_guild_member(guild_id) or public.is_guild_owner(guild_id))
      )
    )
  );

create policy "Users update their own media records"
  on public.media for update
  using (owner_id = auth.uid())
  with check (
    owner_id = auth.uid()
    and (
      visibility <> 'guild'
      or (
        guild_id is not null
        and (public.is_guild_member(guild_id) or public.is_guild_owner(guild_id))
      )
    )
  );

create policy "Users delete their own media records"
  on public.media for delete
  using (owner_id = auth.uid());

create policy "Users read their own notifications"
  on public.notifications for select
  using (user_id = auth.uid());

create policy "Users update their own notifications"
  on public.notifications for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "Arc memories are strictly owner private"
  on public.arc_memories for select
  using (user_id = auth.uid());

create policy "Users create their own Arc memories"
  on public.arc_memories for insert
  with check (user_id = auth.uid());

create policy "Users update their own Arc memories"
  on public.arc_memories for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "Users delete their own Arc memories"
  on public.arc_memories for delete
  using (user_id = auth.uid());

create policy "Users read their own journal entries"
  on public.journal_entries for select
  using (user_id = auth.uid());

create policy "Users manage their own journal entries"
  on public.journal_entries for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "Users read their own Arc letters"
  on public.arc_letters for select
  using (user_id = auth.uid());

create policy "Users update read status on own Arc letters"
  on public.arc_letters for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "Users read their own generation logs"
  on public.generation_logs for select
  using (user_id = auth.uid());

create policy "Users create their own analytics events"
  on public.analytics_events for insert
  with check (user_id = auth.uid() or user_id is null);

create policy "Users read their own analytics events"
  on public.analytics_events for select
  using (user_id = auth.uid());

create policy "Users create reports"
  on public.reports for insert
  with check (reporter_id = auth.uid());

create policy "Users read their own reports"
  on public.reports for select
  using (reporter_id = auth.uid());

create policy "Users manage their own blocks"
  on public.user_blocks for all
  using (blocker_id = auth.uid())
  with check (blocker_id = auth.uid());
