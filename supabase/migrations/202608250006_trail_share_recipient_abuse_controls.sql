-- QST-364: authenticated Trail-share recipient boundary and abuse controls.
begin;

alter table public.trail_share_links
  add column if not exists access_count integer not null default 0 check (access_count >= 0),
  add column if not exists report_count integer not null default 0 check (report_count >= 0),
  add column if not exists last_accessed_at timestamptz,
  add column if not exists safety_hold_at timestamptz;

create or replace function public.create_trail_share_link(
  p_trail_id uuid,
  p_include_title boolean,
  p_include_summary boolean,
  p_include_content boolean,
  p_expires_at timestamptz
)
returns table(id uuid, share_token text, expires_at timestamptz)
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_trail public.trails%rowtype;
  v_token text;
  v_snapshot jsonb;
  v_selected_text text;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if not (p_include_title or p_include_summary or p_include_content) then
    raise exception 'share_fields_required';
  end if;
  if p_expires_at <= now() or p_expires_at > now() + interval '30 days' then
    raise exception 'invalid_share_expiry';
  end if;
  select * into v_trail from public.trails
    where trails.id = p_trail_id and owner_id = auth.uid();
  if not found then raise exception 'trail_not_found'; end if;
  v_selected_text := concat_ws(E'\n',
    case when p_include_title then v_trail.title end,
    case when p_include_summary then v_trail.summary end,
    case when p_include_content then v_trail.content end
  );
  if v_selected_text ~* '[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}'
     or v_selected_text ~ '(\+?81[- ]?)?0[0-9]{1,4}[- ]?[0-9]{1,4}[- ]?[0-9]{3,4}' then
    raise exception 'personal_contact_detected';
  end if;
  v_snapshot := jsonb_strip_nulls(jsonb_build_object(
    'title', case when p_include_title then v_trail.title else null end,
    'summary', case when p_include_summary then v_trail.summary else null end,
    'content', case when p_include_content then v_trail.content else null end,
    'sharedAt', now()
  ));
  v_token := encode(gen_random_bytes(32), 'hex');
  insert into public.trail_share_links(owner_id, trail_id, token_hash, snapshot, expires_at)
  values(auth.uid(), p_trail_id, encode(digest(v_token, 'sha256'), 'hex'), v_snapshot, p_expires_at)
  returning trail_share_links.id, trail_share_links.expires_at into id, expires_at;
  share_token := v_token;
  return next;
end;
$$;

create table if not exists public.trail_share_access_buckets (
  recipient_id uuid not null references public.user_profiles(id) on delete cascade,
  window_start timestamptz not null,
  attempts integer not null default 1 check (attempts between 1 and 10000),
  primary key (recipient_id, window_start)
);

create table if not exists public.trail_share_abuse_reports (
  id uuid primary key default gen_random_uuid(),
  link_id uuid not null references public.trail_share_links(id) on delete cascade,
  reporter_id uuid not null references public.user_profiles(id) on delete cascade,
  reason_code text not null check (
    reason_code in ('spam', 'unsafe', 'personal_info', 'harassment', 'other')
  ),
  status text not null default 'pending' check (status in ('pending', 'confirmed', 'dismissed')),
  created_at timestamptz not null default now(),
  unique (link_id, reporter_id, reason_code)
);

create index if not exists trail_share_abuse_queue_idx
  on public.trail_share_abuse_reports(status, created_at);

alter table public.trail_share_access_buckets enable row level security;
alter table public.trail_share_abuse_reports enable row level security;

create policy "Trail share recipients inspect their reports"
  on public.trail_share_abuse_reports for select using (reporter_id = auth.uid());

create or replace function public.resolve_trail_share_link_guarded(p_token text)
returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_recipient uuid := auth.uid();
  v_window timestamptz := date_trunc('hour', now())
    + floor(extract(minute from now()) / 10) * interval '10 minutes';
  v_attempts integer;
  v_link public.trail_share_links%rowtype;
begin
  if v_recipient is null then raise exception 'authentication_required'; end if;
  delete from public.trail_share_access_buckets
    where window_start < now() - interval '24 hours';
  insert into public.trail_share_access_buckets(recipient_id, window_start, attempts)
  values(v_recipient, v_window, 1)
  on conflict (recipient_id, window_start) do update
    set attempts = public.trail_share_access_buckets.attempts + 1
  returning attempts into v_attempts;
  if v_attempts > 30 then return jsonb_build_object('status', 'rate_limited'); end if;
  if length(trim(coalesce(p_token, ''))) <> 64 then
    return jsonb_build_object('status', 'not_available');
  end if;

  select * into v_link from public.trail_share_links
  where token_hash = encode(digest(p_token, 'sha256'), 'hex')
    and revoked_at is null
    and safety_hold_at is null
    and expires_at > now();
  if not found then return jsonb_build_object('status', 'not_available'); end if;

  update public.trail_share_links set
    access_count = access_count + 1,
    last_accessed_at = now()
  where id = v_link.id;
  return jsonb_build_object(
    'status', 'available',
    'expiresAt', v_link.expires_at,
    'fields', v_link.snapshot
  );
end;
$$;

create or replace function public.report_trail_share_link_guarded(
  p_token text,
  p_reason_code text
) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_reporter uuid := auth.uid();
  v_link_id uuid;
  v_inserted integer := 0;
  v_reports integer;
begin
  if v_reporter is null then raise exception 'authentication_required'; end if;
  if p_reason_code not in ('spam', 'unsafe', 'personal_info', 'harassment', 'other')
     or length(trim(coalesce(p_token, ''))) <> 64 then
    return jsonb_build_object('status', 'not_available');
  end if;
  select id into v_link_id from public.trail_share_links
    where token_hash = encode(digest(p_token, 'sha256'), 'hex');
  if v_link_id is null then return jsonb_build_object('status', 'not_available'); end if;

  insert into public.trail_share_abuse_reports(link_id, reporter_id, reason_code)
  values(v_link_id, v_reporter, p_reason_code)
  on conflict (link_id, reporter_id, reason_code) do nothing;
  get diagnostics v_inserted = row_count;
  if v_inserted > 0 then
    update public.trail_share_links set report_count = report_count + 1
    where id = v_link_id returning report_count into v_reports;
    if v_reports >= 3 then
      update public.trail_share_links set safety_hold_at = coalesce(safety_hold_at, now())
      where id = v_link_id;
    end if;
  end if;
  return jsonb_build_object('status', 'accepted');
end;
$$;

revoke all on public.trail_share_access_buckets, public.trail_share_abuse_reports
  from anon, authenticated;
grant select on public.trail_share_abuse_reports to authenticated;
revoke all on function public.resolve_trail_share_link(text) from anon, authenticated;
revoke all on function public.resolve_trail_share_link_guarded(text) from public, anon;
revoke all on function public.report_trail_share_link_guarded(text, text) from public, anon;
grant execute on function public.resolve_trail_share_link_guarded(text) to authenticated;
grant execute on function public.report_trail_share_link_guarded(text, text) to authenticated;

comment on table public.trail_share_abuse_reports is
  'Reason-code-only reports. Trail snapshot, token, and recipient profile data are never copied into reports.';
comment on function public.resolve_trail_share_link_guarded(text) is
  'Authenticated recipients receive identical not_available responses for unknown, expired, revoked, and safety-held links.';

commit;
