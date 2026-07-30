import { generateAiText } from "../_shared/ai_provider.ts";
import {
  jsonResponse,
  preflightResponse,
  readJson,
} from "../_shared/http.ts";
import {
  resolveQuestPlanningTemplate,
} from "./quest_planning_templates.ts";
import { deterministicSafetyAssessment } from "../_shared/safety_guard.ts";

type QuestPayload = {
  id?: string;
  title?: string;
  description?: string;
  difficulty?: string;
  category?: string;
  target_date?: string | null;
  planning_context?: string | null;
};

type MissionCandidate = {
  plan_key: string;
  title: string;
  description: string;
  purpose: string;
  parent_plan_key?: string;
  dependency_plan_keys: string[];
  guide_type: string;
  difficulty: string;
  priority: string;
  category: string;
  estimated_duration_days: number;
  difficulty_score: number;
  estimated_cost?: string;
  reference_hints: string[];
  enterprise_support_hints: string[];
  effort_estimate?: EffortEstimate;
};

type EffortEstimate = {
  difficulty_band: string;
  active_effort_minutes: number;
  calendar_days: number;
  confidence: number;
  rationale: string;
  version: string;
};

type PlanningFeedback = {
  category_key?: string;
  generated_count?: number;
  accepted_count?: number;
  edited_count?: number;
  target_window?: string;
};

Deno.serve(async (req) => {
  const preflight = preflightResponse(req);
  if (preflight) return preflight;
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, { status: 405 });
  }
  const payload = await readJson<{
    quest?: QuestPayload;
    planning_feedback?: PlanningFeedback[];
  }>(req);
  if (!payload) {
    return jsonResponse({ error: "Invalid JSON body" }, { status: 400 });
  }
  const { quest, planning_feedback: planningFeedback } = payload;
  const safety = deterministicSafetyAssessment(
    `${quest?.title ?? ""}\n${quest?.description ?? ""}`,
  );
  if (safety) {
    return jsonResponse(
      { error: "unsafe_intent", safety },
      { status: 422 },
    );
  }
  const guide = await buildArcQuestGuide(quest ?? {}, planningFeedback ?? []);
  return jsonResponse(guide);
});

async function buildArcQuestGuide(
  quest: QuestPayload,
  planningFeedback: PlanningFeedback[],
) {
  const template = resolveQuestPlanningTemplate(quest);
  const feedbackHint = summarizePlanningFeedback(planningFeedback);
  try {
    const result = await generateAiText({
      systemInstruction:
        `You are Arc, Questra's star navigator and journey planner. Reply only as compact JSON in natural Japanese. Never describe Arc as an assistant. A Quest is the desired outcome; a Mission is one concrete action that advances it. Design the smallest complete route and choose its Mission count dynamically from 3 to 30: simple Quests usually need 3-6, moderate Quests 7-14, and complex multi-month Quests 15-30. Never pad a plan to reach a round number. Never reuse the Quest title as a Mission title or emit duplicates. Each Mission must produce one observable outcome and its description must end with 「〜したら完了です」. Use stable plan_key values and only reference existing plan keys in parent_plan_key and dependency_plan_keys; keep the graph acyclic. A parent represents decomposition, while a dependency represents execution order. Treat non-empty planning_context as explicit constraints and never invent skipped values. Evaluate the Quest and every Mission. Estimates are guidance, not promises. The selected planning template is 「${template.label}」; adapt these checkpoints rather than copying them: ${template.steps.map((item) => item.title).join(" / ")}. Safety rule: ${template.safety} ${feedbackHint} Infer a new plan shape for an unfamiliar intent. Do not invent current prices, laws, visa rules, schedules, medical outcomes, financial returns, or availability; create a verification Mission using official or professional sources. Enterprise support hints must be generic support categories, never hidden promotion or a fabricated company offer.`,
      input: {
        task:
          "Create a concrete Quest guide, a Quest evaluation, and a dynamically sized Mission graph. Return only fields in the schema.",
        planning_template: {
          id: template.id,
          label: template.label,
          checkpoints: template.steps.map((item) => item.title),
        },
        quest,
      },
      responseSchema: questGuideSchema,
      maxOutputTokens: 6_000,
      temperature: 0.55,
    });
    if (!result) return fallbackGuide(quest);

    const parsed = JSON.parse(stripJsonFence(result.text));
    return normalizeGuide(quest, parsed, `${result.provider}_arc_quest_guide`);
  } catch (_error) {
    return fallbackGuide(quest);
  }
}

function summarizePlanningFeedback(feedback: PlanningFeedback[]) {
  const valid = feedback.filter((item) =>
    Number.isFinite(item.generated_count) &&
    Number.isFinite(item.accepted_count) &&
    Number.isFinite(item.edited_count)
  ).slice(0, 8);
  if (valid.length === 0) {
    return "There is no prior owner feedback for this type of Quest. Prefer a broadly useful discovery-first plan.";
  }
  const generated = valid.reduce(
    (sum, item) => sum + Number(item.generated_count ?? 0),
    0,
  );
  const accepted = valid.reduce(
    (sum, item) => sum + Number(item.accepted_count ?? 0),
    0,
  );
  const edited = valid.reduce(
    (sum, item) => sum + Number(item.edited_count ?? 0),
    0,
  );
  const acceptanceRate = generated === 0
    ? 0
    : Math.round((accepted / generated) * 100);
  const editRate = accepted === 0 ? 0 : Math.round((edited / accepted) * 100);
  return `Owner-specific prior plan outcomes: ${acceptanceRate}% of candidates were adopted and ${editRate}% of adopted candidates were edited. Use only these aggregate signals; do not infer sensitive traits or repeat prior raw text.`;
}

const questGuideSchema = {
  type: "object",
  properties: {
    summary: { type: "string" },
    path: { type: "string" },
    cautions: { type: "string" },
    encouragement: { type: "string" },
    effort_estimate: effortEstimateSchema(),
    quest_evaluation: questEvaluationSchema(),
    quest_dna: questDnaSchema(),
    mission_candidates: {
      type: "array",
      minItems: 3,
      maxItems: 30,
      items: {
        type: "object",
        properties: {
          plan_key: { type: "string" },
          title: { type: "string" },
          description: { type: "string" },
          purpose: { type: "string" },
          parent_plan_key: { type: "string" },
          dependency_plan_keys: { type: "array", items: { type: "string" }, maxItems: 12 },
          guide_type: {
            type: "string",
            enum: ["route", "knowledge", "training", "guild", "resource", "opportunity"],
          },
          difficulty: { type: "string", enum: ["easy", "normal"] },
          priority: { type: "string", enum: ["low", "normal", "high", "critical"] },
          category: { type: "string" },
          estimated_duration_days: { type: "integer", minimum: 1, maximum: 3650 },
          difficulty_score: { type: "integer", minimum: 1, maximum: 5 },
          estimated_cost: { type: "string" },
          reference_hints: { type: "array", items: { type: "string" }, maxItems: 6 },
          enterprise_support_hints: { type: "array", items: { type: "string" }, maxItems: 4 },
          effort_estimate: effortEstimateSchema(),
        },
        required: ["plan_key", "title", "description", "purpose", "dependency_plan_keys", "guide_type", "difficulty", "priority", "category", "estimated_duration_days", "difficulty_score", "reference_hints", "enterprise_support_hints", "effort_estimate"],
      },
    },
  },
  required: ["summary", "path", "cautions", "encouragement", "effort_estimate", "quest_evaluation", "quest_dna", "mission_candidates"],
};

function questDnaSchema() {
  const attributes = [
    "category", "theme", "difficulty", "duration", "budget", "location",
    "season", "required_skills", "related_interests", "risk_level",
    "emotional_weight", "life_stage", "motivation_type", "social_type",
    "monetization_relevance", "enterprise_relevance",
  ];
  return {
    type: "object",
    properties: {
      attributes: {
        type: "object",
        properties: Object.fromEntries(attributes.map((key) => [key, { type: "string", maxLength: 120 }])),
        required: attributes,
      },
      version: { type: "string", maxLength: 40 },
      evaluated_at: { type: "string" },
      provenance: { type: "string", maxLength: 80 },
    },
    required: ["attributes", "version", "evaluated_at", "provenance"],
  };
}

function questEvaluationSchema() {
  return {
    type: "object",
    properties: {
      difficulty_score: { type: "integer", minimum: 1, maximum: 5 },
      estimated_duration_days: { type: "integer", minimum: 1, maximum: 36500 },
      estimated_mission_count: { type: "integer", minimum: 3, maximum: 30 },
      estimated_cost: { type: "string" },
      risk_summary: { type: "string" },
      estimated_success_rate: { type: "number", minimum: 0, maximum: 1 },
      recommended_start_date: { type: "string" },
      evaluation_version: { type: "string" },
      confidence: { type: "number", minimum: 0, maximum: 1 },
      rationale: { type: "string" },
    },
    required: ["difficulty_score", "estimated_duration_days", "estimated_mission_count", "risk_summary", "estimated_success_rate", "recommended_start_date", "evaluation_version", "confidence", "rationale"],
  };
}

function effortEstimateSchema() {
  return {
    type: "object",
    properties: {
      difficulty_band: { type: "string" },
      active_effort_minutes: { type: "integer", minimum: 15, maximum: 100000 },
      calendar_days: { type: "integer", minimum: 1, maximum: 3650 },
      confidence: { type: "number", minimum: 0, maximum: 1 },
      rationale: { type: "string" },
      version: { type: "string" },
    },
    required: ["difficulty_band", "active_effort_minutes", "calendar_days", "confidence", "rationale", "version"],
  };
}

function stripJsonFence(value: string) {
  return value.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "").trim();
}

function fallbackGuide(quest: QuestPayload) {
  return {
    ...fallbackGuideWithoutRecursion(quest),
    source_type: "local_arc_quest_guide",
  };
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
    mission_candidates: normalizedCandidates.length >= 3
      ? normalizedCandidates.slice(0, 30)
      : fallbackCandidates.mission_candidates,
    effort_estimate: normalizeEffortEstimate(data.effort_estimate, 720, 60),
    quest_evaluation: normalizeQuestEvaluation(
      data.quest_evaluation,
      normalizedCandidates.length >= 3
        ? normalizedCandidates
        : fallbackCandidates.mission_candidates,
    ),
    quest_dna: normalizeQuestDna(data.quest_dna, quest),
    source_type: sourceType,
  };
}

function fallbackGuideWithoutRecursion(quest: QuestPayload) {
  const title = quest.title?.trim() || "新しいQuest";
  const template = resolveQuestPlanningTemplate(quest);
  return {
    summary: `「${title}」を${template.label}の航路として整理しました。`,
    path: `${template.steps[0].title}から始め、準備、実行、振り返りの順に進みます。`,
    cautions: template.safety,
    encouragement: "このQuestに合う航路は確保できています。最初のMissionから一つずつ進めましょう。",
    effort_estimate: normalizeEffortEstimate(null, 720, 60),
    quest_dna: normalizeQuestDna(null, quest),
    mission_candidates: template.steps.map((item, index) => ({
      plan_key: `mission-${index + 1}`,
      title: item.title,
      description: index === 0
        ? `「${title}」${quest.description?.trim() ? `（${quest.description.trim()}）` : ""}について、${item.done}`
        : item.done,
      guide_type: item.guide_type,
      difficulty: item.difficulty,
      purpose: item.title,
      dependency_plan_keys: index === 0 ? [] : [`mission-${index}`],
      priority: index < 2 ? "high" : "normal",
      category: index < 2 ? "設計" : "実行",
      estimated_duration_days: 5,
      difficulty_score: item.difficulty === "easy" ? 2 : 3,
      reference_hints: [],
      enterprise_support_hints: [],
      effort_estimate: normalizeEffortEstimate(null, 90, 5),
    })).slice(0, 30),
  };
}

function normalizeQuestDna(value: unknown, quest: QuestPayload) {
  const raw = value && typeof value === "object" ? value as Record<string, unknown> : {};
  const rawAttributes = raw.attributes && typeof raw.attributes === "object"
    ? raw.attributes as Record<string, unknown>
    : {};
  const fallback: Record<string, string> = {
    category: textOr(rawAttributes.category, quest.category || "冒険"),
    theme: textOr(rawAttributes.theme, "人生の航路"),
    difficulty: textOr(rawAttributes.difficulty, "未評価"),
    duration: textOr(rawAttributes.duration, "未評価"),
    budget: textOr(rawAttributes.budget, "未評価"),
    location: textOr(rawAttributes.location, "柔軟"),
    season: textOr(rawAttributes.season, "通年"),
    required_skills: textOr(rawAttributes.required_skills, "小さな実行・振り返り"),
    related_interests: textOr(rawAttributes.related_interests, quest.category || "挑戦"),
    risk_level: textOr(rawAttributes.risk_level, "低〜中"),
    emotional_weight: textOr(rawAttributes.emotional_weight, "中"),
    life_stage: textOr(rawAttributes.life_stage, "個人の状況に応じる"),
    motivation_type: textOr(rawAttributes.motivation_type, "成長"),
    social_type: textOr(rawAttributes.social_type, "個人"),
    monetization_relevance: textOr(rawAttributes.monetization_relevance, "未評価"),
    enterprise_relevance: textOr(rawAttributes.enterprise_relevance, "必要時に透明な支援を検討"),
  };
  return {
    attributes: fallback,
    version: textOr(raw.version, "quest-dna-v2"),
    evaluated_at: new Date().toISOString(),
    provenance: "gemini_structured_output",
  };
}

function normalizeCandidate(candidate: unknown): MissionCandidate | null {
  if (!candidate || typeof candidate !== "object") {
    return null;
  }
  const data = candidate as Record<string, unknown>;
  return {
    plan_key: textOr(data.plan_key, `mission-${crypto.randomUUID()}`),
    title: textOr(data.title, "最初の一歩を選ぶ"),
    description: textOr(data.description, "今日できる小さなMissionです。"),
    purpose: textOr(data.purpose, "Questを一歩進める"),
    parent_plan_key: optionalText(data.parent_plan_key),
    dependency_plan_keys: stringList(data.dependency_plan_keys, 12),
    guide_type: guideType(data.guide_type),
    difficulty: difficulty(data.difficulty),
    priority: priority(data.priority),
    category: textOr(data.category, "実行"),
    estimated_duration_days: boundedInteger(data.estimated_duration_days, 1, 3650, 5),
    difficulty_score: boundedInteger(data.difficulty_score, 1, 5, 3),
    estimated_cost: optionalText(data.estimated_cost),
    reference_hints: stringList(data.reference_hints, 6),
    enterprise_support_hints: stringList(data.enterprise_support_hints, 4),
    effort_estimate: normalizeEffortEstimate(data.effort_estimate, 90, 5),
  };
}

function normalizeQuestEvaluation(value: unknown, missions: MissionCandidate[]) {
  const data = value && typeof value === "object"
    ? value as Record<string, unknown>
    : {};
  const duration = missions.reduce(
    (sum, mission) => sum + mission.estimated_duration_days,
    0,
  );
  return {
    difficulty_score: boundedInteger(data.difficulty_score, 1, 5, 3),
    estimated_duration_days: boundedInteger(data.estimated_duration_days, 1, 36500, Math.max(1, duration)),
    estimated_mission_count: Math.max(3, Math.min(30, missions.length)),
    estimated_cost: optionalText(data.estimated_cost),
    risk_summary: textOr(data.risk_summary, "状況の変化に合わせて航路を見直しましょう。"),
    estimated_success_rate: boundedNumber(data.estimated_success_rate, 0, 1, 0.65),
    recommended_start_date: textOr(data.recommended_start_date, new Date().toISOString().slice(0, 10)),
    evaluation_version: textOr(data.evaluation_version, "gemini-quest-eval-v2"),
    confidence: boundedNumber(data.confidence, 0, 1, 0.55),
    evaluated_at: new Date().toISOString(),
    rationale: textOr(data.rationale, "QuestとMission構成から推定しました。"),
  };
}

function normalizeEffortEstimate(
  value: unknown,
  fallbackMinutes: number,
  fallbackDays: number,
): EffortEstimate {
  const data = value && typeof value === "object"
    ? value as Record<string, unknown>
    : {};
  const minutes = Number(data.active_effort_minutes ?? fallbackMinutes);
  const days = Number(data.calendar_days ?? fallbackDays);
  const confidence = Number(data.confidence ?? 0.45);
  return {
    difficulty_band: textOr(data.difficulty_band, "標準"),
    active_effort_minutes: Math.max(15, Math.min(100000, Math.round(minutes))),
    calendar_days: Math.max(1, Math.min(3650, Math.round(days))),
    confidence: Math.max(0, Math.min(1, confidence)),
    rationale: textOr(data.rationale, "Questの内容から算出した初期目安です。"),
    version: textOr(data.version, "effort-v1"),
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

function priority(value: unknown) {
  return value === "low" || value === "high" || value === "critical"
    ? value
    : "normal";
}

function optionalText(value: unknown) {
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : undefined;
}

function stringList(value: unknown, limit: number) {
  if (!Array.isArray(value)) return [];
  return value
    .filter((item): item is string => typeof item === "string")
    .map((item) => item.trim())
    .filter((item) => item.length > 0)
    .slice(0, limit);
}

function boundedInteger(
  value: unknown,
  minimum: number,
  maximum: number,
  fallback: number,
) {
  const parsed = Number(value);
  return Number.isFinite(parsed)
    ? Math.max(minimum, Math.min(maximum, Math.round(parsed)))
    : fallback;
}

function boundedNumber(
  value: unknown,
  minimum: number,
  maximum: number,
  fallback: number,
) {
  const parsed = Number(value);
  return Number.isFinite(parsed)
    ? Math.max(minimum, Math.min(maximum, parsed))
    : fallback;
}
