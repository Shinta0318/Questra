import { generateAiText } from "../_shared/ai_provider.ts";
import { jsonResponse, preflightResponse, readJson } from "../_shared/http.ts";

type AdviceRequest = {
  quest?: Record<string, unknown>;
  guide?: Record<string, unknown>;
};

Deno.serve(async (req) => {
  const preflight = preflightResponse(req);
  if (preflight) return preflight;
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, { status: 405 });
  }
  const payload = await readJson<AdviceRequest>(req);
  if (!payload) {
    return jsonResponse({ error: "Invalid JSON body" }, { status: 400 });
  }

  const guideType = text(payload.guide?.guide_type, "route");
  const fallback = {
    advice_text: "今日できるいちばん小さな一歩を選ぼう。焦らなくても、航路は少しずつ見えてくるよ。",
    guide_type: guideType,
    emotion: guideType === "training" ? "support" : "normal",
    source_type: "local_arc_advice",
  };

  try {
    const result = await generateAiText({
      systemInstruction:
        "You are Arc, Questra's gentle star navigator. Return only compact Japanese JSON. Celebrate the challenge, avoid commands, and never describe Arc as an assistant.",
      input: {
        task: "Give one specific, warm next-step suggestion in 90 Japanese characters or fewer.",
        quest: payload.quest ?? {},
        guide: payload.guide ?? {},
      },
      responseSchema: {
        type: "object",
        properties: { advice_text: { type: "string" } },
        required: ["advice_text"],
      },
      maxOutputTokens: 220,
      temperature: 0.7,
    });
    if (!result) return jsonResponse(fallback);
    const parsed = JSON.parse(stripFence(result.text)) as Record<string, unknown>;
    return jsonResponse({
      advice_text: text(parsed.advice_text, fallback.advice_text),
      guide_type: guideType,
      emotion: fallback.emotion,
      source_type: result.sourceType,
    });
  } catch (_) {
    return jsonResponse(fallback);
  }
});

function text(value: unknown, fallback: string) {
  return typeof value === "string" && value.trim() ? value.trim() : fallback;
}

function stripFence(value: string) {
  return value.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "").trim();
}
