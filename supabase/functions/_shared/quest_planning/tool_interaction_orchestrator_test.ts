import assert from "node:assert/strict";
import test from "node:test";

import type {
  ProviderRequest,
  ProviderResponse,
} from "./contracts.ts";
import { callGeminiInteraction } from "./interactions_adapter.ts";
import { estimateProviderInputTokens } from "./ai_budget_admission.ts";
import { callGeminiInteractionWithTools } from "./tool_interaction_orchestrator.ts";
import { executeQuestraTool } from "./tool_server.ts";

test("adapter sends stateless history and preserves continuation steps", async () => {
  const runtime = globalThis as unknown as Record<string, unknown>;
  const originalDeno = runtime.Deno;
  const originalFetch = globalThis.fetch;
  const providerInputs: unknown[] = [];
  let receiptBody: Record<string, unknown> | null = null;
  const env: Record<string, string> = {
    GEMINI_API_KEY: "test-key",
    SUPABASE_URL: "https://example.supabase.co",
    SUPABASE_SERVICE_ROLE_KEY: "service-role",
  };
  try {
    runtime.Deno = { env: { get: (key: string) => env[key] } };
    globalThis.fetch = (async (input, init) => {
      const url = String(input);
      if (url.endsWith("/rpc/reserve_ai_usage_budget_v2")) {
        return jsonResponse({
          allowed: true,
          reservation_id: "11111111-1111-4111-8111-111111111111",
          reason: "reserved",
        });
      }
      if (url.endsWith("/rpc/record_ai_provider_execution_receipt_v3")) {
        receiptBody = JSON.parse(String(init?.body)) as Record<string, unknown>;
        return jsonResponse({ recorded: true, idempotent: false });
      }
      if (url.endsWith("/rpc/settle_ai_usage_budget")) {
        return jsonResponse({ settled: true });
      }
      if (url.includes("generativelanguage.googleapis.com")) {
        const body = JSON.parse(String(init?.body)) as Record<string, unknown>;
        providerInputs.push(body.input);
        return jsonResponse({
          id: "interaction-1",
          status: "requires_action",
          steps: [{
            type: "function_call",
            id: "call-1",
            name: "get_quest_context",
            arguments: { questId: "quest-1" },
            signature: "keep-exactly",
          }],
          usage: { total_input_tokens: 10, total_output_tokens: 4 },
        });
      }
      throw new Error(`Unexpected URL: ${url}`);
    }) as typeof fetch;

    const value = request();
    value.interactionHistory = [{
      type: "user_input",
      content: [{ type: "text", text: "hello" }],
    }];
    const result = await callGeminiInteraction(value);

    assert.deepEqual(providerInputs[0], value.interactionHistory);
    assert.equal(result.finishReason, "requires_action");
    assert.equal(result.toolCalls[0].name, "get_quest_context");
    assert.equal(receiptBody?.p_grounding_query_count, 0);
    assert.equal(receiptBody?.p_thinking_level, "high");
    assert.deepEqual(result.continuation?.steps, [{
      type: "function_call",
      id: "call-1",
      name: "get_quest_context",
      arguments: { questId: "quest-1" },
      signature: "keep-exactly",
    }]);
  } finally {
    globalThis.fetch = originalFetch;
    if (originalDeno === undefined) delete runtime.Deno;
    else runtime.Deno = originalDeno;
  }
});

test("budget estimate includes stateless continuation history", () => {
  const initial = request();
  const continued = request();
  continued.interactionHistory = [
    { type: "user_input", content: [{ type: "text", text: "hello" }] },
    {
      type: "function_call",
      id: "call-1",
      name: "get_quest_context",
      arguments: { questId: "quest-1" },
    },
    {
      type: "function_result",
      call_id: "call-1",
      name: "get_quest_context",
      result: [{ type: "text", text: "x".repeat(4000) }],
    },
  ];

  assert.ok(
    estimateProviderInputTokens(continued) >
      estimateProviderInputTokens(initial) + 500,
  );
});

test("provider-backed multi-turn fallback finalizes exact aggregate cost attribution", async () => {
  const runtime = globalThis as unknown as Record<string, unknown>;
  const originalDeno = runtime.Deno;
  const originalFetch = globalThis.fetch;
  const attributionBodies: Record<string, unknown>[] = [];
  const providerModels: string[] = [];
  let reservationCount = 0;
  let providerCall = 0;
  let finalizedBody: Record<string, unknown> | null = null;
  const env: Record<string, string> = {
    GEMINI_API_KEY: "test-key",
    SUPABASE_URL: "https://example.supabase.co",
    SUPABASE_SERVICE_ROLE_KEY: "service-role",
    AI_TOOL_CONTINUATION_ATTRIBUTION_ENABLED: "true",
    AI_RECEIPT_BINDING_ENABLED: "false",
  };
  try {
    runtime.Deno = { env: { get: (key: string) => env[key] } };
    globalThis.fetch = (async (input, init) => {
      const url = String(input);
      const body = init?.body
        ? JSON.parse(String(init.body)) as Record<string, unknown>
        : {};
      if (url.endsWith("/rpc/start_ai_tool_continuation_attribution")) {
        attributionBodies.push(body);
        return jsonResponse({
          started: true,
          run_id: "22222222-2222-4222-8222-222222222222",
          status: "running",
        });
      }
      if (url.endsWith("/rpc/reserve_ai_usage_budget_v2")) {
        reservationCount++;
        return jsonResponse({
          allowed: true,
          reservation_id: reservationCount === 1
            ? "11111111-1111-4111-8111-111111111111"
            : "33333333-3333-4333-8333-333333333333",
          reason: "reserved",
        });
      }
      if (url.endsWith("/rpc/reserve_ai_grounding_budget")) {
        return jsonResponse({ allowed: true, reason: "reserved" });
      }
      if (url.endsWith("/rpc/record_ai_provider_execution_receipt_v3")) {
        return jsonResponse({ recorded: true, idempotent: false });
      }
      if (url.endsWith("/rpc/settle_ai_usage_budget")) {
        return jsonResponse({ settled: true });
      }
      if (url.endsWith("/rpc/record_ai_tool_continuation_turn")) {
        attributionBodies.push(body);
        return jsonResponse({ recorded: true, idempotent: false });
      }
      if (url.endsWith("/rpc/finalize_ai_tool_continuation_attribution")) {
        finalizedBody = body;
        attributionBodies.push(body);
        return jsonResponse({ completed: true, idempotent: false });
      }
      if (url.endsWith("/rpc/fail_ai_tool_continuation_attribution")) {
        throw new Error("Successful drill must not fail attribution");
      }
      if (url.includes("generativelanguage.googleapis.com")) {
        providerCall++;
        providerModels.push(String(body.model));
        if (providerCall === 2) {
          return jsonResponse({ error: { message: "temporary outage" } }, 503);
        }
        if (providerCall === 1) {
          return jsonResponse({
            id: "interaction-turn-0",
            status: "requires_action",
            steps: [
              {
                type: "google_search_call",
                id: "search-0",
                status: "completed",
                query: "official entry requirements",
              },
              {
                type: "function_call",
                id: "call-1",
                name: "get_quest_context",
                arguments: { questId: "quest-1" },
                signature: "signed-continuation",
              },
            ],
            usage: { total_input_tokens: 10, total_output_tokens: 4 },
          });
        }
        return jsonResponse({
          id: "interaction-turn-1",
          status: "completed",
          output_text: '{"phases":["prepare"]}',
          steps: [{
            type: "google_search_call",
            id: "search-1",
            status: "completed",
            query: "official entry requirements",
          }],
          usage: { total_input_tokens: 14, total_output_tokens: 8 },
        });
      }
      throw new Error(`Unexpected URL: ${url}`);
    }) as typeof fetch;

    const requestValue = request();
    requestValue.tools = [
      ...requestValue.tools ?? [],
      { type: "google_search" },
    ];
    const result = await callGeminiInteractionWithTools(
      requestValue,
      { userId: "user-1" },
      {},
      {
        executeTool: async () => ({
          ok: true,
          data: { title: "private-tool-result-must-not-enter-cost-ledger" },
        }),
      },
    );

    assert.equal(result.error, null);
    assert.deepEqual(result.usage, {
      inputTokens: 24,
      outputTokens: 12,
      generatedOutputTokens: 12,
      thoughtTokens: 0,
      groundingQueries: 2,
    });
    assert.equal(result.groundingMetadata?.billableQueryCount, 2);
    assert.deepEqual(result.groundingMetadata?.queries, [
      "official entry requirements",
    ]);
    assert.equal(reservationCount, 2);
    assert.equal(providerModels.length, 3);
    assert.notEqual(providerModels[1], providerModels[2]);
    const turnBodies = attributionBodies.filter((item) =>
      Object.hasOwn(item, "p_turn_number")
    );
    assert.equal(turnBodies.length, 2);
    assert.deepEqual(turnBodies[0].p_attempted_models, [providerModels[0]]);
    assert.deepEqual(turnBodies[1].p_attempted_models, [
      providerModels[1],
      providerModels[2],
    ]);
    assert.deepEqual(finalizedBody, {
      p_run_id: "22222222-2222-4222-8222-222222222222",
      p_total_input_tokens: 24,
      p_total_output_tokens: 12,
      p_total_grounding_query_count: 2,
    });
    assert.doesNotMatch(
      JSON.stringify(attributionBodies),
      /private-tool-result-must-not-enter-cost-ledger/,
    );
  } finally {
    globalThis.fetch = originalFetch;
    if (originalDeno === undefined) delete runtime.Deno;
    else runtime.Deno = originalDeno;
  }
});

test("tool server rejects arguments outside the registered schema", async () => {
  const runtime = globalThis as unknown as Record<string, unknown>;
  const originalDeno = runtime.Deno;
  const originalFetch = globalThis.fetch;
  let ownershipReads = 0;
  try {
    runtime.Deno = {
      env: {
        get: (key: string) => key === "SUPABASE_URL"
          ? "https://example.supabase.co"
          : "service-role",
      },
    };
    globalThis.fetch = (async (input) => {
      if (String(input).includes("/rest/v1/quests?")) ownershipReads++;
      return jsonResponse({ logged: true });
    }) as typeof fetch;

    const result = await executeQuestraTool(
      "get_quest_context",
      { questId: "", unexpected: true },
      { userId: "user-1", traceId: "trace-1", approved: false },
    );

    assert.equal(result.error, "invalid_arguments");
    assert.equal(ownershipReads, 0);
  } finally {
    globalThis.fetch = originalFetch;
    if (originalDeno === undefined) delete runtime.Deno;
    else runtime.Deno = originalDeno;
  }
});

test("executes owner-scoped read tool and continues stateless interaction", async () => {
  const providerRequests: ProviderRequest[] = [];
  const executed: string[] = [];
  const responses = [
    response({
      finishReason: "requires_action",
      toolCalls: [{
        id: "call-1",
        name: "get_quest_context",
        arguments: { questId: "quest-1" },
      }],
      continuation: {
        steps: [{
          type: "function_call",
          id: "call-1",
          name: "get_quest_context",
          arguments: { questId: "quest-1" },
          signature: "provider-signature",
        }],
      },
      groundingMetadata: {
        queries: ["entry requirements"],
        sources: [{ uri: "https://example.gov/entry", title: "Entry" }],
      },
      usage: { inputTokens: 5, outputTokens: 3 },
    }),
    response({
      output: { phases: ["prepare"] },
      text: "{\"phases\":[\"prepare\"]}",
      groundingMetadata: {
        queries: ["official travel requirements"],
        sources: [{ uri: "https://example.gov/travel", title: "Official" }],
      },
      usage: { inputTokens: 7, outputTokens: 11 },
    }),
  ];

  const result = await callGeminiInteractionWithTools(
    request(),
    { userId: "user-1" },
    {},
    {
      callProvider: async (value) => {
        providerRequests.push(value);
        return responses.shift()!;
      },
      executeTool: async (name, args, context) => {
        executed.push(name);
        assert.equal(context.approved, false);
        assert.equal(args.questId, "quest-1");
        return { ok: true, data: [{ id: "quest-1", title: "Singapore" }] };
      },
    },
  );

  assert.deepEqual(executed, ["get_quest_context"]);
  assert.equal(providerRequests.length, 2);
  assert.equal(providerRequests[1].idempotencyKey, "test-request:tool-turn-1");
  const history = providerRequests[1].interactionHistory as Record<string, unknown>[];
  assert.equal(history[0].type, "user_input");
  assert.equal(history[1].type, "function_call");
  assert.equal(history[1].signature, "provider-signature");
  assert.equal(history[2].type, "function_result");
  assert.equal(history[2].call_id, "call-1");
  assert.deepEqual(result.output, { phases: ["prepare"] });
  assert.equal(result.continuation, undefined);
  assert.deepEqual(result.usage, { inputTokens: 12, outputTokens: 14 });
  assert.deepEqual(result.groundingMetadata?.queries, [
    "entry requirements",
    "official travel requirements",
  ]);
  assert.equal(result.groundingMetadata?.billableQueryCount, 2);
});

test("blocks write tools before execution", async () => {
  let executions = 0;
  const result = await callGeminiInteractionWithTools(
    request(),
    { userId: "user-1", approved: true },
    {},
    {
      callProvider: async () => response({
        finishReason: "requires_action",
        toolCalls: [{
          id: "call-write",
          name: "approve_plan_transaction",
          arguments: { previewId: "preview-1", approvalToken: "token-1" },
        }],
        continuation: { steps: [{ type: "function_call" }] },
      }),
      executeTool: async () => {
        executions++;
        return { ok: true };
      },
    },
  );

  assert.equal(executions, 0);
  assert.equal(result.error?.code, "tool_failed");
  assert.match(result.error?.message ?? "", /explicit user approval flow/);
});

test("stops repeated tool-call cycles", async () => {
  let providerCalls = 0;
  let executions = 0;
  const toolCall = {
    id: "call-repeat",
    name: "get_quest_context",
    arguments: { questId: "quest-1" },
  };
  const result = await callGeminiInteractionWithTools(
    request(),
    { userId: "user-1" },
    {},
    {
      callProvider: async () => {
        providerCalls++;
        return response({
          finishReason: "requires_action",
          toolCalls: [{ ...toolCall, id: `call-${providerCalls}` }],
          continuation: { steps: [{ type: "function_call" }] },
        });
      },
      executeTool: async () => {
        executions++;
        return { ok: true, data: [] };
      },
    },
  );

  assert.equal(providerCalls, 2);
  assert.equal(executions, 1);
  assert.match(result.error?.message ?? "", /cycle/);
});

test("maxTurns counts the initial provider turn and never exceeds the five-turn ledger", async () => {
  let providerCalls = 0;
  const result = await callGeminiInteractionWithTools(
    request(),
    { userId: "user-1" },
    { maxTurns: 5, maxToolCalls: 12 },
    {
      callProvider: async () => {
        providerCalls++;
        return response({
          finishReason: "requires_action",
          toolCalls: [{
            id: `call-${providerCalls}`,
            name: "get_quest_context",
            arguments: { questId: `quest-${providerCalls}` },
          }],
          continuation: { steps: [{ type: "function_call" }] },
        });
      },
      executeTool: async () => ({ ok: true, data: [] }),
    },
  );

  assert.equal(providerCalls, 5);
  assert.equal(result.error?.code, "tool_failed");
  assert.match(result.error?.message ?? "", /continuation limit/);
});

function request(): ProviderRequest {
  return {
    operation: "quest_planning.strategic_plan",
    modelRole: "strategic_planner",
    promptVersion: "test-v1",
    schemaVersion: "test-v1",
    systemInstruction: "Return a plan.",
    input: { wish: "シンガポールへ行きたい" },
    responseSchema: { type: "object" },
    tools: [{
      type: "function",
      name: "get_quest_context",
      parameters: { type: "object" },
    }],
    idempotencyKey: "test-request",
    traceId: "trace-1",
    userId: "user-1",
  };
}

function response(overrides: Partial<ProviderResponse>): ProviderResponse {
  return {
    provider: "gemini",
    model: "gemini-3.6-flash",
    modelVersion: "gemini-3.6-flash",
    thinkingLevel: "high",
    output: null,
    text: "",
    toolCalls: [],
    groundingMetadata: null,
    usage: {},
    latencyMs: 10,
    finishReason: "completed",
    traceId: "trace-1",
    error: null,
    ...overrides,
  };
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
