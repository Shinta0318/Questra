import type { PlanningPipelineResult } from "./pipeline.ts";

export function planningHttpStatus(status: PlanningPipelineResult["status"]): number {
  switch (status) {
    case "preview_ready":
    case "needs_clarification":
      return 200;
    case "retryable_error":
      return 503;
    case "manual_path":
      return 422;
  }
}
