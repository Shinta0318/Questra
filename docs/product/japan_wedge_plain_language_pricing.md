# Japan Wedge, Plain Language, and Pricing Validation

Status: QST-351 validation baseline

## Purpose

Questra must choose a first Japanese wedge with evidence instead of trying to
serve every age, motivation, and AI literacy level at once. This validation
package does not implement billing or a hard paywall.

## Candidate Cohorts

| Cohort | Core Job | Primary Risk | Validation Signal |
| --- | --- | --- | --- |
| Students | Turn vague ambitions into concrete study or experience plans | Too game-like or too much terminology | First Quest completion, D7 return |
| Working adults | Convert career, learning, travel, and health goals into next actions | Looks like another task manager | First Task started, weekly meaningful progress |
| Parents | Balance family constraints with personal or family Quests | Feels selfish or time-consuming | Trust score, low-pressure recovery use |
| 40-60 beginners | Try AI-supported planning without feeling judged | AI anxiety, jargon, small text | Comprehension, manual path usage |
| AI-resistant users | Use Questra as a journey planner with optional Arc help | Perceived loss of control | Arc opt-out success, Quest management without Memory |

## Plain-Language Alias Rules

Use Questra terms, but pair first-use terms with ordinary Japanese.

| Questra Term | First-Use Alias |
| --- | --- |
| Quest | 叶えたい目標 |
| Mission | 中間ステップ |
| Task | 今日できる一歩 |
| Trail | 進んだ記録 |
| Guild | 挑戦を見つける場所 |
| Arc | 一緒に考える星のナビゲーター |
| Horizon | 次の候補 |
| Stardust | 経験のポイント |

Rules:

- Do not introduce more than three proprietary terms in one first-run step.
- Prefer short Japanese sentences with omitted subjects where natural.
- Arc may be warm, but must not pressure, shame, or imply dependency.
- Always keep a manual path when AI or Arc assistance is declined.

## Tone Modes to Validate

| Mode | Use Case | Example |
| --- | --- | --- |
| Calm | Default adult-friendly mode | 「今日は一つだけ進めましょう。」 |
| Coach | Users who want structure | 「次は条件を三つに分けると進めやすくなります。」 |
| Minimal | AI-resistant or busy users | 「次の一歩を表示します。」 |

## Pricing Hypotheses

These are research hypotheses only. They must not connect to production billing
until pricing evidence and legal review are complete.

| Plan Hypothesis | Price | Test Question |
| --- | --- | --- |
| Light Premium | ¥480/month | Is deeper planning worth a small subscription? |
| Standard Premium | ¥780/month | Does Arc route review plus more memory feel valuable? |
| Pro Personal | ¥980/month | Is high-frequency replanning worth paying for? |

Premium must never make basic Quest -> Mission -> Task -> Trail progression weaker
for free users.

## Validation Plan

1. Recruit five users per candidate cohort.
2. Run a moderated first-ten-minute session.
3. Measure comprehension before feature explanation.
4. Ask users to create or accept a first Quest.
5. Record whether they start a first Task.
6. Ask trust and payment-sensitivity questions after the experience.
7. Compare D7 return and weekly meaningful progress for the selected cohort.

## Decision Gate

Choose one wedge only when it has:

- 80%+ comprehension of Quest/Mission/Task/Trail after first-use aliases.
- 60%+ first Task start in moderated tests.
- No severe trust or wellbeing concern.
- Better D7 intent than the other cohorts.
- A pricing hypothesis users can explain in their own words.

If no cohort passes, do not widen the target. Redesign the value proposition.

## Prohibited

- No hard paywall in this QST.
- No real billing integration.
- No price shown as final or launched.
- No research data tied to raw Quest, Mission, Trail, or Arc Chat content.
- No optimization toward addictive streaks, pressure, or fear of missing out.
