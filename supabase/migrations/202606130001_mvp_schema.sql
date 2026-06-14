create extension if not exists "pgcrypto";
create extension if not exists vector;

create table if not exists public.user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nickname text not null,
  avatar_url text,
  onboarding_completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.quests (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.user_profiles(id) on delete cascade,
  title text not null,
  description text,
  difficulty text not null default 'normal',
  status text not null default 'draft',
  visibility text not null default 'private',
  target_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint quests_difficulty_check check (difficulty in ('easy', 'normal', 'hard', 'legendary')),
  constraint quests_status_check check (status in ('draft', 'active', 'completed', 'archived')),
  constraint quests_visibility_check check (visibility in ('private', 'guild', 'public'))
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
  title text not null,
  summary text not null default '',
  content text not null default '',
  trail_type text not null default 'quest_record',
  source_type text not null default 'trail',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint trails_trail_type_check check (
    trail_type in ('quest_record', 'mission_record', 'arc_reflection', 'manual_note')
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
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
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

alter table public.user_profiles enable row level security;
alter table public.quests enable row level security;
alter table public.missions enable row level security;
alter table public.trails enable row level security;
alter table public.trail_events enable row level security;
alter table public.guilds enable row level security;
alter table public.arc_memories enable row level security;
alter table public.analytics_events enable row level security;
alter table public.reports enable row level security;
alter table public.user_blocks enable row level security;
