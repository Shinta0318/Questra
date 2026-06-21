# Final Screenshot QA

## Purpose

Questra needs a repeatable screenshot pass before internal beta expansion and
before any public store review. Screenshots are evidence for design quality,
terminology, Arc framing, and route stability.

## Required Screens

| Screen | Required State | Notes |
| --- | --- | --- |
| Home | Returning user with active Quest and Arc daily greeting | Japanese copy, Arc visible, no Story wording |
| Quest List | Multiple active Quests | Progress and Quest labels fit on mobile |
| Quest Detail | Quest with Arc Guide and Mission candidates | Candidate adoption controls visible |
| Mission | Open and completed Mission states | Completion path should be visually clear |
| Trail | Recent Trails and reflection entry | Trail terminology only |
| Guild | Draft question from Quest/Mission context | Safe sharing language visible |
| Arc Chat | Thinking state and completed response | Arc is a navigator/companion, not an assistant |
| Arc Memory | Visible memories with importance/recency | No private data from other profiles |
| Profile | Bond, Stardust, Navigator Rank | Progression labels fit on small screens |
| Media | Trail image attached and replace/remove controls | No broken image placeholders |

## Viewports

- Mobile narrow: 360 x 800.
- Mobile common: 390 x 844.
- Tablet sanity: 768 x 1024.
- Web sanity: 1280 x 800.

## Pass Criteria

- No visible `Story` product terminology.
- Arc is not described as an AI assistant.
- Japanese UI copy fits without clipping.
- Arc PNG assets render instead of placeholder fallback.
- Primary CTA is visible on Home, Quest creation, Mission completion, and Trail reflection flows.
- No white default Flutter template surfaces appear in core flows.
- No obvious overflow, clipped text, or incoherent overlap.
- Screenshots include build commit and viewport in filename or capture notes.

## Output Location

Save screenshots under:

```text
reports/screenshots/<build-commit>/
```

Suggested filenames:

- `home-390x844.png`
- `quest-list-390x844.png`
- `quest-detail-guide-390x844.png`
- `mission-completion-390x844.png`
- `trail-reflection-390x844.png`
- `guild-draft-390x844.png`
- `arc-chat-thinking-390x844.png`
- `arc-memory-390x844.png`
- `profile-390x844.png`
- `media-trail-image-390x844.png`

## Stop Conditions

- Any core screen crashes.
- Any required screen cannot be reached.
- Story appears in user-facing UI.
- Arc is framed as an AI assistant.
- Text overlap blocks a primary action.
- Arc image fails to render on Home or Arc Chat.
