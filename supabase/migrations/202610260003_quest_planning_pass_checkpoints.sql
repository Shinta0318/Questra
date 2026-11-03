begin;

create table public.quest_planning_pass_checkpoints (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  quest_id uuid not null references public.quests(id) on delete cascade,
  pass_name text not null check (char_length(pass_name) between 1 and 100),
  input_fingerprint text not null check (input_fingerprint ~ '^[0-9a-f]{64}$'),
  output jsonb not null check (jsonb_typeof(output) = 'object'),
  provider_metadata jsonb not null check (jsonb_typeof(provider_metadata) = 'object'),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  unique (owner_id, quest_id, pass_name, input_fingerprint),
  check (expires_at > created_at and expires_at <= created_at + interval '24 hours')
);

create index quest_planning_pass_checkpoints_expiry_idx
  on public.quest_planning_pass_checkpoints (expires_at);

alter table public.quest_planning_pass_checkpoints enable row level security;
revoke all on public.quest_planning_pass_checkpoints from public, anon, authenticated;
grant select, insert, update, delete on public.quest_planning_pass_checkpoints to service_role;

-- Successful checkpoint writes opportunistically remove expired private output.
create function public.prune_quest_planning_pass_checkpoints()
returns trigger language plpgsql security definer
set search_path = pg_catalog
as $$
begin
  delete from public.quest_planning_pass_checkpoints where expires_at <= now();
  return null;
end;
$$;

create trigger prune_quest_planning_pass_checkpoints_after_write
after insert or update on public.quest_planning_pass_checkpoints
for each statement execute function public.prune_quest_planning_pass_checkpoints();

revoke all on function public.prune_quest_planning_pass_checkpoints() from public, anon, authenticated;

commit;
