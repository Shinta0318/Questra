begin;

create table if not exists public.guild_posts (
  id uuid primary key default gen_random_uuid(),
  guild_id uuid not null references public.guilds(id) on delete cascade,
  author_id uuid not null references public.user_profiles(id) on delete cascade,
  content text not null check (char_length(content) between 1 and 1200),
  moderation_status text not null default 'pending'
    check (moderation_status in ('pending', 'approved', 'rejected', 'removed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists guild_posts_guild_created_idx
  on public.guild_posts(guild_id, created_at desc);

alter table public.guild_posts enable row level security;

create policy "Guild members read approved posts or their own"
  on public.guild_posts for select
  using (
    author_id = auth.uid()
    or (
      moderation_status = 'approved'
      and public.is_guild_member(guild_id)
    )
  );

create or replace function public.join_public_guild(p_guild_id uuid)
returns void
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  if not exists (select 1 from public.guilds where id = p_guild_id and visibility = 'public') then
    raise exception 'Guild is not available';
  end if;
  insert into public.guild_members(guild_id, user_id, role, status)
    values (p_guild_id, auth.uid(), 'member', 'active')
  on conflict (guild_id, user_id) do update set status = 'active', updated_at = now();
end;
$$;

create or replace function public.leave_guild(p_guild_id uuid)
returns void
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  delete from public.guild_members
    where guild_id = p_guild_id and user_id = auth.uid() and role = 'member';
  if not found then raise exception 'Membership cannot be removed'; end if;
end;
$$;

create or replace function public.create_guild_post(p_guild_id uuid, p_content text)
returns uuid
language plpgsql security definer set search_path = public, pg_temp
as $$
declare post_id uuid;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  if char_length(trim(p_content)) not between 1 and 1200 then raise exception 'invalid content'; end if;
  if not public.is_guild_member(p_guild_id) and not public.is_guild_owner(p_guild_id) then
    raise exception 'Guild membership required';
  end if;
  insert into public.guild_posts(guild_id, author_id, content, moderation_status)
    values (p_guild_id, auth.uid(), trim(p_content), 'pending') returning id into post_id;
  return post_id;
end;
$$;

create or replace function public.delete_guild_post(p_post_id uuid)
returns void
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  delete from public.guild_posts where id = p_post_id and author_id = auth.uid();
  if not found then raise exception 'Post not found'; end if;
end;
$$;

create or replace function public.report_guild_post(p_post_id uuid, p_reason text)
returns uuid
language plpgsql security definer set search_path = public, pg_temp
as $$
declare report_id uuid;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  if char_length(trim(p_reason)) not between 1 and 500 then raise exception 'invalid reason'; end if;
  if not exists (select 1 from public.guild_posts where id = p_post_id) then raise exception 'Post not found'; end if;
  insert into public.reports(reporter_id, target_type, target_id, reason)
    values (auth.uid(), 'guild_post', p_post_id, trim(p_reason)) returning id into report_id;
  return report_id;
end;
$$;

revoke all on public.guild_posts from anon, authenticated;
grant select on public.guild_posts to authenticated;
revoke all on function public.join_public_guild(uuid) from public;
revoke all on function public.leave_guild(uuid) from public;
revoke all on function public.create_guild_post(uuid, text) from public;
revoke all on function public.delete_guild_post(uuid) from public;
revoke all on function public.report_guild_post(uuid, text) from public;
grant execute on function public.join_public_guild(uuid), public.leave_guild(uuid),
  public.create_guild_post(uuid, text), public.delete_guild_post(uuid),
  public.report_guild_post(uuid, text) to authenticated;

comment on table public.guild_posts is 'Moderated Guild content. Private Quest, Trail, and contact data are never copied automatically.';

commit;
