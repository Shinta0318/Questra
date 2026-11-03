import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { planningHttpStatus } from "./http_status.ts";

Deno.test("planning response status preserves retry semantics", () => {
  assertEquals(planningHttpStatus("preview_ready"), 200);
  assertEquals(planningHttpStatus("needs_clarification"), 200);
  assertEquals(planningHttpStatus("retryable_error"), 503);
  assertEquals(planningHttpStatus("retryable_error", 120), 429);
  assertEquals(planningHttpStatus("manual_path"), 422);
});
