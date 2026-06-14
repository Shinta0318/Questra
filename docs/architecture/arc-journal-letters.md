# Arc Journal And Arc Letters Preparation

Arc Journal and Arc Letters are future Arc experiences. They should build on
Arc Memory, Quest progress, Mission completion, and Trail records without
requiring a rewrite of the MVP schema.

## Arc Journal

Arc Journal creates reflective entries from the user's journey.

Inputs:

- Quest progress
- Mission completion
- Trail posts
- Arc Memory
- emotional tone

MVP table:

- `journal_entries`

Important fields:

- `user_id`
- `related_quest_id`
- `related_memory_ids`
- `related_trail_ids`
- `title`
- `body`
- `status`
- `generated_by`
- `metadata`

## Arc Letters

Arc Letters are weekly, monthly, milestone, or manual letters from Arc to the
user.

MVP table:

- `arc_letters`

Important fields:

- `user_id`
- `related_quest_id`
- `related_memory_ids`
- `related_trail_ids`
- `letter_type`
- `delivery_status`
- `scheduled_for`
- `sent_at`
- `read_at`

## Generation Logs

`generation_logs` records generation attempts for Arc Journal, Arc Letters,
Arc Advice, Mission generation, and Quest Guide generation.

It should store operational metadata and errors, but not raw secrets or
unnecessary sensitive content.

## Done Later

- Real generation pipeline
- Scheduling workers
- Email and push delivery
- Letter templates
- User controls for frequency and opt-out
- Retrospective summaries
- Semantic retrieval over `arc_memories.embedding`
