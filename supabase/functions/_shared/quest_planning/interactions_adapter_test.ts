import { callGeminiInteraction } from "./interactions_adapter.ts";
import type { ProviderRequest } from "./contracts.ts";

Deno.test("fallback failure reports the model and thinking level actually executed", async () => {
  const env = {
    GEMINI_API_KEY: "test-key",
    SUPABASE_URL: "https://example.supabase.co",
    SUPABASE_SERVICE_ROLE_KEY: "test-service-role",
    GEMINI_MODEL_STRATEGIC_PLANNER: "gemini-3.6-flash",
    GEMINI_FALLBACK_MODEL_STRATEGIC_PLANNER: "gemini-3.5-flash",
  };
  const previousEnv = Object.fromEntries(
    Object.keys(env).map((key) => [key, Deno.env.get(key)]),
  );
  const originalFetch = globalThis.fetch;
  const providerModels: string[] = [];
  const reservedModels: string[] = [];
  try {
    for (const [key, value] of Object.entries(env)) Deno.env.set(key, value);
    globalThis.fetch = (async (input, init) => {
      const url = String(input);
      if (url.endsWith("/rpc/reserve_ai_usage_budget_v2")) {
        const body = JSON.parse(String(init?.body)) as Record<string, unknown>;
        reservedModels.push(...body.p_model_names as string[]);
        return jsonResponse({
          allowed: true,
          reservation_id: "11111111-1111-4111-8111-111111111111",
          reason: "reserved",
        });
      }
      if (url.endsWith("/rpc/release_ai_usage_budget")) {
        return jsonResponse({ released: true });
      }
      if (url.includes("generativelanguage.googleapis.com")) {
        const body = JSON.parse(String(init?.body)) as Record<string, unknown>;
        providerModels.push(String(body.model));
        return jsonResponse({ error: { message: "temporary outage" } }, 503);
      }
      throw new Error(`Unexpected URL: ${url}`);
    }) as typeof fetch;

    const result = await callGeminiInteraction(request());

    assertArrayEquals(reservedModels, ["gemini-3.6-flash", "gemini-3.5-flash"]);
    assertArrayEquals(providerModels, ["gemini-3.6-flash", "gemini-3.5-flash"]);
    assertEquals(result.model, "gemini-3.5-flash");
    assertEquals(result.thinkingLevel, "high");
    assertEquals(result.error?.code, "unavailable");
  } finally {
    globalThis.fetch = originalFetch;
    for (const [key, value] of Object.entries(previousEnv)) {
      if (value === undefined) Deno.env.delete(key);
      else Deno.env.set(key, value);
    }
  }
});

function request(): ProviderRequest {
  return {
    operation: "strategic_plan",
    modelRole: "strategic_planner",
    promptVersion: "test-v1",
    schemaVersion: "test-v1",
    systemInstruction: "Return a test plan.",
    input: { wish: "シンガポールへ行きたい" },
    idempotencyKey: "qst430-provider-attribution",
    traceId: "22222222-2222-4222-8222-222222222222",
    userId: "33333333-3333-4333-8333-333333333333",
  };
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function assertEquals(actual: unknown, expected: unknown) {
  if (actual !== expected) {
    throw new Error(`Expected ${expected}, got ${actual}`);
  }
}

function assertArrayEquals(actual: unknown[], expected: unknown[]) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}
