import {
  assertEquals,
  assertNotEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  approvalInputSnapshot,
  hasPersonalPlanningContext,
  readApprovalInputSnapshot,
} from "./approval_input.ts";

const wish = "シンガポールへ行きたい\nArcとの確認:\n誰と行く？ 家族と";

Deno.test("edited approval restores the same personal planning conditions", () => {
  const source = {
    questId: "quest-1",
    wish,
    targetDate: "2027-08-01",
    budget: "30万円",
    availableTime: { weekly_minutes: 120 },
    experience: "初めての海外旅行",
    location: "東京",
    constraints: ["子連れ", "長距離歩行を控える"],
    approvedContext: {
      consent_granted: true,
      weekly_minutes: 120,
      budget_label: "30万円",
      location: "東京",
      experience: "初めての海外旅行",
      available_resources: [],
      preferences: ["子連れ"],
      companion_type: "family",
      setback_reasons: [],
      approved_mission_history_summary: null,
    },
    idempotencyKey: "attempt-1",
  };
  const saved = approvalInputSnapshot(source);
  assertNotEquals(saved, null);
  const restored = readApprovalInputSnapshot(
    JSON.parse(JSON.stringify(saved)),
  );
  assertEquals(restored, saved);
  assertEquals(restored?.wish, wish);
  assertEquals(hasPersonalPlanningContext(restored!), true);
  assertEquals("idempotencyKey" in restored!, false);
});

Deno.test("invalid or oversized private context fails before generation", () => {
  const base = {
    wish,
    targetDate: null,
    budget: null,
    availableTime: null,
    experience: null,
    location: null,
    constraints: [],
    approvedContext: null,
  };
  assertEquals(hasPersonalPlanningContext(base), false);
  assertEquals(
    readApprovalInputSnapshot({ ...base, constraints: ["x".repeat(501)] }),
    null,
  );
  assertEquals(
    readApprovalInputSnapshot({
      ...base,
      availableTime: { weekly_minutes: -1 },
    }),
    null,
  );
  assertEquals(
    readApprovalInputSnapshot({
      ...base,
      approvedContext: { consent_granted: true, token: "secret" },
    }),
    null,
  );
  assertEquals(
    readApprovalInputSnapshot({
      ...base,
      approvedContext: { consent_granted: false },
    }),
    null,
  );
  assertEquals(readApprovalInputSnapshot({ ...base, wish: "" }), null);
});

Deno.test("every consented constraint survives planning and edited approval", () => {
  const base = {
    wish,
    targetDate: null,
    budget: null,
    availableTime: null,
    experience: null,
    location: null,
    approvedContext: null,
  };
  const constraints = Array.from(
    { length: 40 },
    (_, index) => `条件${index + 1}`,
  );
  const snapshot = readApprovalInputSnapshot({ ...base, constraints });
  assertEquals(snapshot?.constraints, constraints);
  assertEquals(
    readApprovalInputSnapshot({
      ...base,
      constraints: [...constraints, "超過"],
    }),
    null,
  );
  assertEquals(
    readApprovalInputSnapshot({ ...base, constraints: ["有効", 7] }),
    null,
  );
  assertEquals(
    readApprovalInputSnapshot({
      ...base,
      budget: "x".repeat(121),
      constraints,
    }),
    null,
  );
});
