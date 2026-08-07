import { generateAiText } from "../ai_provider.ts";
import { ProviderRequest, ProviderResponse } from "./contracts.ts";

// Migration-only adapter. New Quest Planning code must use callGeminiInteraction.
export async function callLegacyGenerateContent(request: ProviderRequest): Promise<ProviderResponse> {
  const startedAt = Date.now();
  const result = await generateAiText({
    systemInstruction: request.systemInstruction,
    input: request.input,
    feature: request.operation,
    promptVersion: request.promptVersion,
    userId: request.userId,
    responseSchema: request.responseSchema,
    maxOutputTokens: request.maxOutputTokens,
    temperature: request.temperature,
  });
  return {
    provider: result?.provider ?? "gemini",
    model: result?.model ?? "legacy-unavailable",
    modelVersion: result?.model ?? "legacy-unavailable",
    output: result?.text ?? null,
    text: result?.text ?? "",
    toolCalls: [],
    groundingMetadata: null,
    usage: {},
    latencyMs: Date.now() - startedAt,
    finishReason: result ? "completed" : "error",
    traceId: request.traceId,
    error: result ? null : { code: "unavailable", retryable: true, message: "Legacy provider unavailable" },
  };
}
