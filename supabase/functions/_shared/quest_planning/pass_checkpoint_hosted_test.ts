import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { ProviderRequest, ProviderResponse } from "./contracts.ts";
import { runCheckpointedPlanningPass } from "./pass_checkpoint.ts";

const url = Deno.env.get("SUPABASE_URL");
const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const ownerA = Deno.env.get("QST_CHECKPOINT_OWNER_A");
const ownerB = Deno.env.get("QST_CHECKPOINT_OWNER_B");
const questA = Deno.env.get("QST_CHECKPOINT_QUEST_A");
const questB = Deno.env.get("QST_CHECKPOINT_QUEST_B");
if (
  !url || !key || !ownerA || !ownerB || !questA || !questB ||
  !url.startsWith("https://tpynzjjqajpkzivgapfq.supabase.co")
) {
  throw new Error(
    "The isolated validation project and synthetic fixtures are required",
  );
}

const schema = {
  type: "object",
  required: ["desiredOutcome"],
  properties: { desiredOutcome: { type: "string" } },
};

function request(userId: string, idempotencyKey: string): ProviderRequest {
  return {
    operation: "quest_planning.quest_understanding",
    modelRole: "quest_understanding",
    promptVersion: "hosted-checkpoint.v1",
    schemaVersion: "hosted-checkpoint.v1",
    systemInstruction: "Synthetic checkpoint contract test",
    input: { wish: "Play one piano piece" },
    responseSchema: schema,
    idempotencyKey,
    traceId: crypto.randomUUID(),
    userId,
  };
}

function syntheticProvider(request: ProviderRequest): ProviderResponse {
  return {
    provider: "gemini",
    model: "gemini-3.6-flash",
    modelVersion: "gemini-3.6-flash",
    thinkingLevel: "medium",
    output: { desiredOutcome: "Play one complete piano piece" },
    text: "",
    toolCalls: [],
    groundingMetadata: null,
    usage: { inputTokens: 10, outputTokens: 10 },
    latencyMs: 1,
    finishReason: "completed",
    traceId: request.traceId,
    error: null,
  };
}

Deno.test("hosted retry reuses an owner-scoped early planning Pass", async () => {
  let calls = 0;
  const dependencies = { legalGate: async () => "granted" as const };
  const firstRequest = request(ownerA!, "synthetic-attempt-1");
  const first = await runCheckpointedPlanningPass(questA!, firstRequest, () => {
    calls++;
    return Promise.resolve(syntheticProvider(firstRequest));
  }, dependencies);
  assertEquals(first.cacheHit, undefined);

  const retryRequest = request(ownerA!, "synthetic-attempt-2");
  const retry = await runCheckpointedPlanningPass(questA!, retryRequest, () => {
    calls++;
    return Promise.resolve(syntheticProvider(retryRequest));
  }, dependencies);
  assertEquals(retry.cacheHit, true);
  assertEquals(retry.output, first.output);
  assertEquals(retry.usage, {});
  assertEquals(calls, 1);

  const otherRequest = request(ownerB!, "synthetic-attempt-3");
  const other = await runCheckpointedPlanningPass(questB!, otherRequest, () => {
    calls++;
    return Promise.resolve(syntheticProvider(otherRequest));
  }, dependencies);
  assertEquals(other.cacheHit, undefined);
  assertEquals(calls, 2);

  const response = await fetch(
    `${url}/rest/v1/quest_planning_pass_checkpoints?owner_id=eq.${ownerA}&quest_id=eq.${questA}&select=id`,
    { headers: { apikey: key!, Authorization: `Bearer ${key}` } },
  );
  assertEquals(response.ok, true);
  assertEquals((await response.json() as unknown[]).length, 1);
});
