import { generateAiText } from "../_shared/ai_provider.ts";
import {
  jsonResponse,
  preflightResponse,
  readJson,
} from "../_shared/http.ts";
import { resolveQuestPlanningTemplate } from "./quest_planning_templates.ts";
import { deterministicSafetyAssessment } from "../_shared/safety_guard.ts";

type QuestPayload = {
  id?: string;
  title?: string;
  description?: string;
  difficulty?: string;
  category?: string;
  target_date?: string | null;
  planning_context?: {
    consent_granted?: boolean;
    weekly_minutes?: number | null;
    budget_label?: string | null;
    location?: string | null;
    experience?: string | null;
    available_resources?: string[];
    preferences?: string[];
    companion_type?: string | null;
    setback_reasons?: string[];
    approved_mission_history_summary?: string | null;
  } | null;
};

type MissionCandidate = {
  plan_key: string;
  title: string;
  description: string;
  purpose: string;
  done_condition: string;
  expected_output: string;
  verification_type: string;
  action: string;
  optionality: string;
  source_requirement: string;
  confidence: number;
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
  mission_feedback_reason?: string;
};

type QuestUnderstanding = {
  original_wish: string;
  quest_outcome: string;
  success_evidence: string;
  motivation: string;
  current_state: string;
  constraints: string[];
  known_resources: string[];
  unknowns: string[];
  planning_risks: string[];
  planning_mode: string;
  assumptions: string[];
  version: number;
};

Deno.serve(async (req) => {
  const preflight = preflightResponse(req);
  if (preflight) return preflight;
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, { status: 405 });
  }
  const payload = await readJson<{
    mode?: string;
    wish?: string;
    target_date?: string | null;
    quest?: QuestPayload;
    mission?: Record<string, unknown>;
    regeneration_intent?: string;
    planning_feedback?: PlanningFeedback[];
    quest_understanding?: QuestUnderstanding;
  }>(req);
  if (!payload) {
    return jsonResponse({ error: "Invalid JSON body" }, { status: 400 });
  }
  if (payload.mode === "quest_intent") {
    const wish = typeof payload.wish === "string"
      ? payload.wish.trim().slice(0, 1200)
      : "";
    if (!wish) {
      return jsonResponse({ error: "wish_required" }, { status: 400 });
    }
    const safety = deterministicSafetyAssessment(wish);
    if (safety) {
      return jsonResponse({ error: "unsafe_intent", safety }, { status: 422 });
    }
    const intent = await buildQuestIntent(wish, payload.target_date ?? null);
    return intent ? jsonResponse(intent) : planningUnavailable("quest_intent");
  }
  if (payload.mode === "regenerate_mission") {
    const quest = payload.quest ?? {};
    const mission = payload.mission ?? {};
    const safety = deterministicSafetyAssessment(
      `${quest.title ?? ""}\n${quest.description ?? ""}\n${mission.title ?? ""}`,
    );
    if (safety) {
      return jsonResponse({ error: "unsafe_intent", safety }, { status: 422 });
    }
    const regeneration = await buildMissionRegeneration(
      quest,
      mission,
      payload.regeneration_intent ?? "moreSpecific",
    );
    return regeneration
      ? jsonResponse(regeneration)
      : planningUnavailable("mission_regeneration");
  }
  const { quest, planning_feedback: planningFeedback } = payload;
  const sanitizedQuest: QuestPayload = {
    ...(quest ?? {}),
    planning_context: sanitizePlanningContext(quest?.planning_context),
  };
  const safety = deterministicSafetyAssessment(
    `${sanitizedQuest.title ?? ""}\n${sanitizedQuest.description ?? ""}`,
  );
  if (safety) {
    return jsonResponse(
      { error: "unsafe_intent", safety },
      { status: 422 },
    );
  }
  const guide = await buildArcQuestGuide(
    sanitizedQuest,
    planningFeedback ?? [],
    payload.quest_understanding,
  );
  return guide ? jsonResponse(guide) : planningUnavailable("quest_guide");
});

const questTypes = [
  "achievement",
  "experience",
  "travel",
  "learning",
  "habit",
  "career",
  "financial",
  "creation",
  "health_fitness",
  "relationship",
  "purchase",
  "event",
  "exploration",
  "other",
] as const;

const clarificationTypes = [
  "deadline",
  "budget",
  "location",
  "experience",
  "safety",
  "party",
  "purpose",
  "target_level",
  "duration",
  "frequency",
] as const;

function questIntentSchema() {
  return {
    type: "object",
    properties: {
      quest_type: { type: "string", enum: questTypes },
      clarity: {
        type: "string",
        enum: ["clear", "needs_clarification", "multiple_directions"],
      },
      optimized_title: { type: "string" },
      summary: { type: "string" },
      success_condition: { type: "string" },
      clarification_questions: {
        type: "array",
        minItems: 0,
        maxItems: 3,
        items: {
          type: "object",
          properties: {
            type: { type: "string", enum: clarificationTypes },
            label: { type: "string" },
            hint: { type: "string" },
          },
          required: ["type", "label", "hint"],
        },
      },
      directions: {
        type: "array",
        minItems: 0,
        maxItems: 3,
        items: {
          type: "object",
          properties: {
            title: { type: "string" },
            success_condition: { type: "string" },
            rationale: { type: "string" },
          },
          required: ["title", "success_condition", "rationale"],
        },
      },
    },
    required: [
      "quest_type",
      "clarity",
      "optimized_title",
      "summary",
      "success_condition",
      "clarification_questions",
      "directions",
    ],
  };
}

async function buildQuestIntent(wish: string, targetDate: string | null) {
  try {
    const result = await generateAiText({
      feature: "quest_intent",
      promptVersion: "quest_intent_v2",
      systemInstruction:
        "You are Arc's private Quest intent planner. Understand the Japanese wish semantically. Never create a title by appending generic phrases such as 小さく試す, 習慣にする, 本格的に取り組む, 挑戦する, or 達成する. If the intent is clear, return clarity=clear, no questions, and an empty directions array. Ask only questions whose answers materially change the route, safety, or success evidence, maximum three. Return 2-3 directions only when there are genuinely different achievable outcomes; never return mere paraphrases. A habit Quest is valid only when the meaning is actually habitual. Do not generate Missions in this operation. Use natural Japanese and schema JSON only.",
      input: {
        task:
          "Classify the internal Quest type, decide whether clarification is necessary, and create one confirmation-ready Quest summary. Candidate directions are optional, never mandatory.",
        wish,
        target_date: targetDate,
      },
      responseSchema: questIntentSchema(),
      maxOutputTokens: 1_500,
      temperature: 0.35,
    });
    if (!result) return null;
    const parsed = JSON.parse(stripJsonFence(result.text));
    const clarity = parsed.clarity;
    const questions = Array.isArray(parsed.clarification_questions)
      ? parsed.clarification_questions.slice(0, 3)
      : [];
    const directions = Array.isArray(parsed.directions)
      ? parsed.directions.slice(0, 3).filter((item: unknown) =>
        isValidQuestDirection(wish, item)
      )
      : [];
    if (clarity === "multiple_directions" && directions.length < 2) {
      return null;
    }
    if (clarity !== "multiple_directions" && directions.length > 0) {
      return null;
    }
    if (clarity === "clear" && questions.length > 0) return null;
    return {
      ...parsed,
      clarification_questions: questions,
      directions,
      source_type: `${result.provider}_quest_intent`,
    };
  } catch (_error) {
    return null;
  }
}

function isValidQuestDirection(wish: string, value: unknown): boolean {
  if (!value || typeof value !== "object") return false;
  const title = String((value as Record<string, unknown>).title ?? "").trim();
  const success = String(
    (value as Record<string, unknown>).success_condition ?? "",
  ).trim();
  if (!title || !success) return false;
  if (!title.startsWith(wish.trim())) return true;
  return ![
    "を小さく試す",
    "を習慣にする",
    "に本格的に取り組む",
    "に挑戦する",
    "を達成する",
  ].some((suffix) => title.endsWith(suffix));
}

function missionRegenerationSchema() {
  return {
    type: "object",
    properties: {
      reason: { type: "string" },
      mission_candidate: questGuideSchema.properties.mission_candidates.items,
    },
    required: ["reason", "mission_candidate"],
  };
}

async function buildMissionRegeneration(
  quest: QuestPayload,
  mission: Record<string, unknown>,
  intent: string,
) {
  try {
    const result = await generateAiText({
      feature: "mission_regeneration",
      promptVersion: "mission_regeneration_v1",
      systemInstruction:
        "You are Arc's private route planner. Rewrite exactly one incomplete Mission according to the requested intent. Preserve the Quest outcome and dependencies. Return one concrete action with observable completion evidence. Never rewrite a completed Mission, invent current facts, or mutate data. For travel, policy, qualification, health, finance, prices, schedules, or applications, require recent official or professional verification. Return only schema JSON.",
      input: {
        task: "Create one replacement candidate for explicit user approval.",
        quest,
        current_mission: mission,
        intent,
      },
      responseSchema: missionRegenerationSchema(),
      maxOutputTokens: 1_500,
      temperature: 0.35,
    });
    if (!result) return null;
    const parsed = JSON.parse(stripJsonFence(result.text));
    const candidate = normalizeCandidate(parsed.mission_candidate);
    if (!candidate) return null;
    return {
      reason: textOr(parsed.reason, "選んだ方針に合わせて、実行可能な一歩へ描き直しました。"),
      mission_candidate: candidate,
      source_type: `${result.provider}_mission_regeneration`,
    };
  } catch (_error) {
    return null;
  }
}

function sanitizePlanningContext(
  context: QuestPayload["planning_context"],
): QuestPayload["planning_context"] {
  if (!context || context.consent_granted !== true) return null;
  const boundedText = (value: unknown, max: number) =>
    typeof value === "string" ? value.trim().slice(0, max) || null : null;
  const boundedList = (value: unknown) =>
    Array.isArray(value)
      ? value.filter((item): item is string => typeof item === "string")
        .map((item) => item.trim().slice(0, 120))
        .filter(Boolean)
        .slice(0, 20)
      : [];
  const weeklyMinutes = Number.isFinite(context.weekly_minutes)
    ? Math.max(0, Math.min(10_080, Math.round(Number(context.weekly_minutes))))
    : null;
  return {
    consent_granted: true,
    weekly_minutes: weeklyMinutes,
    budget_label: boundedText(context.budget_label, 120),
    location: boundedText(context.location, 120),
    experience: boundedText(context.experience, 240),
    available_resources: boundedList(context.available_resources),
    preferences: boundedList(context.preferences),
    companion_type: boundedText(context.companion_type, 120),
    setback_reasons: boundedList(context.setback_reasons),
    approved_mission_history_summary: boundedText(
      context.approved_mission_history_summary,
      500,
    ),
  };
}

async function buildArcQuestGuide(
  quest: QuestPayload,
  planningFeedback: PlanningFeedback[],
  understanding?: QuestUnderstanding,
) {
  const template = resolveQuestPlanningTemplate(quest);
  const feedbackHint = summarizePlanningFeedback(planningFeedback);
  try {
    const result = await generateAiText({
      feature: "arc_quest_guide",
      promptVersion: "quest_guide_v2",
      systemInstruction:
        `You are Arc, Questra's star navigator and journey planner. Reply only as compact JSON in natural Japanese. Never describe Arc as an assistant. A Quest is the desired outcome; a Mission is one concrete action that advances it. Design the smallest complete route from the Quest's success condition and explicit constraints, not from a category template. Choose 3-20 Missions or Milestones dynamically; never pad to a round number. Never reuse the Quest title as a Mission title or emit duplicates. Each Mission must produce one observable outcome and its description must end with 「〜したら完了です」. Use stable plan_key values and only reference existing plan keys in parent_plan_key and dependency_plan_keys; keep the graph acyclic. A parent represents decomposition, while a dependency represents execution order. Use planning_context only when consent_granted is true. Treat omitted or null values as unknown and never infer them. Adjust Mission volume and active effort to weekly_minutes, while keeping necessary future Milestones visible. Offer lower-cost alternatives when budget is constrained. Evaluate the Quest and every Mission. Estimates are guidance, not promises. Use this quality and safety viewpoint only to catch omissions, never to copy wording or order: ${template.safety} ${feedbackHint} Infer a new plan shape for an unfamiliar intent. Do not invent current prices, laws, visa rules, schedules, medical outcomes, financial returns, or availability; create a verification Mission using official or professional sources. Enterprise support hints must be generic support categories, never hidden promotion or a fabricated company offer.`,
      input: {
        task:
          "Create a concrete Quest guide, a Quest evaluation, and a dynamically sized Mission graph. Return only fields in the schema.",
        quality_viewpoint: { id: template.id, safety: template.safety },
        quest,
        quest_understanding: understanding ?? null,
      },
      responseSchema: questGuideSchema,
      maxOutputTokens: 6_000,
      temperature: 0.55,
    });
    if (!result) return null;

    const parsed = JSON.parse(stripJsonFence(result.text));
    const initialGuide = normalizeGuide(
      quest,
      parsed,
      `${result.provider}_arc_quest_guide`,
    );
    if (!initialGuide) return null;
    return await critiqueAndRepairGuide(quest, initialGuide, understanding);
  } catch (_error) {
    return null;
  }
}

async function critiqueAndRepairGuide(
  quest: QuestPayload,
  initialGuide: NonNullable<ReturnType<typeof normalizeGuide>>,
  understanding?: QuestUnderstanding,
) {
  try {
    const result = await generateAiText({
      feature: "arc_quest_guide_critic",
      promptVersion: "quest_guide_critic_v1",
      systemInstruction:
        "You are the private quality critic for a Questra Quest route. Evaluate relevance, user specificity, concreteness, feasibility, done-condition verifiability, ordering, coverage, duplication, granularity, duration realism, and source freshness. Return the complete Mission list, preserving every good Mission exactly and repairing only failing Missions. Never expose critic reasoning to the user. Keep the graph acyclic and retain stable plan_key values where possible. Do not add commercial promotion. Perform at most this one repair pass.",
      input: {
        task:
          "Critique the proposed Mission graph and return one bounded repaired graph plus an aggregate quality score.",
        quest,
        quest_understanding: understanding ?? initialGuide.quest_understanding,
        mission_candidates: initialGuide.mission_candidates,
      },
      responseSchema: missionCriticSchema,
      maxOutputTokens: 5_000,
      temperature: 0.2,
    });
    if (!result) return initialGuide;
    const parsed = JSON.parse(stripJsonFence(result.text));
    const rawCandidates = Array.isArray(parsed.mission_candidates)
      ? parsed.mission_candidates
      : [];
    const repaired = reviewMissionCandidates(
      rawCandidates
        .map(normalizeCandidate)
        .filter((item): item is MissionCandidate => item !== null),
    ).slice(0, 20);
    if (repaired.length < 3) return initialGuide;
    const deterministicScore = scoreMissionCandidates(repaired);
    const providerScore = Number(parsed.overall_score);
    const score = Number.isFinite(providerScore)
      ? Math.min(deterministicScore, Math.max(0, Math.min(1, providerScore)))
      : deterministicScore;
    const previousByKey = new Map(
      initialGuide.mission_candidates.map((item) => [item.plan_key, item]),
    );
    const repairedCount = repaired.filter((item) =>
      JSON.stringify(previousByKey.get(item.plan_key)) !== JSON.stringify(item)
    ).length;
    return {
      ...initialGuide,
      mission_candidates: repaired,
      plan_quality: {
        score,
        generation_version: "quest_guide_v3",
        critic_passes: 1,
        repaired_mission_count: repairedCount,
        generated_at: new Date().toISOString(),
      },
      source_type: `${result.provider}_critic_repaired`,
    };
  } catch (_error) {
    return initialGuide;
  }
}

function summarizePlanningFeedback(feedback: PlanningFeedback[]) {
  const reasons = feedback
    .map((item) => item.mission_feedback_reason)
    .filter((item): item is string => typeof item === "string")
    .slice(0, 12);
  const valid = feedback.filter((item) =>
    Number.isFinite(item.generated_count) &&
    Number.isFinite(item.accepted_count) &&
    Number.isFinite(item.edited_count)
  ).slice(0, 8);
  if (valid.length === 0) {
    return reasons.length === 0
      ? "There is no prior owner feedback for this type of Quest. Prefer a broadly useful discovery-first plan."
      : `Owner feedback to respect without exposing it: ${reasons.join(", ")}. Avoid repeating rejected plan qualities.`;
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
  return `Owner-specific prior plan outcomes: ${acceptanceRate}% of candidates were adopted and ${editRate}% of adopted candidates were edited. Mission feedback: ${reasons.join(", ") || "none"}. Use only these aggregate signals; do not infer sensitive traits or repeat prior raw text.`;
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
    quest_understanding: questUnderstandingSchema(),
    mission_candidates: {
      type: "array",
      minItems: 1,
      maxItems: 30,
      items: {
        type: "object",
        properties: {
          plan_key: { type: "string" },
          title: { type: "string" },
          description: { type: "string" },
          purpose: { type: "string" },
          done_condition: { type: "string" },
          expected_output: { type: "string" },
          verification_type: { type: "string", enum: ["self_check", "artifact", "official_source", "professional_review"] },
          action: { type: "string" },
          optionality: { type: "string", enum: ["required", "optional"] },
          source_requirement: { type: "string", enum: ["none", "recent", "official", "professional"] },
          confidence: { type: "number", minimum: 0, maximum: 1 },
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
        required: ["plan_key", "title", "description", "purpose", "done_condition", "expected_output", "verification_type", "action", "optionality", "source_requirement", "confidence", "dependency_plan_keys", "guide_type", "difficulty", "priority", "category", "estimated_duration_days", "difficulty_score", "reference_hints", "enterprise_support_hints", "effort_estimate"],
      },
    },
  },
  required: ["summary", "path", "cautions", "encouragement", "effort_estimate", "quest_evaluation", "quest_dna", "quest_understanding", "mission_candidates"],
};

const missionCriticSchema = {
  type: "object",
  properties: {
    overall_score: { type: "number", minimum: 0, maximum: 1 },
    mission_candidates: questGuideSchema.properties.mission_candidates,
  },
  required: ["overall_score", "mission_candidates"],
};

function questUnderstandingSchema() {
  const list = { type: "array", items: { type: "string" }, maxItems: 12 };
  return {
    type: "object",
    properties: {
      original_wish: { type: "string" },
      quest_outcome: { type: "string" },
      success_evidence: { type: "string" },
      motivation: { type: "string" },
      current_state: { type: "string" },
      constraints: list,
      known_resources: list,
      unknowns: list,
      planning_risks: list,
      planning_mode: {
        type: "string",
        enum: ["project", "habit", "exploration", "preparation", "challenge"],
      },
      assumptions: list,
      version: { type: "integer", minimum: 1, maximum: 100 },
      evaluated_at: { type: "string" },
    },
    required: ["original_wish", "quest_outcome", "success_evidence", "motivation", "current_state", "constraints", "known_resources", "unknowns", "planning_risks", "planning_mode", "assumptions", "version", "evaluated_at"],
  };
}

function questDnaSchema() {
  const attributes = [
    "quest_type", "category", "theme", "difficulty", "duration", "budget", "location",
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
      estimated_mission_count: { type: "integer", minimum: 1, maximum: 30 },
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
  const reviewedCandidates = reviewMissionCandidates(normalizedCandidates);
  if (reviewedCandidates.length === 0) return null;
  const acceptedCandidates = reviewedCandidates.slice(0, 20);
  return {
    summary: textOr(data.summary, "ArcがQuestの航路を整理しました。"),
    path: textOr(data.path, "承認前の航路を確認してください。"),
    cautions: textOr(data.cautions, "不確かな情報は実行前に確認してください。"),
    encouragement: textOr(data.encouragement, "一緒に航路を確かめて進みましょう。"),
    mission_candidates: acceptedCandidates,
    effort_estimate: normalizeEffortEstimate(data.effort_estimate, 720, 60),
    quest_evaluation: normalizeQuestEvaluation(
      data.quest_evaluation,
      acceptedCandidates,
    ),
    quest_dna: normalizeQuestDna(data.quest_dna, quest),
    quest_understanding: normalizeQuestUnderstanding(
      data.quest_understanding,
      quest,
    ),
    plan_quality: {
      score: scoreMissionCandidates(
        acceptedCandidates,
      ),
      generation_version: "quest_guide_v3",
      critic_passes: 0,
      repaired_mission_count: 0,
      generated_at: new Date().toISOString(),
    },
    source_type: sourceType,
  };
}

function scoreMissionCandidates(candidates: MissionCandidate[]) {
  if (candidates.length === 0) return 0;
  const total = candidates.reduce((sum, item) => {
    let score = 0.35;
    if (item.purpose.trim().length >= 4) score += 0.1;
    if (item.done_condition.trim().length >= 6) score += 0.15;
    if (item.expected_output.trim().length >= 2) score += 0.1;
    if (/完了です[。]?$/.test(item.description)) score += 0.1;
    if (item.effort_estimate.active_effort_minutes > 0) score += 0.1;
    if (item.estimated_duration_days > 0) score += 0.1;
    return sum + Math.min(1, score);
  }, 0);
  return Math.round((total / candidates.length) * 100) / 100;
}

// The deterministic critic is deliberately conservative. It never mutates
// user data; it removes invalid AI candidates before the preview is shown.
function reviewMissionCandidates(candidates: MissionCandidate[]) {
  const knownKeys = new Set(candidates.map((item) => item.plan_key));
  const titles = new Set<string>();
  let valid = candidates.filter((item) => {
    const title = item.title.replace(/\s+/g, "").toLowerCase();
    const abstractOnly = /^(調べる|準備する|検討する|頑張る)$/.test(item.title.trim());
    const doneCondition = /完了です[。]?$/.test(item.description);
    const dependenciesValid = item.dependency_plan_keys.every((key) =>
      key !== item.plan_key && knownKeys.has(key)
    );
    if (!title || titles.has(title) || abstractOnly || !doneCondition || !dependenciesValid) {
      return false;
    }
    titles.add(title);
    return true;
  });
  let changed = true;
  while (changed) {
    const validKeys = new Set(valid.map((item) => item.plan_key));
    const next = valid.filter((item) =>
      item.dependency_plan_keys.every((key) => validKeys.has(key))
    );
    changed = next.length !== valid.length;
    valid = next;
  }

  const ordered: MissionCandidate[] = [];
  const resolved = new Set<string>();
  const remaining = [...valid];
  while (remaining.length > 0) {
    const index = remaining.findIndex((item) =>
      item.dependency_plan_keys.every((key) => resolved.has(key))
    );
    if (index < 0) break;
    const [next] = remaining.splice(index, 1);
    ordered.push(next);
    resolved.add(next.plan_key);
  }
  return ordered;
}

function planningUnavailable(operation: string) {
  return jsonResponse({
    status: "retryable_error",
    error: "planning_temporarily_unavailable",
    operation,
    input_preserved: true,
    manual_path_available: true,
  }, { status: 503 });
}

function normalizeQuestUnderstanding(value: unknown, quest: QuestPayload) {
  const data = value && typeof value === "object"
    ? value as Record<string, unknown>
    : {};
  const title = quest.title?.trim() || "新しいQuest";
  const description = quest.description?.trim() || "";
  return {
    original_wish: textOr(data.original_wish, title),
    quest_outcome: textOr(data.quest_outcome, `${title}を実現する`),
    success_evidence: textOr(
      data.success_evidence,
      `${title}を達成したと本人が確認し、Trailへ記録できる状態`,
    ),
    motivation: textOr(data.motivation, description),
    current_state: textOr(data.current_state, "現在地は未確認"),
    constraints: stringList(data.constraints, 12),
    known_resources: stringList(data.known_resources, 12),
    unknowns: stringList(data.unknowns, 12),
    planning_risks: stringList(data.planning_risks, 12),
    planning_mode: planningMode(data.planning_mode),
    assumptions: stringList(data.assumptions, 12),
    version: boundedInteger(data.version, 1, 100, 1),
    evaluated_at: new Date().toISOString(),
  };
}

function planningMode(value: unknown) {
  const allowed = ["project", "habit", "exploration", "preparation", "challenge"];
  return typeof value === "string" && allowed.includes(value)
    ? value
    : "project";
}

function normalizeQuestDna(value: unknown, quest: QuestPayload) {
  const raw = value && typeof value === "object" ? value as Record<string, unknown> : {};
  const rawAttributes = raw.attributes && typeof raw.attributes === "object"
    ? raw.attributes as Record<string, unknown>
    : {};
  const fallback: Record<string, string> = {
    quest_type: textOr(rawAttributes.quest_type, inferQuestType(quest)),
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

function inferQuestType(quest: QuestPayload) {
  const source = `${quest.title ?? ""} ${quest.description ?? ""}`.toLowerCase();
  if (/(旅行|旅|海外|観光|登山|キャンプ|行きたい)/.test(source)) return "travel";
  if (/(毎日|毎朝|毎週|習慣|継続)/.test(source)) return "habit";
  if (/(英語|学習|勉強|資格|習得)/.test(source)) return "learning";
  if (/(転職|就職|昇進|仕事|キャリア)/.test(source)) return "career";
  if (/(健康|運動|走る|筋トレ|減量)/.test(source)) return "health_fitness";
  if (/(作る|制作|執筆|開発|出版)/.test(source)) return "creation";
  return "other";
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
    done_condition: textOr(data.done_condition, textOr(data.description, "完了条件を記録したら完了です。")),
    expected_output: textOr(data.expected_output, "Questメモに残る確認可能な記録"),
    verification_type: verificationType(data.verification_type),
    action: textOr(data.action, textOr(data.title, "最初の一歩を進める")),
    optionality: data.optionality === "optional" ? "optional" : "required",
    source_requirement: sourceRequirement(
      data.source_requirement,
      textOr(data.category, "実行"),
      textOr(data.title, ""),
    ),
    confidence: boundedNumber(data.confidence, 0, 1, 0.6),
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
    estimated_mission_count: Math.max(1, Math.min(30, missions.length)),
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

function verificationType(value: unknown) {
  const allowed = ["self_check", "artifact", "official_source", "professional_review"];
  return typeof value === "string" && allowed.includes(value)
    ? value
    : "self_check";
}

function sourceRequirement(
  value: unknown,
  category: string,
  title: string,
) {
  const allowed = ["none", "recent", "official", "professional"];
  if (typeof value === "string" && allowed.includes(value)) return value;
  const source = `${category} ${title}`;
  if (/健康|医療|治療|法律|税|投資|金融/.test(source)) return "professional";
  if (/旅行|ビザ|資格|制度|申請|規約|料金/.test(source)) return "official";
  if (/価格|日程|営業時間|募集|予約/.test(source)) return "recent";
  return "none";
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
