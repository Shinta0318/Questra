import { callGeminiInteraction } from "./interactions_adapter.ts";
import { ProviderRequest, ProviderResponse, ValidationIssue } from "./contracts.ts";
import { activePrompt, PROMPTS } from "./prompt_registry.ts";
import { decideGrounding } from "./grounding.ts";
import { validateMissionPlan, validateMissionSemantics } from "./validators.ts";

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

  const generated = await runPass("mission_generation", { questId: input.questId, understanding: understandingOutput, successContract: success.response.output, strategicPlan: strategy.response.output, groundingMetadata: strategy.response.groundingMetadata }, input, traceId, prompts);
  passes.push(generated.pass);
  if (!generated.response || generated.response.error) return failed(traceId, passes, prompts, generated.response?.error?.retryable);
  let plan = generated.response.output;
  let validation = combinedValidation(plan, input);
  passes.push({ name: "rule_validation", status: validation.length ? "failed" : "completed", output: { issues: validation } });

  const critic = await runPass("mission_critic", { quest: input, plan, validationIssues: validation }, input, traceId, prompts);
  passes.push(critic.pass);
  if (!critic.response || critic.response.error) return failed(traceId, passes, prompts, critic.response?.error?.retryable);
  const failedIds = criticFailedIds(critic.response.output, validation);
  if (failedIds.length > 0) {
    const repair = await runPass("targeted_repair", { quest: input, plan, critic: critic.response.output, failedMissionClientIds: failedIds, maxRepairPasses: 1 }, input, traceId, prompts);
    passes.push(repair.pass);
    if (!repair.response || repair.response.error) return failed(traceId, passes, prompts, repair.response?.error?.retryable);
    plan = repair.response.output;
    validation = combinedValidation(plan, input);
  }
  passes.push({ name: "final_validation", status: validation.length ? "failed" : "completed", output: { issues: validation } });
  if (validation.length) return result(traceId, "manual_path", passes, null, validation, prompts);
  return result(traceId, "preview_ready", passes, {
    questId: input.questId,
    successContract: success.response.output,
    strategicPlan: strategy.response.output,
    missionPlan: plan,
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
    maxOutputTokens: key === "mission_generation" || key === "targeted_repair" ? 8_192 : 3_072,
    timeoutMs: 45_000,
    idempotencyKey: `${input.idempotencyKey}:${key}`,
    traceId,
    userId: input.userId,
  });
  const { output: _, text: __, groundingMetadata: ___, ...provider } = response;
  return { response, pass: { name: key, status: response.error ? "failed" : "completed", output: response.output, provider } as PlanningPass };
}

function combinedValidation(plan: unknown, input: PlanningInput) {
  return [...validateMissionPlan(plan, input.questId).issues, ...validateMissionSemantics(plan, input.wish).issues];
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
function failed(traceId: string, passes: PlanningPass[], prompts: Record<string, number>, retryable = false) {
  return result(traceId, retryable ? "retryable_error" : "manual_path", passes, null, [], prompts);
}
function result(traceId: string, status: PlanningPipelineResult["status"], passes: PlanningPass[], preview: unknown, issues: ValidationIssue[], prompts: Record<string, number>): PlanningPipelineResult {
  return { traceId, status, passes, preview, issues, versions: { pipeline: "2.0", schema: "quest-planning-2.0", prompts }, persistenceAllowed: false };
}
