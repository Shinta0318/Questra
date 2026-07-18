import { generateAiText } from "../_shared/ai_provider.ts";

type QuestPayload = {
  id?: string;
  title?: string;
  description?: string;
  difficulty?: string;
  category?: string;
  target_date?: string | null;
};

type MissionCandidate = {
  title: string;
  description: string;
  guide_type: string;
  difficulty: string;
};

Deno.serve(async (req) => {
  const { quest } = (await req.json()) as { quest?: QuestPayload };
  const guide = await buildArcQuestGuide(quest ?? {});
  return Response.json(guide);
});

async function buildArcQuestGuide(quest: QuestPayload) {
  try {
    const result = await generateAiText({
      systemInstruction:
        "You are Arc, Questra's star navigator. Reply only as compact JSON. Use gentle Japanese, nautical and star imagery, and never describe Arc as an assistant.",
      input: {
        task:
          "Create a Quest guide with summary, path, cautions, encouragement, and at least 3 mission_candidates.",
        quest,
      },
      responseSchema: questGuideSchema,
    });
    if (!result) return fallbackGuide(quest);

    const parsed = JSON.parse(stripJsonFence(result.text));
    return normalizeGuide(quest, parsed, `${result.provider}_arc_quest_guide`);
  } catch (_error) {
    return fallbackGuide(quest);
  }
}

const questGuideSchema = {
  type: "object",
  properties: {
    summary: { type: "string" },
    path: { type: "string" },
    cautions: { type: "string" },
    encouragement: { type: "string" },
    mission_candidates: {
      type: "array",
      minItems: 3,
      items: {
        type: "object",
        properties: {
          title: { type: "string" },
          description: { type: "string" },
          guide_type: {
            type: "string",
            enum: ["route", "knowledge", "training", "guild", "resource", "opportunity"],
          },
          difficulty: { type: "string", enum: ["easy", "normal"] },
        },
        required: ["title", "description", "guide_type", "difficulty"],
      },
    },
  },
  required: ["summary", "path", "cautions", "encouragement", "mission_candidates"],
};

function stripJsonFence(value: string) {
  return value.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "").trim();
}

function fallbackGuide(quest: QuestPayload) {
  const title = quest.title?.trim() || "新しいQuest";
  const category = quest.category?.trim() || "冒険";
  const difficulty = difficultyLabel(quest.difficulty);
  return normalizeGuide(
    quest,
    {
      summary:
        `「${title}」は、${category}の星へ向かう${difficulty}Questです。目的地を小さなMissionに分けるほど、航路は澄んでいきます。`,
      path:
        "まず到達点を一文で固定し、今日できる最小Missionを選びます。次にTrailへ気づきを残し、3日ごとに航路を見直しましょう。",
      cautions:
        "計画を大きくしすぎると動き出しが重くなります。迷ったら10分で終わる形までMissionを小さくしてください。",
      encouragement:
        "キャプテン、このQuestはもう星図に灯っています。最初の一歩は小さくて大丈夫。Arcは航路の変化を一緒に見ています。",
      mission_candidates: [
        {
          title: `${title}の到達点を一文で書く`,
          description: "達成した状態、期限、最初に確認したい基準を短く書き出します。",
          guide_type: "route",
          difficulty: "easy",
        },
        {
          title: `${category}で必要な知識を3つ集める`,
          description: "分からないことを3つだけ選び、最初に調べる順番を決めます。",
          guide_type: "knowledge",
          difficulty: "easy",
        },
        {
          title: `10分だけ${title}を進める`,
          description: "今すぐできる最小の練習や準備を10分だけ試し、結果をTrailに残します。",
          guide_type: "training",
          difficulty: "easy",
        },
      ],
    },
    "local_arc_quest_guide",
  );
}

function normalizeGuide(
  quest: QuestPayload,
  data: Record<string, unknown>,
  sourceType: string,
) {
  const candidates = Array.isArray(data.mission_candidates)
    ? data.mission_candidates
    : [];
  const normalizedCandidates = candidates
    .map(normalizeCandidate)
    .filter((candidate): candidate is MissionCandidate => candidate !== null);

  const fallbackCandidates = fallbackGuideWithoutRecursion(quest);
  return {
    summary: textOr(data.summary, fallbackCandidates.summary),
    path: textOr(data.path, fallbackCandidates.path),
    cautions: textOr(data.cautions, fallbackCandidates.cautions),
    encouragement: textOr(
      data.encouragement,
      fallbackCandidates.encouragement,
    ),
    mission_candidates:
      normalizedCandidates.length >= 3
        ? normalizedCandidates
        : fallbackCandidates.mission_candidates,
    source_type: sourceType,
  };
}

function fallbackGuideWithoutRecursion(quest: QuestPayload) {
  const title = quest.title?.trim() || "新しいQuest";
  const category = quest.category?.trim() || "冒険";
  return {
    summary: `「${title}」の輪郭を整理しました。`,
    path: "最初のMissionを選び、Trailで航路を記録しましょう。",
    cautions: "迷ったらMissionを小さくしてください。",
    encouragement: "この一歩は、ちゃんと星図に残ります。",
    mission_candidates: [
      {
        title: `${title}の到達点を一文で書く`,
        description: "達成した状態を短く書きます。",
        guide_type: "route",
        difficulty: "easy",
      },
      {
        title: `${category}の最初の知識を調べる`,
        description: "最初に知りたいことを1つ調べます。",
        guide_type: "knowledge",
        difficulty: "easy",
      },
      {
        title: `${title}を10分だけ試す`,
        description: "最小の一歩を10分だけ実行します。",
        guide_type: "training",
        difficulty: "easy",
      },
    ],
  };
}

function normalizeCandidate(candidate: unknown): MissionCandidate | null {
  if (!candidate || typeof candidate !== "object") {
    return null;
  }
  const data = candidate as Record<string, unknown>;
  return {
    title: textOr(data.title, "最初の一歩を選ぶ"),
    description: textOr(data.description, "今日できる小さなMissionです。"),
    guide_type: guideType(data.guide_type),
    difficulty: difficulty(data.difficulty),
  };
}

function textOr(value: unknown, fallback: string) {
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : fallback;
}

function guideType(value: unknown) {
  const allowed = [
    "route",
    "knowledge",
    "training",
    "guild",
    "resource",
    "opportunity",
  ];
  return typeof value === "string" && allowed.includes(value)
    ? value
    : "route";
}

function difficulty(value: unknown) {
  return value === "normal" ? "normal" : "easy";
}

function difficultyLabel(value?: string) {
  switch (value) {
    case "easy":
      return "やさしい";
    case "hard":
      return "むずかしい";
    case "legendary":
      return "伝説級";
    default:
      return "ふつう";
  }
}
