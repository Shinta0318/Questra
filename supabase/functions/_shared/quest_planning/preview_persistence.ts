type ServiceFetch = (
  path: string,
  init?: RequestInit,
) => Promise<Response | null>;

export type StoredPreview = {
  id: string;
  approval_token: string;
  plan_payload: Record<string, unknown>;
  expires_at: string;
};

export type PlanningAttemptLookup =
  | { state: "missing" | "incomplete" | "conflict" | "unavailable" }
  | { state: "ready"; preview: StoredPreview; draftId: string };

export function approvalSelectionState(
  preview: Record<string, unknown> | undefined,
  fingerprint: string,
  nowMs = Date.now(),
): "pending" | "already_approved" | "conflict" {
  if (preview?.status === "approved") {
    return preview.approved_selection_fingerprint === fingerprint
      ? "already_approved"
      : "conflict";
  }
  return preview?.status === "pending" &&
      typeof preview.expires_at === "string" &&
      Date.parse(preview.expires_at) > nowMs
    ? "pending"
    : "conflict";
}

export async function planningInputFingerprint(
  input: unknown,
): Promise<string> {
  const canonical = JSON.stringify(
    input,
    (_key, value) =>
      value && typeof value === "object" && !Array.isArray(value)
        ? Object.fromEntries(
          Object.entries(value).sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0),
        )
        : value,
  );
  const bytes = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(canonical),
  );
  return Array.from(
    new Uint8Array(bytes),
    (byte) => byte.toString(16).padStart(2, "0"),
  ).join("");
}

export async function loadReadyPlanningAttempt(
  serviceFetch: ServiceFetch,
  ownerId: string,
  questId: string,
  idempotencyKey: string,
  inputFingerprint: string,
): Promise<PlanningAttemptLookup> {
  const runQuery = new URLSearchParams({
    owner_id: `eq.${ownerId}`,
    idempotency_key: `eq.${idempotencyKey}`,
    select: "id,quest_id,status,execution_versions",
    limit: "1",
  });
  const runResponse = await serviceFetch(
    `/rest/v1/quest_planning_runs?${runQuery}`,
  );
  if (!runResponse?.ok) return { state: "unavailable" };
  const runs = await runResponse.json() as Array<Record<string, unknown>>;
  const run = runs[0];
  if (!run) return { state: "missing" };
  const versions = run.execution_versions as Record<string, unknown> | null;
  if (
    run.quest_id !== questId ||
    versions?.requestFingerprint !== inputFingerprint ||
    typeof run.id !== "string" ||
    run.status === "approved"
  ) return { state: "conflict" };
  if (run.status !== "preview_ready") return { state: "incomplete" };

  const previewQuery = new URLSearchParams({
    owner_id: `eq.${ownerId}`,
    quest_id: `eq.${questId}`,
    planning_run_id: `eq.${run.id}`,
    select: "id,approval_token,plan_payload,status,expires_at",
    order: "created_at.asc",
    limit: "1",
  });
  const previewResponse = await serviceFetch(
    `/rest/v1/quest_plan_previews?${previewQuery}`,
  );
  if (!previewResponse?.ok) return { state: "unavailable" };
  const previews = await previewResponse.json() as Array<
    Record<string, unknown>
  >;
  const preview = previews[0];
  if (!preview) return { state: "incomplete" };
  if (
    preview.status !== "pending" ||
    typeof preview.expires_at !== "string" ||
    !(Date.parse(preview.expires_at) > Date.now()) ||
    typeof preview.id !== "string" ||
    typeof preview.approval_token !== "string" ||
    !preview.plan_payload || typeof preview.plan_payload !== "object" ||
    Array.isArray(preview.plan_payload)
  ) return { state: "conflict" };

  const draftQuery = new URLSearchParams({
    preview_id: `eq.${preview.id}`,
    owner_id: `eq.${ownerId}`,
    quest_id: `eq.${questId}`,
    status: "eq.reviewing",
    select: "id",
    limit: "1",
  });
  const draftResponse = await serviceFetch(
    `/rest/v1/mission_plan_drafts?${draftQuery}`,
  );
  if (!draftResponse?.ok) return { state: "unavailable" };
  const drafts = await draftResponse.json() as Array<Record<string, unknown>>;
  const draftId = drafts[0]?.id;
  if (typeof draftId !== "string") return { state: "incomplete" };
  return { state: "ready", preview: preview as StoredPreview, draftId };
}

export async function claimPlanningRun(
  serviceFetch: ServiceFetch,
  ownerId: string,
  questId: string,
  idempotencyKey: string,
  inputFingerprint: string,
  run: Record<string, unknown>,
): Promise<string | null> {
  const response = await serviceFetch(
    "/rest/v1/quest_planning_runs?on_conflict=owner_id,idempotency_key",
    {
      method: "POST",
      headers: { Prefer: "resolution=ignore-duplicates,return=minimal" },
      body: JSON.stringify({
        ...run,
        owner_id: ownerId,
        quest_id: questId,
        idempotency_key: idempotencyKey,
        execution_versions: {
          ...(run.execution_versions as Record<string, unknown> ?? {}),
          requestFingerprint: inputFingerprint,
        },
      }),
    },
  );
  if (!response?.ok) return null;
  const params = new URLSearchParams({
    owner_id: `eq.${ownerId}`,
    idempotency_key: `eq.${idempotencyKey}`,
    select: "id,quest_id,execution_versions",
    limit: "1",
  });
  const stored = await serviceFetch(`/rest/v1/quest_planning_runs?${params}`);
  if (!stored?.ok) return null;
  const rows = await stored.json() as Array<Record<string, unknown>>;
  const row = rows[0];
  const versions = row?.execution_versions as
    | Record<string, unknown>
    | undefined;
  return row?.quest_id === questId &&
      versions?.requestFingerprint === inputFingerprint &&
      typeof row.id === "string"
    ? row.id
    : null;
}

export async function markPlanningRunReady(
  serviceFetch: ServiceFetch,
  ownerId: string,
  runId: string,
): Promise<boolean> {
  const params = new URLSearchParams({
    id: `eq.${runId}`,
    owner_id: `eq.${ownerId}`,
    status: "neq.approved",
    select: "id",
  });
  const response = await serviceFetch(
    `/rest/v1/quest_planning_runs?${params}`,
    {
      method: "PATCH",
      headers: { Prefer: "return=representation" },
      body: JSON.stringify({
        status: "preview_ready",
        error_category: null,
        completed_at: new Date().toISOString(),
      }),
    },
  );
  if (!response?.ok) return false;
  const rows = await response.json() as Array<Record<string, unknown>>;
  return rows.length === 1 && rows[0].id === runId;
}

export async function rejectPlanningPreview(
  serviceFetch: ServiceFetch,
  ownerId: string,
  previewId: string,
  approvalToken: string,
): Promise<"rejected" | "conflict" | "unavailable"> {
  const params = new URLSearchParams({
    id: `eq.${previewId}`,
    owner_id: `eq.${ownerId}`,
    approval_token: `eq.${approvalToken}`,
    status: "eq.pending",
    select: "id",
  });
  const response = await serviceFetch(
    `/rest/v1/quest_plan_previews?${params}`,
    {
      method: "PATCH",
      headers: { Prefer: "return=representation" },
      body: JSON.stringify({ status: "rejected" }),
    },
  );
  if (!response?.ok) return "unavailable";
  const rows = await response.json() as Array<Record<string, unknown>>;
  return rows.length === 1 && rows[0].id === previewId
    ? "rejected"
    : "conflict";
}

export async function stageApprovedPreviewPlan(
  serviceFetch: ServiceFetch,
  ownerId: string,
  previewId: string,
  selectionFingerprint: string,
  planPayload: Record<string, unknown>,
): Promise<string | null> {
  const inserted = await serviceFetch(
    "/rest/v1/quest_plan_approval_selections?on_conflict=preview_id,selection_fingerprint",
    {
      method: "POST",
      headers: { Prefer: "resolution=ignore-duplicates,return=minimal" },
      body: JSON.stringify({
        owner_id: ownerId,
        preview_id: previewId,
        selection_fingerprint: selectionFingerprint,
        plan_payload: planPayload,
      }),
    },
  );
  if (!inserted?.ok) return null;
  const params = new URLSearchParams({
    owner_id: `eq.${ownerId}`,
    preview_id: `eq.${previewId}`,
    selection_fingerprint: `eq.${selectionFingerprint}`,
    select: "id",
    limit: "2",
  });
  const stored = await serviceFetch(
    `/rest/v1/quest_plan_approval_selections?${params}`,
  );
  if (!stored?.ok) return null;
  const rows = await stored.json() as Array<Record<string, unknown>>;
  return rows.length === 1 && typeof rows[0].id === "string"
    ? rows[0].id
    : null;
}

export async function savePreviewOnce(
  serviceFetch: ServiceFetch,
  ownerId: string,
  questId: string,
  runId: string,
  preview: Record<string, unknown>,
): Promise<StoredPreview | null> {
  const read = async () => {
    const params = new URLSearchParams({
      owner_id: `eq.${ownerId}`,
      quest_id: `eq.${questId}`,
      planning_run_id: `eq.${runId}`,
      select: "id,approval_token,plan_payload,status,expires_at",
      order: "created_at.asc",
      limit: "1",
    });
    const response = await serviceFetch(
      `/rest/v1/quest_plan_previews?${params}`,
    );
    if (!response?.ok) return { available: false, row: null };
    const rows = await response.json() as Array<Record<string, unknown>>;
    return { available: true, row: rows[0] ?? null };
  };
  const first = await read();
  if (!first.available) return null;
  if (!first.row) {
    const response = await serviceFetch(
      "/rest/v1/quest_plan_previews?on_conflict=id",
      {
        method: "POST",
        headers: { Prefer: "resolution=ignore-duplicates,return=minimal" },
        body: JSON.stringify({
          id: runId,
          owner_id: ownerId,
          quest_id: questId,
          planning_run_id: runId,
          plan_payload: preview,
        }),
      },
    );
    if (!response?.ok) return null;
  }
  const stored = first.row ? first : await read();
  const row = stored.row;
  if (
    !stored.available || !row || row.status !== "pending" ||
    typeof row.expires_at !== "string" ||
    !(Date.parse(row.expires_at) > Date.now()) ||
    typeof row.id !== "string" ||
    typeof row.approval_token !== "string" ||
    !row.plan_payload || typeof row.plan_payload !== "object" ||
    Array.isArray(row.plan_payload)
  ) return null;
  return row as StoredPreview;
}
