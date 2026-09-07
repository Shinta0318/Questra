begin;

-- These tables are operated only by security-definer functions or service roles.
-- RLS already denied client rows; explicit grants make that boundary auditable.
alter table public.ai_usage_policies enable row level security;
alter table public.mission_research_requests enable row level security;
alter table public.enterprise_support_proposals enable row level security;

revoke all on public.ai_usage_policies from anon, authenticated;
revoke all on public.mission_research_requests from anon, authenticated;
revoke all on public.enterprise_support_proposals from anon, authenticated;

comment on table public.ai_usage_policies is
  'Server-managed AI entitlement policy. Direct client access is prohibited.';
comment on table public.mission_research_requests is
  'Server-managed research rate metadata. Direct client access is prohibited.';
comment on table public.enterprise_support_proposals is
  'Server-reviewed support catalog. Clients consume only approved neutral projections.';

commit;
