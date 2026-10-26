import { assert, assertEquals, assertNotEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { planningPassIdempotencyKey } from "./pass_idempotency.ts";

Deno.test("same pass input retains its reservation identity", async () => {
  const first = await planningPassIdempotencyKey("retry-1", "mission_critic", {
    plan: { title: "Learn piano", missions: ["practice"] },
    promptVersion: 4,
  });
  const reordered = await planningPassIdempotencyKey("retry-1", "mission_critic", {
    promptVersion: 4,
    plan: { missions: ["practice"], title: "Learn piano" },
  });
  assertEquals(first, reordered);
});

Deno.test("repaired plan gets a distinct critic reservation", async () => {
  const before = await planningPassIdempotencyKey("retry-1", "mission_critic", {
    plan: { missions: ["practice"] },
  });
  const after = await planningPassIdempotencyKey("retry-1", "mission_critic", {
    plan: { missions: ["play a complete piece"] },
  });
  assertNotEquals(before, after);
  assertNotEquals(
    before,
    await planningPassIdempotencyKey("retry-1", "task_critic", {
      plan: { missions: ["practice"] },
    }),
  );
});

Deno.test("reservation identity remains within budget ledger limit", async () => {
  const key = await planningPassIdempotencyKey(
    "x".repeat(176),
    "mission_granularity_classifier",
    { plan: "example" },
  );
  assert(key.length >= 8 && key.length + ":tool-turn-9".length <= 240);
});
