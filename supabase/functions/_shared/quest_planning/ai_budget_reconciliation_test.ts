import assert from "node:assert/strict";
import test from "node:test";

import { settleAiBudget } from "./ai_budget_admission.ts";
import type { ProviderResponse } from "./contracts.ts";

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
      if (url.endsWith("/rpc/record_ai_provider_execution_receipt")) {
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
      if (url.endsWith("/rpc/record_ai_provider_execution_receipt")) {
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
