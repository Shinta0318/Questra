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

const endpoint = "https://generativelanguage.googleapis.com/v1beta/interactions";

export async function groundedMissionSearch(
  input: Record<string, unknown>,
): Promise<GroundedSearchResult | null> {
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) return null;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 20_000);
  try {
    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": apiKey,
      },
      signal: controller.signal,
      body: JSON.stringify({
        model: Deno.env.get("GEMINI_SEARCH_MODEL") ?? "gemini-3.5-flash",
        store: false,
        tools: [{ type: "google_search" }],
        system_instruction:
          "Search only for information needed to complete the supplied Mission. Return compact JSON with summary, checkpoints (3-6 strings), and cautions (0-4 strings). Prefer official, primary, and current sources. Do not invent URLs, prices, laws, schedules, availability, or guarantees. Explain uncertainty in cautions. Never include advertising or enterprise proposals.",
        input: JSON.stringify(input).slice(0, 4_000),
        generation_config: {
          max_output_tokens: 1_200,
          temperature: 0.2,
          thinking_level: "minimal",
        },
      }),
    });
    if (!response.ok) return null;
    const data = await response.json() as Record<string, unknown>;
    const parts: string[] = [];
    collectText(data.steps, parts);
    const text = parts.join("\n").trim();
    if (!text) return null;
    return {
      text,
      sources: collectSources(data.steps),
      sourceType: "gemini_google_search_grounding",
    };
  } catch (_) {
    return null;
  } finally {
    clearTimeout(timeout);
  }
}

function collectText(value: unknown, output: string[]) {
  if (Array.isArray(value)) {
    for (const item of value) collectText(item, output);
    return;
  }
  if (!value || typeof value !== "object") return;
  const data = value as Record<string, unknown>;
  if (data.type === "model_output" && typeof data.text === "string") {
    output.push(data.text);
  }
  if (data.type === "model_output") collectText(data.content, output);
  if (data.type !== "model_output") {
    for (const nested of Object.values(data)) collectText(nested, output);
  }
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
