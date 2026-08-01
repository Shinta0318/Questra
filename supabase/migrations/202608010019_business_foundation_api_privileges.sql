begin;

grant select on public.quest_progress_events to authenticated;
grant select on public.quest_stage_state, public.quest_stage_history to authenticated;
grant select, insert, update, delete on public.quest_dna_versions to authenticated;
grant select, insert, update, delete on public.mission_support_profiles to authenticated;
grant select on public.consent_purposes, public.user_consents to authenticated;
grant select, insert, update, delete on public.support_interactions to authenticated;
grant select on public.contribution_outcomes to authenticated;

revoke all on public.business_quest_signals from anon, authenticated;
revoke all on public.segment_definitions from anon, authenticated;
revoke all on public.segment_snapshots from anon, authenticated;
revoke all on public.segment_access_audit from anon, authenticated;

commit;
