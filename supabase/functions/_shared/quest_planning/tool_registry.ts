import { ProviderTool } from "./contracts.ts";

export type ToolAccess = "read" | "preview_write" | "approved_write";
export type QuestraToolDefinition = ProviderTool & { access: ToolAccess; requiresApproval: boolean };

const questIdParameters = {
  type: "object",
  additionalProperties: false,
  properties: { questId: { type: "string", minLength: 1, maxLength: 100 } },
  required: ["questId"],
};

export const QUESTRA_TOOLS: Record<string, QuestraToolDefinition> = {
  get_quest_context: { type: "function", name: "get_quest_context", description: "Gets the current owner-scoped Quest state.", parameters: questIdParameters, access: "read", requiresApproval: false },
  get_mission_progress: { type: "function", name: "get_mission_progress", description: "Gets owner-scoped Mission progress and dependencies.", parameters: questIdParameters, access: "read", requiresApproval: false },
  get_user_planning_preferences: { type: "function", name: "get_user_planning_preferences", description: "Gets only planning preferences the user allowed Questra to use.", parameters: { type: "object", additionalProperties: false, properties: {} }, access: "read", requiresApproval: false },
  get_quest_dna: { type: "function", name: "get_quest_dna", description: "Gets the current owner-scoped Quest DNA version.", parameters: questIdParameters, access: "read", requiresApproval: false },
  get_relevant_arc_memory: { type: "function", name: "get_relevant_arc_memory", description: "Gets a bounded set of consented, relevant Arc Memories.", parameters: { ...questIdParameters, properties: { ...(questIdParameters.properties as object), limit: { type: "integer", minimum: 1, maximum: 5 } } }, access: "read", requiresApproval: false },
  validate_plan: { type: "function", name: "validate_plan", description: "Validates a plan without saving it.", parameters: questIdParameters, access: "read", requiresApproval: false },
  save_plan_preview: { type: "function", name: "save_plan_preview", description: "Saves an expiring owner-scoped preview only.", parameters: { type: "object", properties: { questId: { type: "string" }, idempotencyKey: { type: "string" } }, required: ["questId", "idempotencyKey"] }, access: "preview_write", requiresApproval: false },
  approve_plan_transaction: { type: "function", name: "approve_plan_transaction", description: "Persists a previously reviewed preview transactionally.", parameters: { type: "object", properties: { previewId: { type: "string" }, approvalToken: { type: "string" } }, required: ["previewId", "approvalToken"] }, access: "approved_write", requiresApproval: true },
};

export function planningTools(names: string[]): ProviderTool[] {
  return names.map((name) => QUESTRA_TOOLS[name]).filter(Boolean).map(({ access: _, requiresApproval: __, ...tool }) => tool);
}

export function authorizeToolCall(name: string, context: { authenticated: boolean; approved: boolean }) {
  const tool = QUESTRA_TOOLS[name];
  if (!tool || !context.authenticated) return false;
  return !tool.requiresApproval || context.approved;
}
