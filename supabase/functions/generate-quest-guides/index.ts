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

  const fallback = fallbackGuides(payload.quest);
  try {
    const result = await generateAiText({
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
    if (!result) return jsonResponse({ guides: fallback });
    const parsed = JSON.parse(stripFence(result.text)) as { guides?: unknown };
    const guides = normalizeGuides(parsed.guides);
    return jsonResponse({
      guides: guides.length === 6 ? guides : fallback,
      source_type: result.sourceType,
    });
  } catch (_) {
    return jsonResponse({ guides: fallback });
  }
});

function normalizeGuides(value: unknown) {
  if (!Array.isArray(value)) return [];
  return value.slice(0, 6).map((item, index) => {
    const data = isRecord(item) ? item : {};
    const actions = Array.isArray(data.suggested_actions)
      ? data.suggested_actions.filter((action): action is string => typeof action === "string").slice(0, 3)
      : [];
    return {
      guide_type: guideTypes.includes(String(data.guide_type))
        ? data.guide_type
        : guideTypes[index],
      title: text(data.title, `${guideTypes[index]}の航路`),
      description: text(data.description, "次の一歩を見つけるためのGuideです。"),
      suggested_actions: actions.length >= 2
        ? actions
        : ["今日できる一歩を選ぶ", "進んだことをTrailへ残す"],
    };
  });
}

function fallbackGuides(quest: Record<string, unknown> | undefined) {
  const title = text(quest?.title, "このQuest");
  return guideTypes.map((guideType) => ({
    guide_type: guideType,
    title: `${title}の航路を整える`,
    description: `${title}を無理なく進めるための${guideType} Guideです。`,
    suggested_actions: ["今日できる一歩を選ぶ", "進んだことをTrailへ残す"],
  }));
}

function text(value: unknown, fallback: string) {
  return typeof value === "string" && value.trim() ? value.trim() : fallback;
}

function stripFence(value: string) {
  return value.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "").trim();
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
