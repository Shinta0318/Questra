import {
  assertEquals,
  assertNotEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  approvalPlanningWish,
  previewWithPlanningWish,
} from "./approval_wish.ts";

Deno.test("edited approval retains the exact clarified planning wish", () => {
  const wish = "シンガポールに行きたい\nArcとの確認:\n誰と行く？ 家族と";
  const preview = previewWithPlanningWish(
    { questId: "quest-1", routeMissionPlan: { missions: [] } },
    wish,
  );
  assertEquals(preview?.planningWish, wish);
  assertEquals(approvalPlanningWish(preview!), wish);
  assertNotEquals(
    approvalPlanningWish(preview!),
    "シンガポールに行きたい",
  );
});

Deno.test("legacy or malformed previews cannot silently lose answers", () => {
  assertEquals(approvalPlanningWish({ questId: "quest-1" }), null);
  assertEquals(approvalPlanningWish({ planningWish: "" }), null);
  assertEquals(approvalPlanningWish({ planningWish: "a".repeat(1_201) }), null);
  assertEquals(previewWithPlanningWish({}, ""), null);
  assertEquals(previewWithPlanningWish([], "旅行したい"), null);
});
