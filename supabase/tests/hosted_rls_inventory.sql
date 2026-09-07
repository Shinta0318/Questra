begin;

do $$
declare
  missing_rls text;
  implicit_client_access text;
begin
  select string_agg(format('public.%I', c.relname), ', ' order by c.relname)
    into missing_rls
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relkind in ('r', 'p')
    and not c.relrowsecurity;

  if missing_rls is not null then
    raise exception 'QST-395 tables without RLS: %', missing_rls;
  end if;

  select string_agg(format('public.%I', c.relname), ', ' order by c.relname)
    into implicit_client_access
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relkind in ('r', 'p')
    and not exists (
      select 1
      from pg_policy p
      where p.polrelid = c.oid
    )
    and (
      has_table_privilege('anon', c.oid, 'SELECT')
      or has_table_privilege('anon', c.oid, 'INSERT')
      or has_table_privilege('anon', c.oid, 'UPDATE')
      or has_table_privilege('anon', c.oid, 'DELETE')
      or has_table_privilege('authenticated', c.oid, 'SELECT')
      or has_table_privilege('authenticated', c.oid, 'INSERT')
      or has_table_privilege('authenticated', c.oid, 'UPDATE')
      or has_table_privilege('authenticated', c.oid, 'DELETE')
    );

  if implicit_client_access is not null then
    raise exception
      'QST-395 policy-free tables retain client privileges: %',
      implicit_client_access;
  end if;
end
$$;

select 'QST395_TABLE|' || c.relname as qst_inventory
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind in ('r', 'p')
order by c.relname;

select 'QST-395 hosted dynamic RLS inventory passed' as qst_message;

rollback;
