# QST-345 to QST-352 Cross-Functional Review

## Scope

This review covers the ten-QST increment from shared Today Focus through the
international format foundation. It checks code quality, UI/UX, AI and privacy
boundaries, database readiness, security, and Master Spec alignment.

## Fixed During Review

- QST-352 applied USD to every English locale even though the format matrix
  defines GBP for `en-GB`. The shared formatter now selects GBP for UK English.
- QST-352 used a 24-hour formatter for all English locales while its product
  matrix declares locale time behavior. English now uses locale 12-hour output;
  Japanese remains 24-hour.
- QST-352 had no static contract gate or implementation report. Both are now
  present.
- The Home responsive smoke test expected a lazily-built section before it had
  been scrolled into the viewport. It now scrolls to `次の航路` before asserting
  the section, preserving coverage without a false failure.

## Findings Retained as Deliberate Gates

| Area | Status | Required next action |
| --- | --- | --- |
| Supabase | Blocked for external Beta | Deploy the current migration and all 12 Edge Functions from a clean candidate SHA, then capture real evidence. |
| RLS | Static contract only | Run two-account Quest, Mission, Trail, Memory, Route, and Media verification against hosted Supabase. |
| Accessibility | Automated/static only | Capture physical Android TalkBack, Japanese IME, and 200% text evidence bound to a candidate SHA. |
| Journey pagination | Foundation only | Convert repositories to owner-scoped keyset queries and remove Trail-media N+1 reads. |
| Durable mutations | Shared contract only | Adopt it in Quest, Mission, Trail, and Media repositories after their versioned RPC boundaries exist. |
| Internationalization | Foundation only | Migrate visible display call sites and complete localized UI/Arc/legal E2E before enabling English. |

## Master Spec Alignment

- Arc remains a supportive navigator; recovery signals offer rest, adjustment,
  and user choice rather than guilt or coercion.
- Analytics stays metadata-only and does not store Quest, Mission, Trail, chat,
  or memory text.
- Free users retain the core Quest to Mission to Task to Trail progression; no
  billing or hard paywall has been introduced.
- Release manifests continue to distinguish local evidence from hosted and
  physical-device proof.

## Next QST Direction

QST-353 will migrate the shared cursor and durable-mutation contracts into the
highest-volume Quest Journey repositories, preserving RLS owner scopes and
offline conflict behavior.
