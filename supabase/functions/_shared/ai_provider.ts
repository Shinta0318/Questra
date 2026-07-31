export type AiProvider = "gemini" | "openai";

export type GenerateAiTextOptions = {
  systemInstruction: string;
  input: unknown;
  // Metadata only. User input must never be copied into this field.
  feature?: string;
  promptVersion?: string;
  userId?: string | null;
  responseSchema?: Record<string, unknown>;
  maxOutputTokens?: number;
  temperature?: number;
};

export type AiTextResult = {
  text: string;
  provider: AiProvider;
  sourceType: string;
  model: string;
};

const GEMINI_INTERACTIONS_URL =
  "https://generativelanguage.googleapis.com/v1beta/interactions";
const DEFAULT_GEMINI_MODEL = "gemini-3.5-flash";
const DEFAULT_TIMEOUT_MS = 20_000;
const DEFAULT_MAX_INPUT_CHARS = 16_000;
const DEFAULT_MAX_OUTPUT_TOKENS = 512;
const RETRYABLE_STATUS = new Set([429, 500, 502, 503, 504]);

export async function generateAiText(
  options: GenerateAiTextOptions,
): Promise<AiTextResult | null> {
  const provider = selectedProvider();
  const startedAt = Date.now();
  let result: AiTextResult | null = null;
  try {
    result = provider === "openai"
      ? await generateWithOpenAi(options)
      : await generateWithGemini(options);
    return result;
  } finally {
    // Observability must never make Arc unavailable.
    await recordAiUsage({
      feature: boundedFeature(options.feature ?? "unknown"),
      promptVersion: boundedFeature(options.promptVersion ?? "v1"),
      userId: options.userId ?? null,
      provider,
      model: result?.model ?? selectedModel(provider),
      outcome: result ? "succeeded" : "fallback",
      latencyMs: Date.now() - startedAt,
      inputChars: boundedJson(options.input).length,
      outputChars: result?.text.length ?? 0,
    });
  }
}

function selectedProvider(): AiProvider {
  return Deno.env.get("AI_PROVIDER")?.toLowerCase() === "openai"
    ? "openai"
    : "gemini";
}

function selectedModel(provider: AiProvider) {
  return provider === "openai"
    ? Deno.env.get("OPENAI_MODEL") ?? "gpt-4.1-mini"
    : Deno.env.get("GEMINI_MODEL") ?? DEFAULT_GEMINI_MODEL;
}

type AiUsageEvent = {
  feature: string;
  promptVersion: string;
  userId: string | null;
  provider: AiProvider;
  model: string;
  outcome: "succeeded" | "fallback";
  latencyMs: number;
  inputChars: number;
  outputChars: number;
};

async function recordAiUsage(event: AiUsageEvent) {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceRoleKey) return;

  try {
    await fetch(`${url}/rest/v1/ai_usage_events`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
        Prefer: "return=minimal",
      },
      body: JSON.stringify({
        user_id: event.userId,
        feature: event.feature,
        prompt_version: event.promptVersion,
        provider: event.provider,
        model_name: event.model,
        outcome: event.outcome,
        latency_ms: Math.min(60_000, Math.max(0, event.latencyMs)),
        input_chars: Math.min(40_000, Math.max(0, event.inputChars)),
        output_chars: Math.min(40_000, Math.max(0, event.outputChars)),
      }),
    });
  } catch (error) {
    const name = error instanceof Error ? error.name : "UnknownError";
    console.warn(`AI usage telemetry failed: ${name}`);
  }
}

function boundedFeature(value: string) {
  return value.replace(/[^a-z0-9_.-]/gi, "_").slice(0, 80) || "unknown";
}

async function generateWithGemini(
  options: GenerateAiTextOptions,
): Promise<AiTextResult | null> {
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    console.warn("Gemini request skipped: GEMINI_API_KEY is not configured.");
    return null;
  }

  const model = selectedModel("gemini");
  const body: Record<string, unknown> = {
    model,
    input: boundedJson(options.input),
    system_instruction: options.systemInstruction,
    store: false,
    generation_config: {
      max_output_tokens: boundedInteger(
        options.maxOutputTokens,
        DEFAULT_MAX_OUTPUT_TOKENS,
        128,
        8_192,
      ),
      temperature: boundedNumber(options.temperature, 0.7, 0, 1.5),
      thinking_level: "minimal",
    },
  };
  if (options.responseSchema) {
    body.response_format = {
      type: "text",
      mime_type: "application/json",
      schema: options.responseSchema,
    };
  }

  const response = await fetchWithRetry(GEMINI_INTERACTIONS_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": apiKey,
      "Api-Revision": "2026-05-20",
    },
    body: JSON.stringify(body),
  });
  if (!response?.ok) return null;

  const data = await response.json() as Record<string, unknown>;
  const text = extractGeminiText(data);
  return text
    ? { text, provider: "gemini", sourceType: "gemini_interactions", model }
    : null;
}

async function generateWithOpenAi(
  options: GenerateAiTextOptions,
): Promise<AiTextResult | null> {
  const apiKey = Deno.env.get("OPENAI_API_KEY");
  if (!apiKey) return null;

  const body: Record<string, unknown> = {
    model: selectedModel("openai"),
    input: [
      { role: "system", content: options.systemInstruction },
      { role: "user", content: boundedJson(options.input) },
    ],
    max_output_tokens: boundedInteger(
      options.maxOutputTokens,
      DEFAULT_MAX_OUTPUT_TOKENS,
      128,
      8_192,
    ),
  };
  if (options.responseSchema) {
    body.text = { format: { type: "json_object" } };
  }

  const response = await fetchWithRetry("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  if (!response?.ok) return null;

  const data = await response.json() as Record<string, unknown>;
  const text = extractOpenAiText(data);
  return text
    ? {
      text,
      provider: "openai",
      sourceType: "openai_responses",
      model: selectedModel("openai"),
    }
    : null;
}

async function fetchWithRetry(
  url: string,
  init: RequestInit,
): Promise<Response | null> {
  for (let attempt = 0; attempt < 2; attempt++) {
    const controller = new AbortController();
    const timeout = setTimeout(
      () => controller.abort(),
      envInteger("AI_REQUEST_TIMEOUT_MS", DEFAULT_TIMEOUT_MS, 5_000, 30_000),
    );
    try {
      const response = await fetch(url, { ...init, signal: controller.signal });
      if (response.ok) return response;

      console.warn(
        `AI provider request failed: status=${response.status}, attempt=${attempt + 1}`,
      );
      if (!RETRYABLE_STATUS.has(response.status) || attempt === 1) return null;
      await delay(retryDelayMs(response, attempt));
    } catch (error) {
      const name = error instanceof Error ? error.name : "UnknownError";
      console.warn(`AI provider request failed: ${name}, attempt=${attempt + 1}`);
      if (attempt === 1) return null;
      await delay(350);
    } finally {
      clearTimeout(timeout);
    }
  }
  return null;
}

function retryDelayMs(response: Response, attempt: number) {
  const retryAfter = Number(response.headers.get("retry-after"));
  if (Number.isFinite(retryAfter) && retryAfter > 0) {
    return Math.min(retryAfter * 1_000, 1_500);
  }
  return 350 * (attempt + 1);
}

function delay(milliseconds: number) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

function boundedJson(value: unknown) {
  const serialized = JSON.stringify(value) ?? "{}";
  const limit = envInteger(
    "AI_MAX_INPUT_CHARS",
    DEFAULT_MAX_INPUT_CHARS,
    2_000,
    40_000,
  );
  return serialized.length <= limit
    ? serialized
    : `${serialized.substring(0, limit)}\n[context truncated]`;
}

function envInteger(name: string, fallback: number, min: number, max: number) {
  return boundedInteger(Number(Deno.env.get(name)), fallback, min, max);
}

function boundedInteger(
  value: number | undefined,
  fallback: number,
  min: number,
  max: number,
) {
  if (typeof value !== "number" || !Number.isFinite(value)) return fallback;
  return Math.min(max, Math.max(min, Math.round(value)));
}

function boundedNumber(
  value: number | undefined,
  fallback: number,
  min: number,
  max: number,
) {
  if (typeof value !== "number" || !Number.isFinite(value)) return fallback;
  return Math.min(max, Math.max(min, value));
}

function extractGeminiText(data: Record<string, unknown>): string | null {
  if (!Array.isArray(data.steps)) return null;
  const parts: string[] = [];
  for (const step of data.steps) {
    if (!isRecord(step) || step.type !== "model_output") continue;
    collectText(step.content, parts);
  }
  return joinedText(parts);
}

function extractOpenAiText(data: Record<string, unknown>): string | null {
  if (typeof data.output_text === "string") {
    return nonEmpty(data.output_text);
  }
  const parts: string[] = [];
  collectText(data.output, parts);
  return joinedText(parts);
}

function collectText(value: unknown, parts: string[]) {
  if (typeof value === "string") {
    const text = nonEmpty(value);
    if (text) parts.push(text);
    return;
  }
  if (Array.isArray(value)) {
    for (const item of value) collectText(item, parts);
    return;
  }
  if (!isRecord(value)) return;
  if (typeof value.text === "string") {
    const text = nonEmpty(value.text);
    if (text) parts.push(text);
    return;
  }
  if ("content" in value) collectText(value.content, parts);
}

function joinedText(parts: string[]) {
  return nonEmpty(parts.join("\n"));
}

function nonEmpty(value: string) {
  const text = value.trim();
  return text.length > 0 ? text : null;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
