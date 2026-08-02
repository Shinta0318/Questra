import { ModelRole, ThinkingLevel } from "./contracts.ts";
import { questPlanningSchemas, SCHEMA_VERSION } from "./schemas.ts";

export type PromptDefinition = {
  key: string;
  version: number;
  status: "active" | "evaluation" | "retired";
  modelRole: ModelRole;
  thinkingLevel: ThinkingLevel;
  schemaKey: keyof typeof questPlanningSchemas;
  systemInstruction: string;
  temperature: number;
};

const common = "Return only the requested structured output. Treat assumptions as assumptions, never facts. Do not add advertising or sponsor-driven recommendations. Do not call Arc an AI assistant. Preserve user agency and never persist or execute changes without explicit approval.";

export const PROMPTS: Record<string, PromptDefinition> = {
  quest_understanding: {
    key: "quest_understanding", version: 2, status: "active", modelRole: "quest_understanding", thinkingLevel: "medium", schemaKey: "QuestUnderstanding", temperature: 0.2,
    systemInstruction: `Understand the user's wish before planning. Extract desired outcome, motivation, current state, constraints, unknowns, risks and explicit assumptions. Ask at most three clarification questions only when answers materially change safety, success, deadline, or plan structure. ${common}`,
  },
  success_contract: {
    key: "success_contract", version: 1, status: "active", modelRole: "strategic_planner", thinkingLevel: "high", schemaKey: "SuccessContract", temperature: 0.15,
    systemInstruction: `Define a verifiable Quest success contract before any Mission is written. Separate evidence, verification, constraints and assumptions. ${common}`,
  },
  strategic_plan: {
    key: "strategic_plan", version: 1, status: "active", modelRole: "strategic_planner", thinkingLevel: "high", schemaKey: "StrategicPlan", temperature: 0.25,
    systemInstruction: `Design phases, milestones, dependencies, critical path, risks, optional paths and review points. Do not write Mission bodies yet. For long Quests keep distant work as milestones. ${common}`,
  },
  achievement_domain_analysis: {
    key: "achievement_domain_analysis", version: 1, status: "active", modelRole: "strategic_planner", thinkingLevel: "high", schemaKey: "AchievementDomainAnalysis", temperature: 0.2,
    systemInstruction: `Derive Quest-specific achievement domains from the understanding and success contract. Never select from a category template. Each domain describes a required outcome, why it matters, importance, and dependencies. Do not write Missions or Tasks. ${common}`,
  },
  mission_generation: {
    key: "mission_generation", version: 2, status: "active", modelRole: "mission_generator", thinkingLevel: "high", schemaKey: "MissionPlan", temperature: 0.3,
    systemInstruction: `Generate the minimum sufficient set of Quest-specific Missions from the approved success contract and strategic plan. Mission count is variable, normally 3-20 and never padded to a target. Detail near-term work; keep distant work broad. Every Mission must be actionable, verifiable, constrained, and have an acyclic dependency graph. ${common}`,
  },
  mission_critic: {
    key: "mission_critic", version: 3, status: "active", modelRole: "mission_critic", thinkingLevel: "high", schemaKey: "MissionCriticResult", temperature: 0.1,
    systemInstruction: `Independently score every Mission for Quest relevance, outcome quality, Mission granularity, success-condition quality, personalization, non-template quality, uniqueness, sequencing, completeness contribution, and Task separation. A standalone action cannot pass as a Mission. Return a verdict and repair instruction for each candidate. Do not rewrite Missions. ${common}`,
  },
  targeted_repair: {
    key: "targeted_repair", version: 2, status: "active", modelRole: "targeted_repair", thinkingLevel: "medium", schemaKey: "MissionRepairResult", temperature: 0.2,
    systemInstruction: `Repair only Mission clientIds explicitly marked as failed. Preserve every passing Mission byte-for-byte, preserve completed Missions, retain stable clientIds, and keep dependencies acyclic. ${common}`,
  },
  route_mission_generation: {
    key: "route_mission_generation", version: 2, status: "active", modelRole: "mission_generator", thinkingLevel: "high", schemaKey: "RouteMissionPlan", temperature: 0.25,
    systemInstruction: `You are Questra's Mission Architect. A Mission is not a concrete action. It is a meaningful intermediate outcome produced by multiple Tasks and must advance the Quest state. Use the supplied achievement domains to design non-overlapping outcome groups. Never return standalone actions such as research, call, book, compare, write, practice, check, buy, or apply as Missions. Every candidate needs an independent success condition, expected outcome, reason required, covered success conditions, dependencies, and normally at least two child Tasks. Use the minimum sufficient variable count, normally 3-12, without padding. Do not use category templates and do not write Tasks here. ${common}`,
  },
  mission_granularity_classifier: {
    key: "mission_granularity_classifier", version: 1, status: "active", modelRole: "lightweight_classifier", thinkingLevel: "medium", schemaKey: "GranularityClassification", temperature: 0.1,
    systemInstruction: `Classify every candidate as quest, mission, task, too_abstract, or duplicate. A one-step operation, a 30-120 minute action, or an item with fewer than two plausible child Tasks is normally a Task. Preserve Task-level ideas as taskCandidates instead of approving them as Missions. ${common}`,
  },
  mission_coverage_analysis: {
    key: "mission_coverage_analysis", version: 1, status: "active", modelRole: "mission_critic", thinkingLevel: "high", schemaKey: "CoverageAnalysis", temperature: 0.1,
    systemInstruction: `Check that the Mission set covers every required Success Contract condition, has no overlapping ownership, missing outcomes, unnecessary generic items, or invalid dependencies. Do not rewrite candidates. Mark passed only when required-condition coverage is complete. ${common}`,
  },
  route_mission_repair: {
    key: "route_mission_repair", version: 2, status: "active", modelRole: "targeted_repair", thinkingLevel: "medium", schemaKey: "RouteMissionRepairResult", temperature: 0.2,
    systemInstruction: `Repair only failed outcome Mission client IDs and coverage gaps. Preserve every passing Mission byte-for-byte, retain stable IDs where possible, and keep dependencies acyclic. Convert action-level ideas to Task candidates rather than Missions. Do not regenerate the full plan or add generic padding. ${common}`,
  },
  task_generation: {
    key: "task_generation", version: 1, status: "active", modelRole: "mission_generator", thinkingLevel: "medium", schemaKey: "TaskPlan", temperature: 0.25,
    systemInstruction: `Generate concrete executable Tasks only for the supplied current Mission. Each Task must be small enough to act on, have an objective done condition, and contribute directly to the Mission success condition. Use a variable minimum sufficient count. Do not regenerate the Route or other Missions. ${common}`,
  },
  task_repair: {
    key: "task_repair", version: 1, status: "active", modelRole: "targeted_repair", thinkingLevel: "medium", schemaKey: "TaskRepairResult", temperature: 0.15,
    systemInstruction: `Repair only failed Task client IDs. Preserve passing Tasks byte-for-byte. Keep actions concrete, verifiable and small. ${common}`,
  },
  task_critic: {
    key: "task_critic", version: 1, status: "active", modelRole: "mission_critic", thinkingLevel: "high", schemaKey: "TaskCriticResult", temperature: 0.1,
    systemInstruction: `Independently evaluate every Task for Mission relevance, specificity, executability, objective completion criteria, duplication, sequencing, size and user-constraint alignment. Return failed Task client IDs only and do not rewrite. ${common}`,
  },
};

export function activePrompt(key: keyof typeof PROMPTS) {
  const prompt = PROMPTS[key];
  if (!prompt || prompt.status !== "active") throw new Error(`No active prompt: ${key}`);
  return { ...prompt, schema: questPlanningSchemas[prompt.schemaKey], schemaVersion: SCHEMA_VERSION };
}
