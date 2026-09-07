-- QST-353: share only selected immutable Trail fields through expiring tokens.
create table if not exists public.trail_share_links (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.user_profiles(id) on delete cascade,
  trail_id uuid not null references public.trails(id) on delete cascade,
  token_hash text not null unique,
  snapshot jsonb not null,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  constraint trail_share_links_snapshot_object check (jsonb_typeof(snapshot) = 'object'),
  constraint trail_share_links_expiry_after_creation check (expires_at > created_at)
);

alter table public.trail_share_links enable row level security;

create policy "Trail share owners inspect their links"
  on public.trail_share_links for select using (owner_id = auth.uid());

create policy "Trail share owners revoke their links"
  on public.trail_share_links for update
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create index if not exists trail_share_links_owner_active_idx
  on public.trail_share_links(owner_id, revoked_at, expires_at desc);

create or replace function public.create_trail_share_link(
  p_trail_id uuid,
  p_include_title boolean,
  p_include_summary boolean,
  p_include_content boolean,
  p_expires_at timestamptz
)
returns table(id uuid, share_token text, expires_at timestamptz)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_trail public.trails%rowtype;
  v_token text;
  v_snapshot jsonb;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if not (p_include_title or p_include_summary or p_include_content) then
    raise exception 'share_fields_required';
  end if;
  if p_expires_at <= now() or p_expires_at > now() + interval '30 days' then
    raise exception 'invalid_share_expiry';
  end if;
  select * into v_trail from public.trails where trails.id = p_trail_id and owner_id = auth.uid();
  if not found then raise exception 'trail_not_found'; end if;
  v_snapshot := jsonb_strip_nulls(jsonb_build_object(
    'title', case when p_include_title then v_trail.title else null end,
    'summary', case when p_include_summary then v_trail.summary else null end,
    'content', case when p_include_content then v_trail.content else null end,
    'sharedAt', now()
  ));
  v_token := encode(gen_random_bytes(32), 'hex');
  insert into public.trail_share_links(owner_id, trail_id, token_hash, snapshot, expires_at)
  values (auth.uid(), p_trail_id, encode(digest(v_token, 'sha256'), 'hex'), v_snapshot, p_expires_at)
  returning trail_share_links.id, trail_share_links.expires_at into id, expires_at;
  share_token := v_token;
  return next;
end;
$$;

-- Public token resolution is deliberately only exposed through this narrow RPC.
create or replace function public.resolve_trail_share_link(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_snapshot jsonb;
begin
  if length(trim(coalesce(p_token, ''))) <> 64 then return null; end if;
  select snapshot into v_snapshot
  from public.trail_share_links
  where token_hash = encode(digest(p_token, 'sha256'), 'hex')
    and revoked_at is null
    and expires_at > now();
  return v_snapshot;
end;
$$;

create or replace function public.revoke_trail_share_link(p_link_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.trail_share_links
  set revoked_at = coalesce(revoked_at, now())
  where id = p_link_id and owner_id = auth.uid();
  return found;
end;
$$;

revoke all on public.trail_share_links from anon, authenticated;
grant execute on function public.resolve_trail_share_link(text) to anon, authenticated;
grant execute on function public.create_trail_share_link(uuid, boolean, boolean, boolean, timestamptz) to authenticated;
grant execute on function public.revoke_trail_share_link(uuid) to authenticated;

comment on table public.trail_share_links is
  'QST-353: immutable selected-field Trail snapshots. Media, owner data, and live Trail rows are never shared by this table.';
