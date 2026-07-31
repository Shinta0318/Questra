alter table public.missions
  add column if not exists done_condition text not null default '',
  add column if not exists expected_output text not null default '',
  add column if not exists verification_type text not null default 'self_check';

alter table public.missions
  drop constraint if exists missions_verification_type_check;

alter table public.missions
  add constraint missions_verification_type_check
  check (verification_type in ('self_check', 'artifact', 'official_source', 'professional_review'))
  not valid;

alter table public.missions validate constraint missions_verification_type_check;
