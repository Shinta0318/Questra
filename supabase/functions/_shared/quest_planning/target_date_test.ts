import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { planningTargetDate } from "./target_date.ts";

Deno.test("Flutter timestamps retain the intended calendar date", () => {
  assertEquals(planningTargetDate("2027-08-01T00:00:00.000"), "2027-08-01");
  assertEquals(planningTargetDate("2027-08-01T00:00:00.000Z"), "2027-08-01");
  assertEquals(
    planningTargetDate("2027-08-01T00:00:00+09:00"),
    "2027-08-01",
  );
  assertEquals(planningTargetDate("2027-08-01"), "2027-08-01");
  assertEquals(planningTargetDate(null), null);
});

Deno.test("invalid deadlines are rejected rather than truncated", () => {
  assertEquals(planningTargetDate("2027-02-30"), undefined);
  assertEquals(planningTargetDate("2027-08-01T00:00:00."), undefined);
  assertEquals(planningTargetDate("2027/08/01"), undefined);
  assertEquals(planningTargetDate(20270801), undefined);
});
