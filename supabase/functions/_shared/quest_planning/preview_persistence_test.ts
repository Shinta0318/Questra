import {
  approvalSelectionState,
  claimPlanningRun,
  loadReadyPlanningAttempt,
  markPlanningRunReady,
  planningInputFingerprint,
  rejectPlanningPreview,
  savePreviewOnce,
  stageApprovedPreviewPlan,
} from "./preview_persistence.ts";
import {
  approvalPlanningWish,
  previewWithPlanningWish,
} from "./approval_wish.ts";

function assertEquals(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, received ${
        JSON.stringify(actual)
      }`,
    );
  }
}

const owner = "00000000-0000-4000-8000-000000000001";
const quest = "00000000-0000-4000-8000-000000000002";
const otherQuest = "00000000-0000-4000-8000-000000000003";
const runId = "00000000-0000-4000-8000-000000000004";
const approvalToken = "00000000-0000-4000-8000-000000000005";
const selectionId = "00000000-0000-4000-8000-000000000006";

Deno.test("edited approval replay accepts only the same approved selection", () => {
  const future = new Date(Date.now() + 60_000).toISOString();
  const past = new Date(Date.now() - 60_000).toISOString();
  const fingerprint = "a".repeat(64);
  assertEquals(
    approvalSelectionState(
      { status: "pending", expires_at: future },
      fingerprint,
    ),
    "pending",
  );
  assertEquals(
    approvalSelectionState(
      { status: "pending", expires_at: past },
      fingerprint,
    ),
    "conflict",
  );
  assertEquals(
    approvalSelectionState({
      status: "approved",
      approved_selection_fingerprint: fingerprint,
    }, fingerprint),
    "already_approved",
  );
  assertEquals(
    approvalSelectionState({
      status: "approved",
      approved_selection_fingerprint: "b".repeat(64),
    }, fingerprint),
    "conflict",
  );
  assertEquals(approvalSelectionState(undefined, fingerprint), "conflict");
});

function fakeStore() {
  const runs: Record<string, unknown>[] = [];
  const previews: Record<string, unknown>[] = [];
  const drafts: Record<string, unknown>[] = [];
  const selections: Record<string, unknown>[] = [];
  let readsFail = false;
  const fetchImpl = (
    path: string,
    init: RequestInit = {},
  ): Promise<Response> => {
    const url = new URL(path, "https://example.test");
    const runTable = url.pathname.endsWith("/quest_planning_runs");
    const previewTable = url.pathname.endsWith("/quest_plan_previews");
    const draftTable = url.pathname.endsWith("/mission_plan_drafts");
    const selectionTable = url.pathname.endsWith(
      "/quest_plan_approval_selections",
    );
    if (init.method === "POST" && runTable) {
      const value = JSON.parse(String(init.body)) as Record<string, unknown>;
      if (
        !runs.some((row) =>
          row.owner_id === value.owner_id &&
          row.idempotency_key === value.idempotency_key
        )
      ) {
        runs.push({ ...value, id: runId });
      }
      return Promise.resolve(new Response(null, { status: 201 }));
    }
    if (init.method === "POST" && previewTable) {
      const value = JSON.parse(String(init.body)) as Record<string, unknown>;
      if (!previews.some((row) => row.id === value.id)) {
        previews.push({
          ...value,
          approval_token: approvalToken,
          status: "pending",
          expires_at: new Date(Date.now() + 60_000).toISOString(),
        });
      }
      return Promise.resolve(new Response(null, { status: 201 }));
    }
    if (init.method === "POST" && selectionTable) {
      const value = JSON.parse(String(init.body)) as Record<string, unknown>;
      if (
        !selections.some((row) =>
          row.preview_id === value.preview_id &&
          row.selection_fingerprint === value.selection_fingerprint
        )
      ) {
        selections.push({ ...value, id: selectionId });
      }
      return Promise.resolve(new Response(null, { status: 201 }));
    }
    if (readsFail) {
      return Promise.resolve(
        Response.json({ error: "unavailable" }, { status: 503 }),
      );
    }
    if (init.method === "PATCH" && runTable) {
      const matching = runs.filter((row) =>
        url.searchParams.get("id") === `eq.${row.id}` &&
        url.searchParams.get("owner_id") === `eq.${row.owner_id}` &&
        row.status !== "approved"
      );
      for (const row of matching) {
        Object.assign(row, JSON.parse(String(init.body)));
      }
      return Promise.resolve(
        Response.json(matching.map((row) => ({ id: row.id }))),
      );
    }
    if (init.method === "PATCH" && previewTable) {
      const matching = previews.filter((row) =>
        url.searchParams.get("id") === `eq.${row.id}` &&
        url.searchParams.get("owner_id") === `eq.${row.owner_id}` &&
        url.searchParams.get("approval_token") ===
          `eq.${row.approval_token}` &&
        url.searchParams.get("status") === `eq.${row.status}`
      );
      for (const row of matching) {
        Object.assign(row, JSON.parse(String(init.body)));
      }
      return Promise.resolve(
        Response.json(matching.map((row) => ({ id: row.id }))),
      );
    }
    if (runTable) {
      return Promise.resolve(
        Response.json(
          runs.filter((row) =>
            url.searchParams.get("owner_id") === `eq.${row.owner_id}` &&
            url.searchParams.get("idempotency_key") ===
              `eq.${row.idempotency_key}`
          ),
        ),
      );
    }
    if (previewTable) {
      return Promise.resolve(
        Response.json(
          previews.filter((row) =>
            url.searchParams.get("owner_id") === `eq.${row.owner_id}` &&
            url.searchParams.get("quest_id") === `eq.${row.quest_id}` &&
            url.searchParams.get("planning_run_id") ===
              `eq.${row.planning_run_id}`
          ),
        ),
      );
    }
    if (draftTable) {
      return Promise.resolve(
        Response.json(
          drafts.filter((row) =>
            url.searchParams.get("owner_id") === `eq.${row.owner_id}` &&
            url.searchParams.get("quest_id") === `eq.${row.quest_id}` &&
            url.searchParams.get("preview_id") === `eq.${row.preview_id}` &&
            url.searchParams.get("status") === `eq.${row.status}`
          ),
        ),
      );
    }
    if (selectionTable) {
      return Promise.resolve(
        Response.json(
          selections.filter((row) =>
            url.searchParams.get("owner_id") === `eq.${row.owner_id}` &&
            url.searchParams.get("preview_id") === `eq.${row.preview_id}` &&
            url.searchParams.get("selection_fingerprint") ===
              `eq.${row.selection_fingerprint}`
          ).map((row) => ({ id: row.id })),
        ),
      );
    }
    return Promise.resolve(
      Response.json({ error: "unexpected" }, { status: 404 }),
    );
  };
  return {
    runs,
    previews,
    drafts,
    selections,
    fetchImpl,
    failReads: () => {
      readsFail = true;
    },
  };
}

Deno.test("planning request fingerprint changes with the Quest or constraints", async () => {
  const first = await planningInputFingerprint({
    questId: quest,
    wish: "Learn English",
    constraints: ["30 minutes"],
  });
  assertEquals(
    first,
    await planningInputFingerprint({
      constraints: ["30 minutes"],
      wish: "Learn English",
      questId: quest,
    }),
  );
  assertEquals(
    first ===
      await planningInputFingerprint({
        questId: otherQuest,
        wish: "Learn English",
        constraints: ["30 minutes"],
      }),
    false,
  );
  assertEquals(
    first ===
      await planningInputFingerprint({
        questId: quest,
        wish: "Learn English",
        constraints: ["60 minutes"],
      }),
    false,
  );
});

Deno.test("same attempt claims one run and rejects changed input or Quest", async () => {
  const store = fakeStore();
  const fingerprint = await planningInputFingerprint({
    questId: quest,
    wish: "Learn English",
  });
  const run = {
    trace_id: "00000000-0000-4000-8000-000000000006",
    status: "preview_ready",
    pipeline_version: "test",
    schema_version: "test",
    execution_versions: { pipeline: "test" },
  };
  assertEquals(
    await claimPlanningRun(
      store.fetchImpl,
      owner,
      quest,
      "attempt-1",
      fingerprint,
      run,
    ),
    runId,
  );
  assertEquals(
    await claimPlanningRun(
      store.fetchImpl,
      owner,
      quest,
      "attempt-1",
      fingerprint,
      run,
    ),
    runId,
  );
  assertEquals(
    await claimPlanningRun(
      store.fetchImpl,
      owner,
      otherQuest,
      "attempt-1",
      fingerprint,
      run,
    ),
    null,
  );
  assertEquals(
    await claimPlanningRun(
      store.fetchImpl,
      owner,
      quest,
      "attempt-1",
      "a".repeat(64),
      run,
    ),
    null,
  );
  assertEquals(store.runs.length, 1);
});

Deno.test("retry reuses one preview and cannot create another for the same run", async () => {
  const store = fakeStore();
  const originalWish =
    "シンガポールへ行きたい\nArcとの確認:\n誰と行く？ 家族と";
  const initial = previewWithPlanningWish({
    routeMissionPlan: { missions: [1] },
  }, originalWish)!;
  const first = await savePreviewOnce(
    store.fetchImpl,
    owner,
    quest,
    runId,
    initial,
  );
  const second = await savePreviewOnce(
    store.fetchImpl,
    owner,
    quest,
    runId,
    previewWithPlanningWish({
      routeMissionPlan: { missions: [2] },
    }, "別の相談")!,
  );
  assertEquals(first?.id, runId);
  assertEquals(second?.id, runId);
  assertEquals(second?.plan_payload, first?.plan_payload);
  assertEquals(approvalPlanningWish(second!.plan_payload), originalWish);
  assertEquals(store.previews.length, 1);
  assertEquals(
    await savePreviewOnce(store.fetchImpl, owner, otherQuest, runId, {}),
    null,
  );
  assertEquals(store.previews.length, 1);
  store.previews[0].expires_at = new Date(Date.now() - 1_000).toISOString();
  assertEquals(
    await savePreviewOnce(store.fetchImpl, owner, quest, runId, {}),
    null,
  );
  assertEquals(store.previews.length, 1);
});

Deno.test("unavailable preview lookup fails closed before inserting", async () => {
  const store = fakeStore();
  store.failReads();
  assertEquals(
    await savePreviewOnce(store.fetchImpl, owner, quest, runId, {}),
    null,
  );
  assertEquals(store.previews.length, 0);
});

Deno.test("completed attempt replays the stored preview without a write", async () => {
  const store = fakeStore();
  const fingerprint = await planningInputFingerprint({
    questId: quest,
    wish: "Learn English",
  });
  assertEquals(
    (await loadReadyPlanningAttempt(
      store.fetchImpl,
      owner,
      quest,
      "attempt-1",
      fingerprint,
    )).state,
    "missing",
  );
  assertEquals(
    await claimPlanningRun(
      store.fetchImpl,
      owner,
      quest,
      "attempt-1",
      fingerprint,
      {
        trace_id: "00000000-0000-4000-8000-000000000006",
        status: "running",
        pipeline_version: "test",
        schema_version: "test",
      },
    ),
    runId,
  );
  const stored = await savePreviewOnce(store.fetchImpl, owner, quest, runId, {
    routeMissionPlan: { missions: [1] },
  });
  assertEquals(
    (await loadReadyPlanningAttempt(
      store.fetchImpl,
      owner,
      quest,
      "attempt-1",
      fingerprint,
    )).state,
    "incomplete",
  );
  store.drafts.push({
    id: "00000000-0000-4000-8000-000000000007",
    owner_id: owner,
    quest_id: quest,
    preview_id: stored?.id,
    status: "reviewing",
  });
  assertEquals(
    (await loadReadyPlanningAttempt(
      store.fetchImpl,
      owner,
      quest,
      "attempt-1",
      fingerprint,
    )).state,
    "incomplete",
  );
  store.runs[0].status = "preview_ready";
  const result = await loadReadyPlanningAttempt(
    store.fetchImpl,
    owner,
    quest,
    "attempt-1",
    fingerprint,
  );
  assertEquals(result.state, "ready");
  if (result.state === "ready") {
    assertEquals(result.preview.plan_payload, stored?.plan_payload);
    assertEquals(result.draftId, store.drafts[0].id);
  }
  assertEquals(store.runs.length, 1);
  assertEquals(store.previews.length, 1);
});

Deno.test("attempt replay rejects changed input, approved runs, and expired previews", async () => {
  const store = fakeStore();
  const fingerprint = await planningInputFingerprint({
    questId: quest,
    wish: "Learn English",
  });
  await claimPlanningRun(
    store.fetchImpl,
    owner,
    quest,
    "attempt-1",
    fingerprint,
    {
      trace_id: "00000000-0000-4000-8000-000000000006",
      status: "preview_ready",
      pipeline_version: "test",
      schema_version: "test",
    },
  );
  assertEquals(
    (await loadReadyPlanningAttempt(
      store.fetchImpl,
      owner,
      otherQuest,
      "attempt-1",
      fingerprint,
    )).state,
    "conflict",
  );
  assertEquals(
    (await loadReadyPlanningAttempt(
      store.fetchImpl,
      owner,
      quest,
      "attempt-1",
      "a".repeat(64),
    )).state,
    "conflict",
  );
  await savePreviewOnce(store.fetchImpl, owner, quest, runId, {});
  store.previews[0].expires_at = new Date(Date.now() - 1_000).toISOString();
  assertEquals(
    (await loadReadyPlanningAttempt(
      store.fetchImpl,
      owner,
      quest,
      "attempt-1",
      fingerprint,
    )).state,
    "conflict",
  );
  store.runs[0].status = "approved";
  assertEquals(
    (await loadReadyPlanningAttempt(
      store.fetchImpl,
      owner,
      quest,
      "attempt-1",
      fingerprint,
    )).state,
    "conflict",
  );
});

Deno.test("attempt replay fails closed when storage cannot be read", async () => {
  const store = fakeStore();
  store.failReads();
  assertEquals(
    (await loadReadyPlanningAttempt(
      store.fetchImpl,
      owner,
      quest,
      "attempt-1",
      "a".repeat(64),
    )).state,
    "unavailable",
  );
});

Deno.test("ready transition requires exactly one matching unapproved run", async () => {
  const store = fakeStore();
  store.runs.push({ id: runId, owner_id: owner, status: "running" });
  assertEquals(await markPlanningRunReady(store.fetchImpl, owner, runId), true);
  assertEquals(store.runs[0].status, "preview_ready");
  assertEquals(
    await markPlanningRunReady(store.fetchImpl, otherQuest, runId),
    false,
  );
  store.runs[0].status = "approved";
  assertEquals(
    await markPlanningRunReady(store.fetchImpl, owner, runId),
    false,
  );
  store.failReads();
  assertEquals(
    await markPlanningRunReady(store.fetchImpl, owner, runId),
    false,
  );
});

Deno.test("only the owner with the approval token can reject a pending preview", async () => {
  const store = fakeStore();
  await savePreviewOnce(store.fetchImpl, owner, quest, runId, {
    routeMissionPlan: { missions: [1] },
  });
  assertEquals(
    await rejectPlanningPreview(
      store.fetchImpl,
      otherQuest,
      runId,
      approvalToken,
    ),
    "conflict",
  );
  assertEquals(
    await rejectPlanningPreview(
      store.fetchImpl,
      owner,
      runId,
      "00000000-0000-4000-8000-000000000099",
    ),
    "conflict",
  );
  assertEquals(store.previews[0].status, "pending");
  assertEquals(
    await rejectPlanningPreview(store.fetchImpl, owner, runId, approvalToken),
    "rejected",
  );
  assertEquals(store.previews[0].status, "rejected");
  assertEquals(
    await rejectPlanningPreview(store.fetchImpl, owner, runId, approvalToken),
    "conflict",
  );
});

Deno.test("preview rejection fails closed when storage is unavailable", async () => {
  const store = fakeStore();
  store.failReads();
  assertEquals(
    await rejectPlanningPreview(store.fetchImpl, owner, runId, approvalToken),
    "unavailable",
  );
});

Deno.test("edited selection is staged once without changing the pending preview", async () => {
  const store = fakeStore();
  await savePreviewOnce(store.fetchImpl, owner, quest, runId, {
    routeMissionPlan: { missions: [1] },
  });
  const replacement = { routeMissionPlan: { missions: [2] } };
  const fingerprint = "a".repeat(64);
  assertEquals(
    await stageApprovedPreviewPlan(
      store.fetchImpl,
      owner,
      runId,
      fingerprint,
      replacement,
    ),
    selectionId,
  );
  assertEquals(
    await stageApprovedPreviewPlan(
      store.fetchImpl,
      owner,
      runId,
      fingerprint,
      replacement,
    ),
    selectionId,
  );
  assertEquals(store.selections.length, 1);
  assertEquals(store.previews[0].plan_payload, {
    routeMissionPlan: { missions: [1] },
  });
});

Deno.test("edited selection staging fails closed when storage cannot be read", async () => {
  const store = fakeStore();
  store.failReads();
  assertEquals(
    await stageApprovedPreviewPlan(
      store.fetchImpl,
      owner,
      runId,
      "b".repeat(64),
      { routeMissionPlan: { missions: [2] } },
    ),
    null,
  );
});
