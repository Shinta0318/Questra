begin;

alter table public.route_change_proposals
  add column if not exists generator_type text not null default 'legacyUnknown',
  add column if not exists generator_version text,
  add column if not exists prompt_version text,
  add column if not exists schema_version text,
  add column if not exists grounded boolean not null default false;

alter table public.route_change_proposals
  add constraint route_proposal_generator_type_check
  check (generator_type in ('legacyUnknown', 'rules', 'gemini', 'manual', 'otherProvider')) not valid;
alter table public.route_change_proposals
  validate constraint route_proposal_generator_type_check;

commit;
