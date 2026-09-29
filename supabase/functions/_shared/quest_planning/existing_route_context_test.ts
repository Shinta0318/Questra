import assert from "node:assert/strict";
import test from "node:test";

import { buildExistingRouteContext } from "./existing_route_context.ts";

test("existing route context preserves completion and replacement boundaries", () => {
  const context = buildExistingRouteContext([
    {
      id: "pending-id",
      title: "宿泊先を確定する",
      status: "todo",
      required: true,
      order_index: 2,
      generated_by: "manual",
      updated_at: "2026-09-15T01:00:00Z",
    },
    {
      id: "completed-id",
      title: "旅行時期を確定する",
      status: "completed",
      required: true,
      order_index: 1,
      generated_by: "manual",
      updated_at: "2026-09-14T01:00:00Z",
    },
  ]);

  assert.equal(context.applicationMode, "replace_remaining");
  assert.equal(context.existingMissionCount, 2);
  assert.equal(context.completedMissionCount, 1);
  assert.equal(context.replaceableMissionCount, 1);
  assert.deepEqual(context.completedMissionIds, ["completed-id"]);
  assert.deepEqual(context.missions.map((mission) => mission.id), [
    "completed-id",
    "pending-id",
  ]);
  assert.deepEqual(Object.keys(context.baseMissions[0]).sort(), [
    "id",
    "status",
    "updatedAt",
  ]);
});

test("empty route is classified as an initial plan", () => {
  const context = buildExistingRouteContext([]);

  assert.equal(context.applicationMode, "initial");
  assert.equal(context.existingMissionCount, 0);
  assert.deepEqual(context.baseMissions, []);
});
