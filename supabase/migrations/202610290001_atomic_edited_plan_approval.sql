-- Keep a reviewed Mission selection immutable until its approval transaction.
create table if not exists public.quest_plan_approval_selections (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  preview_id uuid not null references public.quest_plan_previews(id) on delete cascade,
  selection_fingerprint text not null
    check (selection_fingerprint ~ '^[0-9a-f]{64}$'),
  plan_payload jsonb not null check (jsonb_typeof(plan_payload) = 'object'),
  created_at timestamptz not null default now(),
  unique (preview_id, selection_fingerprint)
);

alter table public.quest_plan_approval_selections enable row level security;
revoke all on public.quest_plan_approval_selections from public, anon, authenticated;
grant select, insert on public.quest_plan_approval_selections to service_role;

alter table public.quest_plan_previews
  add column if not exists approved_selection_id uuid,
  add column if not exists approved_selection_fingerprint text;

create or replace function public.approve_quest_plan_preview_with_selection(
  p_preview_id uuid,
  p_approval_token uuid,
  p_selection_id uuid
) returns jsonb language plpgsql security definer
set search_path = public, pg_temp as $$
declare
  v_preview public.quest_plan_previews%rowtype;
  v_selection public.quest_plan_approval_selections%rowtype;
  v_result jsonb;
begin
  select * into v_preview
  from public.quest_plan_previews
  where id = p_preview_id
  for update;

  if not found or v_preview.owner_id is distinct from auth.uid() then
    raise exception 'preview_not_found';
  end if;
  if v_preview.approval_token is distinct from p_approval_token then
    raise exception 'approval_token_invalid';
  end if;
  if public.has_current_ai_legal_acceptance(auth.uid()) is not true then
    raise exception 'ai_legal_consent_required';
  end if;
  if v_preview.status = 'approved' then
    if v_preview.approved_selection_id is distinct from p_selection_id then
      raise exception 'preview_already_approved_with_different_selection';
    end if;
    return public.approve_quest_plan_preview(p_preview_id, p_approval_token);
  end if;
  if v_preview.status <> 'pending' or v_preview.expires_at <= now() then
    raise exception 'preview_not_approvable';
  end if;

  select * into v_selection
  from public.quest_plan_approval_selections
  where id = p_selection_id
    and preview_id = p_preview_id
    and owner_id = auth.uid()
  for update;
  if not found then
    raise exception 'approved_selection_not_found';
  end if;

  update public.quest_plan_previews
  set plan_payload = v_selection.plan_payload,
      approved_selection_id = v_selection.id,
      approved_selection_fingerprint = v_selection.selection_fingerprint
  where id = p_preview_id;

  -- The existing function locks the same row again and persists the route.
  -- Any failure rolls back this payload replacement and all route writes.
  v_result := public.approve_quest_plan_preview(p_preview_id, p_approval_token);
  delete from public.quest_plan_approval_selections
  where preview_id = p_preview_id;
  return v_result;
end;
$$;

revoke all on function public.approve_quest_plan_preview_with_selection(uuid, uuid, uuid)
from public, anon;
grant execute on function public.approve_quest_plan_preview_with_selection(uuid, uuid, uuid)
to authenticated;

comment on function public.approve_quest_plan_preview_with_selection(uuid, uuid, uuid) is
  'Atomically applies a server-validated Mission selection and approves its Quest plan under one preview row lock.';

create or replace function public.approve_quest_plan_preview_unedited(
  p_preview_id uuid,
  p_approval_token uuid
) returns jsonb language plpgsql security definer
set search_path = public, pg_temp as $$
declare
  v_preview public.quest_plan_previews%rowtype;
begin
  select * into v_preview
  from public.quest_plan_previews
  where id = p_preview_id
  for update;
  if not found or v_preview.owner_id is distinct from auth.uid() then
    raise exception 'preview_not_found';
  end if;
  if v_preview.approval_token is distinct from p_approval_token then
    raise exception 'approval_token_invalid';
  end if;
  if public.has_current_ai_legal_acceptance(auth.uid()) is not true then
    raise exception 'ai_legal_consent_required';
  end if;
  if v_preview.status = 'approved' and v_preview.approved_selection_id is not null then
    raise exception 'preview_already_approved_with_different_selection';
  end if;
  return public.approve_quest_plan_preview(p_preview_id, p_approval_token);
end;
$$;

revoke all on function public.approve_quest_plan_preview_unedited(uuid, uuid)
from public, anon;
grant execute on function public.approve_quest_plan_preview_unedited(uuid, uuid)
to authenticated;

comment on function public.approve_quest_plan_preview_unedited(uuid, uuid) is
  'Approves an unedited route while rejecting a replay after an edited selection won.';

-- Only the consent-gated wrappers remain callable by a user JWT.
revoke execute on function public.approve_quest_plan_preview(uuid, uuid)
from public, anon, authenticated;

create or replace function public.prune_stale_quest_plan_approval_selections()
returns integer language plpgsql security definer
set search_path = pg_catalog as $$
declare
  v_deleted integer;
begin
  with stale as (
    select selection.id
    from public.quest_plan_approval_selections selection
    join public.quest_plan_previews preview on preview.id = selection.preview_id
    where preview.status <> 'pending' or preview.expires_at <= now()
    order by selection.created_at
    limit 2000
    for update of selection skip locked
  )
  delete from public.quest_plan_approval_selections selection
  using stale
  where selection.id = stale.id;

  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;

revoke all on function public.prune_stale_quest_plan_approval_selections()
from public, anon, authenticated, service_role;

select cron.schedule(
  'questra-approval-selection-prune',
  '15 * * * *',
  'select public.prune_stale_quest_plan_approval_selections()'
);
