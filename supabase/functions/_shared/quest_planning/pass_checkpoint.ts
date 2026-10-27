import { currentAiLegalGate } from "../ai_legal_gate.ts";
import type { ProviderRequest, ProviderResponse } from "./contracts.ts";
import { validateJsonSchema } from "./json_schema_validator.ts";
import { resolveFallbackModel, resolveModel } from "./model_registry.ts";
import { budgetOperation } from "./ai_budget_admission.ts";

type CheckpointRow = {
  output: unknown;
  provider_metadata: Record<string, unknown>;
};

type Dependencies = {
  fetchImpl?: typeof fetch;
  legalGate?: typeof currentAiLegalGate;
  now?: () => Date;
};

const TTL_MS = 24 * 60 * 60 * 1000;
const CHECKPOINTABLE_PASSES = new Set([
  "quest_planning.quest_understanding",
  "quest_planning.success_contract",
  "quest_planning.achievement_domain_analysis",
]);

export function planningModelPayload(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(planningModelPayload);
  if (!value || typeof value !== "object") return value;
  return Object.fromEntries(
    Object.entries(value).filter(([key]) =>
      !["idempotencyKey", "abuseKeyHash", "userId"].includes(key)
    ).map(([key, nested]) => [key, planningModelPayload(nested)]),
  );
}

export async function planningCheckpointFingerprint(
  request: ProviderRequest,
): Promise<string> {
  const preview = Deno.env.get("AI_ALLOW_PREVIEW_MODELS") === "true";
  const primary = resolveModel(request.modelRole, { allowPreview: preview });
  const fallback = resolveFallbackModel(request.modelRole, primary.name, {
    allowPreview: preview,
  });
  const value = {
    operation: request.operation,
    model: primary.name,
    fallback: fallback.name,
    promptVersion: request.promptVersion,
    schemaVersion: request.schemaVersion,
    systemInstruction: request.systemInstruction,
    thinkingLevel: request.thinkingLevel,
    temperature: request.temperature,
    maxOutputTokens: request.maxOutputTokens,
    responseSchema: request.responseSchema,
    input: request.input,
  };
  const canonical = JSON.stringify(
    value,
    (_key, item) =>
      item && typeof item === "object" && !Array.isArray(item)
        ? Object.fromEntries(
          Object.entries(item).sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0),
        )
        : item,
  );
  const bytes = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(canonical),
  );
  return Array.from(new Uint8Array(bytes)).map((byte) =>
    byte.toString(16).padStart(2, "0")
  ).join("");
}

export async function runCheckpointedPlanningPass(
  questId: string,
  request: ProviderRequest,
  invoke: () => Promise<ProviderResponse>,
  dependencies: Dependencies = {},
): Promise<ProviderResponse> {
  // Downstream candidates and critics need their domain quality gate before reuse.
  if (
    !request.userId || !request.responseSchema || request.tools?.length ||
    !CHECKPOINTABLE_PASSES.has(request.operation)
  ) return invoke();
  // A cached result must never bypass a revoked or unavailable AI consent gate.
  if (
    await (dependencies.legalGate ?? currentAiLegalGate)(request.userId) !==
      "granted"
  ) {
    return invoke();
  }
  const fingerprint = await planningCheckpointFingerprint(request);
  const fetchImpl = dependencies.fetchImpl ?? fetch;
  const enabled = await aiOperationEnabled(request.operation, fetchImpl);
  const cached = enabled
    ? await load(
      questId,
      request,
      fingerprint,
      fetchImpl,
      dependencies.now?.() ?? new Date(),
    )
    : null;
  if (cached) return cached;
  const response = await invoke();
  if (
    !response.error && response.toolCalls.length === 0 &&
    validateJsonSchema(response.output, request.responseSchema).length === 0
  ) {
    await save(
      questId,
      request,
      fingerprint,
      response,
      fetchImpl,
      dependencies.now?.() ?? new Date(),
    );
  }
  return response;
}

async function aiOperationEnabled(operation: string, fetchImpl: typeof fetch) {
  const config = serviceConfig();
  if (!config) return false;
  try {
    const params = new URLSearchParams({
      operation: `eq.${budgetOperation(operation)}`,
      enabled: "eq.true",
      select: "operation",
      limit: "1",
    });
    const response = await fetchImpl(
      `${config.url}/rest/v1/ai_operation_controls?${params}`,
      {
        headers: serviceHeaders(config.key),
        signal: AbortSignal.timeout(5_000),
      },
    );
    if (!response.ok) return false;
    const rows = await response.json() as unknown[];
    return rows.length === 1;
  } catch {
    return false;
  }
}

async function load(
  questId: string,
  request: ProviderRequest,
  fingerprint: string,
  fetchImpl: typeof fetch,
  now: Date,
): Promise<ProviderResponse | null> {
  const config = serviceConfig();
  if (!config) return null;
  const params = new URLSearchParams({
    owner_id: `eq.${request.userId}`,
    quest_id: `eq.${questId}`,
    pass_name: `eq.${request.operation}`,
    input_fingerprint: `eq.${fingerprint}`,
    expires_at: `gt.${now.toISOString()}`,
    select: "output,provider_metadata",
    limit: "1",
  });
  try {
    const response = await fetchImpl(
      `${config.url}/rest/v1/quest_planning_pass_checkpoints?${params}`,
      {
        headers: serviceHeaders(config.key),
        signal: AbortSignal.timeout(5_000),
      },
    );
    if (!response.ok) return null;
    const rows = await response.json() as CheckpointRow[];
    const row = rows[0];
    if (
      !row || validateJsonSchema(row.output, request.responseSchema!).length > 0
    ) return null;
    const metadata = row.provider_metadata;
    if (
      metadata?.provider !== "gemini" || typeof metadata.model !== "string" ||
      typeof metadata.modelVersion !== "string" ||
      !["minimal", "low", "medium", "high"].includes(
        String(metadata.thinkingLevel),
      )
    ) return null;
    return {
      provider: "gemini",
      model: metadata.model,
      modelVersion: metadata.modelVersion,
      thinkingLevel: metadata
        .thinkingLevel as ProviderResponse["thinkingLevel"],
      output: row.output,
      text: "",
      toolCalls: [],
      groundingMetadata: null,
      usage: {},
      latencyMs: 0,
      finishReason: "cached",
      traceId: request.traceId,
      error: null,
      attemptedModels: [],
      cacheHit: true,
    };
  } catch {
    return null;
  }
}

async function save(
  questId: string,
  request: ProviderRequest,
  fingerprint: string,
  response: ProviderResponse,
  fetchImpl: typeof fetch,
  now: Date,
) {
  const config = serviceConfig();
  if (!config) return;
  try {
    const headers = serviceHeaders(config.key);
    headers.set("Content-Type", "application/json");
    headers.set("Prefer", "resolution=merge-duplicates,return=minimal");
    const stored = await fetchImpl(
      `${config.url}/rest/v1/quest_planning_pass_checkpoints?on_conflict=owner_id,quest_id,pass_name,input_fingerprint`,
      {
        method: "POST",
        headers,
        body: JSON.stringify({
          owner_id: request.userId,
          quest_id: questId,
          pass_name: request.operation,
          input_fingerprint: fingerprint,
          output: response.output,
          provider_metadata: {
            provider: response.provider,
            model: response.model,
            modelVersion: response.modelVersion,
            thinkingLevel: response.thinkingLevel,
          },
          created_at: now.toISOString(),
          expires_at: new Date(now.getTime() + TTL_MS).toISOString(),
        }),
        signal: AbortSignal.timeout(5_000),
      },
    );
    if (!stored.ok) console.warn("Planning checkpoint could not be saved");
  } catch {
    console.warn("Planning checkpoint could not be saved");
  }
}

function serviceConfig() {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  return url && key ? { url: url.replace(/\/$/, ""), key } : null;
}

function serviceHeaders(key: string) {
  return new Headers({ apikey: key, Authorization: `Bearer ${key}` });
}
