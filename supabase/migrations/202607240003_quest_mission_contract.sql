begin;

update public.missions
set title = '次の具体的な一歩を決める'
where btrim(title) = '';

alter table public.missions
  drop constraint if exists missions_title_not_blank;

alter table public.missions
  add constraint missions_title_not_blank check (btrim(title) <> '');

create index if not exists missions_quest_sort_order_idx
  on public.missions (quest_id, sort_order, created_at);

comment on column public.missions.quest_id is
  'Required parent Quest. Ownership is enforced through Quest-owner RLS policies.';

comment on table public.missions is
  'Concrete actions belonging to exactly one Quest; Quest deletion cascades to its Missions.';

commit;
