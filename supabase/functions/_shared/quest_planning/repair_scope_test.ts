import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { missionRepairScope, taskRepairIds } from "./repair_scope.ts";
import { validateRouteMissionPlan, validateTaskPlan } from "./validators.ts";
import { revalidateApprovedMissionPlan } from "./pipeline.ts";

const plan = { missions: [{ clientId: "m1" }, { clientId: "m2" }] };

Deno.test("approved Mission selection rejects schema-invalid plans before AI review", async () => {
  const input = {
    questId: "q1",
    wish: "毎朝走りたい",
    idempotencyKey: "approved-selection-test",
  };
  for (const invalidPlan of [
    { planVersion: 1, questId: "q1", missions: [] },
    { planVersion: 1, questId: "q1", missions: [{ clientId: "m1" }] },
  ]) {
    const result = await revalidateApprovedMissionPlan(
      input, invalidPlan, {}, {}, {}, null,
    );
    assertEquals(result.status, "manual_path");
    assertEquals(result.preview, null);
    assertEquals(result.passes.map((pass) => pass.name), ["approved_subset_schema_validation"]);
    assertEquals(result.issues.length > 0, true);
  }
});

Deno.test("repair targets only real failed Mission IDs", () => {
  assertEquals(
    missionRepairScope(plan, ["m2", "__critic_overall__", "m2", "unknown"]),
    {
      failedMissionClientIds: ["m2"],
      coverageGap: false,
      needsRepair: true,
    },
  );
});

Deno.test("plan-level critic failure alone does not trigger blind repair", () => {
  assertEquals(missionRepairScope(plan, ["__critic_overall__"]), {
    failedMissionClientIds: [],
    coverageGap: false,
    needsRepair: false,
  });
});

Deno.test("coverage gaps can be repaired without fake Mission IDs", () => {
  assertEquals(missionRepairScope(plan, ["__coverage_gap__"]), {
    failedMissionClientIds: [],
    coverageGap: true,
    needsRepair: true,
  });
});

Deno.test("Task repair excludes overall-score markers and unknown IDs", () => {
  const taskPlan = { tasks: [{ clientId: "t1" }, { clientId: "t2" }] };
  assertEquals(
    taskRepairIds(taskPlan, ["t2", "__critic_overall__", "unknown", "t2"]),
    ["t2"],
  );
  assertEquals(taskRepairIds(taskPlan, ["__critic_overall__"]), []);
});

Deno.test("internal markers never become repair targets even if model emits them as IDs", () => {
  const missionPlan = {
    missions: [{ clientId: "__critic_overall__" }, { clientId: "m1" }],
  };
  assertEquals(missionRepairScope(missionPlan, ["__critic_overall__", "m1"]), {
    failedMissionClientIds: ["m1"],
    coverageGap: false,
    needsRepair: true,
  });
  const taskPlan = {
    tasks: [{ clientId: "__plan_structure__" }, { clientId: "t1" }],
  };
  assertEquals(taskRepairIds(taskPlan, ["__plan_structure__", "t1"]), ["t1"]);
});

Deno.test("route Mission validation rejects reserved planning IDs", () => {
  const mission = {
    clientId: "m1",
    title: "Travel arrangements",
    objective: "Book the itinerary",
    successCondition: "Bookings confirmed",
    expectedOutcome: "Confirmed trip",
    reasonRequired: "Travel needs reservations",
    coveredSuccessConditions: ["Trip booked"],
    requiresCurrentFacts: false,
    groundedFactRefs: [],
    childTaskEstimate: 2,
    dependencies: [],
  };
  assertEquals(
    validateRouteMissionPlan({ questId: "q1", missions: [mission] }, "q1")
      .valid,
    true,
  );
  const reserved = validateRouteMissionPlan({
    questId: "q1",
    missions: [{ ...mission, clientId: "__coverage_gap__" }],
  }, "q1");
  assertEquals(reserved.valid, false);
  assertEquals(
    reserved.issues.some((issue) => issue.path.endsWith(".clientId")),
    true,
  );
});

Deno.test("Task validation rejects reserved planning IDs", () => {
  const task = {
    clientId: "t1",
    title: "Compare tickets",
    action: "Compare flight options",
    purpose: "Choose a suitable flight",
    doneCondition: "One flight is selected",
    expectedOutput: "Selected flight",
    estimatedEffortMinutes: 45,
    dependencies: [],
    required: true,
    confidence: 0.8,
  };
  assertEquals(
    validateTaskPlan(
      { questId: "q1", missionClientId: "m1", tasks: [task] },
      "q1",
      "m1",
    ).valid,
    true,
  );
  const reserved = validateTaskPlan(
    {
      questId: "q1",
      missionClientId: "m1",
      tasks: [{ ...task, clientId: "__critic_overall__" }],
    },
    "q1",
    "m1",
  );
  assertEquals(reserved.valid, false);
  assertEquals(
    reserved.issues.some((issue) => issue.path.endsWith(".clientId")),
    true,
  );
});
