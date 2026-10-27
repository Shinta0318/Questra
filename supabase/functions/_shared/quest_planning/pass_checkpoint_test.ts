import {
  assert,
  assertEquals,
  assertNotEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { ProviderRequest, ProviderResponse } from "./contracts.ts";
import {
  planningCheckpointFingerprint,
  planningModelPayload,
  runCheckpointedPlanningPass,
} from "./pass_checkpoint.ts";

const questId = "00000000-0000-4000-8000-000000000001";
const userId = "00000000-0000-4000-8000-000000000002";
const schema = {
  type: "object",
  required: ["result"],
  properties: { result: { type: "string" } },
};

function request(
  key = "attempt-1",
  input: unknown = { wish: "Learn piano" },
): ProviderRequest {
  return {
    operation: "quest_planning.quest_understanding",
    modelRole: "quest_understanding",
    promptVersion: "quest_understanding.v2",
    schemaVersion: "test-1",
    systemInstruction: "Understand this Quest",
    input,
    responseSchema: schema,
    idempotencyKey: key,
    traceId: "00000000-0000-4000-8000-000000000003",
    userId,
  };
}

function providerResponse(
  output: unknown = { result: "Plan" },
): ProviderResponse {
  return {
    provider: "gemini",
    model: "gemini-3.6-flash",
    modelVersion: "gemini-3.6-flash",
    thinkingLevel: "medium",
    output,
    text: "",
    toolCalls: [],
    groundingMetadata: null,
    usage: { inputTokens: 20, outputTokens: 10 },
    latencyMs: 100,
    finishReason: "completed",
    traceId: request().traceId,
    error: null,
  };
}

Deno.test("operational identifiers never enter the model payload", () => {
  assertEquals(
    planningModelPayload({
      wish: "Learn piano",
      idempotencyKey: "private-attempt",
      approvedContext: { userId, answer: "30 minutes" },
      nested: [{ abuseKeyHash: "private-hash", goal: "play a song" }],
    }),
    {
      wish: "Learn piano",
      approvedContext: { answer: "30 minutes" },
      nested: [{ goal: "play a song" }],
    },
  );
});

Deno.test("fingerprint follows content and execution settings, not retry key", async () => {
  const first = await planningCheckpointFingerprint(request("attempt-1"));
  assertEquals(
    first,
    await planningCheckpointFingerprint(request("attempt-2")),
  );
  assertNotEquals(
    first,
    await planningCheckpointFingerprint(
      request("attempt-2", { wish: "Run a marathon" }),
    ),
  );
  assertNotEquals(
    first,
    await planningCheckpointFingerprint({
      ...request(),
      promptVersion: "quest_understanding.v3",
    }),
  );
});

Deno.test("validated checkpoint is reused only for the same owner and Quest", async () => {
  const originalUrl = Deno.env.get("SUPABASE_URL");
  const originalKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  Deno.env.set("SUPABASE_URL", "https://example.supabase.co");
  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "test-service-key");
  let stored: Record<string, unknown> | null = null;
  let providerCalls = 0;
  const fetchImpl: typeof fetch = (_url, init) => {
    if (String(_url).includes("/ai_operation_controls?")) {
      return Promise.resolve(Response.json([{ operation: "quest_planning" }]));
    }
    if (init?.method === "POST") {
      stored = JSON.parse(String(init.body));
      return Promise.resolve(new Response(null, { status: 201 }));
    }
    const url = new URL(String(_url));
    const visible = stored &&
      url.searchParams.get("owner_id") === `eq.${stored.owner_id}` &&
      url.searchParams.get("quest_id") === `eq.${stored.quest_id}` &&
      url.searchParams.get("input_fingerprint") ===
        `eq.${stored.input_fingerprint}`;
    return Promise.resolve(Response.json(visible ? [stored] : []));
  };
  const deps = { fetchImpl, legalGate: async () => "granted" as const };
  const invoke = () => {
    providerCalls++;
    return Promise.resolve(providerResponse());
  };
  try {
    const first = await runCheckpointedPlanningPass(
      questId,
      request(),
      invoke,
      deps,
    );
    assertEquals(first.cacheHit, undefined);
    const second = await runCheckpointedPlanningPass(
      questId,
      request("attempt-2"),
      invoke,
      deps,
    );
    assertEquals(second.cacheHit, true);
    assertEquals(second.usage, {});
    assertEquals(providerCalls, 1);
    await runCheckpointedPlanningPass(
      "00000000-0000-4000-8000-000000000004",
      request(),
      invoke,
      deps,
    );
    await runCheckpointedPlanningPass(
      questId,
      { ...request(), userId: "00000000-0000-4000-8000-000000000005" },
      invoke,
      deps,
    );
    assertEquals(providerCalls, 3);
  } finally {
    restore("SUPABASE_URL", originalUrl);
    restore("SUPABASE_SERVICE_ROLE_KEY", originalKey);
  }
});

Deno.test("revoked consent and stale or invalid checkpoints cannot be reused", async () => {
  const originalUrl = Deno.env.get("SUPABASE_URL");
  const originalKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  Deno.env.set("SUPABASE_URL", "https://example.supabase.co");
  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "test-service-key");
  let reads = 0;
  let calls = 0;
  const fetchImpl: typeof fetch = (url) => {
    if (String(url).includes("/ai_operation_controls?")) {
      return Promise.resolve(Response.json([{ operation: "quest_planning" }]));
    }
    reads++;
    return Promise.resolve(Response.json([{
      output: { wrong: "shape" },
      provider_metadata: {
        provider: "gemini",
        model: "gemini-3.6-flash",
        modelVersion: "gemini-3.6-flash",
        thinkingLevel: "medium",
      },
    }]));
  };
  const invoke = () => {
    calls++;
    return Promise.resolve(providerResponse({ wrong: "shape" }));
  };
  try {
    await runCheckpointedPlanningPass(questId, request(), invoke, {
      fetchImpl,
      legalGate: async () => "denied" as const,
    });
    assertEquals(reads, 0);
    await runCheckpointedPlanningPass(questId, request(), invoke, {
      fetchImpl,
      legalGate: async () => "granted" as const,
    });
    assertEquals(reads, 1);
    assertEquals(calls, 2);
  } finally {
    restore("SUPABASE_URL", originalUrl);
    restore("SUPABASE_SERVICE_ROLE_KEY", originalKey);
  }
});

Deno.test("AI operation kill switch prevents cached output from bypassing admission", async () => {
  const originalUrl = Deno.env.get("SUPABASE_URL");
  const originalKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  Deno.env.set("SUPABASE_URL", "https://example.supabase.co");
  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "test-service-key");
  let providerCalls = 0;
  try {
    const response = await runCheckpointedPlanningPass(
      questId,
      request(),
      () => {
        providerCalls++;
        return Promise.resolve({
          ...providerResponse(null),
          error: {
            code: "ai_disabled" as const,
            retryable: false,
            message: "AI disabled",
          },
        });
      },
      {
        legalGate: async () => "granted" as const,
        fetchImpl: (url) => {
          assert(String(url).includes("/ai_operation_controls?"));
          return Promise.resolve(Response.json([]));
        },
      },
    );
    assertEquals(response.cacheHit, undefined);
    assertEquals(response.error?.code, "ai_disabled");
    assertEquals(providerCalls, 1);
  } finally {
    restore("SUPABASE_URL", originalUrl);
    restore("SUPABASE_SERVICE_ROLE_KEY", originalKey);
  }
});

Deno.test("tool-backed Passes are never checkpointed", async () => {
  let calls = 0;
  const withTools: ProviderRequest = {
    ...request(),
    tools: [{ type: "function", name: "get_quest_context" }],
  };
  const invoke = () => {
    calls++;
    return Promise.resolve(providerResponse());
  };
  const result = await runCheckpointedPlanningPass(questId, withTools, invoke, {
    fetchImpl: () => {
      throw new Error("checkpoint access forbidden");
    },
    legalGate: async () => {
      throw new Error("checkpoint gate access forbidden");
    },
  });
  assertEquals(calls, 1);
  assert(!result.cacheHit);
});

Deno.test("Mission candidates are not reused before domain validation", async () => {
  let calls = 0;
  const missionRequest = {
    ...request(),
    operation: "quest_planning.route_mission_generation",
  };
  const invoke = () => {
    calls++;
    return Promise.resolve(providerResponse());
  };
  const deps = {
    fetchImpl: () => {
      throw new Error("checkpoint access forbidden");
    },
    legalGate: async () => {
      throw new Error("checkpoint gate access forbidden");
    },
  };
  await runCheckpointedPlanningPass(questId, missionRequest, invoke, deps);
  await runCheckpointedPlanningPass(questId, missionRequest, invoke, deps);
  assertEquals(calls, 2);
});

function restore(key: string, original: string | undefined) {
  if (original === undefined) Deno.env.delete(key);
  else Deno.env.set(key, original);
}
