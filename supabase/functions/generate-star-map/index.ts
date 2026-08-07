import { generateAiText } from "../_shared/ai_provider.ts";
import { jsonResponse, preflightResponse, readJson } from "../_shared/http.ts";

Deno.serve(async (req) => {
  const preflight = preflightResponse(req);
  if (preflight) return preflight;
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, { status: 405 });
  }
  const payload = await readJson<{
    quest?: Record<string, unknown>;
    guide?: Record<string, unknown>;
  }>(req);
  if (!payload) {
    return jsonResponse({ error: "Invalid JSON body" }, { status: 400 });
  }

  const guideType = text(payload.guide?.guide_type, "route");
  const fallback = [{
    title: "最初に確認する星",
    description: "Questに必要な条件をひとつ選び、信頼できる一次情報で確認します。",
    url: null,
    content_type: "suggestion",
    guide_type: guideType,
    source_type: "local_star_map",
  }];

  try {
    const result = await generateAiText({
      feature: "star_map_generation",
      promptVersion: "star_map_v1",
      systemInstruction:
        "You are Arc, Questra's gentle star navigator. Return only compact Japanese JSON. Suggest useful search directions, but never invent URLs, sources, facts, or endorsements.",
      input: {
        task: "Suggest up to three safe research directions for this Quest. Do not provide URLs.",
        quest: payload.quest ?? {},
        guide: payload.guide ?? {},
      },
      responseSchema: {
        type: "object",
        properties: {
          items: {
            type: "array",
            minItems: 1,
            maxItems: 3,
            items: {
              type: "object",
              properties: {
                title: { type: "string" },
                description: { type: "string" },
              },
              required: ["title", "description"],
            },
          },
        },
        required: ["items"],
      },
      maxOutputTokens: 500,
      temperature: 0.45,
    });
    if (!result) return jsonResponse({ items: fallback });
    const parsed = JSON.parse(stripFence(result.text)) as { items?: unknown };
    const items = Array.isArray(parsed.items)
      ? parsed.items.slice(0, 3).map((item) => {
        const data = isRecord(item) ? item : {};
        return {
          title: text(data.title, "次に調べる星"),
          description: text(data.description, "信頼できる一次情報で確認します。"),
          url: null,
          content_type: "suggestion",
          guide_type: guideType,
          source_type: result.sourceType,
        };
      })
      : fallback;
    return jsonResponse({ items: items.length ? items : fallback });
  } catch (_) {
    return jsonResponse({ items: fallback });
  }
});

function text(value: unknown, fallback: string) {
  return typeof value === "string" && value.trim() ? value.trim() : fallback;
}

function stripFence(value: string) {
  return value.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "").trim();
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
