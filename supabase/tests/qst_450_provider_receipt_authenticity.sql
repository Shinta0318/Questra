-- QST-450 hosted contract checks. Run after candidate deployment.
begin;

select has_function_privilege(
  'authenticated',
  'public.reserve_ai_usage_budget_v3(uuid,text,text,text,text[],integer,integer,uuid,text,text,text)',
  'EXECUTE'
) = false as client_cannot_issue_receipt_binding;

select has_function_privilege(
  'authenticated',
  'public.record_ai_provider_execution_receipt_v4(uuid,text,text,integer,integer,text,uuid,integer,text,text,text,text)',
  'EXECUTE'
) = false as client_cannot_record_bound_receipt;

select position(
  'provider_interaction_replay'
  in pg_get_functiondef(
    'public.record_ai_provider_execution_receipt_v4(uuid,text,text,integer,integer,text,uuid,integer,text,text,text,text)'::regprocedure
  )
) > 0 as cross_reservation_interaction_replay_is_rejected;

select position(
  'ai_provider_request_binding_required'
  in pg_get_functiondef(
    'public.require_ai_receipt_request_binding()'::regprocedure
  )
) > 0 as settlement_requires_verified_request_binding;

select count(*) = 0 as raw_nonce_or_output_columns_are_absent
from information_schema.columns
where table_schema = 'public'
  and table_name in (
    'ai_budget_reservations',
    'ai_provider_execution_receipts'
  )
  and column_name in (
    'receipt_nonce', 'provider_output', 'response_body', 'prompt', 'api_key',
    'secret'
  );

rollback;
