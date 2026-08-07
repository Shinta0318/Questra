# Questra Threat Model

Status: Beta baseline. Authority: `docs/QUESTRA_MASTER_SPEC_V2.md`.

## Assets and boundaries

- Auth sessions are held by Supabase; native refresh data uses secure storage and web does not persist session storage.
- Quest, Mission, Trail, Arc Memory, media, route proposals, and private Guild content are owner-bound through RLS.
- Gemini and service-role credentials remain server-side Edge Function secrets. The client receives only public Supabase configuration.
- AI prompts, grounded sources, and public Guild content are untrusted input. They cannot grant tools, mutate a route, or alter system instructions.

## Primary threats and controls

| Threat | Beta control |
| --- | --- |
| XSS / content injection | Flutter renders text as text; CSP blocks external scripts, objects, and frames. |
| Cross-account data access | RLS, owner-checking RPCs, and two-account cloud evidence. |
| CSRF-like cross-origin calls | Origin-scoped CORS, POST-only APIs, bearer authentication. |
| AI prompt injection | Structured schemas, bounded context, safety guard, proposal-before-mutation. |
| Unsafe Guild content | Pending moderation, owner-only deletion, reporting, no automatic private-data publication. |
| Token leakage | Server-only provider/service keys; CI contains no deployment secrets. |
| Supply chain / regression | Release gate analyzes, tests, validates contracts, and builds artifacts. |

## Deployment controls

Set `WEB_APP_ORIGIN` to the exact production web origin. Set `ALLOW_LOCAL_WEB_ORIGINS=true` only locally. The hosting provider must apply `apps/mobile/web/_headers`; QST-212 remains open until deployed headers are checked.
