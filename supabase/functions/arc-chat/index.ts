import { generateAiText } from "../_shared/ai_provider.ts";

type ArcChatRequest = {
  message?: string;
  history?: Array<{ role?: string; text?: string }>;
  context?: {
    active_quests?: Array<Record<string, unknown>>;
    recent_missions?: Array<Record<string, unknown>>;
    recent_trails?: Array<Record<string, unknown>>;
    memories?: Array<Record<string, unknown>>;
  };
};

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return Response.json({ error: "Method not allowed" }, { status: 405 });
  }

  const payload = (await req.json()) as ArcChatRequest;
  const message = payload.message?.trim() ?? "";
  if (!message) {
    return Response.json({
      message: "静かな星図だね。話したいことが見えたら、そっと教えて。",
      source_type: "arc_chat_fallback",
      quick_actions: ["次のMissionを選ぶ", "Trailを振り返る"],
    });
  }

  try {
    const result = await generateAiText({
      systemInstruction:
        "You are Arc, Questra's gentle star navigator. Reply in Japanese. Be kind, hopeful, slightly mysterious, use stars or voyage metaphors, avoid commands, celebrate the user's challenge, and never describe yourself as software or a generic helper.",
      input: {
        user_message: message,
        journey_context: payload.context ?? {},
        recent_history: payload.history?.slice(-8) ?? [],
      },
    });
    if (!result) return Response.json(buildFallbackResponse(payload));

    return Response.json({
      message: result.text,
      source_type: result.sourceType,
      quick_actions: ["次のMissionを選ぶ", "Trailを振り返る", "小さな一歩に分ける"],
    });
  } catch (_error) {
    return Response.json(buildFallbackResponse(payload));
  }
});

function buildFallbackResponse(payload: ArcChatRequest) {
  const quest = payload.context?.active_quests?.[0];
  const trail = payload.context?.recent_trails?.[0];
  const questTitle = typeof quest?.title === "string" ? quest.title : "今のQuest";
  const trailTitle = typeof trail?.title === "string" ? trail.title : "最近のTrail";

  return {
    message:
      `おかえり、キャプテン。\n「${questTitle}」へ向かう航路は、まだ少し星雲の中にあるみたい。でも「${trailTitle}」の足あとが、次の光になっているよ。\n今日はひとつだけ、小さなMissionに分けて進もう。`,
    source_type: "arc_chat_fallback",
    quick_actions: ["次のMissionを選ぶ", "Trailを振り返る", "小さな一歩に分ける"],
  };
}
