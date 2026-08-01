alter table public.missions
  add column if not exists action text not null default '',
  add column if not exists is_optional boolean not null default false,
  add column if not exists source_requirement text not null default 'none',
  add column if not exists confidence double precision not null default 0.5;

alter table public.missions
  drop constraint if exists missions_source_requirement_check;
alter table public.missions
  add constraint missions_source_requirement_check
  check (source_requirement in ('none', 'recent', 'official', 'professional'));

alter table public.missions
  drop constraint if exists missions_confidence_check;
alter table public.missions
  add constraint missions_confidence_check
  check (confidence >= 0 and confidence <= 1);
