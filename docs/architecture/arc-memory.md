# Arc Memory

Arc Memory is Questra's long-term structured memory system. It is not chat
history. It stores durable context from a user's Quest, Mission, Trail,
emotional tone, values, and important life events so Arc can make contextual
suggestions later.

## MVP Memory Types

- `quest_memory`: Durable context about a Quest.
- `mission_memory`: Mission creation, completion, and learning signals.
- `trail_memory`: Challenge records, achievement records, and lived experience.
- `preference_memory`: User values, preferences, and dislikes.
- `emotional_memory`: Meaningful emotional shifts.
- `life_event_memory`: Important personal milestones.
- `arc_relationship_memory`: How the user relates to Arc and wants Arc to help.

## Database Shape

The `arc_memories` table links memory back to Questra context:

- `user_id`
- `quest_id`
- `mission_id`
- `trail_id`
- `memory_type`
- `title`
- `content`
- `importance_score`
- `emotional_tone`
- `source_type`
- `source_id`
- `embedding`
- `metadata`
- `sensitivity_level`
- `user_visible`

`embedding` is nullable in MVP. The schema reserves `vector(1536)` so pgvector
similarity search can be added without changing the memory contract.

## Extraction Rules

`MemoryExtractionService` receives events such as:

- Quest created
- Quest updated
- Mission created
- Mission completed
- Trail posted
- Arc chat
- Guild post

It creates a memory candidate only when the event appears durable: connected to
a Quest/Mission/Trail, emotionally meaningful, preference-bearing, life-event
related, or useful for Arc's future relationship with the user.

## Privacy Notes

MVP extraction redacts email addresses and phone-like strings before saving. It
also assigns a `sensitivity_level`. Sensitive memories are saved with
`user_visible = false` so future UX can require explicit review before display
or reuse.

Future work should add:

- explicit user controls for memory review/deletion
- LLM-assisted extraction with the same schema contract
- embedding generation jobs
- Supabase RLS policies scoped to `auth.uid()`
- Arc Journal, Arc Letters, and Quest Retrospective readers over this table
