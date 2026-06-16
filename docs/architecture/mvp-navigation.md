# MVP Navigation

Questra's MVP navigation stays Quest-centered while keeping Arc present as a
guide.

## Primary Screens

- Home
- Quest
- Mission
- Trail
- Guild
- Arc Chat
- Profile

## Bottom Navigation

The MVP bottom navigation uses five stable tabs:

1. Home
2. Quest
3. Arc
4. Trail
5. Mission

Arc stays centered and visually emphasized. Guild and Profile are routed from
Home action cards and can later move into a drawer, top action, or expanded
navigation pattern if product usage shows they need permanent tab placement.

## Route Policy

- Home is the dashboard for today's Mission, Quest progress, recent Trail, Arc,
  Guild, and Profile entry points.
- Quest is the main creation and detail surface.
- Quest Detail owns the deepest MVP loop: Guide -> Mission -> Trail.
- Mission is the user's focused action list.
- Trail is the user's journey record, not a temporary post format.
- Guild is a place for people sharing Quests or values.
- Arc Chat is the companion conversation surface.
- Profile contains identity and settings entry points.

## MVP Scope Check

This structure is enough for the MVP because it exposes the core loop without
requiring future systems such as DM, Guild Follow, Corporate Quest, Quest Offer,
or Premium to be implemented now.

Guild prototype scope is defined in
`docs/product/guild_prototype_plan.md`; broader social features remain reserved
until the core journey loop and access rules are stable.
