# Questra

Questra is an adventure-style mobile experience built around Quest, Mission,
Trail, Guild, and Arc Memory systems, with supporting backend, product, AI,
worldbuilding, branding, architecture, analytics, and design documentation
spaces.

## Project Structure

```text
.
├── apps
│   ├── mobile
│   └── business
├── docs
│   ├── ai
│   ├── analytics
│   ├── architecture
│   ├── branding
│   ├── design
│   ├── product
│   └── world
└── supabase
    ├── functions
    ├── migrations
    └── seed
```

## Areas

- `apps/mobile`: Flutter mobile app.
- `apps/business`: Future business/admin app workspace.
- `supabase/migrations`: Database migration files.
- `supabase/functions`: Supabase Edge Functions.
- `supabase/seed`: Seed data and scripts.
- `docs/product`: Product requirements and planning.
- `docs/ai`: AI behavior, prompts, and model notes.
- `docs/world`: Worldbuilding and Quest / Trail lore.
- `docs/branding`: Brand guidelines.
- `docs/architecture`: System design and technical decisions.
- `docs/analytics`: Measurement plans and event specs.
- `docs/design`: UX and visual design documentation.

## MVP Performance Check

Use these checks before internal beta builds:

- Run `flutter analyze` from `apps/mobile`.
- Run `flutter test -r expanded` from `apps/mobile`.
- Run `dart run tools/qst/verify_performance_readiness.dart` from the repository root.
- Run `dart run tools/qst/verify_beta_feedback_readiness.dart` from the repository root.
- Run the app on a physical device with `flutter run --profile`.
- Check Home first render target: 1.5 seconds or less.
- Check Quest and Trail list render target: 1 second or less.
- Check route transition target: 300 ms or less.
- Check list scrolling target: stable 60 fps in Flutter DevTools.
- Confirm Arc Chat shows a waiting or thinking state while work is pending.
- Confirm Arc PNG assets remain below `QuestraPerformanceLimits.arcAssetMaxBytes`.
- Confirm Trail images are picked with max 1600 px dimensions and quality 78 before upload.
- Confirm Supabase list queries use limits and explicit column selections.
- Confirm Arc Memory visible reads are limited and ordered by importance and recency.
