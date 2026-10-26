import type { PlanningPipelineResult } from "./pipeline.ts";

export function planningHttpStatus(
  status: PlanningPipelineResult["status"],
  retryAfterSeconds?: number,
): number {
  switch (status) {
    case "preview_ready":
    case "needs_clarification":
      return 200;
    case "retryable_error":
      return retryAfterSeconds === undefined ? 503 : 429;
    case "manual_path":
      return 422;
  }
}
