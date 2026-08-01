import { callGeminiInteraction } from "./interactions_adapter.ts";
import { ProviderRequest, ProviderResponse, ValidationIssue } from "./contracts.ts";
import { activePrompt, PROMPTS } from "./prompt_registry.ts";
import { decideGrounding } from "./grounding.ts";
import { validateRouteMissionPlan, validateTaskPlan } from "./validators.ts";

export type PlanningInput = {
  questId: string;
  wish: string;
  targetDate?: string | null;
  budget?: string | null;
  availableTime?: unknown;
  experience?: string | null;
  location?: string | null;
  constraints?: string[];
  approvedContext?: Record<string, unknown>;
  userId?: string | null;
  idempotencyKey: string;
};

export type PlanningPass = {
  name: string;
  status: "completed" | "failed" | "needs_clarification";
  output: unknown;
  provider?: Omit<ProviderResponse, "output" | "text" | "groundingMetadata">;
};

export type PlanningPipelineResult = {
  traceId: string;
  status: "preview_ready" | "needs_clarification" | "retryable_error" | "manual_path";
  passes: PlanningPass[];
  preview: unknown | null;
  issues: ValidationIssue[];
  versions: { pipeline: string; schema: string; prompts: Record<string, number> };
  persistenceAllowed: false;
};

export async function runQuestPlanningPipeline(input: PlanningInput): Promise<PlanningPipelineResult> {
  const traceId = crypto.randomUUID();
  const passes: PlanningPass[] = [];
  const prompts: Record<string, number> = {};
  const understanding = await runPass("quest_understanding", input, input, traceId, prompts);
  passes.push(understanding.pass);
  if (!understanding.response || understanding.response.error) return failed(traceId, passes, prompts, understanding.response?.error?.retryable);
  const understandingOutput = understanding.response.output as Record<string, unknown>;
  if (understandingOutput.clarificationRequired === true && Array.isArray(understandingOutput.clarificationQuestions) && understandingOutput.clarificationQuestions.length > 0) {
    return result(traceId, "needs_clarification", passes, null, [], prompts);
  }

  const success = await runPass("success_contract", { understanding: understandingOutput, explicit: input }, input, traceId, prompts);
  passes.push(success.pass);
  if (!success.response || success.response.error) return failed(traceId, passes, prompts, success.response?.error?.retryable);

  const grounding = decideGrounding(`${input.wish}\n${JSON.stringify(success.response.output)}`);
  const strategy = await runPass("strategic_plan", { understanding: understandingOutput, successContract: success.response.output, groundingDecision: grounding }, input, traceId, prompts, grounding.required ? [{ type: "google_search" }] : []);
  passes.push(strategy.pass);
  if (!strategy.response || strategy.response.error) return failed(traceId, passes, prompts, strategy.response?.error?.retryable);
  if (grounding.required && !strategy.response.groundingMetadata) {
    passes.push({ name: "grounding_validation", status: "failed", output: { reason: "grounding_required_but_missing" } });
    return result(traceId, "retryable_error", passes, null, [{ path: "$.grounding", code: "grounding_failed", message: "Current facts could not be verified" }], prompts);
  }

  const generated = await runPass("route_mission_generation", { questId: input.questId, understanding: understandingOutput, successContract: success.response.output, strategicPlan: strategy.response.output, groundingMetadata: strategy.response.groundingMetadata }, input, traceId, prompts);
  passes.push(generated.pass);
  if (!generated.response || generated.response.error) return failed(traceId, passes, prompts, generated.response?.error?.retryable);
  let plan = generated.response.output;
  let validation = validateRouteMissionPlan(plan, input.questId).issues;
  passes.push({ name: "rule_validation", status: validation.length ? "failed" : "completed", output: { issues: validation } });

  const critic = await runPass("mission_critic", { quest: input, plan, validationIssues: validation }, input, traceId, prompts);
  passes.push(critic.pass);
  if (!critic.response || critic.response.error) return failed(traceId, passes, prompts, critic.response?.error?.retryable);
  const failedIds = criticFailedIds(critic.response.output, validation);
  if (failedIds.length > 0) {
    const repair = await runPass("route_mission_repair", { quest: input, plan, critic: critic.response.output, failedMissionClientIds: failedIds, maxRepairPasses: 1 }, input, traceId, prompts);
    passes.push(repair.pass);
    if (!repair.response || repair.response.error) return failed(traceId, passes, prompts, repair.response?.error?.retryable);
    plan = repair.response.output;
    validation = validateRouteMissionPlan(plan, input.questId).issues;
  }
  passes.push({ name: "final_validation", status: validation.length ? "failed" : "completed", output: { issues: validation } });
  if (validation.length) return result(traceId, "manual_path", passes, null, validation, prompts);
  const routeMissions = (plan as { missions?: unknown[] }).missions ?? [];
  const currentMission = routeMissions.find((item) => item && typeof item === "object" && (item as { required?: unknown }).required === true) ?? routeMissions[0];
  if (!currentMission || typeof currentMission !== "object") return result(traceId, "manual_path", passes, null, [{ path: "$.missions", code: "missing_current_mission", message: "No Mission is available for Task generation" }], prompts);
  const missionClientId = String((currentMission as { clientId?: unknown }).clientId ?? "");
  const taskGenerated = await runPass("task_generation", { questId: input.questId, mission: currentMission, understanding: understandingOutput, successContract: success.response.output, userConstraints: input.constraints ?? [] }, input, traceId, prompts);
  passes.push(taskGenerated.pass);
  if (!taskGenerated.response || taskGenerated.response.error) return failed(traceId, passes, prompts, taskGenerated.response?.error?.retryable);
  let taskPlan = taskGenerated.response.output;
  let taskValidation = validateTaskPlan(taskPlan, input.questId, missionClientId).issues;
  passes.push({ name: "task_rule_validation", status: taskValidation.length ? "failed" : "completed", output: { issues: taskValidation } });
  const taskCritic = await runPass("task_critic", { quest: input, mission: currentMission, taskPlan, validationIssues: taskValidation }, input, traceId, prompts);
  passes.push(taskCritic.pass);
  if (!taskCritic.response || taskCritic.response.error) return failed(traceId, passes, prompts, taskCritic.response?.error?.retryable);
  const failedTaskIds = failedEntityIds(taskCritic.response.output, "taskResults", taskValidation);
  if (failedTaskIds.length > 0) {
    const taskRepair = await runPass("task_repair", { quest: input, mission: currentMission, taskPlan, critic: taskCritic.response.output, failedTaskClientIds: failedTaskIds, maxRepairPasses: 1 }, input, traceId, prompts);
    passes.push(taskRepair.pass);
    if (!taskRepair.response || taskRepair.response.error) return failed(traceId, passes, prompts, taskRepair.response?.error?.retryable);
    taskPlan = taskRepair.response.output;
    taskValidation = validateTaskPlan(taskPlan, input.questId, missionClientId).issues;
  }
  passes.push({ name: "task_final_validation", status: taskValidation.length ? "failed" : "completed", output: { issues: taskValidation } });
  if (taskValidation.length) return result(traceId, "manual_path", passes, null, taskValidation, prompts);
  return result(traceId, "preview_ready", passes, {
    questId: input.questId,
    successContract: success.response.output,
    strategicPlan: strategy.response.output,
    routeMissionPlan: plan,
    currentTaskPlan: taskPlan,
    groundingMetadata: strategy.response.groundingMetadata,
  }, [], prompts);
}

async function runPass(key: keyof typeof PROMPTS, payload: unknown, input: PlanningInput, traceId: string, versions: Record<string, number>, tools: ProviderRequest["tools"] = []) {
  const prompt = activePrompt(key);
  versions[key] = prompt.version;
  const response = await callGeminiInteraction({
    operation: `quest_planning.${key}`,
    modelRole: prompt.modelRole,
    promptVersion: `${prompt.key}.v${prompt.version}`,
    schemaVersion: prompt.schemaVersion,
    systemInstruction: prompt.systemInstruction,
    input: payload,
    responseSchema: prompt.schema,
    tools,
    thinkingLevel: prompt.thinkingLevel,
    temperature: prompt.temperature,
    maxOutputTokens: key.includes("generation") || key.includes("repair") ? 8_192 : 3_072,
    timeoutMs: 45_000,
    idempotencyKey: `${input.idempotencyKey}:${key}`,
    traceId,
    userId: input.userId,
  });
  const { output: _, text: __, groundingMetadata: ___, ...provider } = response;
  return { response, pass: { name: key, status: response.error ? "failed" : "completed", output: response.output, provider } as PlanningPass };
}

function criticFailedIds(value: unknown, issues: ValidationIssue[]) {
  const ids = new Set(issues.map((item) => item.missionClientId).filter((item): item is string => Boolean(item)));
  if (value && typeof value === "object" && Array.isArray((value as Record<string, unknown>).missionResults)) {
    for (const raw of (value as Record<string, unknown>).missionResults as unknown[]) {
      if (raw && typeof raw === "object" && (raw as Record<string, unknown>).passed === false && typeof (raw as Record<string, unknown>).clientId === "string") ids.add((raw as Record<string, unknown>).clientId as string);
    }
  }
  return [...ids];
}
function failedEntityIds(value: unknown, resultKey: string, issues: ValidationIssue[]) {
  const ids = new Set(issues.map((item) => item.missionClientId).filter((item): item is string => Boolean(item)));
  if (value && typeof value === "object" && Array.isArray((value as Record<string, unknown>)[resultKey])) {
    for (const raw of (value as Record<string, unknown>)[resultKey] as unknown[]) {
      if (raw && typeof raw === "object" && (raw as Record<string, unknown>).passed === false && typeof (raw as Record<string, unknown>).clientId === "string") ids.add((raw as Record<string, unknown>).clientId as string);
    }
  }
  return [...ids];
}
function failed(traceId: string, passes: PlanningPass[], prompts: Record<string, number>, retryable = false) {
  return result(traceId, retryable ? "retryable_error" : "manual_path", passes, null, [], prompts);
}
function result(traceId: string, status: PlanningPipelineResult["status"], passes: PlanningPass[], preview: unknown, issues: ValidationIssue[], prompts: Record<string, number>): PlanningPipelineResult {
  return { traceId, status, passes, preview, issues, versions: { pipeline: "3.0", schema: "quest-hierarchy-3.0", prompts }, persistenceAllowed: false };
}
