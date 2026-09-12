import type { ProviderRequest, ProviderResponse } from "./contracts.ts";

export type AiBudgetReservation = {
  allowed: boolean;
  reservationId: string | null;
  reason: string;
  resetsAt: string | null;
};

export async function reserveAiBudget(
  request: ProviderRequest,
  models: string[],
): Promise<AiBudgetReservation> {
  if (!request.userId) return denied("user_required");
  const modelNames = [...new Set(models.map((model) => model.trim()))]
    .filter((model) => model.length > 0);
  if (modelNames.length === 0) return denied("budget_model_required");
  const response = await serviceRpc("reserve_ai_usage_budget_v2", {
    p_user_id: request.userId,
    p_operation: budgetOperation(request.operation),
    p_idempotency_key: request.idempotencyKey,
    p_provider: "gemini",
    p_model_names: modelNames,
    p_estimated_input_tokens: estimateProviderInputTokens(request),
    p_max_output_tokens: bounded(request.maxOutputTokens, 2_048, 128, 16_384),
    p_trace_id: request.traceId,
    p_abuse_key_hash: request.abuseKeyHash ?? null,
  });
  if (!response?.ok) return denied("budget_service_unavailable");
  const body = await safeJson(response);
  if (!isRecord(body)) return denied("budget_response_invalid");
  return {
    allowed: body.allowed === true,
    reservationId: stringValue(body.reservation_id),
    reason: stringValue(body.reason) ??
      (body.allowed === true ? "reserved" : "denied"),
    resetsAt: stringValue(body.resets_at),
  };
}

export async function settleAiBudget(
  reservationId: string,
  response: ProviderResponse,
) {
  if (
    response.usage.inputTokens === undefined ||
    response.usage.outputTokens === undefined
  ) return false;
  const result = await serviceRpc("settle_ai_usage_budget", {
    p_reservation_id: reservationId,
    p_model_name: response.model,
    p_input_tokens: response.usage.inputTokens,
    p_output_tokens: response.usage.outputTokens,
    p_finish_reason: response.finishReason.slice(0, 80),
  });
  return result?.ok === true;
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
    input: boundedInputJson(request.input),
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
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), resolveBudgetRpcTimeout());
  try {
    return await fetch(`${url}/rest/v1/rpc/${name}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: key,
        Authorization: `Bearer ${key}`,
      },
      body: JSON.stringify(body),
      signal: controller.signal,
    });
  } catch (_) {
    return null;
  } finally {
    clearTimeout(timeout);
  }
}

export function resolveBudgetRpcTimeout(
  value = Deno.env.get("AI_BUDGET_RPC_TIMEOUT_MS"),
) {
  const parsed = Number.parseInt(value ?? "", 10);
  return Number.isFinite(parsed)
    ? Math.min(10_000, Math.max(500, parsed))
    : 4_000;
}

async function safeJson(response: Response): Promise<unknown> {
  try {
    return await response.json();
  } catch (_) {
    return null;
  }
}

function denied(reason: string): AiBudgetReservation {
  return { allowed: false, reservationId: null, reason, resetsAt: null };
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
  return typeof value === "object" && value !== null;
}

function stringValue(value: unknown) {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}
