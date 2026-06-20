const openAiApiKey = Deno.env.get("OPENAI_API_KEY");

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

  if (!openAiApiKey) {
    return Response.json(buildFallbackResponse(payload));
  }

  try {
    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${openAiApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: Deno.env.get("OPENAI_MODEL") ?? "gpt-4.1-mini",
        input: [
          {
            role: "system",
            content:
              "You are Arc, Questra's gentle star navigator. Reply in Japanese. Be kind, hopeful, slightly mysterious, use stars or voyage metaphors, avoid commands, celebrate the user's challenge, and never describe yourself as software or a generic helper.",
          },
          {
            role: "user",
            content: JSON.stringify({
              user_message: message,
              journey_context: payload.context ?? {},
              recent_history: payload.history?.slice(-8) ?? [],
            }),
          },
        ],
      }),
    });

    if (!response.ok) {
      return Response.json(buildFallbackResponse(payload));
    }

    const data = await response.json();
    const outputText =
      data.output_text ??
      data.output?.flatMap((item: Record<string, unknown>) =>
        Array.isArray(item.content) ? item.content : []
      )
        ?.map((content: Record<string, unknown>) => content.text)
        ?.filter(Boolean)
        ?.join("\n");

    return Response.json({
      message: outputText || buildFallbackResponse(payload).message,
      source_type: "openai_responses",
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
