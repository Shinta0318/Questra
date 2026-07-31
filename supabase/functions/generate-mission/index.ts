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
  const fallbackMission = {
    title: "今日の一歩を10分だけ進める",
    description: "Questにつながる具体的な行動をひとつ選び、10分だけ試してTrailへ残します。",
    guide_type: guideType,
    difficulty: "easy",
    status: "todo",
  };

  try {
    const result = await generateAiText({
      feature: "mission_generation",
      promptVersion: "mission_generation_v1",
      systemInstruction:
        "You are Arc, Questra's gentle star navigator. Return only compact Japanese JSON. Suggest a safe, concrete Mission that takes 5 to 30 minutes.",
      input: {
        task: "Create one immediately actionable Mission for this Quest and guide.",
        quest: payload.quest ?? {},
        guide: payload.guide ?? {},
      },
      responseSchema: {
        type: "object",
        properties: {
          title: { type: "string" },
          description: { type: "string" },
          difficulty: { type: "string", enum: ["easy", "normal"] },
        },
        required: ["title", "description", "difficulty"],
      },
      maxOutputTokens: 280,
      temperature: 0.55,
    });
    if (!result) return jsonResponse({ mission: fallbackMission });
    const parsed = JSON.parse(stripFence(result.text)) as Record<string, unknown>;
    return jsonResponse({
      mission: {
        title: text(parsed.title, fallbackMission.title),
        description: text(parsed.description, fallbackMission.description),
        guide_type: guideType,
        difficulty: parsed.difficulty === "normal" ? "normal" : "easy",
        status: "todo",
        source_type: result.sourceType,
      },
    });
  } catch (_) {
    return jsonResponse({ mission: fallbackMission });
  }
});

function text(value: unknown, fallback: string) {
  return typeof value === "string" && value.trim() ? value.trim() : fallback;
}

function stripFence(value: string) {
  return value.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "").trim();
}
