begin;

-- Hosted Supabase installs pgcrypto in extensions; local databases may use public.
-- Keep both trusted schemas visible to the receipt functions without changing
-- the extension installation or recreating the audited function bodies.
alter function public.record_ai_provider_execution_receipt(
  uuid, text, text, integer, integer, text, uuid
) set search_path = extensions, public, pg_temp;

alter function public.record_ai_provider_execution_receipt_v2(
  uuid, text, text, integer, integer, text, uuid, integer
) set search_path = extensions, public, pg_temp;

alter function public.record_ai_provider_execution_receipt_v4(
  uuid, text, text, integer, integer, text, uuid, integer, text, text, text, text
) set search_path = extensions, public, pg_temp;

commit;
