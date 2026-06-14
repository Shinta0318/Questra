# Reserved Domains

This document records future Questra domains that are intentionally not part of
the current MVP implementation. The names below are reserved so later work can
extend the system without introducing new product vocabulary.

## Arc

- `arc_memories`: Long-lived Arc observations and user preference memory.
- `journal_entries`: Future reflective journal entries generated with or by Arc.
- `arc_letters`: Future letter-style Arc messages to the user.
- `generation_logs`: Future audit trail for generated Arc output.

## Trail

- `trails`: A Quest-level progression log.
- `trail_events`: Mission completions, Arc reflections, and manual notes inside
  a Trail.

## Guild

- `guild_follows`: Future lightweight follow relationship between users or
  Guilds.
- `guild_members`: Membership and role records.
- `sponsor_guilds`: Future sponsor-managed Guild domain.

## Direct Messages

- `direct_threads`: Future DM thread container.
- `direct_messages`: Future DM messages. This domain is distinct from Arc
  Memory and Trail.

## Premium

- `subscriptions`: Future premium entitlement records.
- `premium_entitlements`: Future feature-level access flags.
- `business_accounts`: Future Business Account and Enterprise Plan ownership.
- `business_account_members`: Future multi-user business membership.

## Corporate Quest

- `corporate_quests`: Future organization-created Quest templates.
- `quest_offers`: Future offer records. These must stay distinct from Star Map
  recommendations and Opportunity Guide content.

## Social Graph

- `constellations`: Future grouping and reputation layer for Navigator Rank.
