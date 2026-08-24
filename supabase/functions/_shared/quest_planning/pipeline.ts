import { callGeminiInteraction } from "./interactions_adapter.ts";
import { ProviderRequest, ProviderResponse, ValidationIssue } from "./contracts.ts";
import { activePrompt, PROMPTS } from "./prompt_registry.ts";
import { decideGrounding, validateGroundedMissionReferences, validateGroundingEvidence } from "./grounding.ts";
import { validateMissionArchitectureSemantics, validateRouteMissionPlan, validateTaskPlan } from "./validators.ts";

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
  abuseKeyHash?: string | null;
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

export type TaskExpansionInput = PlanningInput & {
  mission: Record<string, unknown>;
  questContext?: Record<string, unknown>;
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

  const domains = await runPass("achievement_domain_analysis", { understanding: understandingOutput, successContract: success.response.output }, input, traceId, prompts);
  passes.push(domains.pass);
  if (!domains.response || domains.response.error) return failed(traceId, passes, prompts, domains.response?.error?.retryable);

  const grounding = decideGrounding(`${input.wish}\n${JSON.stringify(success.response.output)}`);
  const strategy = await runPass("strategic_plan", { understanding: understandingOutput, successContract: success.response.output, achievementDomains: domains.response.output, groundingDecision: grounding }, input, traceId, prompts, grounding.required ? [{ type: "google_search" }] : []);
  passes.push(strategy.pass);
  if (!strategy.response || strategy.response.error) return failed(traceId, passes, prompts, strategy.response?.error?.retryable);
  const groundingValidation = validateGroundingEvidence(grounding, strategy.response.groundingMetadata);
  passes.push({ name: "grounding_validation", status: groundingValidation.valid ? "completed" : "failed", output: groundingValidation });
  if (!groundingValidation.valid) {
    return result(traceId, "retryable_error", passes, null, [{ path: "$.grounding", code: "grounding_failed", message: "Current facts could not be verified with traceable sources" }], prompts);
  }

  const generated = await runPass("route_mission_generation", { questId: input.questId, understanding: understandingOutput, successContract: success.response.output, achievementDomains: domains.response.output, strategicPlan: strategy.response.output, groundingMetadata: strategy.response.groundingMetadata }, input, traceId, prompts);
  passes.push(generated.pass);
  if (!generated.response || generated.response.error) return failed(traceId, passes, prompts, generated.response?.error?.retryable);
  let plan = generated.response.output;
  let quality = await evaluateMissionPlan(plan, input, success.response.output, domains.response.output, traceId, prompts, grounding, strategy.response.groundingMetadata);
  passes.push(...quality.passes);
  if (quality.evaluationUnavailable) return result(traceId, "retryable_error", passes, null, missionQualityGateIssues(plan, quality), prompts);
  for (let repairPass = 1; quality.failedIds.length > 0 && repairPass <= 1; repairPass++) {
    const repair = await runPass("route_mission_repair", {
      quest: input, plan, successContract: success.response.output, achievementDomains: domains.response.output,
      granularity: quality.granularity, coverage: quality.coverage, critic: quality.critic,
      groundingMetadata: strategy.response.groundingMetadata,
      failedMissionClientIds: quality.failedIds, repairPass, maxRepairPasses: 1,
    }, input, traceId, prompts);
    passes.push(repair.pass);
    if (!repair.response || repair.response.error) return failed(traceId, passes, prompts, repair.response?.error?.retryable);
    plan = repair.response.output;
    quality = await evaluateMissionPlan(plan, input, success.response.output, domains.response.output, traceId, prompts, grounding, strategy.response.groundingMetadata);
    passes.push(...quality.passes);
    if (quality.evaluationUnavailable) return result(traceId, "retryable_error", passes, null, missionQualityGateIssues(plan, quality), prompts);
  }
  const validation = missionQualityGateIssues(plan, quality);
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
  let finalTaskCritic = taskCritic.response.output;
  let failedTaskIds = failedEntityIds(finalTaskCritic, "taskResults", taskValidation, allTaskIds(taskPlan));
  if (failedTaskIds.length > 0) {
    const taskRepair = await runPass("task_repair", { quest: input, mission: currentMission, taskPlan, critic: taskCritic.response.output, failedTaskClientIds: failedTaskIds, maxRepairPasses: 1 }, input, traceId, prompts);
    passes.push(taskRepair.pass);
    if (!taskRepair.response || taskRepair.response.error) return failed(traceId, passes, prompts, taskRepair.response?.error?.retryable);
    taskPlan = taskRepair.response.output;
    taskValidation = validateTaskPlan(taskPlan, input.questId, missionClientId).issues;
    const repairedTaskCritic = await runPass("task_critic", { quest: input, mission: currentMission, taskPlan, validationIssues: taskValidation, evaluationStage: "after_repair" }, input, traceId, prompts);
    passes.push(repairedTaskCritic.pass);
    if (!repairedTaskCritic.response || repairedTaskCritic.response.error) return failed(traceId, passes, prompts, repairedTaskCritic.response?.error?.retryable);
    finalTaskCritic = repairedTaskCritic.response.output;
    failedTaskIds = failedEntityIds(finalTaskCritic, "taskResults", taskValidation, allTaskIds(taskPlan));
    if (failedTaskIds.length > 0) taskValidation.push({ path: "$.tasks", code: "task_critic_rejected", message: "One or more Tasks did not meet the quality threshold" });
  }
  passes.push({ name: "task_final_validation", status: taskValidation.length ? "failed" : "completed", output: { issues: taskValidation } });
  if (taskValidation.length) return result(traceId, "manual_path", passes, null, taskValidation, prompts);
  return result(traceId, "preview_ready", passes, {
    questId: input.questId,
    questUnderstanding: understandingOutput,
    successContract: success.response.output,
    achievementDomains: domains.response.output,
    strategicPlan: strategy.response.output,
    routeMissionPlan: plan,
    granularityClassification: quality.granularity,
    coverageAnalysis: quality.coverage,
    missionCritic: quality.critic,
    currentTaskPlan: taskPlan,
    currentTaskCritic: finalTaskCritic,
    groundingMetadata: strategy.response.groundingMetadata,
    qualityGate: {
      status: "passed",
      version: "qst-341-v1",
      missionCount: routeMissions.length,
      taskCount: Array.isArray((taskPlan as { tasks?: unknown[] }).tasks) ? (taskPlan as { tasks: unknown[] }).tasks.length : 0,
    },
  }, [], prompts);
}

export async function revalidateApprovedMissionPlan(
  input: PlanningInput,
  plan: unknown,
  successContract: unknown,
  achievementDomains: unknown,
  questContext: Record<string, unknown>,
  groundingMetadata: unknown,
): Promise<PlanningPipelineResult> {
  const traceId = crypto.randomUUID();
  const passes: PlanningPass[] = [];
  const prompts: Record<string, number> = {};
  const grounding = decideGrounding(`${input.wish}\n${JSON.stringify(successContract)}`);
  const groundingValidation = validateGroundingEvidence(grounding, groundingMetadata);
  passes.push({ name: "approved_subset_grounding_validation", status: groundingValidation.valid ? "completed" : "failed", output: groundingValidation });
  if (!groundingValidation.valid) return result(traceId, "retryable_error", passes, null, [{ path: "$.grounding", code: "grounding_failed", message: "Current facts could not be verified with traceable sources" }], prompts);
  const quality = await evaluateMissionPlan(plan, input, successContract, achievementDomains, traceId, prompts, grounding, groundingMetadata);
  passes.push(...quality.passes);
  if (quality.evaluationUnavailable) return result(traceId, "retryable_error", passes, null, missionQualityGateIssues(plan, quality), prompts);
  const issues = missionQualityGateIssues(plan, quality);
  passes.push({ name: "approved_subset_final_validation", status: issues.length ? "failed" : "completed", output: { issues } });
  if (issues.length) return result(traceId, "manual_path", passes, null, issues, prompts);

  const missions = plan && typeof plan === "object" && Array.isArray((plan as Record<string, unknown>).missions)
    ? (plan as Record<string, unknown>).missions as unknown[]
    : [];
  const currentMission = missions.find((item) => item && typeof item === "object" && (item as Record<string, unknown>).required === true) ?? missions[0];
  if (!currentMission || typeof currentMission !== "object") {
    return result(traceId, "manual_path", passes, null, [{ path: "$.missions", code: "missing_current_mission", message: "No Mission is available for Task generation" }], prompts);
  }
  const taskPipeline = await runTaskExpansionPipeline({
    ...input,
    idempotencyKey: `${input.idempotencyKey}:approved-subset`,
    mission: currentMission as Record<string, unknown>,
    questContext,
  });
  passes.push(...taskPipeline.passes);
  if (taskPipeline.status !== "preview_ready" || !taskPipeline.preview || typeof taskPipeline.preview !== "object") {
    return result(traceId, taskPipeline.status, passes, null, taskPipeline.issues, { ...prompts, ...taskPipeline.versions.prompts });
  }
  const taskPayload = taskPipeline.preview as Record<string, unknown>;
  return result(traceId, "preview_ready", passes, {
    routeMissionPlan: plan,
    granularityClassification: quality.granularity,
    coverageAnalysis: quality.coverage,
    missionCritic: quality.critic,
    currentTaskPlan: Object.fromEntries(Object.entries(taskPayload).filter(([key]) => key !== "taskCritic" && key !== "qualityGate")),
    currentTaskCritic: taskPayload.taskCritic,
    qualityGate: {
      status: "passed",
      version: "qst-341-v1",
      revalidatedSelection: true,
      missionCount: missions.length,
      taskCount: Array.isArray(taskPayload.tasks) ? taskPayload.tasks.length : 0,
    },
  }, [], { ...prompts, ...taskPipeline.versions.prompts });
}

export async function runTaskExpansionPipeline(input: TaskExpansionInput): Promise<PlanningPipelineResult> {
  const traceId = crypto.randomUUID();
  const passes: PlanningPass[] = [];
  const prompts: Record<string, number> = {};
  const missionClientId = String(input.mission.clientId ?? input.mission.id ?? "");
  if (!missionClientId) {
    return result(traceId, "manual_path", passes, null, [{ path: "$.mission", code: "mission_id_missing", message: "Mission ID is required" }], prompts);
  }
  const generated = await runPass("task_generation", {
    questId: input.questId,
    quest: input.questContext ?? { title: input.wish },
    mission: { ...input.mission, clientId: missionClientId },
    userConstraints: input.constraints ?? [],
  }, input, traceId, prompts);
  passes.push(generated.pass);
  if (!generated.response || generated.response.error) return failed(traceId, passes, prompts, generated.response?.error?.retryable);

  let taskPlan = generated.response.output;
  let validation = validateTaskPlan(taskPlan, input.questId, missionClientId).issues;
  passes.push({ name: "task_rule_validation", status: validation.length ? "failed" : "completed", output: { issues: validation } });
  const critic = await runPass("task_critic", {
    quest: input.questContext ?? { title: input.wish }, mission: input.mission, taskPlan, validationIssues: validation,
  }, input, traceId, prompts);
  passes.push(critic.pass);
  if (!critic.response || critic.response.error) return failed(traceId, passes, prompts, critic.response?.error?.retryable);

  let finalCritic = critic.response.output;
  let failedTaskIds = failedEntityIds(finalCritic, "taskResults", validation, allTaskIds(taskPlan));
  if (failedTaskIds.length > 0) {
    const repair = await runPass("task_repair", {
      quest: input.questContext ?? { title: input.wish }, mission: input.mission, taskPlan,
      critic: critic.response.output, failedTaskClientIds: failedTaskIds, maxRepairPasses: 1,
    }, input, traceId, prompts);
    passes.push(repair.pass);
    if (!repair.response || repair.response.error) return failed(traceId, passes, prompts, repair.response?.error?.retryable);
    taskPlan = repair.response.output;
    validation = validateTaskPlan(taskPlan, input.questId, missionClientId).issues;
    const repairedCritic = await runPass("task_critic", {
      quest: input.questContext ?? { title: input.wish }, mission: input.mission, taskPlan,
      validationIssues: validation, evaluationStage: "after_repair",
    }, input, traceId, prompts);
    passes.push(repairedCritic.pass);
    if (!repairedCritic.response || repairedCritic.response.error) return failed(traceId, passes, prompts, repairedCritic.response?.error?.retryable);
    finalCritic = repairedCritic.response.output;
    failedTaskIds = failedEntityIds(finalCritic, "taskResults", validation, allTaskIds(taskPlan));
    if (failedTaskIds.length > 0) validation.push({ path: "$.tasks", code: "task_critic_rejected", message: "One or more Tasks did not meet the quality threshold" });
  }
  passes.push({ name: "task_final_validation", status: validation.length ? "failed" : "completed", output: { issues: validation } });
  if (validation.length) return result(traceId, "manual_path", passes, null, validation, prompts);
  return result(traceId, "preview_ready", passes, {
    ...(taskPlan as Record<string, unknown>),
    qualityGate: { status: "passed", version: "qst-341-v1" },
    taskCritic: finalCritic,
  }, [], prompts);
}

async function evaluateMissionPlan(
  plan: unknown,
  input: PlanningInput,
  successContract: unknown,
  achievementDomains: unknown,
  traceId: string,
  prompts: Record<string, number>,
  groundingDecision = decideGrounding(input.wish),
  groundingMetadata: unknown = null,
) {
  const evaluationPasses: PlanningPass[] = [];
  const structuralIssues = validateRouteMissionPlan(plan, input.questId).issues;
  evaluationPasses.push({ name: "route_structural_validation", status: structuralIssues.length ? "failed" : "completed", output: { issues: structuralIssues } });

  const granularity = await runPass("mission_granularity_classifier", { quest: input, successContract, achievementDomains, plan }, input, traceId, prompts);
  evaluationPasses.push(granularity.pass);
  if (!granularity.response || granularity.response.error) return { passes: evaluationPasses, validation: structuralIssues, failedIds: allMissionIds(plan), granularity: null, coverage: null, critic: null, evaluationUnavailable: true };

  const coverage = await runPass("mission_coverage_analysis", { quest: input, successContract, achievementDomains, plan, granularity: granularity.response.output }, input, traceId, prompts);
  evaluationPasses.push(coverage.pass);
  if (!coverage.response || coverage.response.error) return { passes: evaluationPasses, validation: structuralIssues, failedIds: allMissionIds(plan), granularity: granularity.response.output, coverage: null, critic: null, evaluationUnavailable: true };

  const semanticIssues = validateMissionArchitectureSemantics(plan, input.wish, successContract, granularity.response.output, coverage.response.output).issues;
  evaluationPasses.push({ name: "mission_semantic_validation", status: semanticIssues.length ? "failed" : "completed", output: { issues: semanticIssues } });
  const groundingIssues = validateGroundedMissionReferences(plan, groundingDecision, groundingMetadata);
  evaluationPasses.push({ name: "mission_grounding_reference_validation", status: groundingIssues.length ? "failed" : "completed", output: { issues: groundingIssues } });
  const validation = [...structuralIssues, ...semanticIssues, ...groundingIssues];
  const critic = await runPass("mission_critic", { quest: input, successContract, achievementDomains, plan, granularity: granularity.response.output, coverage: coverage.response.output, validationIssues: validation }, input, traceId, prompts);
  evaluationPasses.push(critic.pass);
  if (!critic.response || critic.response.error) return { passes: evaluationPasses, validation, failedIds: allMissionIds(plan), granularity: granularity.response.output, coverage: coverage.response.output, critic: null, evaluationUnavailable: true };
  const failedIds = criticFailedIds(critic.response.output, validation, granularity.response.output, coverage.response.output);
  if (failedIds.length > 0 && validation.length === 0) validation.push({ path: "$.missions", code: "critic_rejected", message: "One or more Missions did not meet the quality threshold" });
  return { passes: evaluationPasses, validation, failedIds, granularity: granularity.response.output, coverage: coverage.response.output, critic: critic.response.output, evaluationUnavailable: false };
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
    abuseKeyHash: input.abuseKeyHash,
  });
  const { output: _, text: __, groundingMetadata: ___, ...provider } = response;
  return { response, pass: { name: key, status: response.error ? "failed" : "completed", output: response.output, provider } as PlanningPass };
}

function criticFailedIds(value: unknown, issues: ValidationIssue[], granularity: unknown, coverage: unknown) {
  const ids = new Set(issues.map((item) => item.missionClientId).filter((item): item is string => Boolean(item)));
  if (issues.some((item) => !item.missionClientId)) ids.add("__plan_structure__");
  if (value && typeof value === "object" && (value as Record<string, unknown>).passed !== true) ids.add("__critic_overall__");
  if (value && typeof value === "object" && Array.isArray((value as Record<string, unknown>).missionResults)) {
    for (const raw of (value as Record<string, unknown>).missionResults as unknown[]) {
      if (!raw || typeof raw !== "object" || typeof (raw as Record<string, unknown>).clientId !== "string") continue;
      const result = raw as Record<string, unknown>;
      if (result.passed === false || result.verdict !== "pass" || belowMissionThreshold(result.scores)) ids.add(result.clientId as string);
    }
  }
  if (granularity && typeof granularity === "object" && Array.isArray((granularity as Record<string, unknown>).classifications)) {
    for (const raw of (granularity as Record<string, unknown>).classifications as unknown[]) {
      if (!raw || typeof raw !== "object") continue;
      const item = raw as Record<string, unknown>;
      if (item.classification !== "mission" && typeof item.candidateId === "string") ids.add(item.candidateId);
    }
  }
  if (coverage && typeof coverage === "object") {
    const value = coverage as Record<string, unknown>;
    if (value.passed !== true || Array.isArray(value.missingMissions) && value.missingMissions.length > 0) ids.add("__coverage_gap__");
    for (const key of ["duplicationGroups", "unnecessaryMissions"] as const) {
      if (!Array.isArray(value[key])) continue;
      for (const raw of value[key] as unknown[]) {
        if (!raw || typeof raw !== "object") continue;
        const item = raw as Record<string, unknown>;
        if (typeof item.candidateId === "string") ids.add(item.candidateId);
        if (Array.isArray(item.candidateIds)) for (const id of item.candidateIds) if (typeof id === "string") ids.add(id);
      }
    }
  }
  return [...ids];
}

function missionQualityGateIssues(
  plan: unknown,
  quality: {
    validation: ValidationIssue[];
    failedIds: string[];
    granularity: unknown;
    coverage: unknown;
    critic: unknown;
    evaluationUnavailable: boolean;
  },
) {
  const issues = [...quality.validation];
  if (!quality.granularity) issues.push({ path: "$.granularity", code: "granularity_missing", message: "Mission granularity evaluation is required" });
  if (!quality.coverage) issues.push({ path: "$.coverage", code: "coverage_missing", message: "Mission coverage evaluation is required" });
  if (!quality.critic || typeof quality.critic !== "object") {
    issues.push({ path: "$.critic", code: "critic_missing", message: "Mission critic evaluation is required" });
  } else {
    const critic = quality.critic as Record<string, unknown>;
    const expectedIds = allMissionIds(plan);
    const results = Array.isArray(critic.missionResults) ? critic.missionResults : [];
    const reviewedIds = new Set(results.map((item) => item && typeof item === "object" ? (item as Record<string, unknown>).clientId : null).filter((id): id is string => typeof id === "string"));
    if (critic.passed !== true || typeof critic.overallScore !== "number" || Number(critic.overallScore) < 85) issues.push({ path: "$.critic", code: "critic_rejected", message: "Mission plan did not pass the overall critic threshold" });
    for (const id of expectedIds) if (!reviewedIds.has(id)) issues.push({ path: "$.critic.missionResults", code: "critic_result_missing", message: "Every Mission requires an independent critic result", missionClientId: id });
  }
  if (quality.failedIds.length > 0 && !issues.some((item) => item.code === "critic_rejected")) issues.push({ path: "$.missions", code: "critic_rejected", message: "One or more Missions did not meet the quality threshold" });
  return dedupeIssues(issues);
}

function belowMissionThreshold(value: unknown) {
  if (!value || typeof value !== "object") return true;
  const scores = value as Record<string, unknown>;
  const minimums: Record<string, number> = {
    questRelevance: 90, outcomeQuality: 85, missionGranularity: 90,
    successConditionQuality: 90, personalization: 80, nonTemplateQuality: 90,
    uniqueness: 90, sequencing: 80, completenessContribution: 85, taskSeparation: 95,
  };
  return Object.entries(minimums).some(([key, minimum]) => typeof scores[key] !== "number" || Number(scores[key]) < minimum);
}

function allMissionIds(plan: unknown) {
  if (!plan || typeof plan !== "object" || !Array.isArray((plan as Record<string, unknown>).missions)) return [];
  return ((plan as Record<string, unknown>).missions as unknown[]).map((raw) => raw && typeof raw === "object" ? (raw as Record<string, unknown>).clientId : null).filter((id): id is string => typeof id === "string");
}
function failedEntityIds(value: unknown, resultKey: string, issues: ValidationIssue[], expectedIds: string[]) {
  const ids = new Set(issues.map((item) => item.missionClientId).filter((item): item is string => Boolean(item)));
  const reviewedIds = new Set<string>();
  if (!value || typeof value !== "object" || (value as Record<string, unknown>).passed !== true || typeof (value as Record<string, unknown>).overallScore !== "number" || Number((value as Record<string, unknown>).overallScore) < 85) ids.add("__critic_overall__");
  if (value && typeof value === "object" && Array.isArray((value as Record<string, unknown>)[resultKey])) {
    for (const raw of (value as Record<string, unknown>)[resultKey] as unknown[]) {
      if (!raw || typeof raw !== "object" || typeof (raw as Record<string, unknown>).clientId !== "string") continue;
      const clientId = (raw as Record<string, unknown>).clientId as string;
      reviewedIds.add(clientId);
      if ((raw as Record<string, unknown>).passed !== true) ids.add(clientId);
    }
  }
  for (const id of expectedIds) if (!reviewedIds.has(id)) ids.add(id);
  return [...ids];
}
function allTaskIds(plan: unknown) {
  if (!plan || typeof plan !== "object" || !Array.isArray((plan as Record<string, unknown>).tasks)) return [];
  return ((plan as Record<string, unknown>).tasks as unknown[]).map((raw) => raw && typeof raw === "object" ? (raw as Record<string, unknown>).clientId : null).filter((id): id is string => typeof id === "string");
}
function dedupeIssues(issues: ValidationIssue[]) {
  const seen = new Set<string>();
  return issues.filter((item) => {
    const key = `${item.path}|${item.code}|${item.missionClientId ?? ""}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}
function failed(traceId: string, passes: PlanningPass[], prompts: Record<string, number>, retryable = false) {
  return result(traceId, retryable ? "retryable_error" : "manual_path", passes, null, [], prompts);
}
function result(traceId: string, status: PlanningPipelineResult["status"], passes: PlanningPass[], preview: unknown, issues: ValidationIssue[], prompts: Record<string, number>): PlanningPipelineResult {
  return { traceId, status, passes, preview, issues, versions: { pipeline: "4.0", schema: "mission-architecture-4.0", prompts }, persistenceAllowed: false };
}
