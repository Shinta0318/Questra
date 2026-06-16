# Guild Prototype Plan

## Purpose

Guild is the MVP place where users can find lightweight support around shared
Quests, values, and Mission progress. It should strengthen the Quest -> Mission
-> Trail loop without becoming a separate social network.

## MVP Prototype Scope

- Show a small set of Guild entry points from Home and Quest Guide surfaces.
- Help users phrase one clear Mission question they could ask a Guild.
- Surface recent Trail learnings that are safe to share or reflect on.
- Keep Guild language centered on shared Quests, values, Missions, and Trails.
- Preserve private-first defaults until membership and visibility rules are
  implemented.

## Out Of Scope For MVP Prototype

- Direct messages.
- Guild Follow.
- Sponsor Guilds.
- Corporate Quest.
- Public ranking, reputation, or Navigator Rank competition.
- Automatic sharing of private Quest, Mission, Trail, or Arc Memory data.

## Prototype UX

1. Home keeps Guild as a secondary action, not a primary tab.
2. Quest Guide can suggest "ask one clear Guild question" as a Mission.
3. Guild screen starts as an orientation surface with future sections for
   suggested questions, related values, and safe Trail reflections.
4. Any future share action must preview the exact Trail content before posting.

## Data Readiness

- `guilds` and `guild_members` remain reserved boundaries until RLS is ready.
- Quest and Trail visibility must stay private by default.
- Guild-linked Trail display requires explicit user action and membership checks.

## Acceptance Notes

This plan intentionally avoids building broad social features before the core
journey loop is stable. The next Guild implementation QST should start with
read-only orientation and question drafting, not feeds or messaging.
