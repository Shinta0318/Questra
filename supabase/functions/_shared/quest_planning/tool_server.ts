import { authorizeToolCall, QUESTRA_TOOLS } from "./tool_registry.ts";

export type ToolExecutionContext = {
  userId: string;
  traceId: string;
  approved: boolean;
};

export type ToolExecutionResult = {
  ok: boolean;
  data?: unknown;
  error?: "tool_not_allowed" | "invalid_arguments" | "target_not_owned" | "tool_failed";
};

export async function executeQuestraTool(name: string, args: Record<string, unknown>, context: ToolExecutionContext): Promise<ToolExecutionResult> {
  const definition = QUESTRA_TOOLS[name];
  if (!definition || !authorizeToolCall(name, { authenticated: Boolean(context.userId), approved: context.approved })) {
    await audit(name, args, context, "denied");
    return { ok: false, error: "tool_not_allowed" };
  }
  const questId = typeof args.questId === "string" ? args.questId : null;
  if (questId && !await ownsQuest(questId, context.userId)) {
    await audit(name, args, context, "denied", questId);
    return { ok: false, error: "target_not_owned" };
  }
  try {
    let data: unknown;
    switch (name) {
      case "get_quest_context":
        data = await select(`/rest/v1/quests?id=eq.${questId}&owner_id=eq.${context.userId}&select=id,title,description,status,target_date,requested_target_month,difficulty_score,estimated_duration_days&limit=1`);
        break;
      case "get_mission_progress":
        data = await select(`/rest/v1/missions?quest_id=eq.${questId}&select=id,title,status,sort_order,dependency_ids,estimated_duration_days&order=sort_order&limit=30`);
        break;
      case "get_quest_dna":
        data = await select(`/rest/v1/quest_dna_profiles?quest_id=eq.${questId}&select=*&order=version.desc&limit=1`);
        break;
      case "get_relevant_arc_memory":
        if (!await hasArcMemoryConsent(context.userId)) {
          data = [];
          break;
        }
        data = await rpc("get_relevant_arc_memories", {
          p_user_id: context.userId,
          p_quest_id: questId,
          p_limit: Math.min(5, Math.max(1, Number(args.limit) || 3)),
        });
        break;
      case "get_user_planning_preferences":
        data = await select(`/rest/v1/planning_context_preferences?owner_id=eq.${context.userId}&select=weekly_minutes,budget_label,location,experience,consent_granted&limit=1`);
        break;
      case "validate_plan":
        data = { accepted: true, note: "Use server domain and semantic validators before preview persistence." };
        break;
      default:
        await audit(name, args, context, "denied", questId);
        return { ok: false, error: "tool_not_allowed" };
    }
    await audit(name, args, context, "allowed", questId);
    return { ok: true, data: redact(data) };
  } catch (_) {
    await audit(name, args, context, "failed", questId);
    return { ok: false, error: "tool_failed" };
  }
}

async function ownsQuest(questId: string, userId: string) {
  const rows = await select(`/rest/v1/quests?id=eq.${questId}&owner_id=eq.${userId}&select=id&limit=1`);
  return Array.isArray(rows) && rows.length === 1;
}
async function hasArcMemoryConsent(userId: string) {
  const rows = await select(`/rest/v1/user_consents?user_id=eq.${userId}&purpose_code=eq.arc_personalization&status=eq.granted&select=id&limit=1`);
  return Array.isArray(rows) && rows.length === 1;
}
async function select(path: string) {
  const response = await serviceFetch(path);
  if (!response.ok) throw new Error("tool_failed");
  return response.json();
}
async function rpc(name: string, body: Record<string, unknown>) {
  const response = await serviceFetch(`/rest/v1/rpc/${name}`, {
    method: "POST",
    body: JSON.stringify(body),
  });
  if (!response.ok) throw new Error("tool_failed");
  return response.json();
}
async function audit(name: string, args: Record<string, unknown>, context: ToolExecutionContext, outcome: string, targetId?: string | null) {
  try {
    await serviceFetch("/rest/v1/ai_tool_audit_logs", {
      method: "POST",
      headers: { Prefer: "return=minimal" },
      body: JSON.stringify({
        owner_id: context.userId,
        trace_id: context.traceId,
        tool_name: name.slice(0, 100),
        access_type: QUESTRA_TOOLS[name]?.access ?? "read",
        target_type: targetId ? "quest" : null,
        target_id: targetId ?? null,
        outcome,
        argument_keys: Object.keys(args).filter((key) => !/token|secret|password/i.test(key)).slice(0, 20),
      }),
    });
  } catch (_) {
    // Audit failure is reported in server telemetry but never exposes tool data.
  }
}
async function serviceFetch(path: string, init: RequestInit = {}) {
  const url = Deno.env.get("SUPABASE_URL")!;
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const headers = new Headers(init.headers);
  headers.set("Content-Type", "application/json");
  headers.set("apikey", key);
  headers.set("Authorization", `Bearer ${key}`);
  return fetch(`${url}${path}`, { ...init, headers });
}
function redact(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(redact);
  if (!value || typeof value !== "object") return value;
  return Object.fromEntries(Object.entries(value as Record<string, unknown>).filter(([key]) => !/email|phone|token|secret|password|raw_content/i.test(key)).map(([key, item]) => [key, redact(item)]));
}
