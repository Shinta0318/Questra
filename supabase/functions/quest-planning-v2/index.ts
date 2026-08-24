import { jsonResponse, preflightResponse, readJson } from "../_shared/http.ts";
import { revalidateApprovedMissionPlan, runQuestPlanningPipeline, runTaskExpansionPipeline } from "../_shared/quest_planning/pipeline.ts";
import { validateRouteMissionPlan } from "../_shared/quest_planning/validators.ts";

type RequestBody = {
  mode?: "plan" | "approve" | "expand_tasks";
  quest_id?: string;
  mission_id?: string;
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
  approved_missions?: unknown[];
};

Deno.serve(async (req) => {
  const preflight = preflightResponse(req);
  if (preflight) return preflight;
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, { status: 405 });
  const auth = req.headers.get("Authorization");
  const userId = await authenticatedUserId(auth);
  if (!auth || !userId) return jsonResponse({ error: "authentication_required" }, { status: 401 });
  const abuseKeyHash = await hashedAbuseKey(req);
  const payload = await readJson<RequestBody>(req);
  if (!payload) return jsonResponse({ error: "invalid_json" }, { status: 400 });
  if (payload.mode === "approve") return approvePreview(auth, userId, payload);
  if (payload.mode === "expand_tasks") return expandTasks(auth, userId, abuseKeyHash, payload);

  const questId = uuid(payload.quest_id);
  const wish = text(payload.wish, 1_200);
  const idempotencyKey = text(payload.idempotency_key, 160);
  if (!questId || !wish || !idempotencyKey) return jsonResponse({ error: "quest_wish_and_idempotency_required" }, { status: 400 });
  if (!await ownsQuest(auth, userId, questId)) return jsonResponse({ error: "quest_not_found" }, { status: 404 });

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
    abuseKeyHash,
    idempotencyKey,
  });
  if (pipeline.status !== "preview_ready" || !pipeline.preview) {
    await recordRun(userId, questId, idempotencyKey, pipeline, null);
    const status = pipeline.status === "needs_clarification" ? 200 : 422;
    return jsonResponse(pipeline, { status });
  }
  const stored = await recordRun(userId, questId, idempotencyKey, pipeline, pipeline.preview);
  if (!stored) return jsonResponse({ ...pipeline, status: "retryable_error", preview: null, error: "preview_store_failed" }, { status: 503 });
  return jsonResponse({ ...pipeline, preview_id: stored.id, approval_token: stored.approvalToken, draft_id: stored.draftId });
});

async function expandTasks(
  auth: string,
  userId: string,
  abuseKeyHash: string | null,
  payload: RequestBody,
) {
  const questId = uuid(payload.quest_id);
  const missionId = uuid(payload.mission_id);
  const idempotencyKey = text(payload.idempotency_key, 160);
  if (!questId || !missionId || !idempotencyKey) {
    return jsonResponse({ error: "quest_mission_and_idempotency_required" }, { status: 400 });
  }
  if (!await ownsQuest(auth, userId, questId)) {
    return jsonResponse({ error: "quest_not_found" }, { status: 404 });
  }
  const [questResponse, missionResponse, taskResponse] = await Promise.all([
    userFetch(auth, `/rest/v1/quests?id=eq.${questId}&select=id,title,description,target_date&limit=1`),
    userFetch(auth, `/rest/v1/missions?id=eq.${missionId}&quest_id=eq.${questId}&select=id,title,description,objective,success_condition,expected_outcome,done_condition,expected_output,action&limit=1`),
    userFetch(auth, `/rest/v1/tasks?mission_id=eq.${missionId}&quest_id=eq.${questId}&select=id,title,action,done_condition,status,order_index&order=order_index.asc&limit=50`),
  ]);
  if (!questResponse?.ok || !missionResponse?.ok || !taskResponse?.ok) return jsonResponse({ error: "planning_context_unavailable" }, { status: 503 });
  const quests = await questResponse.json() as Array<Record<string, unknown>>;
  const missions = await missionResponse.json() as Array<Record<string, unknown>>;
  const existingTasks = await taskResponse.json() as Array<Record<string, unknown>>;
  if (!quests[0] || !missions[0]) return jsonResponse({ error: "mission_not_found" }, { status: 404 });
  const quest = quests[0];
  const mission = missions[0];
  const pipeline = await runTaskExpansionPipeline({
    questId,
    wish: String(quest.title ?? ""),
    targetDate: typeof quest.target_date === "string" ? quest.target_date : null,
    userId,
    abuseKeyHash,
    idempotencyKey,
    questContext: quest,
    mission: {
      clientId: missionId,
      title: mission.title,
      description: mission.description,
      objective: mission.objective,
      successCondition: mission.success_condition,
      expectedOutcome: mission.expected_outcome,
      doneCondition: mission.done_condition,
      expectedOutput: mission.expected_output,
      action: mission.action,
      existingTasks,
    },
  });
  if (pipeline.status !== "preview_ready" || !pipeline.preview) {
    const status = pipeline.status === "retryable_error" ? 503 : 422;
    return jsonResponse(pipeline, { status });
  }
  return jsonResponse({
    status: pipeline.status,
    trace_id: pipeline.traceId,
    task_plan: pipeline.preview,
    passes: pipeline.passes,
    versions: pipeline.versions,
  });
}

async function hashedAbuseKey(req: Request) {
  const value = req.headers.get("cf-connecting-ip") ??
    req.headers.get("x-forwarded-for")?.split(",")[0]?.trim();
  const salt = Deno.env.get("AI_ABUSE_HASH_SALT") ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!value || !salt) return null;
  const bytes = new TextEncoder().encode(`${salt}:${value}`);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

async function authenticatedUserId(auth: string | null) {
  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !anon || !auth) return null;
  const response = await fetch(`${url}/auth/v1/user`, { headers: { apikey: anon, Authorization: auth } });
  if (!response.ok) return null;
  const data = await response.json() as Record<string, unknown>;
  return uuid(data.id);
}

async function ownsQuest(auth: string, userId: string, questId: string) {
  const response = await userFetch(auth, `/rest/v1/quests?id=eq.${questId}&owner_id=eq.${userId}&select=id&limit=1`);
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
  if (!previews[0]?.id || !previews[0]?.approval_token) return null;
  const draftStored = await recordMissionDraft(userId, questId, runs[0].id as string, previews[0], pipeline, preview);
  if (!draftStored) return null;
  return { id: previews[0].id, approvalToken: previews[0].approval_token, draftId: draftStored };
}

async function recordMissionDraft(userId: string, questId: string, runId: string, previewRow: Record<string, unknown>, pipeline: Awaited<ReturnType<typeof runQuestPlanningPipeline>>, preview: unknown) {
  if (!preview || typeof preview !== "object") return null;
  const payload = preview as Record<string, unknown>;
  const plan = payload.routeMissionPlan as Record<string, unknown> | undefined;
  if (!plan || !Array.isArray(plan.missions)) return null;
  const critic = payload.missionCritic && typeof payload.missionCritic === "object" ? payload.missionCritic as Record<string, unknown> : {};
  const results = Array.isArray(critic.missionResults) ? critic.missionResults as Array<Record<string, unknown>> : [];
  if (critic.passed !== true || results.length !== plan.missions.length) return null;
  const resultById = new Map(results.map((item) => [String(item.clientId ?? ""), item]));
  if (plan.missions.some((item) => {
    const mission = item as Record<string, unknown>;
    const review = resultById.get(String(mission.clientId ?? ""));
    return !review || review.passed !== true || review.verdict !== "pass";
  })) return null;
  const providerPass = [...pipeline.passes].reverse().find((item) => item.name === "mission_critic" && item.provider)?.provider;
  const draftResponse = await serviceFetch("/rest/v1/mission_plan_drafts", {
    method: "POST", headers: { Prefer: "return=representation" }, body: JSON.stringify({
      owner_id: userId, quest_id: questId, planning_run_id: runId, preview_id: previewRow.id,
      status: "reviewing", prompt_versions: pipeline.versions.prompts, schema_version: pipeline.versions.schema,
      model_name: providerPass?.model ?? "gemini", model_version: providerPass?.modelVersion ?? "",
      thinking_level: "high", overall_confidence: Math.max(0, Math.min(1, Number(critic.overallScore ?? 0) / 100)),
      achievement_domains: payload.achievementDomains ?? {}, coverage_analysis: payload.coverageAnalysis ?? {}, expires_at: previewRow.expires_at,
    }),
  });
  if (!draftResponse?.ok) return null;
  const rows = await draftResponse.json() as Array<Record<string, unknown>>;
  const draftId = rows[0]?.id;
  if (typeof draftId !== "string") return null;
  const candidates = plan.missions.map((raw, index) => {
    const mission = raw as Record<string, unknown>;
    const clientId = String(mission.clientId ?? "");
    const review = resultById.get(clientId) ?? {};
    return {
      owner_id: userId, draft_id: draftId, client_id: clientId, title: mission.title, objective: mission.objective,
      success_condition: mission.successCondition, expected_outcome: mission.expectedOutcome, reason_required: mission.reasonRequired,
      covered_success_conditions: mission.coveredSuccessConditions ?? [], dependency_client_ids: mission.dependencies ?? [],
      required: mission.required, parallelizable: mission.parallelizable, child_task_estimate: mission.childTaskEstimate,
      confidence: mission.confidence, critic_scores: review.scores ?? {}, verdict: review.verdict, order_index: index, original_payload: mission,
    };
  });
  const candidateResponse = await serviceFetch("/rest/v1/mission_candidates", { method: "POST", body: JSON.stringify(candidates) });
  return candidateResponse?.ok ? draftId : null;
}

async function approvePreview(auth: string, userId: string, payload: RequestBody) {
  const previewId = uuid(payload.preview_id);
  const approvalToken = uuid(payload.approval_token);
  if (!previewId || !approvalToken) return jsonResponse({ error: "preview_and_approval_required" }, { status: 400 });
  if (Array.isArray(payload.approved_missions)) {
    const prepared = await prepareApprovedPreview(userId, previewId, approvalToken, payload.approved_missions);
    if (!prepared.ok) return jsonResponse({ error: prepared.error }, { status: 409 });
  }
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

async function prepareApprovedPreview(userId: string, previewId: string, approvalToken: string, missions: unknown[]) {
  const response = await serviceFetch(`/rest/v1/quest_plan_previews?id=eq.${previewId}&owner_id=eq.${userId}&approval_token=eq.${approvalToken}&status=eq.pending&select=id,quest_id,plan_payload&limit=1`);
  if (!response?.ok) return { ok: false, error: "preview_load_failed" };
  const rows = await response.json() as Array<Record<string, unknown>>;
  const row = rows[0];
  if (!row || typeof row.quest_id !== "string" || !row.plan_payload || typeof row.plan_payload !== "object") return { ok: false, error: "preview_not_approvable" };
  const payload = row.plan_payload as Record<string, unknown>;
  const originalPlan = payload.routeMissionPlan && typeof payload.routeMissionPlan === "object" ? payload.routeMissionPlan as Record<string, unknown> : null;
  if (!originalPlan) return { ok: false, error: "route_plan_missing" };
  const originalMissions = Array.isArray(originalPlan.missions) ? originalPlan.missions : [];
  const originalIds = new Set(originalMissions.map((mission) => mission && typeof mission === "object" ? (mission as Record<string, unknown>).clientId : null).filter((id): id is string => typeof id === "string"));
  const selectedIds = missions.map((mission) => mission && typeof mission === "object" ? (mission as Record<string, unknown>).clientId : null);
  if (selectedIds.some((id) => typeof id !== "string" || !originalIds.has(id))) return { ok: false, error: "approved_selection_contains_unknown_mission" };
  const routeMissionPlan = { ...originalPlan, missions };
  const validation = validateRouteMissionPlan(routeMissionPlan, row.quest_id);
  if (!validation.valid) return { ok: false, error: validation.issues[0]?.code ?? "approved_plan_invalid" };
  const questResponse = await serviceFetch(`/rest/v1/quests?id=eq.${row.quest_id}&owner_id=eq.${userId}&select=id,title,description,target_date&limit=1`);
  if (!questResponse?.ok) return { ok: false, error: "quest_context_unavailable" };
  const quests = await questResponse.json() as Array<Record<string, unknown>>;
  const quest = quests[0];
  if (!quest) return { ok: false, error: "quest_context_unavailable" };
  const wish = [quest.title, quest.description].filter((item): item is string => typeof item === "string" && item.trim().length > 0).join("\n");
  const revalidation = await revalidateApprovedMissionPlan(
    {
      questId: row.quest_id,
      wish,
      targetDate: typeof quest.target_date === "string" ? quest.target_date : null,
      userId,
      idempotencyKey: `approval:${previewId}`,
    },
    routeMissionPlan,
    payload.successContract,
    payload.achievementDomains,
    quest,
    payload.groundingMetadata,
  );
  if (revalidation.status !== "preview_ready" || !revalidation.preview || typeof revalidation.preview !== "object") {
    return { ok: false, error: revalidation.issues[0]?.code ?? "approved_selection_quality_gate_failed" };
  }
  const validated = revalidation.preview as Record<string, unknown>;
  const update = await serviceFetch(`/rest/v1/quest_plan_previews?id=eq.${previewId}&owner_id=eq.${userId}&status=eq.pending`, {
    method: "PATCH", headers: { Prefer: "return=minimal" }, body: JSON.stringify({
      plan_payload: {
        ...payload,
        routeMissionPlan: validated.routeMissionPlan,
        granularityClassification: validated.granularityClassification,
        coverageAnalysis: validated.coverageAnalysis,
        missionCritic: validated.missionCritic,
        currentTaskPlan: validated.currentTaskPlan,
        currentTaskCritic: validated.currentTaskCritic,
        qualityGate: validated.qualityGate,
        selectionRevalidationTraceId: revalidation.traceId,
      },
    }),
  });
  return update?.ok ? { ok: true } : { ok: false, error: "preview_update_failed" };
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

async function userFetch(auth: string, path: string, init: RequestInit = {}) {
  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !anon) return null;
  const headers = new Headers(init.headers);
  headers.set("Content-Type", "application/json");
  headers.set("apikey", anon);
  headers.set("Authorization", auth);
  return fetch(`${url}${path}`, { ...init, headers });
}

function text(value: unknown, limit: number) { return typeof value === "string" && value.trim() ? value.trim().slice(0, limit) : null; }
function uuid(value: unknown) { return typeof value === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value) ? value : null; }
