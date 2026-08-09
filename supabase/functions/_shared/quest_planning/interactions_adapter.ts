import { classifyProviderError, shouldRetry } from "./errors.ts";
import { resolveModel } from "./model_registry.ts";
import { ProviderErrorCode, ProviderRequest, ProviderResponse, ProviderToolCall } from "./contracts.ts";
import { resolveThinkingLevel } from "./thinking_policy.ts";

const INTERACTIONS_URL = "https://generativelanguage.googleapis.com/v1/interactions";

export async function callGeminiInteraction(request: ProviderRequest): Promise<ProviderResponse> {
  const startedAt = Date.now();
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) return failure(request, startedAt, "unknown", "GEMINI_API_KEY is not configured");
  const allowPreview = Deno.env.get("AI_ALLOW_PREVIEW_MODELS") === "true";
  let lastError = classifyProviderError();
  for (let attempt = 1; attempt <= 2; attempt++) {
    const model = resolveModel(request.modelRole, { fallback: attempt > 1, allowPreview });
    const thinkingLevel = request.thinkingLevel ?? resolveThinkingLevel(request.modelRole, model);
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), bounded(request.timeoutMs, 25_000, 5_000, 60_000));
    try {
      const body: Record<string, unknown> = {
        model: model.name,
        input: boundedJson(request.input),
        system_instruction: request.systemInstruction,
        store: false,
        generation_config: {
          max_output_tokens: bounded(request.maxOutputTokens, 2_048, 128, 16_384),
          thinking_level: thinkingLevel,
          thinking_summaries: "none",
        },
      };
      if (request.responseSchema) {
        body.response_format = {
          type: "text",
          mime_type: "application/json",
          schema: toGeminiSchema(request.responseSchema),
        };
      }
      if (request.tools?.length) body.tools = request.tools;
      const response = await fetch(INTERACTIONS_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": apiKey,
          "X-Questra-Trace-Id": request.traceId,
          "Idempotency-Key": request.idempotencyKey,
        },
        body: JSON.stringify(body),
        signal: controller.signal,
      });
      if (!response.ok) {
        lastError = classifyProviderError(response.status);
        const providerMessage = await safeProviderErrorMessage(response);
        if (shouldRetry(lastError, attempt)) {
          await delay(attempt * 400);
          continue;
        }
        return failure(
          request,
          startedAt,
          lastError.code,
          providerMessage ?? lastError.message,
          response.status,
          model.name,
        );
      }
      const data = await response.json() as Record<string, unknown>;
      const text = extractText(data);
      let output: unknown = text;
      if (request.responseSchema) {
        try {
          output = JSON.parse(text);
        } catch (_) {
          lastError = classifyProviderError(400);
          if (attempt === 1) {
            await delay(400);
            continue;
          }
          return failure(request, startedAt, "malformed_output", "Structured output was not valid JSON", undefined, model.name);
        }
      }
      return {
        provider: "gemini",
        model: model.name,
        modelVersion: model.family,
        output,
        text,
        toolCalls: extractToolCalls(data),
        groundingMetadata: extractGroundingMetadata(data),
        usage: extractUsage(data),
        latencyMs: Date.now() - startedAt,
        finishReason: stringValue(data.finish_reason) ?? "completed",
        traceId: request.traceId,
        error: null,
      };
    } catch (error) {
      lastError = classifyProviderError(undefined, error);
      if (!shouldRetry(lastError, attempt)) return failure(request, startedAt, lastError.code, lastError.message);
      await delay(attempt * 400);
    } finally {
      clearTimeout(timeout);
    }
  }
  return failure(request, startedAt, lastError.code, lastError.message);
}

function failure(request: ProviderRequest, startedAt: number, code: ProviderErrorCode, message: string, status?: number, model = "unresolved"): ProviderResponse {
  return {
    provider: "gemini",
    model,
    modelVersion: model,
    output: null,
    text: "",
    toolCalls: [],
    groundingMetadata: null,
    usage: {},
    latencyMs: Date.now() - startedAt,
    finishReason: "error",
    traceId: request.traceId,
    error: { code, retryable: ["timeout", "rate_limited", "unavailable"].includes(code), status, message },
  };
}

function extractText(data: Record<string, unknown>) {
  if (typeof data.output_text === "string") return data.output_text.trim();
  const output: string[] = [];
  visit(data.steps, (item) => {
    if (item.type !== "model_output") return;
    if (typeof item.text === "string") output.push(item.text);
    collectContentText(item.content, output);
  });
  return output.join("\n").trim();
}

function extractToolCalls(data: Record<string, unknown>) {
  const calls: ProviderToolCall[] = [];
  visit(data.steps, (item) => {
    if (item.type !== "function_call" || typeof item.name !== "string") return;
    calls.push({
      id: stringValue(item.id) ?? crypto.randomUUID(),
      name: item.name,
      arguments: isRecord(item.arguments) ? item.arguments : {},
    });
  });
  return calls;
}

function extractGroundingMetadata(data: Record<string, unknown>) {
  const searches: Record<string, unknown>[] = [];
  visit(data.steps, (item) => {
    if (item.type === "google_search_call" || item.type === "google_search_result") searches.push(item);
  });
  return searches.length ? { steps: searches } : null;
}

function extractUsage(data: Record<string, unknown>) {
  const usage = isRecord(data.usage) ? data.usage : {};
  return {
    inputTokens: numberValue(usage.input_tokens),
    outputTokens: numberValue(usage.output_tokens),
    totalTokens: numberValue(usage.total_tokens),
  };
}

function collectContentText(value: unknown, output: string[]) {
  if (Array.isArray(value)) for (const item of value) collectContentText(item, output);
  else if (isRecord(value) && typeof value.text === "string") output.push(value.text);
}
function visit(value: unknown, callback: (item: Record<string, unknown>) => void) {
  if (Array.isArray(value)) { for (const item of value) visit(item, callback); return; }
  if (!isRecord(value)) return;
  callback(value);
  for (const nested of Object.values(value)) visit(nested, callback);
}
function boundedJson(value: unknown) { const text = JSON.stringify(value) ?? "{}"; return text.slice(0, 40_000); }
async function safeProviderErrorMessage(response: Response) {
  try {
    const body = await response.json() as Record<string, unknown>;
    const error = isRecord(body.error) ? body.error : {};
    const message = stringValue(error.message);
    return message?.replace(/key=[^&\s]+/gi, "key=[redacted]").slice(0, 400) ?? null;
  } catch (_) {
    return null;
  }
}
function toGeminiSchema(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(toGeminiSchema);
  if (!isRecord(value)) return value;
  const supported = new Set([
    "type", "title", "description", "properties", "required",
    "enum", "format", "items",
  ]);
  return Object.fromEntries(
    Object.entries(value)
      .filter(([key]) => supported.has(key))
      .map(([key, nested]) => [
        key,
        key === "properties" && isRecord(nested)
          ? Object.fromEntries(
            Object.entries(nested).map(([name, schema]) => [name, toGeminiSchema(schema)]),
          )
          : toGeminiSchema(nested),
      ]),
  );
}
function bounded(value: number | undefined, fallback: number, min: number, max: number) { return Number.isFinite(value) ? Math.min(max, Math.max(min, Math.round(value!))) : fallback; }
function isRecord(value: unknown): value is Record<string, unknown> { return typeof value === "object" && value !== null; }
function stringValue(value: unknown) { return typeof value === "string" && value.trim() ? value.trim() : null; }
function numberValue(value: unknown) { return typeof value === "number" && Number.isFinite(value) ? value : undefined; }
function delay(ms: number) { return new Promise((resolve) => setTimeout(resolve, ms)); }
