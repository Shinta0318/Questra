import { generateAiText } from "../_shared/ai_provider.ts";
import { jsonResponse, preflightResponse, readJson } from "../_shared/http.ts";

const guideTypes = [
  "route",
  "knowledge",
  "training",
  "guild",
  "resource",
  "opportunity",
];

Deno.serve(async (req) => {
  const preflight = preflightResponse(req);
  if (preflight) return preflight;
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, { status: 405 });
  }
  const payload = await readJson<{ quest?: Record<string, unknown> }>(req);
  if (!payload) {
    return jsonResponse({ error: "Invalid JSON body" }, { status: 400 });
  }

  try {
    const result = await generateAiText({
      feature: "quest_guides",
      promptVersion: "quest_guides_v1",
      systemInstruction:
        "You are Arc, Questra's gentle star navigator. Return only compact Japanese JSON. Keep each guide practical, warm, and distinct. Never describe Arc as an assistant.",
      input: {
        task: "Create exactly six Quest guides, one for each requested guide_type.",
        guide_types: guideTypes,
        quest: payload.quest ?? {},
      },
      responseSchema: {
        type: "object",
        properties: {
          guides: {
            type: "array",
            minItems: 6,
            maxItems: 6,
            items: {
              type: "object",
              properties: {
                guide_type: { type: "string", enum: guideTypes },
                title: { type: "string" },
                description: { type: "string" },
                suggested_actions: {
                  type: "array",
                  minItems: 2,
                  maxItems: 3,
                  items: { type: "string" },
                },
              },
              required: ["guide_type", "title", "description", "suggested_actions"],
            },
          },
        },
        required: ["guides"],
      },
      maxOutputTokens: 1_200,
      temperature: 0.6,
    });
    if (!result) return planningUnavailable();
    const parsed = JSON.parse(stripFence(result.text)) as { guides?: unknown };
    const guides = normalizeGuides(parsed.guides);
    return jsonResponse({
      guides,
      source_type: result.sourceType,
    }, { status: guides.length === 6 ? 200 : 503 });
  } catch (_) {
    return planningUnavailable();
  }
});

function normalizeGuides(value: unknown) {
  if (!Array.isArray(value)) return [];
  return value.slice(0, 6).map((item) => {
    const data = isRecord(item) ? item : {};
    const actions = Array.isArray(data.suggested_actions)
      ? data.suggested_actions.filter((action): action is string => typeof action === "string").slice(0, 3)
      : [];
    const guideType = String(data.guide_type);
    const title = requiredText(data.title);
    const description = requiredText(data.description);
    if (!guideTypes.includes(guideType) || !title || !description || actions.length < 2) return null;
    return { guide_type: guideType, title, description, suggested_actions: actions };
  }).filter((item): item is NonNullable<typeof item> => item !== null);
}

function planningUnavailable() {
  return jsonResponse({
    status: "retryable_error",
    error: "quest_guides_temporarily_unavailable",
    input_preserved: true,
    manual_path_available: true,
  }, { status: 503 });
}

function requiredText(value: unknown) {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

function stripFence(value: string) {
  return value.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "").trim();
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
