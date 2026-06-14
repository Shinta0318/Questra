# DB Future Readiness Review

Questra should stay MVP-sized while keeping stable boundaries for future
features such as Arc Journal, Arc Letters, Premium, Guild Follow, DM,
Corporate Quest, Sponsor Guild, Quest Offer, Business Account, Enterprise Plan,
Arc Level, Bond, Stardust, Navigator Rank, and Constellation.

## Current Problems Found

- RLS was enabled but no policies were defined, so authenticated access rules
  were not explicit.
- Trail visibility needed first-class `private`, `guild`, and `public` states
  to support public Trails and Guild-only records.
- Guild membership was missing, which made Guild-scoped access impossible to
  express safely.
- Media, notifications, subscriptions, and business accounts had no minimal
  ownership tables.
- Arc Journal and Arc Letters had no future anchor despite depending on Arc
  Memory and Trail.
- Profile progression concepts existed only as future product names, not as
  stable columns.

## Tables Added Now

- `guild_members`: role and status boundary for Guild access.
- `business_accounts`: owner-level shell for Business Account, Sponsor Guild,
  and Enterprise Plan.
- `subscriptions`: user or business subscription state.
- `media`: owned media metadata with optional Guild visibility.
- `notifications`: user-owned notification inbox.
- `journal_entries`: minimal Arc Journal storage.
- `arc_letters`: minimal Arc Letters storage and delivery state.
- `generation_logs`: audit trail for generated Arc output.

## Columns Added Now

- `user_profiles.public_profile`
- `user_profiles.arc_level`
- `user_profiles.bond_score`
- `user_profiles.stardust_balance`
- `user_profiles.navigator_rank`
- `quests.guild_id`
- `trails.guild_id`
- `trails.visibility`
- `guilds.visibility`

## Add Later

- `guild_follows`
- `direct_threads`
- `direct_messages`
- `corporate_quests`
- `quest_offers`
- `sponsor_guilds`
- `premium_entitlements`
- `business_account_members`
- `constellations`
- billing provider event tables
- moderation queues and review assignment tables

## Index Policy

- Owner/time indexes for user-owned feeds: Trails, media, journal entries,
  letters.
- Relationship indexes for Quest and Mission lookups.
- Visibility indexes for public and Guild feeds.
- Membership indexes by both `user_id` and `guild_id`.
- Generation logs indexed by `target_type` and `target_id` for audits.

## RLS Policy

- Private data is owner-only.
- Public Trail and media records are readable by other users.
- Guild-scoped Quest, Trail, and media records require active Guild membership.
- Arc Memory is always owner-only.
- Business Account can read only its own account/subscription records and has
  no policy path into personal Arc Memory.

## Migration Note

The MVP repository currently keeps a single initial migration. For an existing
hosted Supabase project, apply these changes as a new additive migration
instead of editing already-applied production migration history.
