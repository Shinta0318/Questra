import assert from "node:assert/strict";
import test from "node:test";

import { executeQuestraTool } from "./tool_server.ts";

const userId = "00000000-0000-4000-8000-000000000001";
const questId = "00000000-0000-4000-8000-000000000002";

test("unimplemented validate_plan cannot report an unverified plan as accepted", async () => {
  const result = await executeQuestraTool("validate_plan", { questId }, {
    userId,
    expectedQuestId: questId,
    traceId: crypto.randomUUID(),
    approved: false,
  });
  assert.deepEqual(result, { ok: false, error: "tool_not_allowed" });
});

test("planning tools read the actual Quest DNA and consented availability schema", async () => {
  const originalFetch = globalThis.fetch;
  const originalUrl = Deno.env.get("SUPABASE_URL");
  const originalKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const requestedPaths: string[] = [];
  let planningConsent = false;
  try {
    Deno.env.set("SUPABASE_URL", "https://example.supabase.co");
    Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "test-service-key");
    globalThis.fetch = (async (input) => {
      const url = new URL(String(input));
      requestedPaths.push(`${url.pathname}${url.search}`);
      if (url.pathname === "/rest/v1/quests" && url.searchParams.get("select") === "id") {
        return Response.json([{ id: questId }]);
      }
      if (url.pathname === "/rest/v1/quests") {
        return Response.json([{ quest_dna: { theme: "learning" }, quest_dna_version: "v2", quest_dna_evaluated_at: null }]);
      }
      if (url.pathname === "/rest/v1/weekly_availability") {
        return Response.json([{
          planning_consent_granted: planningConsent,
          monday_minutes: 30,
          tuesday_minutes: 0,
          wednesday_minutes: 60,
          thursday_minutes: 0,
          friday_minutes: 0,
          saturday_minutes: 0,
          sunday_minutes: 0,
          budget_label: "private budget",
          location: "private location",
          experience: "beginner",
        }]);
      }
      if (url.pathname === "/rest/v1/ai_tool_audit_logs") {
        return Response.json({});
      }
      return Response.json({ error: "unexpected path" }, { status: 404 });
    }) as typeof fetch;

    const context = { userId, traceId: crypto.randomUUID(), approved: false };
    const dna = await executeQuestraTool("get_quest_dna", { questId }, context);
    assert.equal(dna.ok, true);
    assert.deepEqual(dna.data, [{ quest_dna: { theme: "learning" }, quest_dna_version: "v2", quest_dna_evaluated_at: null }]);
    assert.ok(requestedPaths.some((path) => path.includes(`owner_id=eq.${userId}`) && path.includes("quest_dna_version")));

    const withheld = await executeQuestraTool("get_user_planning_preferences", {}, context);
    assert.equal(withheld.ok, true);
    assert.deepEqual(withheld.data, []);

    planningConsent = true;
    const consented = await executeQuestraTool("get_user_planning_preferences", {}, context);
    assert.equal(consented.ok, true);
    assert.deepEqual(consented.data, [{
      weekly_minutes: 90,
      budget_label: "private budget",
      location: "private location",
      experience: "beginner",
      consent_granted: true,
    }]);
    assert.ok(requestedPaths.some((path) => path.includes(`/weekly_availability?user_id=eq.${userId}`)));
    assert.ok(requestedPaths.every((path) => !path.includes("quest_dna_profiles") && !path.includes("planning_context_preferences")));
  } finally {
    globalThis.fetch = originalFetch;
    if (originalUrl === undefined) Deno.env.delete("SUPABASE_URL");
    else Deno.env.set("SUPABASE_URL", originalUrl);
    if (originalKey === undefined) Deno.env.delete("SUPABASE_SERVICE_ROLE_KEY");
    else Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", originalKey);
  }
});

test("planning tools reject invalid and different Quest IDs before database reads", async () => {
  const originalFetch = globalThis.fetch;
  let questReads = 0;
  try {
    globalThis.fetch = (async (input) => {
      if (new URL(String(input)).pathname === "/rest/v1/quests") questReads++;
      return Response.json([]);
    }) as typeof fetch;
    const context = { userId, expectedQuestId: questId, traceId: crypto.randomUUID(), approved: false };
    const invalid = await executeQuestraTool("get_quest_context", { questId: "not-a-uuid" }, context);
    assert.deepEqual(invalid, { ok: false, error: "invalid_arguments" });
    const other = await executeQuestraTool("get_quest_context", { questId: userId }, context);
    assert.deepEqual(other, { ok: false, error: "target_not_owned" });
    assert.equal(questReads, 0);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("planning ownership lookup failure returns a controlled tool error", async () => {
  const originalFetch = globalThis.fetch;
  const originalUrl = Deno.env.get("SUPABASE_URL");
  const originalKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  try {
    Deno.env.set("SUPABASE_URL", "https://example.supabase.co");
    Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "test-service-key");
    globalThis.fetch = (async (input) => {
      if (new URL(String(input)).pathname === "/rest/v1/quests") {
        return Response.json({ error: "database unavailable" }, { status: 503 });
      }
      return Response.json({});
    }) as typeof fetch;
    const result = await executeQuestraTool("get_quest_context", { questId }, {
      userId, expectedQuestId: questId, traceId: crypto.randomUUID(), approved: false,
    });
    assert.deepEqual(result, { ok: false, error: "tool_failed" });
  } finally {
    globalThis.fetch = originalFetch;
    if (originalUrl === undefined) Deno.env.delete("SUPABASE_URL");
    else Deno.env.set("SUPABASE_URL", originalUrl);
    if (originalKey === undefined) Deno.env.delete("SUPABASE_SERVICE_ROLE_KEY");
    else Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", originalKey);
  }
});
