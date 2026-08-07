import { ModelRole, ThinkingLevel } from "./contracts.ts";
import { ModelDefinition, modelSupportsThinking } from "./model_registry.ts";

const DEFAULT_LEVELS: Record<ModelRole, ThinkingLevel> = {
  lightweight_classifier: "low",
  quest_understanding: "medium",
  quest_proposal: "medium",
  strategic_planner: "high",
  mission_generator: "high",
  mission_critic: "high",
  targeted_repair: "medium",
  schema_repair: "low",
};

export type PlanningComplexity = {
  longTerm?: boolean;
  ambiguous?: boolean;
  highRisk?: boolean;
  constraintCount?: number;
  dependencyCount?: number;
  priorRepairCount?: number;
};

export function resolveThinkingLevel(role: ModelRole, model: ModelDefinition, complexity: PlanningComplexity = {}): ThinkingLevel {
  const configured = Deno.env.get(`GEMINI_THINKING_${role.toUpperCase()}`) as ThinkingLevel | undefined;
  let requested = configured ?? DEFAULT_LEVELS[role];
  const complex = complexity.longTerm || complexity.ambiguous || complexity.highRisk ||
    (complexity.constraintCount ?? 0) >= 3 || (complexity.dependencyCount ?? 0) >= 5 ||
    (complexity.priorRepairCount ?? 0) >= 2;
  if (complex && (role === "strategic_planner" || role === "mission_generator")) requested = "high";
  return modelSupportsThinking(model, requested) ? requested : model.defaultThinkingLevel;
}
