# Supabase RLS And Security Design

Questra uses Supabase Auth as the user source of truth. Application tables store
profile, Quest, Mission, Trail, Guild, Arc Memory, media, notification, and
future billing or business metadata.

## Policy Summary

- `user_profiles`: users can create and update only their own profile; public
  profiles are readable for discovery.
- `quests`: owners can manage their Quests. Public Quests are readable. Guild
  Quests require active Guild membership.
- `missions`: visibility follows the parent Quest. Only the Quest owner can
  create, update, or delete Missions.
- `trails`: owners can manage Trails. Public Trails are readable. Guild Trails
  require active Guild membership.
- `trail_events`: visibility follows the parent Trail. Only Trail owners can
  create events.
- `guilds`: public Guilds are discoverable; private Guilds require ownership or
  membership.
- `guild_members`: users can read their own membership rows; Guild owners can
  manage membership.
- `arc_memories`: strict owner-only access. This table must not be exposed to
  Business Account, Sponsor Guild, or Quest Offer policies.
- `media`: owner, public, or Guild-membership visibility.
- `notifications`: users can read and mark only their own notifications.
- `business_accounts`: owner-only in MVP.
- `subscriptions`: user owner or business account owner can read.
- `journal_entries` and `arc_letters`: user owner-only.
- `generation_logs`: user owner-only read; service role can write generation
  audits.

## Implementation SQL

The current implementation lives in:

`supabase/migrations/202606130001_mvp_schema.sql`

The migration includes:

- `public.is_guild_member(target_guild_id uuid)`
- `public.is_guild_owner(target_guild_id uuid)`
- RLS enablement for all application tables.
- Policies for owner, public, and Guild-scoped access.

## Security Notes

- Edge Functions that generate Arc Memory, Arc Journal, or Arc Letters should
  use the Supabase service role only on the server.
- Client code must never receive a service role key.
- Arc Memory may contain emotion, values, life events, and sensitive personal
  context; keep it separate from analytics and business domains.
- Business Account and Quest Offer features should read aggregate or explicit
  opt-in data only, never raw Arc Memory.
- Media storage bucket policies must mirror the `media` table visibility rules.
- Generated content should be logged through `generation_logs` without storing
  raw secrets or unnecessary personal data.

## Test Policy

- Add SQL tests for owner-only CRUD on private tables.
- Add SQL tests that another authenticated user cannot read private Quest,
  Mission, Trail, media, notification, journal, letter, or Arc Memory rows.
- Add SQL tests that public Trails are readable by other users.
- Add SQL tests that Guild Trails and media are readable only by active Guild
  members.
- Add SQL tests that Business Account owners cannot read `arc_memories`.
- Add storage policy tests when Supabase Storage buckets are introduced.
