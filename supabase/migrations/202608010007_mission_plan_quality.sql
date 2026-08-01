alter table public.quests
  add column if not exists plan_quality jsonb;

alter table public.quests
  drop constraint if exists quests_plan_quality_object_check,
  add constraint quests_plan_quality_object_check
    check (plan_quality is null or jsonb_typeof(plan_quality) = 'object')
    not valid;

alter table public.quests validate constraint quests_plan_quality_object_check;

comment on column public.quests.plan_quality is
  'Bounded aggregate plan quality metadata. Internal Critic reasoning and raw prompts are never stored here.';
