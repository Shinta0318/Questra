export type AiProvider = "gemini" | "openai";

export type GenerateAiTextOptions = {
  systemInstruction: string;
  input: unknown;
  responseSchema?: Record<string, unknown>;
};

export type AiTextResult = {
  text: string;
  provider: AiProvider;
  sourceType: string;
};

export async function generateAiText(
  options: GenerateAiTextOptions,
): Promise<AiTextResult | null> {
  const provider = selectedProvider();
  return provider === "openai"
    ? await generateWithOpenAi(options)
    : await generateWithGemini(options);
}

function selectedProvider(): AiProvider {
  return Deno.env.get("AI_PROVIDER")?.toLowerCase() === "openai"
    ? "openai"
    : "gemini";
}

async function generateWithGemini(
  options: GenerateAiTextOptions,
): Promise<AiTextResult | null> {
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) return null;

  const body: Record<string, unknown> = {
    model: Deno.env.get("GEMINI_MODEL") ?? "gemini-3.5-flash",
    input: JSON.stringify(options.input),
    system_instruction: options.systemInstruction,
    store: false,
  };
  if (options.responseSchema) {
    body.response_format = {
      type: "text",
      mime_type: "application/json",
      schema: options.responseSchema,
    };
  }

  const response = await fetch(
    "https://generativelanguage.googleapis.com/v1/interactions",
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": apiKey,
      },
      body: JSON.stringify(body),
    },
  );
  if (!response.ok) return null;

  const data = await response.json() as Record<string, unknown>;
  const text = extractGeminiText(data);
  return text
    ? { text, provider: "gemini", sourceType: "gemini_interactions" }
    : null;
}

async function generateWithOpenAi(
  options: GenerateAiTextOptions,
): Promise<AiTextResult | null> {
  const apiKey = Deno.env.get("OPENAI_API_KEY");
  if (!apiKey) return null;

  const body: Record<string, unknown> = {
    model: Deno.env.get("OPENAI_MODEL") ?? "gpt-4.1-mini",
    input: [
      { role: "system", content: options.systemInstruction },
      { role: "user", content: JSON.stringify(options.input) },
    ],
  };
  if (options.responseSchema) {
    body.text = { format: { type: "json_object" } };
  }

  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  if (!response.ok) return null;

  const data = await response.json() as Record<string, unknown>;
  const text = extractOpenAiText(data);
  return text
    ? { text, provider: "openai", sourceType: "openai_responses" }
    : null;
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
