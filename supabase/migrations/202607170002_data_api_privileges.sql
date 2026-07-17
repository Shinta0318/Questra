-- Automatic table exposure is disabled for Beta. Grant only the current
-- public schema surface; future tables require an explicit migration.
grant usage on schema public to authenticated;

grant select, insert, update, delete
  on all tables in schema public
  to authenticated;

grant usage, select
  on all sequences in schema public
  to authenticated;
