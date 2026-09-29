-- QST-452 hosted contract checks. Run after candidate deployment.
begin;

select has_table_privilege(
  'authenticated',
  'public.ai_tool_continuation_runs',
  'SELECT'
) = false as clients_cannot_read_continuation_runs;

select has_table_privilege(
  'authenticated',
  'public.ai_tool_continuation_turns',
  'SELECT'
) = false as clients_cannot_read_continuation_turns;

select has_function_privilege(
  'authenticated',
  'public.record_ai_tool_continuation_turn(uuid,integer,text,text[])',
  'EXECUTE'
) = false as clients_cannot_record_cost_evidence;

select count(*) = 0 as content_columns_are_absent
from information_schema.columns
where table_schema = 'public'
  and table_name in (
    'ai_tool_continuation_runs',
    'ai_tool_continuation_turns'
  )
  and column_name in (
    'prompt', 'response', 'response_body', 'tool_result', 'tool_result_body',
    'interaction_history', 'api_key', 'secret'
  );

select position(
  'ai_tool_continuation_total_mismatch'
  in pg_get_functiondef(
    'public.finalize_ai_tool_continuation_attribution(uuid,integer,integer,integer)'::regprocedure
  )
) > 0 as finalization_requires_exact_turn_totals;

select position(
  'ai_tool_continuation_turn_conflict'
  in pg_get_functiondef(
    'public.record_ai_tool_continuation_turn(uuid,integer,text,text[])'::regprocedure
  )
) > 0 as duplicate_turn_conflicts_are_rejected;

select position(
  '''idempotent'', true'
  in pg_get_functiondef(
    'public.fail_ai_tool_continuation_attribution(uuid,text)'::regprocedure
  )
) > 0 as repeated_failure_is_idempotent;

rollback;
