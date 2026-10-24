import { isValidUserId } from "./ai_auth.ts";
import { callGeminiInteraction } from "./quest_planning/interactions_adapter.ts";
import type { ModelRole } from "./quest_planning/contracts.ts";

export type AiProvider = "gemini" | "openai";

export type GenerateAiTextOptions = {
  systemInstruction: string;
  input: unknown;
  // Metadata only. User input must never be copied into this field.
  feature?: string;
  promptVersion?: string;
  userId: string;
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

const DEFAULT_MAX_INPUT_CHARS = 16_000;

export async function generateAiText(
  options: GenerateAiTextOptions,
): Promise<AiTextResult | null> {
  if (!isValidUserId(options.userId)) return null;
  const provider = selectedProvider();
  const startedAt = Date.now();
  let result: AiTextResult | null = null;
  let model = "unresolved";
  try {
    if (provider !== "gemini") {
      console.warn("Direct OpenAI generation is disabled until it has budget admission.");
      return null;
    }
    const response = await callGeminiInteraction({
      operation: options.feature ?? "direct_ai",
      modelRole: modelRoleForFeature(options.feature),
      promptVersion: options.promptVersion ?? "v1",
      schemaVersion: "direct_ai_v1",
      systemInstruction: options.systemInstruction,
      input: options.input,
      responseSchema: options.responseSchema,
      maxOutputTokens: options.maxOutputTokens,
      temperature: options.temperature,
      idempotencyKey: crypto.randomUUID(),
      traceId: crypto.randomUUID(),
      userId: options.userId,
    });
    model = response.model;
    if (response.error || !response.text) return null;
    result = {
      text: response.text,
      provider: "gemini",
      sourceType: "gemini_interactions",
      model: response.model,
    };
    return result;
  } finally {
    // Observability must never make Arc unavailable.
    await recordAiUsage({
      feature: boundedFeature(options.feature ?? "unknown"),
      promptVersion: boundedFeature(options.promptVersion ?? "v1"),
      userId: options.userId,
      provider,
      model: result?.model ?? model,
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

function modelRoleForFeature(feature: string | undefined): ModelRole {
  if (feature === "quest_intent_moderation" || feature === "quest_intent") {
    return "lightweight_classifier";
  }
  if (feature === "mission_generation") return "mission_generator";
  if (feature === "mission_regeneration") return "targeted_repair";
  if (feature === "arc_quest_guide_critic") return "mission_critic";
  if (feature === "arc_quest_guide") return "strategic_planner";
  if (feature === "quest_guides" || feature === "star_map_generation") {
    return "quest_proposal";
  }
  return "quest_understanding";
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

function boundedJson(value: unknown) {
  const serialized = JSON.stringify(value) ?? "{}";
  const limit = DEFAULT_MAX_INPUT_CHARS;
  return serialized.length <= limit
    ? serialized
    : `${serialized.substring(0, limit)}\n[context truncated]`;
}
