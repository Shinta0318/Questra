import { isValidUserId } from "./ai_auth.ts";
import { callGeminiInteraction } from "./quest_planning/interactions_adapter.ts";

type GroundedSource = {
  title: string;
  publisher: string;
  url: string;
};

export type GroundedSearchResult = {
  text: string;
  sources: GroundedSource[];
  sourceType: string;
};

type GroundedSearchOptions = {
  userId: string;
  operation: "arc_grounded_search" | "mission_research";
};

export async function groundedMissionSearch(
  input: Record<string, unknown>,
  options: GroundedSearchOptions,
): Promise<GroundedSearchResult | null> {
  if (!isValidUserId(options.userId)) return null;
  const response = await callGeminiInteraction({
    operation: options.operation,
    modelRole: "quest_understanding",
    promptVersion: "grounded_mission_search_v2",
    schemaVersion: "grounded_mission_search_v2",
    systemInstruction:
      "Search only for information needed to complete the supplied Mission. Return compact JSON with summary, checkpoints (3-6 strings), and cautions (0-4 strings). Prefer official, primary, and current sources. Do not invent URLs, prices, laws, schedules, availability, or guarantees. Explain uncertainty in cautions. Never include advertising or enterprise proposals.",
    input: JSON.stringify(input).slice(0, 4_000),
    responseSchema: {
      type: "object",
      required: ["summary", "checkpoints", "cautions"],
      properties: {
        summary: { type: "string" },
        checkpoints: { type: "array", items: { type: "string" } },
        cautions: { type: "array", items: { type: "string" } },
      },
    },
    tools: [{ type: "google_search" }],
    maxOutputTokens: 1_200,
    temperature: 0.2,
    timeoutMs: 20_000,
    idempotencyKey: crypto.randomUUID(),
    traceId: crypto.randomUUID(),
    userId: options.userId,
  });
  if (response.error || !response.text || !response.groundingMetadata) return null;
  const sources = collectSources(response.groundingMetadata.sources);
  if (sources.length === 0) return null;
  return {
    text: response.text,
    sources,
    sourceType: "gemini_google_search_grounding",
  };
}

function collectSources(value: unknown) {
  const sources = new Map<string, GroundedSource>();
  visit(value, (data) => {
    const rawUrl = typeof data.url === "string"
      ? data.url
      : typeof data.uri === "string"
      ? data.uri
      : null;
    if (!rawUrl) return;
    const url = safePublicHttpsUrl(rawUrl);
    if (!url) return;
    const title = stringValue(data.title) ?? url.hostname;
    sources.set(url.href, {
      title: title.slice(0, 180),
      publisher: (stringValue(data.publisher) ?? url.hostname).slice(0, 120),
      url: url.href,
    });
  });
  return [...sources.values()].slice(0, 8);
}

function visit(value: unknown, callback: (data: Record<string, unknown>) => void) {
  if (Array.isArray(value)) {
    for (const item of value) visit(item, callback);
    return;
  }
  if (!value || typeof value !== "object") return;
  const data = value as Record<string, unknown>;
  callback(data);
  for (const nested of Object.values(data)) visit(nested, callback);
}

function safePublicHttpsUrl(raw: string) {
  try {
    const url = new URL(raw);
    const host = url.hostname.toLowerCase();
    if (url.protocol !== "https:" || host === "localhost" || host.endsWith(".local")) return null;
    if (/^(127\.|10\.|192\.168\.|169\.254\.)/.test(host)) return null;
    return url;
  } catch (_) {
    return null;
  }
}

function stringValue(value: unknown) {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}
