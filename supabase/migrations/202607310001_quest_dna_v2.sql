begin;

alter table public.quests
  add column if not exists quest_dna jsonb,
  add column if not exists quest_dna_version text,
  add column if not exists quest_dna_evaluated_at timestamptz;

alter table public.quests
  add constraint quests_quest_dna_object_check
    check (quest_dna is null or jsonb_typeof(quest_dna) = 'object') not valid;

alter table public.quests validate constraint quests_quest_dna_object_check;

comment on column public.quests.quest_dna is
  'Versioned, bounded Quest DNA snapshot. AI values are explanatory, not user-declared facts.';

commit;
