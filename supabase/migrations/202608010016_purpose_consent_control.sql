begin;

create table public.consent_purposes (
  purpose_code text not null,
  version integer not null,
  title text not null,
  description text not null,
  is_required boolean not null default false,
  effective_from timestamptz not null default now(),
  primary key (purpose_code, version)
);

insert into public.consent_purposes (purpose_code, version, title, description, is_required) values
('arc_personalization',1,'Arcのパーソナライズ','過去のQuestやMission傾向から提案を改善します。',false),
('product_improvement',1,'プロダクト改善','内部限定データで品質を改善します。',false),
('anonymous_analytics',1,'匿名統計','個人を特定しない集計へ利用します。',false),
('business_recommendations',1,'支援情報の表示','関連する企業・団体の支援情報を表示します。',false),
('business_segment_analysis',1,'匿名傾向分析','一定人数以上の匿名集計へ利用します。',false),
('personal_data_sharing',1,'個人情報の共有','指定した企業へ指定情報を共有します。',false)
on conflict do nothing;

create table public.user_consents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.user_profiles(id) on delete cascade,
  purpose_code text not null,
  purpose_version integer not null,
  status text not null check (status in ('granted','denied','withdrawn')),
  granted_at timestamptz,
  withdrawn_at timestamptz,
  source text not null check (source in ('onboarding','settings','contextual_prompt')),
  evidence jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (user_id, purpose_code, purpose_version),
  foreign key (purpose_code, purpose_version) references public.consent_purposes(purpose_code, version)
);

alter table public.consent_purposes enable row level security;
alter table public.user_consents enable row level security;
create policy "Anyone reads active consent purposes" on public.consent_purposes for select using (true);
create policy "Users read own consents" on public.user_consents for select using (user_id = auth.uid());
revoke insert, update, delete on public.user_consents from anon, authenticated;

create or replace function public.set_user_consent(
  p_purpose_code text, p_purpose_version integer, p_granted boolean, p_source text
) returns public.user_consents
language plpgsql security definer set search_path = public
as $$
declare result public.user_consents; actor_id uuid := auth.uid();
begin
  if actor_id is null then raise exception 'authentication required'; end if;
  if p_purpose_code = 'personal_data_sharing' and p_source <> 'contextual_prompt' then
    raise exception 'contextual confirmation required';
  end if;
  insert into public.user_consents (
    user_id, purpose_code, purpose_version, status, granted_at, withdrawn_at, source, evidence
  ) values (
    actor_id, p_purpose_code, p_purpose_version,
    case when p_granted then 'granted' else 'withdrawn' end,
    case when p_granted then now() end,
    case when not p_granted then now() end,
    p_source, jsonb_build_object('explicit_action', true)
  ) on conflict (user_id, purpose_code, purpose_version) do update set
    status = excluded.status, granted_at = excluded.granted_at,
    withdrawn_at = excluded.withdrawn_at, source = excluded.source,
    evidence = excluded.evidence, created_at = now()
  returning * into result;

  if not p_granted and p_purpose_code in ('business_segment_analysis','business_recommendations') then
    delete from public.business_quest_signals where owner_id = actor_id;
  end if;
  return result;
end;
$$;
grant execute on function public.set_user_consent(text, integer, boolean, text) to authenticated;

commit;
