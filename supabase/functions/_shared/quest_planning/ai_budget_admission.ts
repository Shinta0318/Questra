import type { ProviderRequest, ProviderResponse } from "./contracts.ts";

export type AiBudgetReservation = {
  allowed: boolean;
  reservationId: string | null;
  receiptBinding: AiBudgetReceiptBinding | null;
  reason: string;
  resetsAt: string | null;
};

export type AiBudgetReceiptBinding = {
  nonce: string;
  operation: string;
  modelRouteDigest: string;
};

export type AiToolContinuationAttribution = {
  enabled: boolean;
  runId: string | null;
  reason: string;
};

export async function reserveAiBudget(
  request: ProviderRequest,
  models: string[],
): Promise<AiBudgetReservation> {
  if (!request.userId) return denied("user_required");
  const modelNames = [...new Set(models.map((model) => model.trim()))]
    .filter((model) => model.length > 0)
    .sort();
  if (modelNames.length === 0) return denied("budget_model_required");
  const operation = budgetOperation(request.operation);
  const bindingEnabled = receiptBindingEnabled();
  const binding = bindingEnabled
    ? await createReceiptBinding(request, modelNames, operation)
    : null;
  if (bindingEnabled && !binding) return denied("receipt_binding_unavailable");
  const response = await serviceRpc(
    binding ? "reserve_ai_usage_budget_v3" : "reserve_ai_usage_budget_v2",
    {
    p_user_id: request.userId,
    p_operation: operation,
    p_idempotency_key: request.idempotencyKey,
    p_provider: "gemini",
    p_model_names: modelNames,
    p_estimated_input_tokens: estimateProviderInputTokens(request),
    p_max_output_tokens: bounded(request.maxOutputTokens, 2_048, 128, 16_384),
    p_trace_id: request.traceId,
    ...(binding
      ? {
        p_receipt_nonce_hash: binding.nonceHash,
        p_model_route_digest: binding.modelRouteDigest,
      }
      : {}),
    p_abuse_key_hash: request.abuseKeyHash ?? null,
    },
  );
  if (!response?.ok) return denied("budget_service_unavailable");
  const body = await safeJson(response);
  if (!isRecord(body)) return denied("budget_response_invalid");
  const reservationId = stringValue(body.reservation_id);
  if (
    binding && body.allowed === true &&
    (body.receipt_binding !== true ||
      body.model_route_digest !== binding.modelRouteDigest)
  ) {
    if (reservationId) {
      await serviceRpc("release_ai_usage_budget", {
        p_reservation_id: reservationId,
        p_reason: "receipt_binding_invalid",
      });
    }
    return denied("receipt_binding_invalid");
  }
  if (body.allowed === true && reservationId && requestsGoogleSearch(request)) {
    const grounding = await serviceRpc("reserve_ai_grounding_budget", {
      p_reservation_id: reservationId,
      p_max_query_count: maxGroundingQueriesPerRequest(),
    });
    const groundingBody = grounding?.ok ? await safeJson(grounding) : null;
    if (!isRecord(groundingBody) || groundingBody.allowed !== true) {
      await serviceRpc("release_ai_usage_budget", {
        p_reservation_id: reservationId,
        p_reason: "grounding_budget_unavailable",
      });
      return denied(
        stringValue(isRecord(groundingBody) ? groundingBody.reason : null) ??
          "grounding_budget_unavailable",
      );
    }
  }
  return {
    allowed: body.allowed === true,
    reservationId,
    receiptBinding: body.allowed === true && binding
      ? {
        nonce: binding.nonce,
        operation,
        modelRouteDigest: binding.modelRouteDigest,
      }
      : null,
    reason: stringValue(body.reason) ??
      (body.allowed === true ? "reserved" : "denied"),
    resetsAt: stringValue(body.resets_at),
  };
}

export async function settleAiBudget(
  reservationId: string,
  response: ProviderResponse,
  binding: AiBudgetReceiptBinding | null = null,
) {
  if (
    response.usage.inputTokens === undefined ||
    response.usage.outputTokens === undefined
  ) return false;
  const groundingQueryCount = verifiedGroundingQueryCount(
    response.groundingMetadata,
  );
  if (groundingQueryCount === null) return false;
  const receipt = await serviceRpc(
    binding
      ? "record_ai_provider_execution_receipt_v4"
      : "record_ai_provider_execution_receipt_v3",
    {
    p_reservation_id: reservationId,
    p_provider_interaction_id: response.providerInteractionId ?? null,
    p_model_name: response.model,
    p_input_tokens: response.usage.inputTokens,
    p_output_tokens: response.usage.outputTokens,
    p_finish_reason: response.finishReason.slice(0, 80),
    p_trace_id: response.traceId,
    p_grounding_query_count: groundingQueryCount,
    p_thinking_level: response.thinkingLevel,
    ...(binding
      ? {
        p_operation: binding.operation,
        p_model_route_digest: binding.modelRouteDigest,
        p_receipt_nonce: binding.nonce,
      }
      : {}),
    },
  );
  if (!receipt?.ok) return false;
  const receiptOutcome = await safeJson(receipt);
  if (!isRecord(receiptOutcome) || receiptOutcome.recorded !== true) {
    return false;
  }
  const result = await serviceRpc("settle_ai_usage_budget", {
    p_reservation_id: reservationId,
    p_model_name: response.model,
    p_input_tokens: response.usage.inputTokens,
    p_output_tokens: response.usage.outputTokens,
    p_finish_reason: response.finishReason.slice(0, 80),
  });
  if (result?.ok === true) return true;
  const reconciliation = await serviceRpc("reconcile_ai_usage_budget", {
    p_reservation_id: reservationId,
  });
  if (!reconciliation?.ok) return false;
  const outcome = await safeJson(reconciliation);
  return isRecord(outcome) && outcome.reconciled === true;
}

export async function releaseAiBudget(
  reservationId: string,
  reason: string,
) {
  const result = await serviceRpc("release_ai_usage_budget", {
    p_reservation_id: reservationId,
    p_reason: reason.replace(/[^a-z0-9_.-]/gi, "_").slice(0, 80) ||
      "provider_failed",
  });
  return result?.ok === true;
}

export async function startAiToolContinuationAttribution(
  request: ProviderRequest,
): Promise<AiToolContinuationAttribution> {
  if (!toolContinuationAttributionEnabled()) {
    return { enabled: false, runId: null, reason: "disabled" };
  }
  if (!request.userId) {
    return { enabled: true, runId: null, reason: "user_required" };
  }
  const response = await serviceRpc(
    "start_ai_tool_continuation_attribution",
    {
      p_user_id: request.userId,
      p_operation: budgetOperation(request.operation),
      p_idempotency_key: request.idempotencyKey,
      p_trace_id: request.traceId,
    },
  );
  const body = response?.ok ? await safeJson(response) : null;
  return {
    enabled: true,
    runId: isRecord(body) ? stringValue(body.run_id) : null,
    reason: isRecord(body) && body.started === true
      ? "started"
      : "attribution_service_unavailable",
  };
}

export async function recordAiToolContinuationTurn(
  attribution: AiToolContinuationAttribution,
  turnNumber: number,
  idempotencyKey: string,
  response: ProviderResponse,
) {
  if (!attribution.enabled) return true;
  if (!attribution.runId || response.error) return false;
  const attemptedModels = response.attemptedModels?.length
    ? response.attemptedModels
    : [response.model];
  const result = await serviceRpc("record_ai_tool_continuation_turn", {
    p_run_id: attribution.runId,
    p_turn_number: turnNumber,
    p_idempotency_key: idempotencyKey,
    p_attempted_models: attemptedModels,
  });
  if (!result?.ok) return false;
  const body = await safeJson(result);
  return isRecord(body) && body.recorded === true;
}

export async function finalizeAiToolContinuationAttribution(
  attribution: AiToolContinuationAttribution,
  usage: ProviderResponse["usage"],
) {
  if (!attribution.enabled) return true;
  if (
    !attribution.runId ||
    usage.inputTokens === undefined ||
    usage.outputTokens === undefined ||
    usage.groundingQueries === undefined
  ) return false;
  const result = await serviceRpc(
    "finalize_ai_tool_continuation_attribution",
    {
      p_run_id: attribution.runId,
      p_total_input_tokens: usage.inputTokens,
      p_total_output_tokens: usage.outputTokens,
      p_total_grounding_query_count: usage.groundingQueries,
    },
  );
  if (!result?.ok) return false;
  const body = await safeJson(result);
  return isRecord(body) && body.completed === true;
}

export async function failAiToolContinuationAttribution(
  attribution: AiToolContinuationAttribution,
  reason: "timeout" | "cancelled" | "tool_failed" | "provider_failed" |
    "attribution_failed",
) {
  if (!attribution.enabled) return true;
  if (!attribution.runId) return false;
  const result = await serviceRpc("fail_ai_tool_continuation_attribution", {
    p_run_id: attribution.runId,
    p_reason: reason,
  });
  return result?.ok === true;
}

function budgetOperation(operation: string) {
  if (operation.includes("task_generation")) return "basic_mission_planning";
  if (operation.includes("repair")) return "mission_redesign";
  if (operation.includes("critic") || operation.includes("coverage")) {
    return "detailed_progress_review";
  }
  return "quest_planning";
}

export function estimateProviderInputTokens(request: ProviderRequest) {
  const envelope = JSON.stringify({
    input: boundedInputJson(request.interactionHistory ?? request.input),
    system_instruction: request.systemInstruction,
    response_schema: request.responseSchema ?? null,
    tools: request.tools ?? [],
  });
  let asciiCharacters = 0;
  let nonAsciiCharacters = 0;
  for (const character of envelope) {
    if ((character.codePointAt(0) ?? 0) <= 0x7f) {
      asciiCharacters++;
    } else {
      nonAsciiCharacters++;
    }
  }
  const estimatedTokens = Math.ceil(asciiCharacters / 4) +
    nonAsciiCharacters;
  const safetyMargin = Math.ceil(estimatedTokens * 0.15);
  return Math.max(1, estimatedTokens + safetyMargin + 32);
}

function boundedInputJson(input: unknown) {
  const text = JSON.stringify(input) ?? "{}";
  return text.slice(0, 40_000);
}

async function serviceRpc(name: string, body: Record<string, unknown>) {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return null;
  for (let attempt = 1; attempt <= 2; attempt++) {
    const controller = new AbortController();
    const timeout = setTimeout(
      () => controller.abort(),
      resolveBudgetRpcTimeout(),
    );
    try {
      const response = await fetch(`${url}/rest/v1/rpc/${name}`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          apikey: key,
          Authorization: `Bearer ${key}`,
        },
        body: JSON.stringify(body),
        signal: controller.signal,
      });
      if (response.ok || (response.status < 500 && response.status !== 429)) {
        return response;
      }
    } catch (_) {
      // A lost response is safe to retry because all budget RPCs are idempotent.
    } finally {
      clearTimeout(timeout);
    }
    if (attempt < 2) await delay(150 * attempt);
  }
  return null;
}

export function resolveBudgetRpcTimeout(
  value = Deno.env.get("AI_BUDGET_RPC_TIMEOUT_MS"),
) {
  const parsed = Number.parseInt(value ?? "", 10);
  return Number.isFinite(parsed)
    ? Math.min(10_000, Math.max(500, parsed))
    : 4_000;
}

function delay(milliseconds: number) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function safeJson(response: Response): Promise<unknown> {
  try {
    return await response.json();
  } catch (_) {
    return null;
  }
}

function denied(reason: string): AiBudgetReservation {
  return {
    allowed: false,
    reservationId: null,
    receiptBinding: null,
    reason,
    resetsAt: null,
  };
}

function receiptBindingEnabled() {
  return Deno.env.get("AI_RECEIPT_BINDING_ENABLED") === "true";
}

export function toolContinuationAttributionEnabled() {
  return typeof Deno !== "undefined" &&
    Deno.env.get("AI_TOOL_CONTINUATION_ATTRIBUTION_ENABLED") === "true";
}

async function createReceiptBinding(
  request: ProviderRequest,
  modelNames: string[],
  operation: string,
) {
  const secret = Deno.env.get("AI_RECEIPT_NONCE_SECRET") ?? "";
  if (secret.length < 32 || !request.userId) return null;
  const context = JSON.stringify([
    request.userId,
    operation,
    request.idempotencyKey,
    request.traceId,
    modelNames,
  ]);
  const nonce = await hmacHex(secret, context);
  return {
    nonce,
    nonceHash: await sha256Hex(nonce),
    modelRouteDigest: await sha256Hex(
      JSON.stringify(["gemini", operation, modelNames]),
    ),
  };
}

async function hmacHex(secret: string, value: string) {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return bytesToHex(
    new Uint8Array(await crypto.subtle.sign("HMAC", key, encoder.encode(value))),
  );
}

async function sha256Hex(value: string) {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return bytesToHex(new Uint8Array(digest));
}

function bytesToHex(bytes: Uint8Array) {
  return Array.from(bytes)
    .map((value) => value.toString(16).padStart(2, "0"))
    .join("");
}

export function verifiedGroundingQueryCount(metadata: unknown): number | null {
  if (metadata === null || metadata === undefined) return 0;
  if (!isRecord(metadata) || !Array.isArray(metadata.queries)) return null;
  if (metadata.queries.some((value) => typeof value !== "string")) return null;
  const queries = metadata.queries
    .filter((value): value is string => typeof value === "string")
    .map((value) => value.trim())
    .filter((value) => value.length > 0);
  const uniqueCount = new Set(queries).size;
  const declared = metadata.billableQueryCount;
  if (
    !Number.isSafeInteger(declared) ||
    declared !== uniqueCount ||
    uniqueCount > 20
  ) return null;
  return uniqueCount;
}

function requestsGoogleSearch(request: ProviderRequest) {
  return request.tools?.some((tool) => tool.type === "google_search") === true;
}

function maxGroundingQueriesPerRequest() {
  const parsed = Number.parseInt(
    Deno.env.get("AI_GROUNDING_MAX_QUERIES_PER_REQUEST") ?? "",
    10,
  );
  return Number.isFinite(parsed) ? Math.min(20, Math.max(1, parsed)) : 8;
}

function bounded(
  value: number | undefined,
  fallback: number,
  min: number,
  max: number,
) {
  return Number.isFinite(value)
    ? Math.min(max, Math.max(min, Math.round(value!)))
    : fallback;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function stringValue(value: unknown) {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}
