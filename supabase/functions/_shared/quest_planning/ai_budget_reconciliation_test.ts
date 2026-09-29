import assert from "node:assert/strict";
import test from "node:test";

import {
  reserveAiBudget,
  settleAiBudget,
  verifiedGroundingQueryCount,
} from "./ai_budget_admission.ts";
import type { ProviderRequest, ProviderResponse } from "./contracts.ts";

test("lost settlement response reconciles from recorded provider receipt", async () => {
  const runtime = globalThis as unknown as Record<string, unknown>;
  const originalDeno = runtime.Deno;
  const originalFetch = globalThis.fetch;
  let settlementAttempts = 0;
  let reconciliationAttempts = 0;
  let receiptBody: Record<string, unknown> | null = null;
  try {
    installDeno(runtime);
    globalThis.fetch = (async (input, init) => {
      const url = String(input);
      if (url.endsWith("/rpc/record_ai_provider_execution_receipt_v3")) {
        receiptBody = JSON.parse(String(init?.body)) as Record<string, unknown>;
        return jsonResponse({ recorded: true, idempotent: false });
      }
      if (url.endsWith("/rpc/settle_ai_usage_budget")) {
        settlementAttempts++;
        throw new Error("response lost after provider success");
      }
      if (url.endsWith("/rpc/reconcile_ai_usage_budget")) {
        reconciliationAttempts++;
        return jsonResponse({ reconciled: true, idempotent: true });
      }
      throw new Error(`Unexpected URL: ${url}`);
    }) as typeof fetch;

    finalAssert(await settleAiBudget("reservation-1", response()), true);
    assert.equal(settlementAttempts, 2);
    assert.equal(reconciliationAttempts, 1);
    assert.equal(receiptBody?.p_provider_interaction_id, "interaction-1");
    assert.equal(receiptBody?.p_input_tokens, 123);
    assert.equal(receiptBody?.p_output_tokens, 45);
    assert.equal(receiptBody?.p_grounding_query_count, 0);
    assert.equal(receiptBody?.p_thinking_level, "high");
  } finally {
    globalThis.fetch = originalFetch;
    restoreDeno(runtime, originalDeno);
  }
});

test("receipt conflict stops settlement and leaves operator review", async () => {
  const runtime = globalThis as unknown as Record<string, unknown>;
  const originalDeno = runtime.Deno;
  const originalFetch = globalThis.fetch;
  let settlementCalls = 0;
  try {
    installDeno(runtime);
    globalThis.fetch = (async (input) => {
      const url = String(input);
      if (url.endsWith("/rpc/record_ai_provider_execution_receipt_v3")) {
        return jsonResponse({
          recorded: false,
          reason: "provider_execution_receipt_conflict",
          operator_review: true,
        });
      }
      if (url.endsWith("/rpc/settle_ai_usage_budget")) settlementCalls++;
      throw new Error(`Unexpected URL: ${url}`);
    }) as typeof fetch;

    finalAssert(await settleAiBudget("reservation-1", response()), false);
    assert.equal(settlementCalls, 0);
  } finally {
    globalThis.fetch = originalFetch;
    restoreDeno(runtime, originalDeno);
  }
});

test("grounding cost uses only a verified unique provider query count", () => {
  assert.equal(verifiedGroundingQueryCount(null), 0);
  assert.equal(
    verifiedGroundingQueryCount({
      queries: ["singapore visa", " singapore visa ", "official entry"],
      billableQueryCount: 2,
    }),
    2,
  );
  assert.equal(
    verifiedGroundingQueryCount({
      queries: ["singapore visa"],
      billableQueryCount: 2,
    }),
    null,
  );
  assert.equal(
    verifiedGroundingQueryCount({ billableQueryCount: 1 }),
    null,
  );
  assert.equal(
    verifiedGroundingQueryCount({
      queries: ["official entry", 42],
      billableQueryCount: 1,
    }),
    null,
  );
});

test("enabled receipt binding uses a deterministic nonce and v4 receipt", async () => {
  const runtime = globalThis as unknown as Record<string, unknown>;
  const originalDeno = runtime.Deno;
  const originalFetch = globalThis.fetch;
  let reserveBody: Record<string, unknown> | null = null;
  let receiptBody: Record<string, unknown> | null = null;
  try {
    const env: Record<string, string> = {
      SUPABASE_URL: "https://example.supabase.co",
      SUPABASE_SERVICE_ROLE_KEY: "service-role",
      AI_RECEIPT_BINDING_ENABLED: "true",
      AI_RECEIPT_NONCE_SECRET: "a-test-secret-with-at-least-32-characters",
      AI_BUDGET_RPC_TIMEOUT_MS: "500",
    };
    runtime.Deno = { env: { get: (key: string) => env[key] } };
    globalThis.fetch = (async (input, init) => {
      const url = String(input);
      const body = JSON.parse(String(init?.body)) as Record<string, unknown>;
      if (url.endsWith("/rpc/reserve_ai_usage_budget_v3")) {
        reserveBody = body;
        return jsonResponse({
          allowed: true,
          reservation_id: "reservation-bound",
          reason: "reserved",
          receipt_binding: true,
          model_route_digest: body.p_model_route_digest,
        });
      }
      if (url.endsWith("/rpc/record_ai_provider_execution_receipt_v4")) {
        receiptBody = body;
        return jsonResponse({ recorded: true, idempotent: false });
      }
      if (url.endsWith("/rpc/settle_ai_usage_budget")) {
        return jsonResponse({ settled: true });
      }
      throw new Error(`Unexpected URL: ${url}`);
    }) as typeof fetch;

    const reservation = await reserveAiBudget(providerRequest(), [
      "gemini-3.6-flash",
      "gemini-3.5-flash",
    ]);
    assert.equal(reservation.allowed, true);
    assert.match(String(reserveBody?.p_receipt_nonce_hash), /^[0-9a-f]{64}$/);
    assert.match(String(reserveBody?.p_model_route_digest), /^[0-9a-f]{64}$/);
    assert.match(reservation.receiptBinding?.nonce ?? "", /^[0-9a-f]{64}$/);
    assert.equal(
      await settleAiBudget(
        reservation.reservationId!,
        response(),
        reservation.receiptBinding,
      ),
      true,
    );
    assert.equal(receiptBody?.p_operation, "quest_planning");
    assert.equal(
      receiptBody?.p_model_route_digest,
      reserveBody?.p_model_route_digest,
    );
    assert.equal(receiptBody?.p_receipt_nonce, reservation.receiptBinding?.nonce);
  } finally {
    globalThis.fetch = originalFetch;
    restoreDeno(runtime, originalDeno);
  }
});

function response(): ProviderResponse {
  return {
    provider: "gemini",
    providerInteractionId: "interaction-1",
    model: "gemini-3.6-flash",
    modelVersion: "gemini-3.6-flash",
    thinkingLevel: "high",
    output: { ok: true },
    text: "{\"ok\":true}",
    toolCalls: [],
    groundingMetadata: null,
    usage: { inputTokens: 123, outputTokens: 45 },
    latencyMs: 100,
    finishReason: "completed",
    traceId: "22222222-2222-4222-8222-222222222222",
    error: null,
  };
}

function providerRequest(): ProviderRequest {
  return {
    operation: "quest_understanding",
    modelRole: "quest_understanding",
    promptVersion: "test-v1",
    schemaVersion: "test-v1",
    systemInstruction: "test",
    input: { wish: "visit Singapore" },
    thinkingLevel: "high",
    idempotencyKey: "binding-test-key",
    traceId: "22222222-2222-4222-8222-222222222222",
    userId: "11111111-1111-4111-8111-111111111111",
  };
}

function installDeno(runtime: Record<string, unknown>) {
  runtime.Deno = {
    env: {
      get: (key: string) => {
        if (key === "SUPABASE_URL") return "https://example.supabase.co";
        if (key === "SUPABASE_SERVICE_ROLE_KEY") return "service-role";
        if (key === "AI_BUDGET_RPC_TIMEOUT_MS") return "500";
        return undefined;
      },
    },
  };
}

function restoreDeno(runtime: Record<string, unknown>, original: unknown) {
  if (original === undefined) delete runtime.Deno;
  else runtime.Deno = original;
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function finalAssert(actual: boolean, expected: boolean) {
  assert.equal(actual, expected);
}
