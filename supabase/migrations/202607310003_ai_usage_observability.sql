-- QST-206: metadata only. Raw prompts, responses, and model secrets are never stored.
create table if not exists public.ai_usage_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  feature text not null check (char_length(feature) between 1 and 80),
  prompt_version text not null check (char_length(prompt_version) between 1 and 80),
  provider text not null check (provider in ('gemini', 'openai')),
  model_name text not null check (char_length(model_name) between 1 and 120),
  outcome text not null check (outcome in ('succeeded', 'fallback')),
  latency_ms integer not null check (latency_ms between 0 and 60000),
  input_chars integer not null default 0 check (input_chars between 0 and 40000),
  output_chars integer not null default 0 check (output_chars between 0 and 40000),
  input_tokens integer check (input_tokens is null or input_tokens between 0 and 200000),
  output_tokens integer check (output_tokens is null or output_tokens between 0 and 200000),
  estimated_cost_micros bigint check (estimated_cost_micros is null or estimated_cost_micros >= 0),
  created_at timestamptz not null default now()
);

create index if not exists ai_usage_events_feature_created_at_idx
  on public.ai_usage_events (feature, created_at desc);
create index if not exists ai_usage_events_user_created_at_idx
  on public.ai_usage_events (user_id, created_at desc)
  where user_id is not null;

alter table public.ai_usage_events enable row level security;

create policy "Users can view their own AI usage metadata"
  on public.ai_usage_events for select
  using (auth.uid() = user_id);

-- Only the service-role key used by trusted Edge Functions writes telemetry.
revoke all on public.ai_usage_events from anon, authenticated;
grant select on public.ai_usage_events to authenticated;
