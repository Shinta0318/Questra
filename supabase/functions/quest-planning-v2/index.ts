import { jsonResponse, preflightResponse, readJson } from "../_shared/http.ts";
import { runQuestPlanningPipeline } from "../_shared/quest_planning/pipeline.ts";

type RequestBody = {
  mode?: "plan" | "approve";
  quest_id?: string;
  wish?: string;
  target_date?: string | null;
  budget?: string | null;
  available_time?: unknown;
  experience?: string | null;
  location?: string | null;
  constraints?: string[];
  approved_context?: Record<string, unknown>;
  idempotency_key?: string;
  preview_id?: string;
  approval_token?: string;
};

Deno.serve(async (req) => {
  const preflight = preflightResponse(req);
  if (preflight) return preflight;
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, { status: 405 });
  const auth = req.headers.get("Authorization");
  const userId = await authenticatedUserId(auth);
  if (!auth || !userId) return jsonResponse({ error: "authentication_required" }, { status: 401 });
  const payload = await readJson<RequestBody>(req);
  if (!payload) return jsonResponse({ error: "invalid_json" }, { status: 400 });
  if (payload.mode === "approve") return approvePreview(auth, payload);

  const questId = uuid(payload.quest_id);
  const wish = text(payload.wish, 1_200);
  const idempotencyKey = text(payload.idempotency_key, 160);
  if (!questId || !wish || !idempotencyKey) return jsonResponse({ error: "quest_wish_and_idempotency_required" }, { status: 400 });
  if (!await ownsQuest(userId, questId)) return jsonResponse({ error: "quest_not_found" }, { status: 404 });

  const pipeline = await runQuestPlanningPipeline({
    questId,
    wish,
    targetDate: text(payload.target_date, 20),
    budget: text(payload.budget, 120),
    availableTime: payload.available_time,
    experience: text(payload.experience, 300),
    location: text(payload.location, 200),
    constraints: Array.isArray(payload.constraints) ? payload.constraints.filter((item): item is string => typeof item === "string").slice(0, 12) : [],
    approvedContext: payload.approved_context,
    userId,
    idempotencyKey,
  });
  if (pipeline.status !== "preview_ready" || !pipeline.preview) {
    await recordRun(userId, questId, idempotencyKey, pipeline, null);
    const status = pipeline.status === "needs_clarification" ? 200 : 422;
    return jsonResponse(pipeline, { status });
  }
  const stored = await recordRun(userId, questId, idempotencyKey, pipeline, pipeline.preview);
  if (!stored) return jsonResponse({ ...pipeline, status: "retryable_error", preview: null, error: "preview_store_failed" }, { status: 503 });
  return jsonResponse({ ...pipeline, preview_id: stored.id, approval_token: stored.approvalToken });
});

async function authenticatedUserId(auth: string | null) {
  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !anon || !auth) return null;
  const response = await fetch(`${url}/auth/v1/user`, { headers: { apikey: anon, Authorization: auth } });
  if (!response.ok) return null;
  const data = await response.json() as Record<string, unknown>;
  return uuid(data.id);
}

async function ownsQuest(userId: string, questId: string) {
  const response = await serviceFetch(`/rest/v1/quests?id=eq.${questId}&owner_id=eq.${userId}&select=id&limit=1`);
  if (!response?.ok) return false;
  const rows = await response.json() as unknown[];
  return rows.length === 1;
}

async function recordRun(userId: string, questId: string, idempotencyKey: string, pipeline: Awaited<ReturnType<typeof runQuestPlanningPipeline>>, preview: unknown) {
  const runResponse = await serviceFetch("/rest/v1/quest_planning_runs?on_conflict=owner_id,idempotency_key", {
    method: "POST",
    headers: { Prefer: "resolution=merge-duplicates,return=representation" },
    body: JSON.stringify({
      owner_id: userId,
      quest_id: questId,
      trace_id: pipeline.traceId,
      idempotency_key: idempotencyKey,
      status: pipeline.status === "preview_ready" ? "preview_ready" : pipeline.status === "needs_clarification" ? "needs_clarification" : "failed",
      pipeline_version: pipeline.versions.pipeline,
      schema_version: pipeline.versions.schema,
      execution_versions: pipeline.versions,
      error_category: pipeline.issues[0]?.code ?? null,
      completed_at: new Date().toISOString(),
    }),
  });
  if (!runResponse?.ok) return null;
  const runs = await runResponse.json() as Array<Record<string, unknown>>;
  if (!preview || !runs[0]?.id) return null;
  const previewResponse = await serviceFetch("/rest/v1/quest_plan_previews", {
    method: "POST",
    headers: { Prefer: "return=representation" },
    body: JSON.stringify({ owner_id: userId, quest_id: questId, planning_run_id: runs[0].id, plan_payload: preview }),
  });
  if (!previewResponse?.ok) return null;
  const previews = await previewResponse.json() as Array<Record<string, unknown>>;
  return previews[0]?.id && previews[0]?.approval_token
    ? { id: previews[0].id, approvalToken: previews[0].approval_token }
    : null;
}

async function approvePreview(auth: string, payload: RequestBody) {
  const previewId = uuid(payload.preview_id);
  const approvalToken = uuid(payload.approval_token);
  if (!previewId || !approvalToken) return jsonResponse({ error: "preview_and_approval_required" }, { status: 400 });
  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !anon) return jsonResponse({ error: "service_unavailable" }, { status: 503 });
  const response = await fetch(`${url}/rest/v1/rpc/approve_quest_plan_preview`, {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: anon, Authorization: auth },
    body: JSON.stringify({ p_preview_id: previewId, p_approval_token: approvalToken }),
  });
  if (!response.ok) return jsonResponse({ error: "approval_failed" }, { status: response.status === 400 ? 409 : 503 });
  return jsonResponse(await response.json());
}

async function serviceFetch(path: string, init: RequestInit = {}) {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return null;
  const headers = new Headers(init.headers);
  headers.set("Content-Type", "application/json");
  headers.set("apikey", key);
  headers.set("Authorization", `Bearer ${key}`);
  return fetch(`${url}${path}`, { ...init, headers });
}

function text(value: unknown, limit: number) { return typeof value === "string" && value.trim() ? value.trim().slice(0, limit) : null; }
function uuid(value: unknown) { return typeof value === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value) ? value : null; }
