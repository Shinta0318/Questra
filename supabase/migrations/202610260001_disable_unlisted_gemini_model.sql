begin;

update public.ai_model_registry
set enabled = false,
    retire_at = coalesce(retire_at, now()),
    updated_at = now()
where provider = 'gemini'
  and model_name = 'gemini-3.5-flash';

commit;
